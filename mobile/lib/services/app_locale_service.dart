import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLanguage {
  const AppLanguage(this.code, this.name);

  final String code;
  final String name;
}

class AppLocaleService {
  static const languages = <AppLanguage>[
    AppLanguage('fr', 'Français'),
    AppLanguage('en', 'English'),
    AppLanguage('zh-Hans', '简体中文'),
    AppLanguage('de', 'Deutsch'),
    AppLanguage('pt', 'Português'),
    AppLanguage('es', 'Español'),
    AppLanguage('ar', 'العربية'),
    AppLanguage('ru', 'Русский'),
    AppLanguage('hi', 'हिन्दी'),
    AppLanguage('bn', 'বাংলা'),
    AppLanguage('id', 'Bahasa Indonesia'),
    AppLanguage('ur', 'اردو'),
    AppLanguage('ja', '日本語'),
    AppLanguage('sw', 'Kiswahili'),
    AppLanguage('it', 'Italiano'),
    AppLanguage('nl', 'Nederlands'),
    AppLanguage('tr', 'Türkçe'),
    AppLanguage('ko', '한국어'),
    AppLanguage('fa', 'فارسی'),
    AppLanguage('th', 'ไทย'),
    AppLanguage('pl', 'Polski'),
    AppLanguage('vi', 'Tiếng Việt'),
    AppLanguage('uk', 'Українська'),
    AppLanguage('ro', 'Română'),
    AppLanguage('el', 'Ελληνικά'),
  ];

  static const _preferenceKey = 'preferred_language';
  static final ValueNotifier<Locale> locale = ValueNotifier(
    _systemLocaleOrFrench(),
  );

  static List<Locale> get supportedLocales =>
      languages.map((language) => localeFromTag(language.code)).toList();

  static Locale localeFromTag(String tag) {
    final parts = tag.split('-');
    return parts.length > 1
        ? Locale.fromSubtags(languageCode: parts[0], scriptCode: parts[1])
        : Locale(parts.first);
  }

  static String localeTag(Locale value) => value.scriptCode == null
      ? value.languageCode
      : '${value.languageCode}-${value.scriptCode}';

  static Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    final savedLanguage = preferences.getString(_preferenceKey);
    if (savedLanguage != null && isSupported(savedLanguage)) {
      locale.value = localeFromTag(savedLanguage);
      return;
    }
    locale.value = _systemLocaleOrFrench();
  }

  static Future<void> setLanguage(String languageCode) async {
    if (!isSupported(languageCode)) {
      throw ArgumentError.value(languageCode, 'languageCode', 'Unsupported');
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, languageCode);
    locale.value = localeFromTag(languageCode);
  }

  static Future<void> applyAccountPreference({
    required String preferredLanguage,
    required String countryCode,
  }) async {
    final language = isSupported(preferredLanguage)
        ? preferredLanguage
        : languageForCountry(countryCode) ?? localeTag(_systemLocaleOrFrench());
    await setLanguage(language);
  }

  static bool isSupported(String code) =>
      languages.any((language) => language.code == code);

  static String? languageForCountry(String countryCode) {
    final country = countryCode.toUpperCase();
    const countryLanguages = <String, String>{
      'AF': 'fa',
      'AL': 'el',
      'AM': 'ru',
      'AO': 'pt',
      'AR': 'es',
      'AT': 'de',
      'BD': 'bn',
      'BE': 'nl',
      'BF': 'fr',
      'BG': 'ru',
      'BJ': 'fr',
      'BR': 'pt',
      'BY': 'ru',
      'CA': 'en',
      'CH': 'de',
      'CI': 'fr',
      'CM': 'fr',
      'CN': 'zh-Hans',
      'CZ': 'pl',
      'DE': 'de',
      'DK': 'nl',
      'DZ': 'ar',
      'EG': 'ar',
      'ES': 'es',
      'ET': 'am',
      'FI': 'en',
      'FR': 'fr',
      'GB': 'en',
      'GH': 'en',
      'GR': 'el',
      'HT': 'fr',
      'ID': 'id',
      'IE': 'en',
      'IL': 'ar',
      'IN': 'hi',
      'IR': 'fa',
      'IT': 'it',
      'JP': 'ja',
      'KE': 'sw',
      'KR': 'ko',
      'LU': 'fr',
      'MA': 'ar',
      'ML': 'fr',
      'MX': 'es',
      'NG': 'en',
      'NL': 'nl',
      'NO': 'en',
      'NP': 'hi',
      'PK': 'ur',
      'PL': 'pl',
      'PT': 'pt',
      'RO': 'ro',
      'RU': 'ru',
      'SA': 'ar',
      'SE': 'en',
      'SN': 'fr',
      'TH': 'th',
      'TN': 'ar',
      'TR': 'tr',
      'TZ': 'sw',
      'UA': 'uk',
      'US': 'en',
      'VN': 'vi',
      'ZA': 'en',
    };
    final language = countryLanguages[country];
    return language != null && isSupported(language) ? language : null;
  }

  static Locale _systemLocaleOrFrench() {
    final systemLocale = PlatformDispatcher.instance.locale;
    final code = localeTag(systemLocale);
    if (isSupported(code)) return localeFromTag(code);
    if (isSupported(systemLocale.languageCode)) {
      return Locale(systemLocale.languageCode);
    }
    return const Locale('fr');
  }
}
