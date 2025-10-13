// ABOUTME: Integration tests for ProofMode session lifecycle during video recording
// ABOUTME: Tests ProofModeSessionService integration with VineRecordingController

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/services/proofmode_session_service.dart' as proofmode;
import 'package:openvine/services/vine_recording_controller.dart';

// Generate mocks
@GenerateMocks([proofmode.ProofModeSessionService])
import 'proofmode_recording_integration_test.mocks.g.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProofMode Recording Integration', () {
    late MockProofModeSessionService mockProofModeService;
    late File testVideoFile;

    setUp(() async {
      mockProofModeService = MockProofModeSessionService();

      // Create a minimal test video file for finishRecording() to hash
      testVideoFile = File('/tmp/test_recording.mov');
      await testVideoFile.writeAsBytes([
        // Minimal MP4/MOV header (ftyp atom)
        0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, // ftyp header
        0x69, 0x73, 0x6F, 0x6D, 0x00, 0x00, 0x02, 0x00, // isom brand
        0x69, 0x73, 0x6F, 0x6D, 0x69, 0x73, 0x6F, 0x32, // compatible brands
        0x61, 0x76, 0x63, 0x31, 0x6D, 0x70, 0x34, 0x31, // more brands
      ]);

      // Mock native camera interface for testing
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('openvine/native_camera'),
        (MethodCall methodCall) async {
          switch (methodCall.method) {
            case 'initialize':
              return true;
            case 'startPreview':
              return true;
            case 'startRecording':
              return true;
            case 'stopRecording':
              return testVideoFile.path;
            case 'finishRecording':
              return testVideoFile.path;
            default:
              return null;
          }
        },
      );
    });

    tearDown(() async {
      // Clean up test video file
      if (await testVideoFile.exists()) {
        await testVideoFile.delete();
      }

      // Clean up mock camera handler
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('openvine/native_camera'),
        null,
      );
    });

    test('startRecording initiates ProofMode session on first segment', () async {
      // Arrange: Mock ProofMode service to return a session ID
      when(mockProofModeService.startSession())
          .thenAnswer((_) async => 'test-session-123');
      when(mockProofModeService.startRecordingSegment())
          .thenAnswer((_) async => {});

      // Act: Create controller with ProofMode and start recording
      final controller = VineRecordingController(
        proofModeSession: mockProofModeService,
      );

      await controller.initialize();
      await controller.startRecording();

      // Assert: Verify ProofMode session was started
      verify(mockProofModeService.startSession()).called(1);
      verify(mockProofModeService.startRecordingSegment()).called(1);

      // Cleanup
      controller.dispose();
    });

    test('stopRecording stops ProofMode segment', () async {
      // Arrange
      when(mockProofModeService.startSession())
          .thenAnswer((_) async => 'test-session-123');
      when(mockProofModeService.startRecordingSegment())
          .thenAnswer((_) async => {});
      when(mockProofModeService.stopRecordingSegment())
          .thenAnswer((_) async => {});

      // Act: Create controller, start recording, then stop
      final controller = VineRecordingController(
        proofModeSession: mockProofModeService,
      );

      await controller.initialize();
      await controller.startRecording();
      await controller.stopRecording();

      // Assert: Verify segment was stopped
      verify(mockProofModeService.stopRecordingSegment()).called(1);

      // Cleanup
      controller.dispose();
    });

    test('finishRecording returns video File and ProofManifest', () async {
      // Arrange: Mock a complete ProofMode session
      final now = DateTime.now();
      final mockManifest = proofmode.ProofManifest(
        sessionId: 'test-session-123',
        challengeNonce: 'challenge-nonce-123',
        vineSessionStart: now,
        vineSessionEnd: now.add(const Duration(seconds: 2)),
        segments: [
          proofmode.RecordingSegment(
            segmentId: 'segment-1',
            startTime: now,
            endTime: now.add(const Duration(seconds: 2)),
            frameHashes: ['hash1', 'hash2'],
          ),
        ],
        pauseProofs: [],
        interactions: [],
        finalVideoHash: 'final-video-hash-abc123',
      );

      when(mockProofModeService.startSession())
          .thenAnswer((_) async => 'test-session-123');
      when(mockProofModeService.startRecordingSegment())
          .thenAnswer((_) async => {});
      when(mockProofModeService.stopRecordingSegment())
          .thenAnswer((_) async => {});
      when(mockProofModeService.finalizeSession(any))
          .thenAnswer((_) async => mockManifest);

      // Act: Create controller, record, and finish
      final controller = VineRecordingController(
        proofModeSession: mockProofModeService,
      );

      await controller.initialize();
      await controller.startRecording();
      await controller.stopRecording();
      final result = await controller.finishRecording();

      // Assert: Should return tuple (File?, ProofManifest?)
      final (videoFile, proofManifest) = result;
      expect(videoFile, isNotNull); // File
      expect(proofManifest, equals(mockManifest)); // ProofManifest

      // Verify ProofMode session was finalized with video hash
      verify(mockProofModeService.finalizeSession(any)).called(1);

      // Cleanup
      controller.dispose();
    });

    test('recording works without ProofMode service (null service)', () async {
      // Arrange & Act: Create controller with null ProofMode service
      final controller = VineRecordingController(
        proofModeSession: null,
      );

      await controller.initialize();
      await controller.startRecording();
      await controller.stopRecording();
      final result = await controller.finishRecording();

      // Assert: Should return video File but null ProofManifest
      final (videoFile, proofManifest) = result;
      expect(videoFile, isNotNull); // File exists
      expect(proofManifest, isNull); // No ProofManifest

      // Verify no ProofMode methods were called (service is null)
      // Note: No verification needed since service is null

      // Cleanup
      controller.dispose();
    });

    test('ProofMode session survives pause and resume cycle', () async {
      // Arrange
      when(mockProofModeService.startSession())
          .thenAnswer((_) async => 'test-session-123');
      when(mockProofModeService.startRecordingSegment())
          .thenAnswer((_) async => {});
      when(mockProofModeService.stopRecordingSegment())
          .thenAnswer((_) async => {});
      when(mockProofModeService.pauseRecording())
          .thenAnswer((_) async => {});
      when(mockProofModeService.resumeRecording())
          .thenAnswer((_) async => {});

      // Act: Create controller and do pause/resume cycle
      final controller = VineRecordingController(
        proofModeSession: mockProofModeService,
      );

      await controller.initialize();
      await controller.startRecording();  // First segment
      await controller.stopRecording();
      await controller.startRecording();  // Resume/second segment

      // Assert: Verify stop and start were called for pause/resume cycle
      verify(mockProofModeService.stopRecordingSegment()).called(1);
      verify(mockProofModeService.startRecordingSegment()).called(greaterThan(1));

      // Cleanup
      controller.dispose();
    });

    test('ProofMode session handles recording errors gracefully', () async {
      // Arrange: Mock ProofMode service to throw error
      when(mockProofModeService.startSession())
          .thenThrow(Exception('ProofMode initialization failed'));

      // Act: Create controller with failing ProofMode service
      final controller = VineRecordingController(
        proofModeSession: mockProofModeService,
      );

      await controller.initialize();

      // Should not throw - recording continues despite ProofMode failure
      await controller.startRecording();

      // Assert: Recording should continue even if ProofMode fails
      expect(controller.state, equals(VineRecordingState.recording));

      // Cleanup
      controller.dispose();
    });

    test('finishRecording calculates SHA256 hash of final video', () async {
      // Arrange
      when(mockProofModeService.startSession())
          .thenAnswer((_) async => 'test-session-123');
      when(mockProofModeService.startRecordingSegment())
          .thenAnswer((_) async => {});
      when(mockProofModeService.stopRecordingSegment())
          .thenAnswer((_) async => {});
      when(mockProofModeService.finalizeSession(any))
          .thenAnswer((_) async {
        final testTime = DateTime.now();
        return proofmode.ProofManifest(
          sessionId: 'test-session-123',
          challengeNonce: 'test-nonce',
          vineSessionStart: testTime,
          vineSessionEnd: testTime.add(const Duration(seconds: 1)),
          segments: [],
          pauseProofs: [],
          interactions: [],
          finalVideoHash: 'captured-hash',
        );
      });

      // Act: Create controller and record video
      final controller = VineRecordingController(
        proofModeSession: mockProofModeService,
      );

      await controller.initialize();
      await controller.startRecording();
      await controller.stopRecording();
      await controller.finishRecording();

      // Assert: Verify finalizeSession was called with a non-empty videoHash
      final captured = verify(mockProofModeService.finalizeSession(
        captureAny,
      )).captured;

      expect(captured.length, equals(1));
      expect(captured[0], isNotNull);
      expect(captured[0], isNotEmpty);
      expect(captured[0], matches(RegExp(r'^[a-f0-9]{64}$'))); // SHA256 hex format

      // Cleanup
      controller.dispose();
    });
  });
}
