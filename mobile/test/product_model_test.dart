import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/product.dart';

void main() {
  test('parses an active promotion and calculates the discount', () {
    final product = Product.fromJson({
      'id': 12,
      'title': 'Produit en promotion',
      'price': '1250.00',
      'promo_price': '900.00',
      'quantity': 4,
      'shop': 3,
      'is_active': true,
    });

    expect(product.isOnPromotion, isTrue);
    expect(product.currentPrice, 900);
    expect(product.discountPercentage, 28);
  });

  test('keeps older product payloads at their regular price', () {
    final product = Product.fromJson({
      'id': 13,
      'title': 'Produit normal',
      'price': '1250.00',
      'quantity': 4,
      'shop': 3,
      'is_active': true,
    });

    expect(product.isOnPromotion, isFalse);
    expect(product.currentPrice, 1250);
    expect(product.discountPercentage, 0);
  });

  test('parses available color and size variants', () {
    final product = Product.fromJson({
      'id': 14,
      'title': 'Vêtement',
      'price': '5000',
      'quantity': 2,
      'shop': 3,
      'is_active': true,
      'color_options': ['Rouge', 'Gris'],
      'size_options': ['L', 'XL', 'XXL'],
    });

    expect(product.colorOptions, ['Rouge', 'Gris']);
    expect(product.sizeOptions, ['L', 'XL', 'XXL']);
  });

  test('combines product gallery images without duplicates', () {
    final product = Product.fromJson({
      'id': 15,
      'title': 'Produit avec galerie',
      'price': '5000',
      'quantity': 2,
      'image': '/media/cover.jpg',
      'images': ['/media/cover.jpg', '/media/detail.jpg'],
      'shop': 3,
      'is_active': true,
    });

    expect(product.galleryImages, ['/media/cover.jpg', '/media/detail.jpg']);
  });
}
