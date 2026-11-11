import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/services/auth_service.dart';

void main() {
  test('maps registration validation errors to their form fields', () {
    final errors = AuthService.fieldErrors({
      'email': ['This email is already in use.'],
      'password': ['This password is too short.'],
      'city': ['Cette ville est obligatoire.'],
    });

    expect(errors.keys, containsAll(['email', 'password', 'city']));
    expect(errors['email'], contains('déjà utilisée'));
    expect(errors['password'], contains('trop court'));
    expect(errors['city'], 'Cette ville est obligatoire.');
  });

  test('does not convert a general authentication error to a field error', () {
    expect(
      AuthService.fieldErrors({'detail': 'Invalid credentials.'}),
      isEmpty,
    );
  });
}
