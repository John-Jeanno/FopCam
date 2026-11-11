import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/user.dart';
import 'package:mobile/widgets/profile_portfolio_editor.dart';

void main() {
  testWidgets('portfolio entry dialogs use white text and date pickers', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProfilePortfolioEditor(
            user: User(
              id: 1,
              username: 'test',
              email: 'test@example.com',
              role: 'particular',
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.widgetWithText(TextButton, 'Ajouter').first);
    await tester.pumpAndSettle();

    final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog).first);
    expect(dialog.backgroundColor, const Color(0xFF581A1A));
    final firstInput = find.descendant(
      of: find.byType(TextFormField).first,
      matching: find.byType(TextField),
    );
    expect(tester.widget<TextField>(firstInput).style?.color, Colors.white);

    await tester.tap(find.byTooltip('Choisir date de début'));
    await tester.pumpAndSettle();
    expect(find.byType(CalendarDatePicker), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('shows editable profile sections in a desktop grid', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 1200,
              child: ProfilePortfolioEditor(
                user: User(
                  id: 1,
                  username: 'test',
                  email: 'test@example.com',
                  role: 'particular',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('Expériences et parcours'), findsOneWidget);
    expect(find.text('Profil et formations'), findsOneWidget);
    expect(find.text('Mes compétences'), findsOneWidget);
    expect(find.text('Mes services'), findsOneWidget);

    final firstCardX = tester.getTopLeft(find.byType(Card).at(0)).dx;
    final secondCardX = tester.getTopLeft(find.byType(Card).at(1)).dx;
    expect(secondCardX, greaterThan(firstCardX + 500));
  });
}
