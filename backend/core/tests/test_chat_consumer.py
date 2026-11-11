from asgiref.sync import async_to_sync
from django.contrib.auth.models import User
from django.test import TestCase
from unittest.mock import AsyncMock

from core.consumers import ChatConsumer


class ChatConsumerTests(TestCase):
    def test_private_room_resolves_numeric_user_ids(self):
        sender = User.objects.create_user(username='chat_sender')
        recipient = User.objects.create_user(username='chat_recipient')
        consumer = ChatConsumer()

        resolved_recipient = async_to_sync(consumer.get_recipient_from_room)(
            f'private_{sender.pk}_{recipient.pk}',
            sender,
        )

        self.assertEqual(resolved_recipient, recipient)

    def test_private_room_rejects_users_outside_the_conversation(self):
        sender = User.objects.create_user(username='chat_sender')
        recipient = User.objects.create_user(username='chat_recipient')
        outsider = User.objects.create_user(username='chat_outsider')
        room = f'private_{sender.pk}_{recipient.pk}'
        consumer = ChatConsumer()
        consumer.scope = {
            'url_route': {'kwargs': {'room_name': room}},
            'user': outsider,
        }
        consumer.close = AsyncMock()

        async_to_sync(consumer.connect)()

        consumer.close.assert_awaited_once_with(code=4403)
