import base64
import io
import wave
from tempfile import TemporaryDirectory

from asgiref.sync import async_to_sync
from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from core.audio_utils import audio_extension, has_audio_payload
from core.consumers import ChatConsumer
from core.models import Message


def empty_m4a():
    return (28).to_bytes(4, 'big') + b'ftypM4A ' + b'\x00' * 12


def m4a_with_audio_payload():
    ftyp = (16).to_bytes(4, 'big') + b'ftypM4A mp42'
    audio_data = b'\x01' * 256
    mdat = (len(audio_data) + 8).to_bytes(4, 'big') + b'mdat' + audio_data
    return ftyp + mdat


def wav_with_audio_payload():
    audio = io.BytesIO()
    with wave.open(audio, 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(16000)
        wav.writeframes(b'\x10\x00' * 1600)
    return audio.getvalue()


class AudioPayloadValidationTests(TestCase):
    def setUp(self):
        self.sender = User.objects.create_user(username='audio-sender')
        self.recipient = User.objects.create_user(username='audio-recipient')
        self.room = f'private_{self.sender.pk}_{self.recipient.pk}'
        self.client = APIClient()
        self.client.force_authenticate(user=self.sender)

    def test_detects_m4a_payload_and_rejects_empty_file_header(self):
        self.assertEqual(audio_extension(empty_m4a()), 'm4a')
        self.assertFalse(has_audio_payload(empty_m4a()))
        self.assertTrue(has_audio_payload(m4a_with_audio_payload()))

    def test_rest_rejects_audio_container_without_audio_data(self):
        response = self.client.post(
            '/api/messages/',
            {
                'room': self.room,
                'content': 'Message vocal',
                'message_type': 'audio',
                'attachment_type': 'audio',
                'attachment_file': SimpleUploadedFile(
                    'voice.m4a',
                    empty_m4a(),
                    content_type='audio/mp4',
                ),
            },
            format='multipart',
        )

        self.assertEqual(response.status_code, 400, response.data)
        self.assertFalse(Message.objects.filter(message_type='audio').exists())

    def test_rest_accepts_audio_container_with_media_data(self):
        with TemporaryDirectory() as media_root:
            with override_settings(MEDIA_ROOT=media_root):
                response = self.client.post(
                    '/api/messages/',
                    {
                        'room': self.room,
                        'content': 'Message vocal',
                        'message_type': 'audio',
                        'attachment_type': 'audio',
                        'attachment_file': SimpleUploadedFile(
                            'voice.m4a',
                            m4a_with_audio_payload(),
                            content_type='audio/mp4',
                        ),
                    },
                    format='multipart',
                )

        self.assertEqual(response.status_code, 201, response.data)
        self.assertTrue(
            Message.objects.filter(
                pk=response.data['id'],
                message_type='audio',
            ).exists()
        )

    def test_rest_accepts_and_persists_recorded_wav(self):
        with TemporaryDirectory() as media_root:
            with override_settings(MEDIA_ROOT=media_root):
                response = self.client.post(
                    '/api/messages/',
                    {
                        'room': self.room,
                        'content': 'Message vocal',
                        'message_type': 'audio',
                        'attachment_type': 'audio',
                        'attachment_file': SimpleUploadedFile(
                            'voice.wav',
                            wav_with_audio_payload(),
                            content_type='audio/wav',
                        ),
                    },
                    format='multipart',
                )
                self.assertEqual(response.status_code, 201, response.data)
                message = Message.objects.get(pk=response.data['id'])
                with message.attachment_file.open('rb') as uploaded:
                    self.assertEqual(uploaded.read(), wav_with_audio_payload())

    def test_websocket_rejects_audio_without_data_before_saving(self):
        with self.assertRaisesMessage(ValueError, 'ne contient pas de son'):
            async_to_sync(ChatConsumer().save_audio_message)(
                self.room,
                self.sender,
                base64.b64encode(empty_m4a()).decode('ascii'),
                4,
                self.recipient,
            )

        self.assertFalse(Message.objects.filter(message_type='audio').exists())
