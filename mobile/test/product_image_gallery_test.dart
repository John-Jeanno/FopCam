import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/widgets/product_image_gallery.dart';

void main() {
  testWidgets('gallery switches between product images with a swipe', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ProductImageGallery(
            images: ['/media/first.jpg', '/media/second.jpg'],
          ),
        ),
      ),
    );

    expect(find.text('1/2'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(find.text('2/2'), findsOneWidget);
  });

  testWidgets(
    'shop gallery opens fullscreen and swipes without adding to cart',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductImageGallery(
              images: ['/media/first.jpg', '/media/second.jpg'],
              enableFullscreenViewer: true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(ProductImageGallery));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Fermer la galerie'), findsOneWidget);

      await tester.drag(find.byType(PageView).last, const Offset(-700, 0));
      await tester.pumpAndSettle();

      expect(find.text('2/2'), findsOneWidget);
    },
  );
}
