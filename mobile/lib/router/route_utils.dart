// ABOUTME: Route parsing and building utilities
// ABOUTME: Converts between URLs and structured route context

/// Route types supported by the app
enum RouteType {
  home,
  explore,
  notifications,
  profile,
  hashtag, // Still supported as push route within explore
  search,
  camera,
  settings,
}

/// Structured representation of a route
class RouteContext {
  const RouteContext({
    required this.type,
    this.videoIndex,
    this.eventId,
    this.npub,
    this.hashtag,
    this.searchTerm,
  });

  final RouteType type;
  final int? videoIndex; // Legacy: index-based routing
  final String? eventId; // Modern: event-based routing (nevent format)
  final String? npub;
  final String? hashtag;
  final String? searchTerm;
}

/// Parse a URL path into a structured RouteContext
/// Normalizes negative indices to 0 and decodes URL-encoded parameters
RouteContext parseRoute(String path) {
  final segments = path.split('/').where((s) => s.isNotEmpty).toList();

  if (segments.isEmpty) {
    return const RouteContext(type: RouteType.home, videoIndex: 0);
  }

  final firstSegment = segments[0];

  switch (firstSegment) {
    case 'home':
      if (segments.length > 1) {
        final segment = segments[1];
        // Check if it's an event ID (starts with "nevent")
        if (segment.startsWith('nevent')) {
          final eventId = Uri.decodeComponent(segment);
          return RouteContext(type: RouteType.home, eventId: eventId);
        }
        // Legacy: parse as index
        final rawIndex = int.tryParse(segment) ?? 0;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return RouteContext(type: RouteType.home, videoIndex: index);
      }
      // Default to index 0 for backward compatibility
      return const RouteContext(type: RouteType.home, videoIndex: 0);

    case 'explore':
      // No segment = grid mode (null videoIndex/eventId)
      // With nevent segment = feed mode with event
      // With index segment = feed mode with legacy index
      if (segments.length > 1) {
        final segment = segments[1];
        if (segment.startsWith('nevent')) {
          final eventId = Uri.decodeComponent(segment);
          return RouteContext(type: RouteType.explore, eventId: eventId);
        }
        // Legacy: parse as index
        final rawIndex = int.tryParse(segment);
        final index = rawIndex != null && rawIndex < 0 ? 0 : rawIndex;
        return RouteContext(type: RouteType.explore, videoIndex: index);
      }
      return const RouteContext(type: RouteType.explore);

    case 'profile':
      if (segments.length < 2) {
        return const RouteContext(type: RouteType.home);
      }
      final npub = Uri.decodeComponent(segments[1]); // Decode URL encoding

      if (segments.length > 2) {
        final segment = segments[2];
        if (segment.startsWith('nevent')) {
          final eventId = Uri.decodeComponent(segment);
          return RouteContext(
            type: RouteType.profile,
            npub: npub,
            eventId: eventId,
          );
        }
        // Legacy: parse as index
        final rawIndex = int.tryParse(segment) ?? 0;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return RouteContext(
          type: RouteType.profile,
          npub: npub,
          videoIndex: index,
        );
      }

      // Handle "me" as special redirect marker - this will be resolved by ProfileScreenRouter
      // The router will redirect /profile/me to /profile/:actualNpub
      return RouteContext(
        type: RouteType.profile,
        npub: npub, // Will be "me" if URL is /profile/me
      );

    case 'notifications':
      if (segments.length > 1) {
        final segment = segments[1];
        if (segment.startsWith('nevent')) {
          final eventId = Uri.decodeComponent(segment);
          return RouteContext(type: RouteType.notifications, eventId: eventId);
        }
        // Legacy: parse as index
        final rawIndex = int.tryParse(segment) ?? 0;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return RouteContext(type: RouteType.notifications, videoIndex: index);
      }
      return const RouteContext(type: RouteType.notifications);

    case 'hashtag':
      if (segments.length < 2) {
        return const RouteContext(type: RouteType.home);
      }
      final tag = Uri.decodeComponent(segments[1]); // Decode URL encoding

      if (segments.length > 2) {
        final segment = segments[2];
        if (segment.startsWith('nevent')) {
          final eventId = Uri.decodeComponent(segment);
          return RouteContext(
            type: RouteType.hashtag,
            hashtag: tag,
            eventId: eventId,
          );
        }
        // Legacy: parse as index
        final rawIndex = int.tryParse(segment);
        final index = rawIndex != null && rawIndex < 0 ? 0 : rawIndex;
        return RouteContext(
          type: RouteType.hashtag,
          hashtag: tag,
          videoIndex: index,
        );
      }

      // No third segment = grid mode
      return RouteContext(
        type: RouteType.hashtag,
        hashtag: tag,
      );

    case 'search':
      // /search - grid mode, no term
      // /search/term - grid mode with search term
      // /search/term/5 - feed mode with search term at index 5
      String? searchTerm;
      int? index;

      if (segments.length > 1) {
        // Try parsing segment 1 as index first
        final maybeIndex = int.tryParse(segments[1]);
        if (maybeIndex != null) {
          // Legacy format: /search/5 (no search term, just index)
          index = maybeIndex < 0 ? 0 : maybeIndex;
        } else {
          // segment 1 is search term
          searchTerm = Uri.decodeComponent(segments[1]);
          // Check for index in segment 2
          if (segments.length > 2) {
            final rawIndex = int.tryParse(segments[2]);
            index = rawIndex != null && rawIndex < 0 ? 0 : rawIndex;
          }
        }
      }

      return RouteContext(
        type: RouteType.search,
        searchTerm: searchTerm,
        videoIndex: index,
      );

    case 'camera':
      return const RouteContext(type: RouteType.camera);

    case 'settings':
      return const RouteContext(type: RouteType.settings);

    default:
      return const RouteContext(type: RouteType.home, videoIndex: 0);
  }
}

