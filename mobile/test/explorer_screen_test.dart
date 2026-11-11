import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/product.dart';
import 'package:mobile/screens/explorer_screen.dart';

void main() {
  test(
    'categories are sorted alphabetically without accent ordering issues',
    () {
      final categories = [
        Category(id: 1, name: 'Services', categoryType: 'professional'),
        Category(id: 2, name: 'Équipement agricole', categoryType: 'product'),
        Category(id: 3, name: 'Agriculture', categoryType: 'product'),
        Category(id: 4, name: 'Éducation', categoryType: 'professional'),
      ];

      expect(
        sortExplorerCategories(categories).map((category) => category.name),
        ['Agriculture', 'Éducation', 'Équipement agricole', 'Services'],
      );
    },
  );

  testWidgets('categories are displayed in a dropdown', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: ExplorerScreen(
          loadData: () async => ExplorerData(
            categories: [
              Category(
                id: 1,
                name: 'Équipement agricole',
                categoryType: 'product',
              ),
              Category(id: 2, name: 'Agriculture', categoryType: 'product'),
            ],
            shops: [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DropdownButtonFormField<int?>), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<int?>));
    await tester.pumpAndSettle();
    expect(find.text('Toutes les catégories'), findsWidgets);
    expect(find.text('Agriculture'), findsWidgets);
    expect(find.text('Équipement agricole'), findsWidgets);
  });

  test('category selection targets its matching explorer scope', () {
    final productCategory = Category(
      id: 1,
      name: 'Artisanat',
      categoryType: 'product',
    );
    final serviceCategory = Category(
      id: 2,
      name: 'Formation',
      categoryType: 'professional',
    );

    expect(explorerScopeForCategory(productCategory), 'products');
    expect(explorerScopeForCategory(serviceCategory), 'services');
  });
}
