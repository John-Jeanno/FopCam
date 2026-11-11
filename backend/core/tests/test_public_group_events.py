from datetime import timedelta

from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.test import APITestCase

from core.models import GroupEvent, UserProfile


class PublicGroupEventTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='event_creator',
            password='password123',
        )
        UserProfile.objects.create(user=self.user, role='buyer')
        self.client.force_authenticate(user=self.user)
        self.url = '/api/group-events/'

    def test_user_can_create_public_event_without_group(self):
        start = timezone.now() + timedelta(days=1)
        response = self.client.post(
            self.url,
            {
                'title': 'Atelier des créateurs',
                'description': 'Rencontre locale',
                'location': 'Dakar',
                'start_date': start.isoformat(),
                'end_date': (start + timedelta(hours=2)).isoformat(),
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201, response.data)
        self.assertIsNone(response.data['group'])
        self.assertTrue(
            GroupEvent.objects.filter(
                creator=self.user,
                group__isnull=True,
                title='Atelier des créateurs',
            ).exists()
        )

    def test_event_end_must_follow_start(self):
        start = timezone.now() + timedelta(days=1)
        response = self.client.post(
            self.url,
            {
                'title': 'Événement invalide',
                'start_date': start.isoformat(),
                'end_date': start.isoformat(),
            },
            format='json',
        )

        self.assertEqual(response.status_code, 400, response.data)
        self.assertIn('end_date', response.data)

    def test_attendance_requires_authentication(self):
        event = GroupEvent.objects.create(
            creator=self.user,
            title='Rencontre publique',
            start_date=timezone.now() + timedelta(days=1),
            end_date=timezone.now() + timedelta(days=1, hours=1),
        )
        self.client.force_authenticate(user=None)

        response = self.client.post(
            f'{self.url}{event.pk}/attend/',
            {'status': 'going'},
            format='json',
        )

        self.assertEqual(response.status_code, 401)
