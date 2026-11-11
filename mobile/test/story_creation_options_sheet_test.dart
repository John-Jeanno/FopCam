import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/create_story_screen.dart';
import 'package:mobile/widgets/home_sections.dart';

void main() {
  const options = [
    ('Photo depuis la galerie', StoryMediaAction.galleryImage),
    ('Prendre une photo', StoryMediaAction.cameraImage),
    ('Vidéo depuis la galerie', StoryMediaAction.galleryVideo),
    ('Enregistrer une vidéo', StoryMediaAction.cameraVideo),
    ('Créer un statut texte', StoryMediaAction.textOnly),
  ];

  for (final (label, expectedAction) in options) {
    testWidgets('selecting "$label" starts the matching action', (
      tester,
    ) async {
      StoryMediaChoice? selectedChoice;
      final startedActions = <StoryMediaAction>[];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  selectedChoice = await StoryCreationOptionsSheet.show(
                    context,
                    onMediaActionSelected: (action) async {
                      startedActions.add(action);
                      return null;
                    },
                  );
                },
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();

      expect(selectedChoice?.action, expectedAction);
      if (expectedAction == StoryMediaAction.textOnly) {
        expect(startedActions, isEmpty);
      } else {
        expect(startedActions, [expectedAction]);
        expect(await selectedChoice?.mediaFuture, isNull);
      }
      expect(find.text('Ajouter un statut'), findsNothing);
    });
  }
}
