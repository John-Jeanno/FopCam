import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/shop.dart';

void main() {
  test('parses optional shop coordinates for map navigation', () {
    final shop = Shop.fromJson({
      'id': 42,
      'name': 'Boutique locale',
      'slug': 'boutique-locale',
      'location': 'Dakar',
      'latitude': '14.716700',
      'longitude': -17.467700,
      'active': true,
    });

    expect(shop.latitude, 14.7167);
    expect(shop.longitude, -17.4677);
  });

  test('keeps shops without coordinates discoverable by address', () {
    final shop = Shop.fromJson({
      'id': 43,
      'name': 'Boutique sans coordonnées',
      'slug': 'boutique-sans-coordonnees',
      'location': 'Thiès',
      'active': true,
    });

    expect(shop.latitude, isNull);
    expect(shop.longitude, isNull);
    expect(shop.location, 'Thiès');
  });

  test('parses shop engagement counters and current user actions', () {
    final shop = Shop.fromJson({
      'id': 44,
      'name': 'Boutique appréciée',
      'slug': 'boutique-appreciee',
      'active': true,
      'like_count': 12,
      'vote_count': '4',
      'share_count': 3,
      'is_liked': true,
      'is_voted': false,
    });

    expect(shop.likeCount, 12);
    expect(shop.voteCount, 4);
    expect(shop.shareCount, 3);
    expect(shop.isLiked, isTrue);
    expect(shop.isVoted, isFalse);
  });

  test('parses storefront customization and multiple call numbers', () {
    final shop = Shop.fromJson({
      'id': 45,
      'name': 'Boutique personnalisée',
      'slug': 'boutique-personnalisee',
      'active': true,
      'phone': '+221 77 111 22 33',
      'phone_numbers': ['+221 77 111 22 33', '+221 76 444 55 66'],
      'background_color': '#102030',
      'text_color': '#F0F0F0',
      'accent_color': '#AABBCC',
      'font_size': 20,
    });

    expect(shop.phoneNumbers, ['+221 77 111 22 33', '+221 76 444 55 66']);
    expect(shop.backgroundColor, '#102030');
    expect(shop.textColor, '#F0F0F0');
    expect(shop.accentColor, '#AABBCC');
    expect(shop.fontSize, 20);
  });

  test('falls back to the legacy phone field when no phone list exists', () {
    final shop = Shop.fromJson({
      'id': 46,
      'name': 'Boutique existante',
      'slug': 'boutique-existante',
      'phone': '+221 77 000 00 00',
      'active': true,
    });

    expect(shop.phoneNumbers, ['+221 77 000 00 00']);
  });
}
