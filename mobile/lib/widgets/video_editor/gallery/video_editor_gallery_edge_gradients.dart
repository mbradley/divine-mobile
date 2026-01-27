// ABOUTME: Edge gradient overlays for clip gallery
// ABOUTME: Darkens left and right edges to focus attention on centered clip

import 'package:flutter/material.dart';

/// Edge gradient overlays that darken the left and right sides of the gallery.
///
/// These gradients fade in when a clip is near center, helping to focus
/// visual attention on the centered clip by darkening adjacent areas.
class ClipGalleryEdgeGradients extends StatelessWidget {
  /// Creates edge gradient overlays.
  const ClipGalleryEdgeGradients({
    required this.opacity,
    required this.gradientWidth,
    super.key,
  });

  /// Opacity of the gradients (0.0-1.0).
  final double opacity;

  /// Width of each gradient overlay.
  final double gradientWidth;

  @override
  Widget build(BuildContext context) {
    const gradientColors = [Color(0xFF000A06), Colors.transparent];

    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Stack(
          children: [
            // Left gradient
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: gradientWidth,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradientColors),
                ),
              ),
            ),
            // Right gradient
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: gradientWidth,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: .centerRight,
                    end: .centerLeft,
                    colors: gradientColors,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
