import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/app_locale_service.dart';

void main() {
  test('exposes each requested language once', () {
    final codes = AppLocaleService.languages.map((language) => language.code);

    expect(codes.length, 25);
    expect(codes.toSet().length, 25);
    expect(AppLocaleService.isSupported('zh-Hans'), isTrue);
    expect(AppLocaleService.isSupported('zh'), isFalse);
  });

  test('chooses a supported default locale from a country code', () {
    expect(AppLocaleService.languageForCountry('SN'), 'fr');
    expect(AppLocaleService.languageForCountry('CN'), 'zh-Hans');
    expect(AppLocaleService.languageForCountry('JP'), 'ja');
    expect(AppLocaleService.languageForCountry('XX'), isNull);
  });
}
