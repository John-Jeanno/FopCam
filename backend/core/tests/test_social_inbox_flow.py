from django.contrib.auth.models import User
from django.test import TestCase
from datetime import timedelta
from django.utils import timezone
from rest_framework.test import APIClient

from core.models import Friend, GameChallenge, Message, Notification, UserProfile


class SocialInboxFlowTests(TestCase):
    def setUp(self):
        self.sender = User.objects.create_user(username='inbox-sender')
        self.receiver = User.objects.create_user(username='inbox-receiver')
        self.client = APIClient()
        self.client.force_authenticate(user=self.receiver)

    def test_receiver_lists_pending_friend_requests_and_can_decide(self):
        request = Friend.objects.create(
            requester=self.sender,
            receiver=self.receiver,
        )
        notification = Notification.objects.create(
            user=self.receiver,
            title='Nouvelle demande',
            message='Demande reçue',
            type='friend_request',
            data={'friend_request_id': request.id},
        )

        inbox = self.client.get('/api/friends/')
        self.assertEqual(inbox.status_code, 200)
        self.assertEqual([item['id'] for item in inbox.data], [request.id])
        self.assertEqual(
            self.client.get('/api/friends/pending_count/').data['count'],
            1,
        )

        accept = self.client.post(f'/api/friends/{request.id}/accept/')
        self.assertEqual(accept.status_code, 200)
        self.assertEqual(accept.data['status'], 'accepted')
        self.assertEqual(
            self.client.get('/api/friends/pending_count/').data['count'],
            0,
        )
        notification.refresh_from_db()
        self.assertEqual(notification.data['status'], 'accepted')
        self.assertTrue(notification.is_read)

        another_sender = User.objects.create_user(username='inbox-sender-two')
        other_request = Friend.objects.create(
            requester=another_sender,
            receiver=self.receiver,
        )
        decline = self.client.post(f'/api/friends/{other_request.id}/decline/')
        self.assertEqual(decline.status_code, 200)
        self.assertEqual(decline.data['status'], 'declined')

    def test_only_receiver_can_accept_or_reject_friend_request(self):
        request = Friend.objects.create(
            requester=self.sender,
            receiver=self.receiver,
        )
        self.client.force_authenticate(user=self.sender)

        response = self.client.post(f'/api/friends/{request.id}/accept/')

        self.assertEqual(response.status_code, 403)
        request.refresh_from_db()
        self.assertEqual(request.status, 'pending')

    def test_friend_request_rejects_pending_relationship_in_either_direction(self):
        Friend.objects.create(
            requester=self.sender,
            receiver=self.receiver,
            status='pending',
        )

        same_direction = self.client.post(
            '/api/friends/',
            {'receiver_id': self.sender.id},
            format='json',
        )
        self.client.force_authenticate(user=self.sender)
        reverse_direction = self.client.post(
            '/api/friends/',
            {'receiver_id': self.receiver.id},
            format='json',
        )

        self.assertEqual(same_direction.status_code, 400)
        self.assertEqual(reverse_direction.status_code, 400)
        self.assertEqual(Friend.objects.count(), 1)

    def test_friend_request_rejects_existing_friendship_in_either_direction(self):
        Friend.objects.create(
            requester=self.sender,
            receiver=self.receiver,
            status='accepted',
        )

        same_direction = self.client.post(
            '/api/friends/',
            {'receiver_id': self.sender.id},
            format='json',
        )
        self.client.force_authenticate(user=self.sender)
        reverse_direction = self.client.post(
            '/api/friends/',
            {'receiver_id': self.receiver.id},
            format='json',
        )

        self.assertEqual(same_direction.status_code, 400)
        self.assertEqual(reverse_direction.status_code, 400)
        self.assertEqual(Friend.objects.count(), 1)

    def test_declined_friend_request_can_be_sent_again(self):
        request = Friend.objects.create(
            requester=self.sender,
            receiver=self.receiver,
            status='declined',
        )
        self.client.force_authenticate(user=self.sender)

        response = self.client.post(
            '/api/friends/',
            {'receiver_id': self.receiver.id},
            format='json',
        )

        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['id'], request.id)
        request.refresh_from_db()
        self.assertEqual(request.status, 'pending')

    def test_friend_request_rejects_requesting_connection_with_self(self):
        self.client.force_authenticate(user=self.sender)

        response = self.client.post(
            '/api/friends/',
            {'receiver_id': self.sender.id},
            format='json',
        )

        self.assertEqual(response.status_code, 400)
        self.assertFalse(Friend.objects.exists())

    def test_unread_messages_are_counted_and_marked_per_private_room(self):
        Friend.objects.create(
            requester=self.sender,
            receiver=self.receiver,
            status='accepted',
        )
        room = f'private_{self.sender.id}_{self.receiver.id}'
        unread = Message.objects.create(
            room=room,
            user=self.sender,
            recipient=self.receiver,
            content='À lire',
        )
        Message.objects.create(
            room=room,
            user=self.receiver,
            recipient=self.sender,
            content='Déjà lu',
            is_read=True,
        )

        count = self.client.get('/api/messages/unread_count/')
        self.assertEqual(count.status_code, 200)
        self.assertEqual(count.data['count'], 1)

        mark_read = self.client.post(
            '/api/messages/mark_conversation_read/',
            {'room': room},
            format='json',
        )
        self.assertEqual(mark_read.status_code, 200)
        self.assertEqual(mark_read.data['updated'], 1)
        unread.refresh_from_db()
        self.assertTrue(unread.is_read)
        self.assertEqual(
            self.client.get('/api/messages/unread_count/').data['count'],
            0,
        )

    def test_private_conversations_list_latest_message_and_unread_count(self):
        room = f'private_{self.sender.id}_{self.receiver.id}'
        Message.objects.create(
            room=room,
            user=self.sender,
            recipient=self.receiver,
            content='Dernier message',
        )

        response = self.client.get('/api/messages/conversations/')

        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['room_id'], room)
        self.assertEqual(response.data[0]['profile']['username'], self.sender.username)
        self.assertEqual(response.data[0]['last_message'], 'Dernier message')
        self.assertEqual(response.data[0]['unread_count'], 1)

    def test_messages_cannot_be_loaded_from_another_users_private_room(self):
        third_user = User.objects.create_user(username='inbox-third')
        room = f'private_{min(self.sender.id, third_user.id)}_{max(self.sender.id, third_user.id)}'
        Message.objects.create(
            room=room,
            user=self.sender,
            recipient=third_user,
            content='Discussion privée',
        )

        response = self.client.get('/api/messages/', {'room': room})

        self.assertEqual(response.status_code, 403)

    def test_message_list_and_unread_count_only_include_own_private_rooms(self):
        third_user = User.objects.create_user(username='inbox-third')
        own_room = (
            f'private_{min(self.sender.id, self.receiver.id)}_'
            f'{max(self.sender.id, self.receiver.id)}'
        )
        other_room = (
            f'private_{min(self.sender.id, third_user.id)}_'
            f'{max(self.sender.id, third_user.id)}'
        )
        own_message = Message.objects.create(
            room=own_room,
            user=self.sender,
            recipient=self.receiver,
            content='Ma discussion',
        )
        unrelated_message = Message.objects.create(
            room=other_room,
            user=self.receiver,
            recipient=self.sender,
            content='Discussion hors salon',
        )

        response = self.client.get('/api/messages/')

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            [message['id'] for message in response.data],
            [own_message.id],
        )
        self.assertEqual(
            self.client.get('/api/messages/unread_count/').data['count'],
            1,
        )
        detail = self.client.get(
            f'/api/messages/{unrelated_message.id}/',
        )
        self.assertEqual(detail.status_code, 404)

    def test_inbox_ignores_messages_with_a_sender_outside_the_room(self):
        third_user = User.objects.create_user(username='inbox-third')
        room = (
            f'private_{min(self.receiver.id, third_user.id)}_'
            f'{max(self.receiver.id, third_user.id)}'
        )
        Message.objects.create(
            room=room,
            user=self.sender,
            recipient=self.receiver,
            content='Expéditeur hors discussion',
        )

        message_list = self.client.get('/api/messages/')
        conversations = self.client.get('/api/messages/conversations/')

        self.assertEqual(message_list.status_code, 200)
        self.assertEqual(message_list.data, [])
        self.assertEqual(conversations.status_code, 200)
        self.assertEqual(conversations.data, [])
        self.assertEqual(
            self.client.get('/api/messages/unread_count/').data['count'],
            0,
        )

    def test_message_creation_rejects_a_room_that_does_not_include_sender(self):
        third_user = User.objects.create_user(username='inbox-third')
        room = f'private_{min(self.sender.id, third_user.id)}_{max(self.sender.id, third_user.id)}'

        response = self.client.post(
            '/api/messages/',
            {'room': room, 'content': 'Message usurpé', 'message_type': 'text'},
            format='json',
        )

        self.assertEqual(response.status_code, 400)
        self.assertFalse(Message.objects.exists())

    def test_conversation_list_excludes_rooms_that_do_not_include_current_user(self):
        third_user = User.objects.create_user(username='inbox-third')
        room = f'private_{min(self.sender.id, third_user.id)}_{max(self.sender.id, third_user.id)}'
        Message.objects.create(
            room=room,
            user=self.sender,
            recipient=third_user,
            content='Discussion privée',
        )

        response = self.client.get('/api/messages/conversations/')

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data, [])

    def test_connected_users_can_open_a_private_conversation(self):
        Friend.objects.create(
            requester=self.sender,
            receiver=self.receiver,
            status='accepted',
        )

        response = self.client.post(
            '/api/messages/start_conversation/',
            {'recipient_id': self.sender.id},
            format='json',
        )

        self.assertEqual(response.status_code, 200)
        self.assertEqual(
            response.data['room_id'],
            f'private_{min(self.sender.id, self.receiver.id)}_{max(self.sender.id, self.receiver.id)}',
        )
        message = self.client.post(
            '/api/messages/',
            {
                'room': response.data['room_id'],
                'content': 'Bonjour',
                'message_type': 'text',
            },
            format='json',
        )
        self.assertEqual(message.status_code, 201, message.data)
        self.assertEqual(message.data['recipient']['id'], self.sender.id)

    def test_legacy_challenge_badge_route_returns_incoming_pending_count(self):
        GameChallenge.objects.create(
            challenger=self.sender,
            challenged=self.receiver,
        )

        response = self.client.get('/api/game/challenges/pending-count/')

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['count'], 1)

    def test_user_directory_excludes_current_user_and_exposes_connection_state(self):
        online_user = User.objects.create_user(
            username='directory-online',
            first_name='En ligne',
        )
        UserProfile.objects.create(
            user=online_user,
            role='producer',
            is_active=True,
            last_seen_at=timezone.now(),
        )
        offline_user = User.objects.create_user(username='directory-offline')
        UserProfile.objects.create(
            user=offline_user,
            is_active=True,
            last_seen_at=timezone.now() - timedelta(minutes=10),
        )
        request = Friend.objects.create(
            requester=self.sender,
            receiver=self.receiver,
        )

        response = self.client.get('/api/users/directory/')
        self.assertEqual(response.status_code, 200)
        users_by_id = {item['id']: item for item in response.data['results']}
        self.assertNotIn(self.receiver.id, users_by_id)
        self.assertTrue(users_by_id[online_user.id]['is_online'])
        self.assertEqual(users_by_id[online_user.id]['role'], 'producer')
        self.assertEqual(users_by_id[offline_user.id]['is_online'], False)
        self.assertEqual(
            users_by_id[self.sender.id]['connection_status'],
            'pending',
        )
        self.assertEqual(
            users_by_id[self.sender.id]['friend_request_id'],
            request.id,
        )
        self.assertEqual(
            users_by_id[self.sender.id]['friend_request_direction'],
            'incoming',
        )
        self.assertNotIn('email', users_by_id[online_user.id])

        online_only = self.client.get('/api/users/directory/?online=true')
        online_ids = {item['id'] for item in online_only.data['results']}
        self.assertIn(online_user.id, online_ids)
        self.assertNotIn(offline_user.id, online_ids)

    def test_user_directory_can_search_by_username_name_and_city(self):
        searched_user = User.objects.create_user(
            username='recherche-eleveur',
            first_name='Aminata',
            last_name='Fall',
        )
        UserProfile.objects.create(
            user=searched_user,
            city='Saint-Louis',
            is_active=True,
        )
        User.objects.create_user(username='autre-utilisateur')

        by_username = self.client.get(
            '/api/users/directory/?search=recherche-eleveur'
        )
        by_name = self.client.get('/api/users/directory/?search=Aminata')
        by_city = self.client.get('/api/users/directory/?search=Saint-Louis')

        for response in (by_username, by_name, by_city):
            self.assertEqual(response.status_code, 200)
            self.assertEqual(
                [user['id'] for user in response.data['results']],
                [searched_user.id],
            )

    def test_presence_ping_marks_active_profile_online(self):
        profile = UserProfile.objects.create(
            user=self.receiver,
            role='producer',
            is_active=True,
            last_seen_at=timezone.now() - timedelta(minutes=10),
        )

        response = self.client.post('/api/users/presence/')

        self.assertEqual(response.status_code, 200)
        self.assertTrue(response.data['is_online'])
        profile.refresh_from_db()
        self.assertGreaterEqual(profile.last_seen_at, timezone.now() - timedelta(seconds=5))

    def test_public_user_profile_is_viewable_without_exposing_email(self):
        UserProfile.objects.create(
            user=self.sender,
            role='producer',
            is_active=True,
            bio='Profil visible',
        )

        response = APIClient().get(f'/api/users/{self.sender.username}/')

        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data['username'], self.sender.username)
        self.assertEqual(response.data['bio'], 'Profil visible')
        self.assertNotIn('email', response.data)

    def test_every_public_user_role_can_register(self):
        roles = (
            'particular',
            'producer',
            'boutique',
            'prestataire',
            'enterprise',
            'influencer',
            'community_lead',
            'driver',
        )
        for index, role in enumerate(roles):
            response = self.client.post(
                '/api/auth/register/',
                {
                    'username': f'register-{role}',
                    'email': f'{role}@example.test',
                    'password': 'FopCam-Secure-2026!',
                    'first_name': 'Test',
                    'last_name': role,
                    'phone': '+221700000000',
                    'address': 'Dakar',
                    'city': 'Dakar',
                    'country': 'Sénégal',
                    'user_type': role,
                    'motorcycle_plate': f'DK-{index:03}-AB' if role == 'driver' else '',
                },
                format='json',
            )

            self.assertEqual(response.status_code, 201, response.data)
            self.assertTrue(
                UserProfile.objects.filter(
                    user__username=f'register-{role}',
                    role=role,
                ).exists()
            )

    def test_legacy_registration_role_names_map_to_supported_roles(self):
        roles = {
            'buyer': 'particular',
            'shop_owner': 'boutique',
            'service_provider': 'prestataire',
            'community_manager': 'community_lead',
        }
        for index, (submitted_role, stored_role) in enumerate(roles.items()):
            response = self.client.post(
                '/api/auth/register/',
                {
                    'username': f'legacy-register-{index}',
                    'email': f'legacy-{index}@example.test',
                    'password': 'FopCam-Secure-2026!',
                    'first_name': 'Test',
                    'last_name': submitted_role,
                    'phone': '+221700000000',
                    'address': 'Dakar',
                    'city': 'Dakar',
                    'country': 'Sénégal',
                    'user_type': submitted_role,
                },
                format='json',
            )

            self.assertEqual(response.status_code, 201, response.data)
            self.assertTrue(
                UserProfile.objects.filter(
                    user__username=f'legacy-register-{index}',
                    role=stored_role,
                ).exists()
            )

    def test_profiles_support_vendor_search_and_exclude_current_user(self):
        vendor = User.objects.create_user(
            username='vendeur-unique',
            first_name='Awa',
        )
        UserProfile.objects.create(user=vendor, role='boutique', city='Dakar')

        response = self.client.get('/api/profiles/?role=producer&search=awa')

        self.assertEqual(response.status_code, 200)
        results = response.data.get('results', response.data)
        self.assertEqual(len(results), 1)
        self.assertEqual(results[0]['user']['username'], 'vendeur-unique')
        self.assertNotEqual(results[0]['user']['id'], self.receiver.id)
