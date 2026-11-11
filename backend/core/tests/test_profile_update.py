import io
import tempfile

from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from rest_framework.test import APITestCase, APIClient
from PIL import Image

from core.models import Friend, UserProfile


class ProfileUpdateTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='visitor',
            email='visitor@example.com',
            password='password123'
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)
        self.url = '/api/auth/profile/'
        self.profile = UserProfile.objects.create(user=self.user, role='buyer')

    def make_image_file(self, name, fmt):
        buffer = io.BytesIO()
        Image.new('RGB', (1, 1), color='white').save(buffer, format=fmt)
        buffer.seek(0)
        content_type = 'image/png' if fmt == 'PNG' else 'image/gif'
        return SimpleUploadedFile(name, buffer.read(), content_type=content_type)

    def test_visitor_can_update_profile_images(self):
        profile_image = self.make_image_file('profile.png', 'PNG')
        cover_image = self.make_image_file('cover.gif', 'GIF')

        response = self.client.patch(self.url, {
            'first_name': 'Visiteur',
            'last_name': 'Test',
            'profile_image': profile_image,
            'cover_image': cover_image,
        }, format='multipart')

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['user']['first_name'], 'Visiteur')
        self.assertEqual(response.data['user']['last_name'], 'Test')
        self.assertTrue(response.data['profile_image'])
        self.assertTrue(response.data['cover_image'])

        self.profile.refresh_from_db()
        self.assertEqual(self.profile.user.first_name, 'Visiteur')
        self.assertEqual(self.profile.user.last_name, 'Test')
        self.assertIsNotNone(self.profile.profile_image)
        self.assertIsNotNone(self.profile.cover_image)

        profile_image_url = response.data['profile_image']
        cover_image_url = response.data['cover_image']
        refreshed_response = self.client.get(self.url)

        self.assertEqual(refreshed_response.status_code, 200, refreshed_response.data)
        self.assertEqual(refreshed_response.data['profile_image'], profile_image_url)
        self.assertEqual(refreshed_response.data['cover_image'], cover_image_url)

    def test_visitor_can_update_only_the_profile_photo(self):
        response = self.client.patch(
            self.url,
            {'profile_image': self.make_image_file('avatar.png', 'PNG')},
            format='multipart',
        )

        self.assertEqual(response.status_code, 200, response.data)
        self.assertTrue(response.data['profile_image'])
        self.assertFalse(response.data['cover_image'])
        self.profile.refresh_from_db()
        self.assertTrue(self.profile.profile_image)
        self.assertFalse(self.profile.cover_image)

    def test_get_profile_creates_user_profile_if_missing(self):
        self.profile.delete()

        response = self.client.get(self.url)

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['user']['username'], 'visitor')
        self.assertEqual(response.data['role'], 'particular')
        self.assertTrue(UserProfile.objects.filter(user=self.user).exists())

    def test_get_profile_reuses_existing_inactive_profile_with_images(self):
        with tempfile.TemporaryDirectory() as media_root:
            with override_settings(MEDIA_ROOT=media_root):
                self.profile.profile_image = self.make_image_file(
                    'saved-profile.png',
                    'PNG',
                )
                self.profile.cover_image = self.make_image_file(
                    'saved-cover.png',
                    'PNG',
                )
                self.profile.save()
                self.profile.is_active = False
                self.profile.save(update_fields=('is_active',))

                response = self.client.get(self.url)

                self.assertEqual(response.status_code, 200, response.data)
                self.assertEqual(response.data['id'], self.profile.id)
                self.assertTrue(
                    response.data['profile_image'].endswith(
                        self.profile.profile_image.name,
                    )
                )
                self.assertTrue(
                    response.data['cover_image'].endswith(
                        self.profile.cover_image.name,
                    )
                )
                self.profile.refresh_from_db()
                self.assertTrue(self.profile.is_active)

    def test_directory_uses_latest_profile_when_no_profile_is_active(self):
        other_user = User.objects.create_user(username='directoryuser')
        with tempfile.TemporaryDirectory() as media_root:
            with override_settings(MEDIA_ROOT=media_root):
                profile = UserProfile.objects.create(
                    user=other_user,
                    role='particular',
                    profile_image=self.make_image_file(
                        'directory-avatar.png',
                        'PNG',
                    ),
                    cover_image=self.make_image_file(
                        'directory-cover.png',
                        'PNG',
                    ),
                )
                self.client.force_authenticate(user=self.user)

                response = self.client.get('/api/users/directory/')

                self.assertEqual(response.status_code, 200, response.data)
                users = response.data.get('results', response.data)
                directory_user = next(
                    user for user in users if user['id'] == other_user.id
                )
                self.assertTrue(
                    directory_user['profile_image'].endswith(
                        profile.profile_image.name,
                    )
                )

                public_profile = self.client.get(
                    f'/api/users/{other_user.username}/'
                )
                self.assertEqual(
                    public_profile.status_code,
                    200,
                    public_profile.data,
                )
                self.assertTrue(
                    public_profile.data['cover_image'].endswith(
                        profile.cover_image.name,
                    )
                )

    def test_owner_can_update_privacy_settings(self):
        response = self.client.patch(
            self.url,
            {
                'profile_visibility': 'private',
                'phone_visibility': 'public',
            },
            format='json',
        )

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['profile_visibility'], 'private')
        self.assertEqual(response.data['phone_visibility'], 'public')
        self.profile.refresh_from_db()
        self.assertEqual(self.profile.profile_visibility, 'private')
        self.assertEqual(self.profile.phone_visibility, 'public')

    def test_owner_can_save_notification_sounds(self):
        preferences = {
            'messages': 'soft',
            'games': 'festive',
            'social': 'system',
            'orders': 'alert',
            'other': 'system',
        }

        response = self.client.patch(
            self.url,
            {'notification_sounds': preferences},
            format='json',
        )

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['notification_sounds'], preferences)
        self.profile.refresh_from_db()
        self.assertEqual(self.profile.notification_sounds, preferences)

    def test_notification_sounds_reject_unknown_categories_and_sounds(self):
        invalid_category = self.client.patch(
            self.url,
            {'notification_sounds': {'unknown': 'soft'}},
            format='json',
        )
        invalid_sound = self.client.patch(
            self.url,
            {'notification_sounds': {'messages': 'loud'}},
            format='json',
        )

        self.assertEqual(invalid_category.status_code, 400)
        self.assertEqual(invalid_sound.status_code, 400)

    def test_owner_can_save_experience_education_services_and_language(self):
        experience = [{
            'title': 'Développeuse',
            'organization': 'FopCam',
            'location': 'Dakar',
            'start_date': '2022',
            'end_date': '2025',
            'description': 'Développement mobile',
        }]
        education = [{
            'title': 'Informatique',
            'institution': 'Université de Dakar',
            'start_date': '2018',
            'end_date': '2021',
            'description': 'Licence',
        }]
        skills = [{
            'title': 'Flutter',
            'level': 'Avancé',
            'description': 'Développement d’applications mobiles',
        }]
        services = [{
            'title': 'Création d’applications',
            'description': 'Développement Flutter',
            'price': '25000.00',
            'currency': 'FCFA',
        }]

        response = self.client.patch(
            self.url,
            {
                'preferred_language': 'en',
                'experience_and_journey': experience,
                'education_and_training': education,
                'skills': skills,
                'services': services,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 200, response.data)
        self.profile.refresh_from_db()
        self.assertEqual(self.profile.preferred_language, 'en')
        self.assertEqual(self.profile.experience_and_journey, experience)
        self.assertEqual(self.profile.education_and_training, education)
        self.assertEqual(self.profile.skills, skills)
        self.assertEqual(self.profile.services[0]['title'], services[0]['title'])

        public_response = self.client.get('/api/users/visitor/')
        self.assertEqual(public_response.status_code, 200, public_response.data)
        self.assertEqual(
            public_response.data['services'][0]['title'],
            services[0]['title'],
        )
        self.assertEqual(public_response.data['skills'], skills)

    def test_all_profile_sections_are_visible_to_anonymous_public_visitors(self):
        experience = [{'title': 'Développeuse', 'organization': 'FopCam'}]
        education = [{'title': 'Informatique', 'institution': 'Université'}]
        skills = [{'title': 'Flutter', 'level': 'Avancé'}]
        services = [{'title': 'Création d’applications'}]
        self.profile.is_active = True
        self.profile.profile_visibility = 'public'
        self.profile.experience_and_journey = experience
        self.profile.education_and_training = education
        self.profile.skills = skills
        self.profile.services = services
        self.profile.save()
        self.client.force_authenticate(user=None)

        response = self.client.get('/api/users/visitor/')

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['experience_and_journey'], experience)
        self.assertEqual(response.data['education_and_training'], education)
        self.assertEqual(response.data['skills'], skills)
        self.assertEqual(response.data['services'], services)
        self.assertNotIn('notification_sounds', response.data)
        self.assertNotIn('email', response.data)

    def test_profile_sections_reject_invalid_languages_and_oversized_lists(self):
        invalid_language = self.client.patch(
            self.url,
            {'preferred_language': 'xx'},
            format='json',
        )
        too_many_services = self.client.patch(
            self.url,
            {'services': [{'title': f'Service {index}'} for index in range(51)]},
            format='json',
        )

        self.assertEqual(invalid_language.status_code, 400)
        self.assertEqual(too_many_services.status_code, 400)

    def test_private_profile_is_not_visible_to_other_users(self):
        self.profile.is_active = True
        self.profile.profile_visibility = 'private'
        self.profile.save()
        other_user = User.objects.create_user(username='privatevisitor')

        self.client.force_authenticate(user=other_user)
        public_profile = self.client.get('/api/users/visitor/')
        profile_detail = self.client.get('/api/profiles/visitor/')
        directory = self.client.get('/api/users/directory/')

        self.assertEqual(public_profile.status_code, 404)
        self.assertEqual(profile_detail.status_code, 404)
        users = directory.data.get('results', directory.data)
        self.assertNotIn(self.user.id, [user['id'] for user in users])

    def test_private_profile_remains_visible_to_accepted_friends(self):
        self.profile.is_active = True
        self.profile.profile_visibility = 'private'
        self.profile.save()
        friend = User.objects.create_user(username='friend')
        Friend.objects.create(
            requester=self.user,
            receiver=friend,
            status='accepted',
        )
        self.client.force_authenticate(user=friend)

        response = self.client.get('/api/users/visitor/')

        self.assertEqual(response.status_code, 200, response.data)

    def test_private_phone_is_hidden_from_public_profile_listing(self):
        self.profile.phone = '+221770000000'
        self.profile.is_active = True
        self.profile.profile_visibility = 'public'
        self.profile.phone_visibility = 'private'
        self.profile.save()
        self.client.force_authenticate(user=None)

        response = self.client.get('/api/profiles/')

        self.assertEqual(response.status_code, 200, response.data)
        profiles = response.data.get('results', response.data)
        profile_data = next(item for item in profiles if item['id'] == self.profile.id)
        self.assertIsNone(profile_data['phone'])
        public_profile = self.client.get('/api/users/visitor/')
        self.assertEqual(public_profile.status_code, 200, public_profile.data)
        self.assertIsNone(public_profile.data['phone'])

    def test_public_phone_is_visible_on_public_profile(self):
        self.profile.phone = '+221770000000'
        self.profile.is_active = True
        self.profile.phone_visibility = 'public'
        self.profile.save()
        self.client.force_authenticate(user=None)

        response = self.client.get('/api/users/visitor/')

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['phone'], '+221770000000')
