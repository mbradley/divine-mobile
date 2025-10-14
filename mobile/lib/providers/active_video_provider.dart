// ABOUTME: Router-driven active video provider
// ABOUTME: Derives active video ID from URL context, feed state, and app foreground state

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_lifecycle_provider.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';

/// Active video ID derived from router state and app lifecycle
/// Returns null when app is backgrounded or no valid video at current index
final activeVideoIdProvider = Provider<String?>((ref) {
  // Check app foreground state
  final isFg = ref.watch(appForegroundProvider).maybeWhen(
    data: (v) => v,
    orElse: () => true,
  );
  if (!isFg) return null;

  // Get current page context from router
  final ctx = ref.watch(pageContextProvider).asData?.value;
  if (ctx == null) return null;

  // Get videos for the current route type
  // For now, only supporting home route (PR5.2 scope)
  if (ctx.type != RouteType.home) return null;

  final videosAsync = ref.watch(videosForHomeRouteProvider);
  final videos = videosAsync.maybeWhen(
    data: (state) => state.videos,
    orElse: () => const [],
  );

  if (videos.isEmpty) return null;

  // Get video at current index
  final idx = (ctx.videoIndex ?? 0).clamp(0, videos.length - 1);
  return videos[idx].id;
});
