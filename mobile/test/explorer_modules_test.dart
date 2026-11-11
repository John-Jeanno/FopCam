import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/explorer_screen.dart';

void main() {
  const moduleRoutes = <String, String>{
    'Statuts': '/stories',
    'Clips': '/reels',
    'Directs': '/live',
    'Carte sociale': '/map',
    'Collaborations': '/collaboration',
    'Communautés': '/groups',
    'Événements': '/create_event',
    'Effets AR': '/ar_effects',
    'Recherche avancée': '/advanced_search',
    'Jeu FopCam': '/game',
    'Légendes': '/game/legends',
  };

  testWidgets('modules remain available while categories and shops load', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final loadData = Completer<ExplorerData>();

    await tester.pumpWidget(
      MaterialApp(home: ExplorerScreen(loadData: () => loadData.future)),
    );
    await tester.pump();
    for (final title in moduleRoutes.keys) {
      expect(find.text(title), findsOneWidget);
    }
  });

  testWidgets('each discovery module opens its destination', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final data = ExplorerData(categories: [], shops: []);

    await tester.pumpWidget(
      MaterialApp(
        home: ExplorerScreen(loadData: () async => data),
        routes: {
          for (final route in moduleRoutes.values)
            route: (_) =>
                Scaffold(body: Center(child: Text('Destination: $route'))),
        },
      ),
    );
    await tester.pump();

    for (final entry in moduleRoutes.entries) {
      final module = find.text(entry.key);
      await tester.ensureVisible(module);
      await tester.tap(module);
      await tester.pumpAndSettle();
      expect(find.text('Destination: ${entry.value}'), findsOneWidget);
      Navigator.of(
        tester.element(find.text('Destination: ${entry.value}')),
      ).pop();
      await tester.pumpAndSettle();
    }
  });
}
