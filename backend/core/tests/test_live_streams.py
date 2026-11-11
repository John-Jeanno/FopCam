import json
from datetime import datetime, timezone
from types import SimpleNamespace
from unittest.mock import patch

from django.contrib.auth.models import User
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

import jwt
from core import livekit_service


class LiveStreamsApiTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.user = User.objects.create_user(
            username='live-host',
            password='password123',
        )

    @patch('core.live_streams.livekit_service.list_live_rooms')
    def test_public_list_contains_active_streams_and_host(self, list_rooms):
        list_rooms.return_value = [{
            'id': 'fopcam-live-room',
            'room_name': 'fopcam-live-room',
            'title': 'Présentation',
            'category': 'Commerce',
            'owner_id': self.user.pk,
            'viewers': 2,
            'started_at': '2026-03-01T10:00:00+00:00',
            'is_live': True,
        }]

        response = self.client.get('/api/live-streams/')

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data[0]['host']['username'], self.user.username)
        self.assertEqual(response.data[0]['viewers'], 2)

    def test_unconfigured_service_returns_explicit_unavailable_response(self):
        with override_settings(
            LIVEKIT_URL='',
            LIVEKIT_API_KEY='',
            LIVEKIT_API_SECRET='',
        ):
            response = self.client.get('/api/live-streams/')

        self.assertEqual(response.status_code, 503)
        self.assertIn('LiveKit', response.data['detail'])

    def test_start_requires_title(self):
        self.client.force_authenticate(self.user)

        response = self.client.post('/api/live-streams/', {}, format='json')

        self.assertEqual(response.status_code, 400)
        self.assertIn('title', response.data)

    def test_start_requires_authentication(self):
        response = self.client.post(
            '/api/live-streams/',
            {'title': 'Présentation'},
            format='json',
        )

        self.assertEqual(response.status_code, 401)

    @patch('core.live_streams.livekit_service.create_live_room')
    def test_authenticated_user_can_start_a_stream(self, create_room):
        self.client.force_authenticate(self.user)
        create_room.return_value = {
            'room_name': 'fopcam-live-room',
            'url': 'wss://example.livekit.cloud',
            'token': 'short-lived-token',
        }

        response = self.client.post(
            '/api/live-streams/',
            {'title': 'Présentation de ma boutique'},
            format='json',
        )

        self.assertEqual(response.status_code, 201)
        self.assertEqual(response.data['room_name'], 'fopcam-live-room')
        create_room.assert_called_once_with(
            self.user.pk,
            'Présentation de ma boutique',
            'Commerce',
        )

    @patch('core.live_streams.livekit_service.create_viewer_token')
    @patch('core.live_streams.livekit_service.find_live_room')
    def test_authenticated_user_can_join_a_live_room(self, find_room, create_token):
        self.client.force_authenticate(self.user)
        find_room.return_value = {'room_name': 'fopcam-live-room'}
        create_token.return_value = 'viewer-token'

        response = self.client.post(
            '/api/live-streams/fopcam-live-room/join/',
            {},
            format='json',
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['token'], 'viewer-token')

    @patch('core.live_streams.livekit_service.end_live_room')
    @patch('core.live_streams.livekit_service.find_live_room')
    def test_only_the_owner_can_end_a_live_room(self, find_room, end_room):
        find_room.return_value = {'owner_id': self.user.pk + 1}
        self.client.force_authenticate(self.user)

        response = self.client.delete('/api/live-streams/fopcam-live-room/')

        self.assertEqual(response.status_code, 403)
        end_room.assert_not_called()

    @patch('core.live_streams.livekit_service.end_live_room')
    @patch('core.live_streams.livekit_service.find_live_room')
    def test_owner_can_end_a_live_room(self, find_room, end_room):
        find_room.return_value = {'owner_id': self.user.pk}
        self.client.force_authenticate(self.user)

        response = self.client.delete('/api/live-streams/fopcam-live-room/')

        self.assertEqual(response.status_code, 204)
        end_room.assert_called_once_with('fopcam-live-room')

    @patch('core.livekit_service._call_livekit')
    def test_live_room_listing_ignores_non_fopcam_rooms(self, call_livekit):
        created = int(datetime(2026, 6, 15, tzinfo=timezone.utc).timestamp())
        call_livekit.return_value = SimpleNamespace(rooms=[
            SimpleNamespace(
                name='fopcam-live-room',
                metadata=json.dumps({
                    'owner_id': self.user.pk,
                    'title': 'Présentation',
                    'category': 'Commerce',
                }),
                creation_time=created,
                num_participants=3,
            ),
            SimpleNamespace(
                name='unrelated-room',
                metadata='{}',
                creation_time=created,
                num_participants=1,
            ),
        ])

        streams = livekit_service.list_live_rooms()

        self.assertEqual(len(streams), 1)
        self.assertEqual(streams[0]['viewers'], 2)
        self.assertEqual(streams[0]['owner_id'], self.user.pk)

    @override_settings(
        LIVEKIT_API_KEY='test-livekit-key',
        LIVEKIT_API_SECRET='test-livekit-secret-key-0123456789',
    )
    def test_viewer_token_cannot_publish(self):
        token = livekit_service._participant_token(
            'fopcam-live-room',
            'viewer-test-identity',
            False,
        )

        claims = jwt.decode(
            token,
            'test-livekit-secret-key-0123456789',
            algorithms=['HS256'],
        )

        self.assertTrue(claims['video']['roomJoin'])
        self.assertFalse(claims['video']['canPublish'])
        self.assertFalse(claims['video']['canPublishData'])
