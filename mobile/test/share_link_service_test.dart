import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/share_link_service.dart';

void main() {
  test('creates direct PWA links for a shop and product', () {
    expect(
      ShareLinkService.shop(42).toString(),
      'https://5nmg.l.time4vps.cloud/fopcam/#/shop?shopId=42',
    );
    expect(
      ShareLinkService.product(84).toString(),
      'https://5nmg.l.time4vps.cloud/fopcam/#/product?productId=84',
    );
  });
}
