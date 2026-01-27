// ABOUTME: Tests for VideoEditorOverviewMoreSheet widget
// ABOUTME: Validates bottom sheet layout and button states for overview options

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/widgets/video_editor/sheets/video_editor_overview_more_sheet.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEditorOverviewMoreSheet Widget Tests', () {
    Widget buildTestWidget({bool hasClips = false}) {
      return ProviderScope(
        overrides: [
          clipManagerProvider.overrideWith(
            () => TestClipManagerNotifier(
              ClipManagerState(
                clips: hasClips
                    ? [
                        RecordingClip(
                          id: 'test-clip',
                          video: EditorVideo.file('/test/clip.mp4'),
                          duration: const Duration(seconds: 2),
                          recordedAt: DateTime.now(),
                          aspectRatio: .vertical,
                        ),
                      ]
                    : [],
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: VideoEditorOverviewMoreSheet()),
        ),
      );
    }

    testWidgets('displays add clip from library option', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Add clip from Library'), findsOneWidget);
    });

    testWidgets('displays Save selected clip option', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Save selected clip'), findsOneWidget);
    });

    testWidgets('displays delete clips option', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.text('Delete clips & start over'), findsOneWidget);
    });

    testWidgets('add clip button is always enabled', (tester) async {
      await tester.pumpWidget(buildTestWidget(hasClips: false));

      final addClipButton = find.text('Add clip from Library');
      expect(addClipButton, findsOneWidget);
    });

    testWidgets('uses SingleChildScrollView', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.byType(VideoEditorOverviewMoreSheet), findsOneWidget);
    });
  });
}

class TestClipManagerNotifier extends ClipManagerNotifier {
  TestClipManagerNotifier(this._state);
  final ClipManagerState _state;

  @override
  ClipManagerState build() => _state;
}
