// ABOUTME: Tests for ClipGalleryEdgeGradients widget
// ABOUTME: Verifies gradient positioning and IgnorePointer behavior

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_editor/gallery/video_editor_gallery_edge_gradients.dart';

void main() {
  group('ClipGalleryEdgeGradients', () {
    testWidgets('should render left and right gradients', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: Stack(
                children: [
                  ClipGalleryEdgeGradients(opacity: 1.0, gradientWidth: 40),
                ],
              ),
            ),
          ),
        ),
      );

      // Should have two DecoratedBox widgets for left and right gradients
      expect(find.byType(DecoratedBox), findsNWidgets(2));
    });

    testWidgets('should ignore pointer events', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClipGalleryEdgeGradients(opacity: 1.0, gradientWidth: 40),
          ),
        ),
      );

      // Find the IgnorePointer that wraps the gradients (direct child of ClipGalleryEdgeGradients)
      final clipGalleryEdgeGradients = find.byType(ClipGalleryEdgeGradients);
      expect(clipGalleryEdgeGradients, findsOneWidget);

      final ignorePointer = tester.widget<IgnorePointer>(
        find
            .descendant(
              of: clipGalleryEdgeGradients,
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      expect(ignorePointer.ignoring, true);
    });

    testWidgets('should apply opacity', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClipGalleryEdgeGradients(opacity: 0.5, gradientWidth: 40),
          ),
        ),
      );

      final opacityWidget = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacityWidget.opacity, 0.5);
    });

    testWidgets('should be invisible when opacity is 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ClipGalleryEdgeGradients(opacity: 0.0, gradientWidth: 40),
          ),
        ),
      );

      final opacityWidget = tester.widget<Opacity>(find.byType(Opacity));
      expect(opacityWidget.opacity, 0.0);
    });

    testWidgets('should position gradients at edges', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 400,
              height: 300,
              child: Stack(
                children: [
                  ClipGalleryEdgeGradients(opacity: 1.0, gradientWidth: 50),
                ],
              ),
            ),
          ),
        ),
      );

      final positionedWidgets = tester.widgetList<Positioned>(
        find.byType(Positioned),
      );

      // Should have exactly 2 Positioned widgets
      expect(positionedWidgets.length, 2);

      final positionedList = positionedWidgets.toList();

      // Left gradient at left: 0
      expect(positionedList[0].left, 0);
      expect(positionedList[0].width, 50);

      // Right gradient at right: 0
      expect(positionedList[1].right, 0);
      expect(positionedList[1].width, 50);
    });
  });
}
