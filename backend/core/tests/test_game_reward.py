from django.contrib.auth.models import User
from rest_framework import status
from rest_framework.test import APIClient, APITestCase

from core.models import GameReward


class GameRewardTests(APITestCase):
    url = '/api/game/rewards/level-12/'
    legends_url = '/api/game/legends/'

    def setUp(self):
        self.user = User.objects.create_user(
            username='gameplayer',
            first_name='Awa',
            password='password123',
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_reward_requires_authentication(self):
        self.client.force_authenticate(user=None)

        response = self.client.post(self.url, {'score': 198}, format='json')

        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
        self.assertFalse(GameReward.objects.exists())

    def test_score_below_level_twelve_threshold_is_rejected(self):
        response = self.client.post(self.url, {'score': 176}, format='json')

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertFalse(GameReward.objects.exists())

    def test_score_at_level_twelve_threshold_can_claim_reward(self):
        response = self.client.post(self.url, {'score': 177}, format='json')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['score'], 177)
        self.assertFalse(response.data['already_claimed'])

    def test_claim_is_persisted_with_a_personalized_reward(self):
        response = self.client.post(self.url, {'score': 198}, format='json')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['title'], 'Trophée Awa · Légende FopCam')
        self.assertEqual(response.data['points'], 500)
        self.assertEqual(response.data['level'], 12)
        self.assertFalse(response.data['already_claimed'])
        self.assertTrue(GameReward.objects.filter(user=self.user).exists())

    def test_reward_can_only_be_claimed_once_per_account(self):
        first_response = self.client.post(
            self.url,
            {'score': 198},
            format='json',
        )
        second_response = self.client.post(
            self.url,
            {'score': 500},
            format='json',
        )

        self.assertEqual(first_response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(second_response.status_code, status.HTTP_200_OK)
        self.assertTrue(second_response.data['already_claimed'])
        self.assertEqual(second_response.data['score'], 500)
        self.assertEqual(GameReward.objects.filter(user=self.user).count(), 1)

    def test_retry_after_lost_response_updates_best_score_without_duplicate_reward(self):
        first_response = self.client.post(
            self.url,
            {'score': 198},
            format='json',
        )
        retry_response = self.client.post(
            self.url,
            {'score': 240},
            format='json',
        )

        self.assertEqual(first_response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(retry_response.status_code, status.HTTP_200_OK)
        self.assertTrue(retry_response.data['already_claimed'])
        self.assertEqual(retry_response.data['score'], 240)
        self.assertEqual(retry_response.data['points'], 500)
        self.assertEqual(GameReward.objects.filter(user=self.user).count(), 1)

    def test_claimed_reward_is_visible_in_legends_with_the_claimed_score(self):
        self.client.post(self.url, {'score': 240}, format='json')

        response = self.client.get(self.legends_url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(
            [
                (legend['username'], legend['score'])
                for legend in response.data
            ],
            [('gameplayer', 240)],
        )
