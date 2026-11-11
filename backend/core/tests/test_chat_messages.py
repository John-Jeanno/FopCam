from asgiref.sync import async_to_sync
from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework.test import APIClient

from core.consumers import ChatConsumer
from core.models import Message


class ChatMessageReplyTests(TestCase):
    def setUp(self):
        self.sender = User.objects.create_user(username='reply-sender')
        self.recipient = User.objects.create_user(username='reply-recipient')
        self.outsider = User.objects.create_user(username='reply-outsider')
        self.room = f'private_{self.sender.pk}_{self.recipient.pk}'
        self.client = APIClient()
        self.client.force_authenticate(user=self.sender)

    def test_create_message_with_reply_returns_limited_preview(self):
        original = Message.objects.create(
            room=self.room,
            user=self.recipient,
            recipient=self.sender,
            content='Message d’origine',
        )

        response = self.client.post(
            '/api/messages/',
            {
                'room': self.room,
                'content': 'Ma réponse',
                'message_type': 'text',
                'reply_to_id': original.pk,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(
            response.data['reply_to'],
            {
                'id': original.pk,
                'content': 'Message d’origine',
                'message_type': 'text',
                'user': {
                    'id': self.recipient.pk,
                    'username': self.recipient.username,
                },
            },
        )
        self.assertEqual(
            Message.objects.get(pk=response.data['id']).reply_to_id,
            original.pk,
        )

    def test_cannot_reply_to_message_from_another_room(self):
        other_room = f'private_{self.sender.pk}_{self.outsider.pk}'
        original = Message.objects.create(
            room=other_room,
            user=self.outsider,
            recipient=self.sender,
            content='Message privé',
        )

        response = self.client.post(
            '/api/messages/',
            {
                'room': self.room,
                'content': 'Réponse non autorisée',
                'message_type': 'text',
                'reply_to_id': original.pk,
            },
            format='json',
        )

        self.assertEqual(response.status_code, 400)
        self.assertFalse(
            Message.objects.filter(content='Réponse non autorisée').exists(),
        )

    def test_websocket_message_reply_is_limited_to_the_same_room(self):
        original = Message.objects.create(
            room=self.room,
            user=self.recipient,
            recipient=self.sender,
            content='Message d’origine',
        )
        consumer = ChatConsumer()

        reply = async_to_sync(consumer.save_message)(
            self.room,
            self.sender,
            'Réponse WebSocket',
            self.recipient,
            'text',
            original.pk,
        )

        self.assertEqual(reply.reply_to_id, original.pk)
        preview = async_to_sync(consumer.get_message_reply_preview)(
            original.pk,
        )
        self.assertEqual(preview['content'], 'Message d’origine')
        self.assertEqual(preview['user']['username'], self.recipient.username)

        other_room = f'private_{self.sender.pk}_{self.outsider.pk}'
        elsewhere = Message.objects.create(
            room=other_room,
            user=self.outsider,
            recipient=self.sender,
            content='Message privé',
        )
        with self.assertRaises(ValueError):
            async_to_sync(consumer.save_message)(
                self.room,
                self.sender,
                'Réponse hors discussion',
                self.recipient,
                'text',
                elsewhere.pk,
            )
