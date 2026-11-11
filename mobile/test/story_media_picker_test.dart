import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/screens/create_story_screen.dart';

void main() {
  testWidgets('selected video is handed to the status composer', (
    tester,
  ) async {
    final file = XFile('statut.mp4');

    await tester.pumpWidget(
      MaterialApp(
        home: CreateStoryScreen(
          initialMediaSelection: StoryMediaSelection(
            action: StoryMediaAction.galleryVideo,
            file: file,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('statut.mp4'), findsOneWidget);
  });
}