/// Build a URL path from a RouteContext
/// Encodes dynamic parameters and normalizes indices to >= 0
/// Prefers eventId over videoIndex when both are present
String buildRoute(RouteContext context) {
  switch (context.type) {
    case RouteType.home:
      // Prefer event-based routing
      if (context.eventId != null) {
        final encodedId = Uri.encodeComponent(context.eventId!);
        return '/home/$encodedId';
      }
      // Legacy: index-based routing (defaults to 0 for backward compatibility)
      final rawIndex = context.videoIndex ?? 0;
      final index = rawIndex < 0 ? 0 : rawIndex;
      return '/home/$index';

    case RouteType.explore:
      // Event-based feed mode
      if (context.eventId != null) {
        final encodedId = Uri.encodeComponent(context.eventId!);
        return '/explore/$encodedId';
      }
      // Legacy index-based feed mode
      if (context.videoIndex != null) {
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return '/explore/$index';
      }
      // Grid mode
      return '/explore';

    case RouteType.notifications:
      // Event-based routing
      if (context.eventId != null) {
        final encodedId = Uri.encodeComponent(context.eventId!);
        return '/notifications/$encodedId';
      }
      // Legacy index-based routing
      if (context.videoIndex != null) {
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return '/notifications/$index';
      }
      return '/notifications';

    case RouteType.profile:
      final npub = Uri.encodeComponent(context.npub ?? '');

      // Event-based routing
      if (context.eventId != null) {
        final encodedId = Uri.encodeComponent(context.eventId!);
        return '/profile/$npub/$encodedId';
      }
      // Legacy index-based routing
      if (context.videoIndex != null) {
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return '/profile/$npub/$index';
      }
      // Grid mode (profile without video)
      return '/profile/$npub';

    case RouteType.hashtag:
      final hashtag = Uri.encodeComponent(context.hashtag ?? '');

      // Event-based feed mode
      if (context.eventId != null) {
        final encodedId = Uri.encodeComponent(context.eventId!);
        return '/hashtag/$hashtag/$encodedId';
      }
      // Legacy index-based feed mode
      if (context.videoIndex != null) {
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return '/hashtag/$hashtag/$index';
      }
      // Grid mode
      return '/hashtag/$hashtag';

    case RouteType.search:
      // Grid mode (null videoIndex):
      //   - With term: '/search/{term}'
      //   - Without term: '/search'
      // Feed mode (videoIndex set):
      //   - With term: '/search/{term}/{index}'
      //   - Without term (legacy): '/search/{index}'
      if (context.searchTerm != null) {
        final encodedTerm = Uri.encodeComponent(context.searchTerm!);
        if (context.videoIndex == null) {
          return '/search/$encodedTerm';
        }
        final rawIndex = context.videoIndex!;
        final index = rawIndex < 0 ? 0 : rawIndex;
        return '/search/$encodedTerm/$index';
      }

      // Legacy format without search term
      if (context.videoIndex == null) return '/search';
      final rawIndex = context.videoIndex!;
      final index = rawIndex < 0 ? 0 : rawIndex;
      return '/search/$index';

    case RouteType.camera:
      return '/camera';

    case RouteType.settings:
      return '/settings';
  }
}
