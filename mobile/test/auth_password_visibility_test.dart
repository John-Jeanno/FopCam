import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/login_screen.dart';
import 'package:mobile/screens/register_screen.dart';

void main() {
  for (final screen in [
    ('login', const LoginScreen()),
    ('registration', const RegisterScreen()),
  ]) {
    testWidgets('${screen.$1} password can be shown and hidden', (
      tester,
    ) async {
      await tester.pumpWidget(MaterialApp(home: screen.$2));

      final passwordField = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Mot de passe',
      );
      await tester.ensureVisible(passwordField);
      expect(tester.widget<TextField>(passwordField).obscureText, isTrue);

      await tester.tap(find.byTooltip('Afficher le mot de passe'));
      await tester.pump();
      expect(tester.widget<TextField>(passwordField).obscureText, isFalse);

      await tester.tap(find.byTooltip('Masquer le mot de passe'));
      await tester.pump();
      expect(tester.widget<TextField>(passwordField).obscureText, isTrue);
    });
  }
}
