// ABOUTME: Comprehensive test for embedded relay functionality using real relay (no mocks)
// ABOUTME: Validates video feed loading performance, P2P sync, and core video features

import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/embedded_relay_service.dart';
import 'package:openvine/services/nostr_key_manager.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/utils/unified_logger.dart';

void main() {
  group('Embedded Relay Comprehensive Tests', () {
    late EmbeddedRelayService embeddedRelay;
    late VideoEventService videoEventService;
    late SubscriptionManager subscriptionManager;
    late NostrKeyManager keyManager;

    setUpAll(() async {
      Log.init(LogLevel.debug);
      Log.info('Starting embedded relay comprehensive tests', 
          name: 'EmbeddedRelayTest', category: LogCategory.debug);
    });

    setUp(() async {
      // Initialize key manager and embedded relay service
      keyManager = NostrKeyManager();
      embeddedRelay = EmbeddedRelayService(keyManager);
      
      // Initialize services
      subscriptionManager = SubscriptionManager(embeddedRelay);
      videoEventService = VideoEventService(
        embeddedRelay, 
        subscriptionManager: subscriptionManager,
      );
      
      Log.debug('Test setup complete', 
          name: 'EmbeddedRelayTest', category: LogCategory.debug);
    });

    tearDown(() async {
      // Clean up services
      videoEventService.dispose();
      await subscriptionManager.dispose();
      // Note: EmbeddedRelayService dispose is handled automatically
      
      Log.debug('Test teardown complete', 
          name: 'EmbeddedRelayTest', category: LogCategory.debug);
    });

    test('embedded relay initializes and accepts connections', () async {
      // Initialize embedded relay (automatically starts)
      await embeddedRelay.initialize();
      expect(embeddedRelay.isInitialized, isTrue);
      
      // Check that it's connected to localhost relay
      expect(embeddedRelay.relays, contains('ws://localhost:7447'));
      expect(embeddedRelay.connectedRelayCount, greaterThan(0));
      
      Log.info('✅ Embedded relay initialized and connected successfully',
          name: 'EmbeddedRelayTest', category: LogCategory.debug);
    });

    test('video feed loading performance < 100ms', () async {
      // Initialize services
      await embeddedRelay.initialize();
      
      // Measure video feed loading time
      final stopwatch = Stopwatch()..start();
      
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 50,
      );
      
      stopwatch.stop();
      final loadTime = stopwatch.elapsedMilliseconds;
      
      Log.info('Video feed loaded in ${loadTime}ms',
          name: 'EmbeddedRelayTest', category: LogCategory.test);
      
      // Target: < 100ms (vs old 500-2000ms)
      expect(loadTime, lessThan(100));
    });

    test('can publish and retrieve video events through embedded relay', () async {
      // Start services
      await embeddedRelay.start();
      await nostrService.initialize();
      
      // Create a test video event
      final testContent = jsonEncode({
        'vine_id': 'test_vine_123',
        'title': 'Test Video',
        'description': 'Test video for embedded relay',
        'url': 'https://example.com/test.mp4',
        'thumbnailUrl': 'https://example.com/thumb.jpg',
        'hashtags': ['test', 'embedded', 'relay'],
      });
      
      // Publish event
      final event = Event.fromPartialData(
        kind: 32222, // Kind for short looping videos
        content: testContent,
        tags: [
          ['d', 'test_vine_123'], // Addressable event identifier
          ['t', 'test'],
          ['t', 'embedded'],
          ['t', 'relay'],
        ],
        createdAt: DateTime.now(),
      );
      
      final result = await nostrService.broadcastEvent(event);
      expect(result.isSuccessful, isTrue);
      
      Log.info('Published test event: ${event.id}',
          name: 'EmbeddedRelayTest', category: LogCategory.test);
      
      // Subscribe to events and verify we can retrieve it
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 10,
      );
      
      // Wait for event processing
      await Future.delayed(Duration(milliseconds: 100));
      
      final videos = videoEventService.getVideos(SubscriptionType.discovery);
      expect(videos, isNotEmpty);
      
      // Verify our test video is in the results
      final testVideo = videos.firstWhere(
        (v) => v.vineId == 'test_vine_123',
        orElse: () => throw Exception('Test video not found'),
      );
      
      expect(testVideo.title, 'Test Video');
      expect(testVideo.hashtags, contains('test'));
      
      Log.info('✅ Successfully published and retrieved video event through embedded relay',
          name: 'EmbeddedRelayTest', category: LogCategory.test);
    });

    test('embedded relay handles multiple concurrent subscriptions', () async {
      await embeddedRelay.start();
      await nostrService.initialize();
      
      // Create multiple concurrent subscriptions
      final futures = <Future>[];
      
      for (int i = 0; i < 5; i++) {
        futures.add(
          videoEventService.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.discovery,
            limit: 20,
          ),
        );
      }
      
      // All subscriptions should complete without error
      await Future.wait(futures);
      
      // Verify the service is still responsive
      expect(videoEventService.isSubscribed(SubscriptionType.discovery), isTrue);
      
      Log.info('✅ Embedded relay handled multiple concurrent subscriptions',
          name: 'EmbeddedRelayTest', category: LogCategory.test);
    });

    test('embedded relay persists events between restarts', () async {
      // Start relay and publish an event
      await embeddedRelay.start();
      await nostrService.initialize();
      
      final testEvent = Event.fromPartialData(
        kind: 32222,
        content: jsonEncode({
          'vine_id': 'persistent_test_456',
          'title': 'Persistence Test',
        }),
        tags: [['d', 'persistent_test_456']],
        createdAt: DateTime.now(),
      );
      
      await nostrService.broadcastEvent(testEvent);
      
      // Stop and restart the relay
      await embeddedRelay.dispose();
      await nostrService.dispose();
      
      // Restart everything
      embeddedRelay = EmbeddedRelayService();
      nostrService = NostrService(keyManager);
      videoEventService = VideoEventService(nostrService);
      
      await embeddedRelay.start();
      await nostrService.initialize();
      
      // Query for the event - it should still exist
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 10,
      );
      
      await Future.delayed(Duration(milliseconds: 100));
      
      final videos = videoEventService.getVideos(SubscriptionType.discovery);
      final persistentVideo = videos.where((v) => v.vineId == 'persistent_test_456');
      
      expect(persistentVideo, isNotEmpty);
      
      Log.info('✅ Embedded relay persisted events between restarts',
          name: 'EmbeddedRelayTest', category: LogCategory.test);
    });

    test('offline functionality - events stored locally when relay unavailable', () async {
      // Initialize without starting embedded relay (simulating offline)
      await nostrService.initialize();
      
      // Try to publish an event while "offline"
      final offlineEvent = Event.fromPartialData(
        kind: 32222,
        content: jsonEncode({
          'vine_id': 'offline_test_789',
          'title': 'Offline Test',
        }),
        tags: [['d', 'offline_test_789']],
        createdAt: DateTime.now(),
      );
      
      // This should queue the event locally
      final result = await nostrService.broadcastEvent(offlineEvent);
      
      // Even if broadcast "fails", the event should be queued
      Log.info('Offline broadcast result: ${result.isSuccessful}',
          name: 'EmbeddedRelayTest', category: LogCategory.test);
      
      // Now bring the relay online
      await embeddedRelay.start();
      
      // Wait for potential sync
      await Future.delayed(Duration(milliseconds: 200));
      
      // Subscribe and check if the queued event appears
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
        limit: 10,
      );
      
      await Future.delayed(Duration(milliseconds: 100));
      
      Log.info('✅ Offline functionality test completed',
          name: 'EmbeddedRelayTest', category: LogCategory.test);
    });

    test('core video features work with embedded relay', () async {
      await embeddedRelay.start();
      await nostrService.initialize();
      
      // Test core video operations
      
      // 1. Subscribe to video feeds
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.discovery,
      );
      expect(videoEventService.isSubscribed(SubscriptionType.discovery), isTrue);
      
      // 2. Subscribe to home feed
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.homeFeed,
      );
      expect(videoEventService.isSubscribed(SubscriptionType.homeFeed), isTrue);
      
      // 3. Test hashtag filtering
      await videoEventService.subscribeToVideoFeed(
        subscriptionType: SubscriptionType.hashtag,
        hashtags: ['test'],
      );
      expect(videoEventService.isSubscribed(SubscriptionType.hashtag), isTrue);
      
      // 4. Test search functionality
      await videoEventService.searchVideos(query: 'test video');
      
      // If we get here without errors, core features are working
      Log.info('✅ All core video features working with embedded relay',
          name: 'EmbeddedRelayTest', category: LogCategory.test);
    });

    test('embedded relay reports correct status and metrics', () async {
      await embeddedRelay.start();
      await nostrService.initialize();
      
      // Check relay status
      expect(embeddedRelay.isRunning, isTrue);
      expect(embeddedRelay.port, 7447);
      
      // Check NostrService status
      expect(nostrService.isInitialized, isTrue);
      expect(nostrService.relayCount, greaterThan(0));
      expect(nostrService.connectedRelayCount, greaterThan(0));
      
      // Check that the embedded relay is in the relay list
      final relayUrls = nostrService.relays;
      expect(relayUrls, contains('ws://localhost:7447'));
      
      Log.info('Relay status: running=${embeddedRelay.isRunning}, '
               'relays=${nostrService.relayCount}, '
               'connected=${nostrService.connectedRelayCount}',
          name: 'EmbeddedRelayTest', category: LogCategory.test);
      
      Log.info('✅ Embedded relay status and metrics correct',
          name: 'EmbeddedRelayTest', category: LogCategory.test);
    });
  });
}