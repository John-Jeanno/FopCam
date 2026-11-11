// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    // Render one frame and verify either the loading indicator or the login text appears.
    await tester.pump();
    final loading = find.byType(CircularProgressIndicator);
    final loginText = find.text('Connexion FopCam');
    expect(
      loading.evaluate().isNotEmpty || loginText.evaluate().isNotEmpty,
      true,
    );
  });
}
