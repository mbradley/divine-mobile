// ABOUTME: Real sensor data collection service for ProofMode using device accelerometer, gyroscope, and magnetometer
// ABOUTME: Provides periodic sensor sampling and graceful degradation when sensors are unavailable

import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service for collecting device sensor data during video recording
class ProofModeSensorCollector {
  Timer? _periodicTimer;
  StreamSubscription<AccelerometerEvent>? _accelSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroSubscription;
  StreamSubscription<MagnetometerEvent>? _magSubscription;

  AccelerometerEvent? _lastAccelEvent;
  GyroscopeEvent? _lastGyroEvent;
  MagnetometerEvent? _lastMagEvent;

  ProofModeSensorCollector({bool initializeSensors = true}) {
    if (initializeSensors) {
      _initializeSensorListeners();
    }
  }

  /// Initialize sensor stream listeners to cache latest values
  void _initializeSensorListeners() {
    // Initialize each sensor stream independently with error handling
    // This allows partial sensor availability (e.g., if only accelerometer works)

    try {
      _accelSubscription = accelerometerEventStream().listen(
        (event) {
          _lastAccelEvent = event;
        },
        onError: (error) {
          // Silently handle errors - sensors may not be available in test environment
          // or on certain devices
        },
        cancelOnError: false,
      );
    } catch (e) {
      // Sensor not available - will return zero values
    }

    try {
      _gyroSubscription = gyroscopeEventStream().listen(
        (event) {
          _lastGyroEvent = event;
        },
        onError: (error) {
          // Silently handle errors
        },
        cancelOnError: false,
      );
    } catch (e) {
      // Sensor not available - will return zero values
    }

    try {
      _magSubscription = magnetometerEventStream().listen(
        (event) {
          _lastMagEvent = event;
        },
        onError: (error) {
          // Silently handle errors
        },
        cancelOnError: false,
      );
    } catch (e) {
      // Sensor not available - will return zero values
    }
  }

  /// Collect a single snapshot of all sensor data
  ///
  /// Returns a Map containing:
  /// - timestamp: ISO8601 formatted timestamp
  /// - accelerometer: {x, y, z} in m/s^2
  /// - gyroscope: {x, y, z} in rad/s
  /// - magnetometer: {x, y, z} in μT (microtesla)
  ///
  /// If sensors are unavailable, returns null values or zero values gracefully.
  Future<Map<String, dynamic>> collectSensorSnapshot({
    Duration timeout = const Duration(milliseconds: 500),
  }) async {
    final timestamp = DateTime.now();

    // Use cached sensor values (most recent from streams)
    // This avoids waiting for new events and handles sensor unavailability gracefully
    final accelerometer = _lastAccelEvent != null
        ? {
            'x': _lastAccelEvent!.x,
            'y': _lastAccelEvent!.y,
            'z': _lastAccelEvent!.z,
          }
        : {
            'x': 0.0,
            'y': 0.0,
            'z': 0.0,
          };

    final gyroscope = _lastGyroEvent != null
        ? {
            'x': _lastGyroEvent!.x,
            'y': _lastGyroEvent!.y,
            'z': _lastGyroEvent!.z,
          }
        : {
            'x': 0.0,
            'y': 0.0,
            'z': 0.0,
          };

    final magnetometer = _lastMagEvent != null
        ? {
            'x': _lastMagEvent!.x,
            'y': _lastMagEvent!.y,
            'z': _lastMagEvent!.z,
          }
        : {
            'x': 0.0,
            'y': 0.0,
            'z': 0.0,
          };

    return {
      'timestamp': timestamp.toIso8601String(),
      'accelerometer': accelerometer,
      'gyroscope': gyroscope,
      'magnetometer': magnetometer,
    };
  }

  /// Start periodic sensor data collection at specified interval
  ///
  /// Calls [onSnapshot] with each collected snapshot at [interval] frequency.
  /// Continues until [stopPeriodicCollection] is called.
  void startPeriodicCollection({
    required Duration interval,
    required void Function(Map<String, dynamic> snapshot) onSnapshot,
  }) {
    // Stop any existing timer
    stopPeriodicCollection();

    _periodicTimer = Timer.periodic(interval, (timer) async {
      try {
        final snapshot = await collectSensorSnapshot();
        onSnapshot(snapshot);
      } catch (e) {
        Log.error('Error collecting periodic sensor snapshot: $e',
            name: 'ProofModeSensorCollector', category: LogCategory.system);
      }
    });

    Log.debug('Started periodic sensor collection with interval: $interval',
        name: 'ProofModeSensorCollector', category: LogCategory.system);
  }

  /// Stop periodic sensor data collection
  void stopPeriodicCollection() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    Log.debug('Stopped periodic sensor collection',
        name: 'ProofModeSensorCollector', category: LogCategory.system);
  }

  /// Clean up resources and stop all sensor streams
  void dispose() {
    stopPeriodicCollection();
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _magSubscription?.cancel();
    _accelSubscription = null;
    _gyroSubscription = null;
    _magSubscription = null;
    Log.debug('Disposed sensor collector',
        name: 'ProofModeSensorCollector', category: LogCategory.system);
  }
}
