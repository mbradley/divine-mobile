// ABOUTME: Tests for event-based routing using nevent IDs instead of indices
// ABOUTME: Verifies route parsing and building with Nostr event identifiers

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/route_utils.dart';

void main() {
  group('Event-based route parsing', () {
    test('should parse home route with nevent ID', () {
      final result = parseRoute('/home/nevent1qqsxyzabc123');

      expect(result.type, RouteType.home);
      expect(result.eventId, 'nevent1qqsxyzabc123');
      expect(result.videoIndex, isNull); // No indices with event-based routing
    });

    test('should parse explore route with nevent ID', () {
      final result = parseRoute('/explore/nevent1qqsdefghi456');

      expect(result.type, RouteType.explore);
      expect(result.eventId, 'nevent1qqsdefghi456');
      expect(result.videoIndex, isNull);
    });

    test('should parse hashtag route with tag and nevent ID', () {
      final result = parseRoute('/hashtag/funny/nevent1qqsjklmno789');

      expect(result.type, RouteType.hashtag);
      expect(result.hashtag, 'funny');
      expect(result.eventId, 'nevent1qqsjklmno789');
      expect(result.videoIndex, isNull);
    });

    test('should parse profile route with npub and nevent ID', () {
      final result = parseRoute('/profile/npub1abc123/nevent1qqspqrstu012');

      expect(result.type, RouteType.profile);
      expect(result.npub, 'npub1abc123');
      expect(result.eventId, 'nevent1qqspqrstu012');
      expect(result.videoIndex, isNull);
    });

    test('should parse notifications route with nevent ID', () {
      final result = parseRoute('/notifications/nevent1qqsvwxyz345');

      expect(result.type, RouteType.notifications);
      expect(result.eventId, 'nevent1qqsvwxyz345');
      expect(result.videoIndex, isNull);
    });

    test('should handle URL-encoded nevent IDs', () {
      final result = parseRoute('/home/nevent1qqs%2Fabc%2F123');

      expect(result.type, RouteType.home);
      expect(result.eventId, 'nevent1qqs/abc/123'); // Decoded
    });

    test('should default to home without event ID', () {
      final result = parseRoute('/home');

      expect(result.type, RouteType.home);
      expect(result.eventId, isNull);
    });
  });

  group('Event-based route building', () {
    test('should build home route with nevent ID', () {
      final context = RouteContext(
        type: RouteType.home,
        eventId: 'nevent1qqsxyzabc123',
      );

      expect(buildRoute(context), '/home/nevent1qqsxyzabc123');
    });

    test('should build explore route with nevent ID', () {
      final context = RouteContext(
        type: RouteType.explore,
        eventId: 'nevent1qqsdefghi456',
      );

      expect(buildRoute(context), '/explore/nevent1qqsdefghi456');
    });

    test('should build hashtag route with tag and nevent ID', () {
      final context = RouteContext(
        type: RouteType.hashtag,
        hashtag: 'funny',
        eventId: 'nevent1qqsjklmno789',
      );

      expect(buildRoute(context), '/hashtag/funny/nevent1qqsjklmno789');
    });

    test('should build profile route with npub and nevent ID', () {
      final context = RouteContext(
        type: RouteType.profile,
        npub: 'npub1abc123',
        eventId: 'nevent1qqspqrstu012',
      );

      expect(buildRoute(context), '/profile/npub1abc123/nevent1qqspqrstu012');
    });

    test('should URL-encode special characters in nevent ID', () {
      final context = RouteContext(
        type: RouteType.home,
        eventId: 'nevent1qqs/abc/123',
      );

      expect(buildRoute(context), '/home/nevent1qqs%2Fabc%2F123');
    });

    test('should build home route without event ID when null', () {
      final context = RouteContext(
        type: RouteType.home,
        eventId: null,
      );

      // Defaults to index 0 for backward compatibility
      expect(buildRoute(context), '/home/0');
    });
  });

  group('Event-based round-trip consistency', () {
    test('parse then build returns original URL with nevent', () {
      final urls = [
        '/home/nevent1qqsxyzabc123',
        '/explore/nevent1qqsdefghi456',
        '/hashtag/nostr/nevent1qqsjklmno789',
        '/profile/npub1abc123/nevent1qqspqrstu012',
        '/notifications/nevent1qqsvwxyz345',
      ];

      for (final url in urls) {
        final parsed = parseRoute(url);
        final rebuilt = buildRoute(parsed);
        expect(rebuilt, url, reason: 'Failed round-trip for $url');
      }
    });
  });

  group('Backward compatibility', () {
    test('should still parse legacy index-based home routes', () {
      final result = parseRoute('/home/5');

      expect(result.type, RouteType.home);
      expect(result.videoIndex, 5);
      expect(result.eventId, isNull);
    });

    test('should still parse legacy index-based hashtag routes', () {
      final result = parseRoute('/hashtag/funny/3');

      expect(result.type, RouteType.hashtag);
      expect(result.hashtag, 'funny');
      expect(result.videoIndex, 3);
      expect(result.eventId, isNull);
    });

    test('should still build legacy index-based routes when videoIndex provided', () {
      final context = RouteContext(
        type: RouteType.home,
        videoIndex: 5,
      );

      expect(buildRoute(context), '/home/5');
    });

    test('should prefer eventId over videoIndex when both provided', () {
      final context = RouteContext(
        type: RouteType.home,
        eventId: 'nevent1qqsxyz',
        videoIndex: 5, // Should be ignored
      );

      expect(buildRoute(context), '/home/nevent1qqsxyz');
    });
  });
}
