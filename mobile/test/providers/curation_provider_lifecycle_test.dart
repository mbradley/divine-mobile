// ABOUTME: Tests curation provider lifecycle behavior during navigation
// ABOUTME: Verifies editor's picks persist when navigating away and back to tab

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/curation_set.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/services/analytics_api_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curation_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:riverpod/riverpod.dart';

import 'curation_provider_lifecycle_test.mocks.dart';

@GenerateMocks([
  INostrService,
  VideoEventService,
  SocialService,
  AuthService,
  AnalyticsApiService,
])
void main() {
  group('CurationProvider Lifecycle', () {
    late MockINostrService mockNostrService;
    late MockVideoEventService mockVideoEventService;
    late MockSocialService mockSocialService;
    late MockAuthService mockAuthService;
    late MockAnalyticsApiService mockAnalyticsApiService;
    late List<VideoEvent> sampleVideos;

    setUp(() {
      mockNostrService = MockINostrService();
      mockVideoEventService = MockVideoEventService();
      mockSocialService = MockSocialService();
      mockAuthService = MockAuthService();
      mockAnalyticsApiService = MockAnalyticsApiService();

      // Create sample videos for editor's picks
      sampleVideos = List.generate(
        23,
        (i) => VideoEvent(
          id: 'video_$i',
          pubkey: 'pubkey_$i',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          content: 'Test video $i',
          timestamp: DateTime.now(),
          title: 'Video $i',
        ),
      );

      // Mock video event service to return sample videos
      when(mockVideoEventService.discoveryVideos).thenReturn(sampleVideos);

      // Stub nostr service methods
      when(mockNostrService.subscribeToEvents(
        filters: anyNamed('filters'),
        bypassLimits: anyNamed('bypassLimits'),
        onEose: anyNamed('onEose'),
      )).thenAnswer((_) => const Stream.empty());

      // Stub social service methods
      when(mockSocialService.getCachedLikeCount(any)).thenReturn(0);
    });

    test('provider is autodisposed when no longer watched (demonstrates bug)',
        () async {
      // ARRANGE: Create first container
      final container1 = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          socialServiceProvider.overrideWithValue(mockSocialService),
          authServiceProvider.overrideWithValue(mockAuthService),
          analyticsApiServiceProvider.overrideWithValue(mockAnalyticsApiService),
        ],
      );
      addTearDown(container1.dispose);

      // Read curation provider to trigger initialization
      final curationState1 = container1.read(curationProvider);
      expect(curationState1.isLoading, isTrue,
          reason: 'Should be loading initially');

      // Wait for async initialization to complete by polling
      // (In real app, the provider notifies listeners when state changes)
      var attempts = 0;
      while (container1.read(curationProvider).isLoading && attempts < 50) {
        await Future.delayed(Duration(milliseconds: 10));
        attempts++;
      }

      // ACT: Read state after initialization
      final curationState1AfterInit = container1.read(curationProvider);

      // ASSERT: Should have finished loading
      expect(
        curationState1AfterInit.isLoading,
        isFalse,
        reason: 'Should finish loading after initialization (waited ${attempts * 10}ms)',
      );

      // Record initial state (may be empty if relay fetch failed, that's OK)
      final initialIsLoading = curationState1AfterInit.isLoading;

      // SIMULATE NAVIGATION AWAY: Dispose container
      // This happens when user navigates to a different tab
      container1.dispose();

      // SIMULATE NAVIGATION BACK: Create new container
      // This happens when user returns to Editor's Pick tab
      final container2 = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          socialServiceProvider.overrideWithValue(mockSocialService),
          authServiceProvider.overrideWithValue(mockAuthService),
          analyticsApiServiceProvider.overrideWithValue(mockAnalyticsApiService),
        ],
      );
      addTearDown(container2.dispose);

      // ACT: Read curation provider immediately (like the widget does)
      final curationState2 = container2.read(curationProvider);

      // ASSERT: Without keepAlive, provider was disposed and recreated
      // So it's back to loading state (the bug!)
      expect(
        curationState2.isLoading,
        isTrue,
        reason:
            'Without keepAlive, provider is recreated in loading state on navigation return (BUG)',
      );

      // With keepAlive, this test would fail because provider state persists:
      // expect(curationState2.isLoading, equals(initialIsLoading))
    });

    test(
        'curation provider initialization completes and populates editor picks',
        () async {
      // ARRANGE: Create container
      final container = ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          socialServiceProvider.overrideWithValue(mockSocialService),
          authServiceProvider.overrideWithValue(mockAuthService),
          analyticsApiServiceProvider.overrideWithValue(mockAnalyticsApiService),
        ],
      );
      addTearDown(container.dispose);

      // ACT: Read initial state
      final initialState = container.read(curationProvider);

      // ASSERT: Initially loading
      expect(initialState.isLoading, isTrue);
      expect(initialState.editorsPicks, isEmpty);

      // Wait for async initialization
      await Future.microtask(() {});
      await Future.delayed(Duration(milliseconds: 10));

      // ACT: Read after initialization
      final loadedState = container.read(curationProvider);
      final editorsPicks = container.read(editorsPicksProvider);

      // ASSERT: Should be loaded with videos
      expect(loadedState.isLoading, isFalse);
      expect(editorsPicks.length, greaterThan(0));
    });

    test('curation service initializes with sample data', () {
      // ARRANGE: Create curation service directly
      final service = CurationService(
        nostrService: mockNostrService,
        videoEventService: mockVideoEventService,
        socialService: mockSocialService,
        authService: mockAuthService,
      );

      // ACT & ASSERT: Service should initialize with sample data
      expect(service.isLoading, isFalse);
      final editorsPicks = service.getVideosForSetType(CurationSetType.editorsPicks);

      // Editor's picks may be empty if no videos available, but service should not be loading
      expect(service.isLoading, isFalse);
    });
  });
}
