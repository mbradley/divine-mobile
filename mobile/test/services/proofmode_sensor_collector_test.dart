// ABOUTME: Test suite for ProofModeSensorCollector that validates sensor data structure and graceful degradation
// ABOUTME: Real sensor accuracy validation requires integration testing on physical devices with sensor hardware

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/proofmode_sensor_collector.dart';

void main() {
  // NOTE: These tests validate data structure and error handling logic.
  // Real sensor readings require physical device testing (integration tests).
  // In test environment without sensors, the service gracefully returns zero values.

  group('ProofModeSensorCollector - Structure & Error Handling', () {
    test('collectSensorSnapshot returns valid data structure', () async {
      final collector = ProofModeSensorCollector(initializeSensors: false);

      final snapshot = await collector.collectSensorSnapshot();

      // Validate structure
      expect(snapshot, isA<Map<String, dynamic>>());
      expect(snapshot.containsKey('timestamp'), isTrue);
      expect(snapshot.containsKey('accelerometer'), isTrue);
      expect(snapshot.containsKey('gyroscope'), isTrue);
      expect(snapshot.containsKey('magnetometer'), isTrue);

      // Validate timestamp format
      final timestamp = snapshot['timestamp'] as String;
      expect(() => DateTime.parse(timestamp), returnsNormally);

      // Validate sensor data structure (values will be zero in test environment)
      final accel = snapshot['accelerometer'] as Map<String, dynamic>;
      expect(accel.containsKey('x'), isTrue);
      expect(accel.containsKey('y'), isTrue);
      expect(accel.containsKey('z'), isTrue);

      final gyro = snapshot['gyroscope'] as Map<String, dynamic>;
      expect(gyro.containsKey('x'), isTrue);
      expect(gyro.containsKey('y'), isTrue);
      expect(gyro.containsKey('z'), isTrue);

      final mag = snapshot['magnetometer'] as Map<String, dynamic>;
      expect(mag.containsKey('x'), isTrue);
      expect(mag.containsKey('y'), isTrue);
      expect(mag.containsKey('z'), isTrue);

      collector.dispose();
    });

    test('collectSensorSnapshot includes timestamp in correct format', () async {
      final collector = ProofModeSensorCollector(initializeSensors: false);

      final snapshot = await collector.collectSensorSnapshot();

      final timestamp = snapshot['timestamp'] as String;
      final parsedTime = DateTime.parse(timestamp);

      // Timestamp should be recent (within last second)
      final now = DateTime.now();
      final difference = now.difference(parsedTime).inSeconds.abs();
      expect(difference, lessThan(2));

      collector.dispose();
    });

    test('collectSensorSnapshot gracefully handles sensor unavailability', () async {
      final collector = ProofModeSensorCollector(initializeSensors: false);

      // Should not throw even without sensor hardware
      expect(() async => await collector.collectSensorSnapshot(), returnsNormally);

      final snapshot = await collector.collectSensorSnapshot();

      // Should still return valid structure
      expect(snapshot, isA<Map<String, dynamic>>());
      expect(snapshot.containsKey('timestamp'), isTrue);
      expect(snapshot.containsKey('accelerometer'), isTrue);
      expect(snapshot.containsKey('gyroscope'), isTrue);
      expect(snapshot.containsKey('magnetometer'), isTrue);

      collector.dispose();
    });

    test('collectSensorSnapshot timeout parameter is accepted', () async {
      final collector = ProofModeSensorCollector(initializeSensors: false);

      // Should accept timeout parameter without error
      final snapshot = await collector.collectSensorSnapshot(
        timeout: const Duration(milliseconds: 100),
      );

      expect(snapshot, isA<Map<String, dynamic>>());

      collector.dispose();
    });

    test('periodic collection can be started and stopped', () async {
      final collector = ProofModeSensorCollector(initializeSensors: false);
      final snapshots = <Map<String, dynamic>>[];

      // Start collection
      collector.startPeriodicCollection(
        interval: const Duration(milliseconds: 50),
        onSnapshot: (snapshot) => snapshots.add(snapshot),
      );

      // Wait for some snapshots
      await Future.delayed(const Duration(milliseconds: 180));

      // Stop collection
      collector.stopPeriodicCollection();

      final countAfterStop = snapshots.length;

      // Wait longer - should not collect more
      await Future.delayed(const Duration(milliseconds: 150));

      expect(snapshots.length, equals(countAfterStop));

      // Should have collected some snapshots (at least 1)
      expect(snapshots.length, greaterThanOrEqualTo(1));

      collector.dispose();
    });

    test('dispose stops periodic collection', () async {
      final collector = ProofModeSensorCollector(initializeSensors: false);
      final snapshots = <Map<String, dynamic>>[];

      collector.startPeriodicCollection(
        interval: const Duration(milliseconds: 50),
        onSnapshot: (snapshot) => snapshots.add(snapshot),
      );

      await Future.delayed(const Duration(milliseconds: 100));

      // Dispose should stop collection
      collector.dispose();

      final countAfterDispose = snapshots.length;
      await Future.delayed(const Duration(milliseconds: 100));

      expect(snapshots.length, equals(countAfterDispose));
    });

    test('can create multiple collectors independently', () async {
      final collector1 = ProofModeSensorCollector(initializeSensors: false);
      final collector2 = ProofModeSensorCollector(initializeSensors: false);

      final snapshot1 = await collector1.collectSensorSnapshot();
      final snapshot2 = await collector2.collectSensorSnapshot();

      expect(snapshot1, isA<Map<String, dynamic>>());
      expect(snapshot2, isA<Map<String, dynamic>>());

      collector1.dispose();
      collector2.dispose();
    });
  });

  group('ProofModeSensorCollector - Physical Device Integration Tests', () {
    // These tests require a physical device with sensor hardware
    // Run with: flutter test --dart-define=INTEGRATION_TEST=true

    test('INTEGRATION: real sensors provide non-zero readings during movement',
        () async {
      // Skip if not running integration tests
      const integrationTest = bool.fromEnvironment('INTEGRATION_TEST');
      if (!integrationTest) {
        markTestSkipped('Requires physical device - run with --dart-define=INTEGRATION_TEST=true');
      }

      final collector = ProofModeSensorCollector();

      // Wait for sensors to initialize
      await Future.delayed(const Duration(milliseconds: 500));

      final snapshot = await collector.collectSensorSnapshot();

      // On a real device with movement, at least one axis should be non-zero
      final accel = snapshot['accelerometer'] as Map<String, dynamic>;
      final gyro = snapshot['gyroscope'] as Map<String, dynamic>;
      final mag = snapshot['magnetometer'] as Map<String, dynamic>;

      // At minimum, accelerometer should show gravity (~9.8 m/s^2 on one axis)
      final accelMagnitude = ((accel['x'] as double).abs() +
              (accel['y'] as double).abs() +
              (accel['z'] as double).abs())
          .abs();

      expect(accelMagnitude, greaterThan(5.0),
          reason: 'Accelerometer should detect gravity');

      collector.dispose();
    }, skip: true); // Skipped by default - run manually on device
  });
}
