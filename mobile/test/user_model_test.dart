import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/user.dart';

void main() {
  test('parses directory profile and connection metadata', () {
    final user = User.fromJson({
      'id': 42,
      'username': 'fopcam-user',
      'first_name': 'Awa',
      'last_name': 'Sow',
      'role': 'producer',
      'is_online': true,
      'connection_status': 'pending',
      'friend_request_id': 7,
      'friend_request_direction': 'incoming',
      'bio': 'Productrice',
      'city': 'Dakar',
    });

    expect(user.id, 42);
    expect(user.username, 'fopcam-user');
    expect(user.firstName, 'Awa');
    expect(user.role, 'producer');
    expect(user.isOnline, isTrue);
    expect(user.connectionStatus, 'pending');
    expect(user.friendRequestId, 7);
    expect(user.friendRequestDirection, 'incoming');
    expect(user.email, isEmpty);
  });

  test('parses profile sections and language preferences', () {
    final user = User.fromJson({
      'id': 8,
      'username': 'profil',
      'preferred_language': 'zh-Hans',
      'country': 'Sénégal',
      'country_code': 'SN',
      'experience_and_journey': [
        {'title': 'Designer', 'organization': 'Studio'},
      ],
      'education_and_training': [
        {'title': 'Design', 'institution': 'École'},
      ],
      'skills': [
        {'title': 'Flutter', 'level': 'Avancé'},
      ],
      'services': [
        {'title': 'Création visuelle', 'price': '15000.00'},
      ],
      'role': 'particular',
    });

    expect(user.preferredLanguage, 'zh-Hans');
    expect(user.countryCode, 'SN');
    expect(user.experienceAndJourney.single['organization'], 'Studio');
    expect(user.educationAndTraining.single['institution'], 'École');
    expect(user.skills.single['level'], 'Avancé');
    expect(user.services.single['price'], '15000.00');
  });
}
