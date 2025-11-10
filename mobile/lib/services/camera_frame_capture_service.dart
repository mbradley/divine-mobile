// ABOUTME: Real-time camera frame capture service for ProofMode frame hashing during video recording
// ABOUTME: Extracts frame data from CameraImage and converts to Uint8List for SHA256 hashing

import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/services/proofmode_session_service.dart';

/// Service for capturing and processing camera frames during video recording
class CameraFrameCaptureService {
  final ProofModeSessionService _sessionService;
  int _frameCounter = 0;

  CameraFrameCaptureService(this._sessionService);

  /// Reset frame counter (call when starting new recording)
  void reset() {
    _frameCounter = 0;
  }

  /// Process incoming camera frame from video recording stream
  /// This is called by CameraController.startVideoRecording(onAvailable: callback)
  Future<void> onFrameAvailable(CameraImage image) async {
    try {
      // Check if ProofMode session is active and recording
      if (_sessionService.currentSession == null ||
          !_sessionService.isRecording) {
        return;
      }

      _frameCounter++;

      // Extract frame bytes from CameraImage
      final frameBytes = await extractFrameBytes(image);

      // Pass to ProofMode session service for hashing and storage
      await _sessionService.captureFrame(frameBytes);
    } catch (e, stackTrace) {
      Log.error('Failed to process camera frame: $e\n$stackTrace',
          name: 'CameraFrameCaptureService', category: LogCategory.system);
      // Don't rethrow - frame capture errors should not stop video recording
    }
  }

  /// Extract raw bytes from CameraImage for hashing
  /// Supports YUV420 (Android), BGRA8888 (iOS), and other formats
  Future<Uint8List> extractFrameBytes(CameraImage image) async {
    try {
      switch (image.format.group) {
        case ImageFormatGroup.yuv420:
          return _convertYUV420ToBytes(image);
        case ImageFormatGroup.bgra8888:
          return _convertBGRA8888ToBytes(image);
        case ImageFormatGroup.jpeg:
          return _convertJPEGToBytes(image);
        case ImageFormatGroup.nv21:
          return _convertNV21ToBytes(image);
        default:
          Log.warning(
              'Unsupported image format: ${image.format.group}, using raw plane data',
              name: 'CameraFrameCaptureService',
              category: LogCategory.system);
          return _convertRawPlanesToBytes(image);
      }
    } catch (e) {
      Log.error('Failed to convert CameraImage to bytes: $e',
          name: 'CameraFrameCaptureService', category: LogCategory.system);
      rethrow;
    }
  }

  /// Convert YUV420 format to bytes (most common on Android)
  Uint8List _convertYUV420ToBytes(CameraImage image) {
    // YUV420 has 3 planes: Y (luminance), U (chrominance), V (chrominance)
    // For hashing purposes, we concatenate all plane data
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final yBytes = yPlane.bytes;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;

    // Concatenate all planes
    final totalSize = yBytes.length + uBytes.length + vBytes.length;
    final result = Uint8List(totalSize);

    int offset = 0;
    result.setRange(offset, offset + yBytes.length, yBytes);
    offset += yBytes.length;
    result.setRange(offset, offset + uBytes.length, uBytes);
    offset += uBytes.length;
    result.setRange(offset, offset + vBytes.length, vBytes);

    return result;
  }

  /// Convert BGRA8888 format to bytes (most common on iOS)
  Uint8List _convertBGRA8888ToBytes(CameraImage image) {
    // BGRA8888 typically has a single plane with 4 bytes per pixel
    return image.planes[0].bytes;
  }

  /// Convert JPEG format to bytes
  Uint8List _convertJPEGToBytes(CameraImage image) {
    // JPEG is already compressed, use as-is
    return image.planes[0].bytes;
  }

  /// Convert NV21 format to bytes (Android alternative format)
  Uint8List _convertNV21ToBytes(CameraImage image) {
    // NV21 is similar to YUV420 but with interleaved U/V plane
    final yPlane = image.planes[0].bytes;
    final uvPlane = image.planes[1].bytes;

    final totalSize = yPlane.length + uvPlane.length;
    final result = Uint8List(totalSize);

    result.setRange(0, yPlane.length, yPlane);
    result.setRange(yPlane.length, totalSize, uvPlane);

    return result;
  }

  /// Convert raw planes to bytes (fallback for unknown formats)
  Uint8List _convertRawPlanesToBytes(CameraImage image) {
    // Concatenate all plane data
    int totalSize = 0;
    for (final plane in image.planes) {
      totalSize += plane.bytes.length;
    }

    final result = Uint8List(totalSize);
    int offset = 0;

    for (final plane in image.planes) {
      result.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }

    return result;
  }

  /// Get current frame count
  int get frameCount => _frameCounter;
}
