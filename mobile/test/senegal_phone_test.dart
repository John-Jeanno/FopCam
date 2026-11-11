import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/senegal_phone.dart';

void main() {
  test('uses Senegal country code for local phone numbers', () {
    expect(normalizeSenegalPhone('77 000 00 00'), '+221770000000');
    expect(normalizeSenegalPhone('+221 77 000 00 00'), '+221770000000');
    expect(normalizeSenegalPhone('077 000 00 00'), '+221770000000');
  });

  test('rejects phone numbers that are not valid Senegal local numbers', () {
    expect(normalizeSenegalPhone('77 000 00'), isNull);
    expect(normalizeSenegalPhone('+224 77 000 00 00'), isNull);
  });
}
