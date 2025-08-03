// ABOUTME: Helper utilities for real integration tests without over-mocking
// ABOUTME: Provides real Nostr relay connections and minimal platform channel mocking

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/app_config.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:openvine/services/nostr_key_manager.dart';

/// Setup real integration test environment with minimal mocking
/// Only mocks platform channels that can't be tested, uses real Nostr connections
class RealIntegrationTestHelper {
  static bool _isSetup = false;

  /// Setup test environment with platform channel mocks and real Nostr
  static Future<void> setupTestEnvironment() async {
    if (_isSetup) return;

    TestWidgetsFlutterBinding.ensureInitialized();

    // Mock platform channels that can't run in test environment
    _setupPlatformChannelMocks();

    _isSetup = true;
  }

  /// Create a real NostrService with embedded relay
  static Future<NostrService> createRealNostrService() async {
    await setupTestEnvironment();

    final keyManager = NostrKeyManager();
    // Note: May need to set up test keys differently based on actual API
    
    final nostrService = NostrService(keyManager);
    await nostrService.initialize();

    // Embedded relay is automatically started during initialization
    // No need for external relay connections

    return nostrService;
  }

  /// Setup minimal platform channel mocks (only what's needed, not business logic)
  static void _setupPlatformChannelMocks() {
    // Mock SharedPreferences
    const MethodChannel prefsChannel = MethodChannel('plugins.flutter.io/shared_preferences');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      prefsChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getAll') {
          return <String, dynamic>{};
        }
        if (methodCall.method == 'setString' || methodCall.method == 'setStringList') {
          return true;
        }
        return null;
      },
    );

    // Mock connectivity
    const MethodChannel connectivityChannel = MethodChannel('dev.fluttercommunity.plus/connectivity');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      connectivityChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'check') {
          return ['wifi']; // Always online for tests
        }
        return null;
      },
    );

    // Mock secure storage
    const MethodChannel secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      secureStorageChannel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'write') {
          return null;
        }
        if (methodCall.method == 'read') {
          return null;
        }
        if (methodCall.method == 'readAll') {
          return <String, String>{};
        }
        return null;
      },
    );
  }

  /// Clean up after tests
  static Future<void> cleanup() async {
    // Reset static state if needed
    _isSetup = false;
  }
}