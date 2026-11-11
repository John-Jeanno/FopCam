from pathlib import Path
from tempfile import TemporaryDirectory
from unittest.mock import patch

from django.contrib.auth.models import User
from django.core.files.base import ContentFile
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from core.models import Message


class ChatDeletionTests(TestCase):
    def setUp(self):
        self.sender = User.objects.create_user(username='delete-sender')
        self.recipient = User.objects.create_user(username='delete-recipient')
        self.other_user = User.objects.create_user(username='delete-outsider')
        self.room = (
            f'private_{min(self.sender.id, self.recipient.id)}_'
            f'{max(self.sender.id, self.recipient.id)}'
        )
        self.client = APIClient()

    def create_message(self, user=None, message_type='text'):
        author = user or self.sender
        recipient = self.recipient if author == self.sender else self.sender
        return Message.objects.create(
            room=self.room,
            user=author,
            recipient=recipient,
            content='Message à supprimer',
            message_type=message_type,
        )

    @patch('core.views.MessageViewSet._broadcast_deletion')
    def test_author_can_delete_text_message_for_both_participants(self, broadcast):
        message = self.create_message()
        self.client.force_authenticate(user=self.sender)

        with self.captureOnCommitCallbacks(execute=True):
            response = self.client.delete(f'/api/messages/{message.id}/')

        self.assertEqual(response.status_code, 204)
        self.assertFalse(Message.objects.filter(id=message.id).exists())
        broadcast.assert_called_once_with(
            self.room,
            {
                'event': 'message_deleted',
                'room': self.room,
                'message_id': message.id,
            },
        )

    def test_author_can_delete_audio_message(self):
        message = self.create_message(message_type='audio')
        self.client.force_authenticate(user=self.sender)

        response = self.client.delete(f'/api/messages/{message.id}/')

        self.assertEqual(response.status_code, 204)
        self.assertFalse(Message.objects.filter(id=message.id).exists())

    def test_deleting_message_removes_its_unreferenced_audio_file(self):
        self.client.force_authenticate(user=self.sender)
        with TemporaryDirectory() as media_root:
            with override_settings(MEDIA_ROOT=media_root):
                message = self.create_message(message_type='audio')
                message.attachment_file.save(
                    'voice.mp3',
                    ContentFile(b'audio data'),
                    save=True,
                )
                file_path = Path(media_root, message.attachment_file.name)

                with patch('core.views.MessageViewSet._broadcast_deletion'):
                    with self.captureOnCommitCallbacks(execute=True):
                        response = self.client.delete(
                            f'/api/messages/{message.id}/'
                        )

                self.assertEqual(response.status_code, 204)
                self.assertFalse(file_path.exists())

    def test_recipient_cannot_delete_another_users_message(self):
        message = self.create_message()
        self.client.force_authenticate(user=self.recipient)

        response = self.client.delete(f'/api/messages/{message.id}/')

        self.assertEqual(response.status_code, 403)
        self.assertTrue(Message.objects.filter(id=message.id).exists())

    @patch('core.views.MessageViewSet._broadcast_deletion')
    def test_either_participant_can_delete_entire_conversation(self, broadcast):
        text_message = self.create_message()
        audio_message = self.create_message(
            user=self.recipient,
            message_type='audio',
        )
        self.client.force_authenticate(user=self.recipient)

        with self.captureOnCommitCallbacks(execute=True):
            response = self.client.delete(
                '/api/messages/delete_conversation/',
                {'room': self.room},
                format='json',
            )

        self.assertEqual(response.status_code, 200, response.data)
        self.assertFalse(
            Message.objects.filter(id__in=[text_message.id, audio_message.id]).exists()
        )
        broadcast.assert_called_once_with(
            self.room,
            {'event': 'conversation_deleted', 'room': self.room},
        )

    def test_non_participant_cannot_delete_conversation(self):
        message = self.create_message()
        self.client.force_authenticate(user=self.other_user)

        response = self.client.delete(
            '/api/messages/delete_conversation/',
            {'room': self.room},
            format='json',
        )

        self.assertEqual(response.status_code, 403)
        self.assertTrue(Message.objects.filter(id=message.id).exists())
