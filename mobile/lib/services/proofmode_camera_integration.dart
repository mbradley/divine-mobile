// ABOUTME: ProofMode camera integration for real-time frame capture during vine recording
// ABOUTME: Coordinates camera recording with ProofMode session management and frame hashing

import 'camera_service.dart';
import 'camera_service_impl.dart';
import 'proofmode_key_service.dart';
import 'proofmode_attestation_service.dart';
import 'proofmode_session_service.dart';
import 'camera_frame_capture_service.dart';
import 'proofmode_config.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Result of ProofMode-enabled recording
class ProofModeVineRecordingResult extends VineRecordingResult {
  final bool hasProof;
  final String? proofLevel;
  final Map<String, dynamic>? proofManifest;

  ProofModeVineRecordingResult({
    required super.videoFile,
    required super.duration,
    this.hasProof = false,
    this.proofLevel,
    this.proofManifest,
  });
}

/// ProofMode camera integration service
class ProofModeCameraIntegration {
  final CameraService _cameraService;
  final ProofModeSessionService _sessionService;
  late final CameraFrameCaptureService _frameCaptureService;

  ProofModeCameraIntegration(
    this._cameraService,
    ProofModeKeyService keyService,
    ProofModeAttestationService attestationService,
    this._sessionService,
  ) {
    _frameCaptureService = CameraFrameCaptureService(_sessionService);
  }

  Future<void> initialize() async {
    // Initialize ProofMode services
    await _sessionService.ensureInitialized();
  }

  Future<void> startRecording() async {
    // Check if ProofMode is enabled
    final proofModeEnabled = await ProofModeConfig.isCaptureEnabled;

    if (proofModeEnabled) {
      // Start ProofMode session
      await _sessionService.startSession();
      await _sessionService.startRecordingSegment();

      // Set up frame capture callback if camera supports it
      if (_cameraService case final CameraServiceImpl cameraImpl) {
        cameraImpl.setFrameCallback((image) {
          // Process frame asynchronously to avoid blocking recording
          _frameCaptureService.onFrameAvailable(image);
        });
        Log.info('Frame capture enabled for recording',
            name: 'ProofModeCameraIntegration', category: LogCategory.system);
      } else {
        Log.warning('Camera service does not support frame capture',
            name: 'ProofModeCameraIntegration', category: LogCategory.system);
      }
    }

    // Start camera recording (with frame streaming if callback is set)
    await _cameraService.startRecording();
  }

  Future<ProofModeVineRecordingResult> stopRecording() async {
    final result = await _cameraService.stopRecording();

    // Check if we had an active ProofMode session
    final proofSession = _sessionService.currentSession;

    if (proofSession != null) {
      // Stop the current recording segment
      await _sessionService.stopRecordingSegment();

      // Clear frame capture callback
      if (_cameraService case final CameraServiceImpl cameraImpl) {
        cameraImpl.setFrameCallback(null);
      }

      // Finalize the session and generate proof manifest
      // Note: We don't have the final video hash yet - that would be computed after encoding
      // For now, we return the proof data we've collected
      final manifest = {
        'sessionId': proofSession.sessionId,
        'segments': proofSession.segments.length,
        'frameHashes': proofSession.frameHashes.length,
        'interactions': proofSession.interactions.length,
        'hasDeviceAttestation': proofSession.deviceAttestation != null,
      };

      return ProofModeVineRecordingResult(
        videoFile: result.videoFile,
        duration: result.duration,
        hasProof: true,
        proofLevel: _determineProofLevel(proofSession),
        proofManifest: manifest,
      );
    } else {
      // No ProofMode session - return standard result
      return ProofModeVineRecordingResult(
        videoFile: result.videoFile,
        duration: result.duration,
        hasProof: false,
        proofLevel: 'unverified',
        proofManifest: null,
      );
    }
  }

  String _determineProofLevel(ProofSession session) {
    if (session.deviceAttestation != null &&
        session.deviceAttestation!.isHardwareBacked) {
      return 'verified_mobile';
    } else if (session.deviceAttestation != null) {
      return 'verified_web';
    } else {
      return 'basic_proof';
    }
  }

  bool get hasActiveProofSession => _sessionService.currentSession != null;

  void recordTouchInteraction() {
    if (_sessionService.currentSession != null) {
      // Record touch at center of screen (coordinate handling would be done by caller)
      _sessionService.recordInteraction('touch', 0.5, 0.5);
    }
  }

  Future<void> pauseRecording() async {
    if (_sessionService.currentSession != null) {
      await _sessionService.pauseRecording();
    }
  }

  Future<void> resumeRecording() async {
    if (_sessionService.currentSession != null) {
      await _sessionService.resumeRecording();
    }
  }

  Future<void> cancelRecording() async {
    // Clear frame capture callback
    if (_cameraService case final CameraServiceImpl cameraImpl) {
      cameraImpl.setFrameCallback(null);
    }

    if (_sessionService.currentSession != null) {
      await _sessionService.cancelSession();
    }
  }

  void dispose() {
    // Clean up resources
    if (_cameraService case final CameraServiceImpl cameraImpl) {
      cameraImpl.setFrameCallback(null);
    }
  }
}
