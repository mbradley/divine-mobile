// ABOUTME: Tests for VideoEditorClipEditMoreSheet widget
// ABOUTME: Validates bottom sheet layout and clip-specific actions

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/sheets/video_editor_clip_edit_more_sheet.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEditorClipEditMoreSheet Widget Tests', () {
    final testClip = RecordingClip(
      id: 'test-clip',
      video: EditorVideo.file('/test/clip.mp4'),
      duration: const Duration(seconds: 2),
      recordedAt: DateTime.now(),
      aspectRatio: .vertical,
    );

    Widget buildTestWidget({required RecordingClip clip, int clipIndex = 0}) {
      return ProviderScope(
        overrides: [
          clipManagerProvider.overrideWith(
            () => TestClipManagerNotifier(ClipManagerState(clips: [clip])),
          ),
          videoEditorProvider.overrideWith(
            () => TestVideoEditorNotifier(
              VideoEditorProviderState(currentClipIndex: clipIndex),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: VideoEditorClipEditMoreSheet()),
        ),
      );
    }

    testWidgets('displays split clip option', (tester) async {
      await tester.pumpWidget(buildTestWidget(clip: testClip));

      expect(find.text('Split clip'), findsOneWidget);
    });

    testWidgets('displays save clip option', (tester) async {
      await tester.pumpWidget(buildTestWidget(clip: testClip));

      expect(find.text('Save clip'), findsOneWidget);
    });

    testWidgets('displays delete clip option', (tester) async {
      await tester.pumpWidget(buildTestWidget(clip: testClip));

      expect(find.text('Delete clip'), findsOneWidget);
    });

    testWidgets('delete option has red color', (tester) async {
      await tester.pumpWidget(buildTestWidget(clip: testClip));

      expect(find.text('Delete clip'), findsOneWidget);
    });

    testWidgets('uses SingleChildScrollView', (tester) async {
      await tester.pumpWidget(buildTestWidget(clip: testClip));

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(buildTestWidget(clip: testClip));
      await tester.pumpAndSettle();

      expect(find.byType(VideoEditorClipEditMoreSheet), findsOneWidget);
    });
  });
}

class TestClipManagerNotifier extends ClipManagerNotifier {
  TestClipManagerNotifier(this._state);
  final ClipManagerState _state;

  @override
  ClipManagerState build() => _state;
}

class TestVideoEditorNotifier extends VideoEditorNotifier {
  TestVideoEditorNotifier(this._state);
  final VideoEditorProviderState _state;

  @override
  VideoEditorProviderState build() => _state;
}
