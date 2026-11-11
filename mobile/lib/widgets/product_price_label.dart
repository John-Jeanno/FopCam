import 'package:flutter/material.dart';
import 'package:mobile/models/product.dart';

class ProductPriceLabel extends StatelessWidget {
  const ProductPriceLabel({
    super.key,
    required this.product,
    this.color = Colors.white,
    this.fontSize = 14,
  });

  final Product product;
  final Color color;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (!product.isOnPromotion) {
      return Text(
        '${product.price.toStringAsFixed(0)} FCFA',
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 7,
      runSpacing: 4,
      children: [
        Text(
          '${product.currentPrice.toStringAsFixed(0)} FCFA',
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          '${product.price.toStringAsFixed(0)} FCFA',
          style: TextStyle(
            color: color.withValues(alpha: 0.62),
            fontSize: fontSize - 2,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '-${product.discountPercentage} %',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
