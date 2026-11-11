from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework.test import APIClient

from core.models import Friend, Notification


class NotificationActionTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='notify-user')
        self.other_user = User.objects.create_user(username='notify-other')
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_mark_all_read_only_changes_current_users_notifications(self):
        unread = Notification.objects.create(
            user=self.user,
            title='Commande',
            message='Nouvelle commande',
            type='order',
        )
        Notification.objects.create(
            user=self.user,
            title='Message',
            message='Nouveau message',
            type='message',
            is_read=True,
        )
        other_unread = Notification.objects.create(
            user=self.other_user,
            title='Privée',
            message='Notification privée',
            type='info',
        )

        response = self.client.post('/api/notifications/mark_all_read/')

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['updated'], 1)
        unread.refresh_from_db()
        other_unread.refresh_from_db()
        self.assertTrue(unread.is_read)
        self.assertFalse(other_unread.is_read)

    def test_friend_request_creates_actionable_notification(self):
        response = self.client.post(
            '/api/friends/',
            {'receiver_id': self.other_user.id},
            format='json',
        )

        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(Friend.objects.count(), 1)
        notification = Notification.objects.get(user=self.other_user)
        self.assertEqual(notification.type, 'friend_request')
        self.assertEqual(
            notification.data,
            {
                'requester_id': self.user.id,
                'requester_username': self.user.username,
                'friend_request_id': response.data['id'],
            },
        )
