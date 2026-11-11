import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/login_screen.dart';
import 'package:mobile/screens/register_screen.dart';
import 'package:mobile/widgets/responsive_app_frame.dart';

void main() {
  testWidgets('centers and caps the app width on desktop', (tester) async {
    await tester.binding.setSurfaceSize(const Size(2560, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const contentKey = Key('responsive-content');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResponsiveAppFrame(child: SizedBox.expand(key: contentKey)),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(contentKey)).width, 1920);
    expect(tester.getTopLeft(find.byKey(contentKey)).dx, 320);
  });

  testWidgets('keeps the available width below the desktop breakpoint', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const contentKey = Key('responsive-content');

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ResponsiveAppFrame(child: SizedBox.expand(key: contentKey)),
        ),
      ),
    );

    expect(tester.getSize(find.byKey(contentKey)).width, 800);
  });

  testWidgets('keeps authentication forms readable on a desktop viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
    final loginField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText == 'Nom d’utilisateur ou email',
    );
    expect(tester.getSize(loginField).width, lessThanOrEqualTo(520));

    await tester.pumpWidget(const MaterialApp(home: RegisterScreen()));
    await tester.pump();
    final registrationField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Email',
    );
    expect(tester.getSize(registrationField).width, lessThanOrEqualTo(820));
  });
}
