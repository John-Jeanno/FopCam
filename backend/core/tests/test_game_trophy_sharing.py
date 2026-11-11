from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework.test import APIClient

from core.models import GameChallenge, GameReward, Post


class GameTrophySharingTests(TestCase):
    def setUp(self):
        self.winner = User.objects.create_user(username='cup-winner')
        self.opponent = User.objects.create_user(username='cup-opponent')
        GameReward.objects.create(
            user=self.winner,
            score=420,
            title='Champion 1ère Ligue',
            duel_medal='cup',
            earned_duel_medals=['bronze', 'silver', 'gold', 'cup'],
        )
        self.challenge = GameChallenge.objects.create(
            challenger=self.winner,
            challenged=self.opponent,
            status=GameChallenge.COMPLETED,
            winner=self.winner,
            challenger_score=230,
            challenged_score=190,
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.winner)
        self.url = (
            f'/api/game/challenges/{self.challenge.id}/share-trophy/'
        )

    def test_winner_can_publish_trophy_to_feed_only_once(self):
        response = self.client.post(self.url, {}, format='json')

        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['post_type'], 'trophy')
        self.assertEqual(response.data['trophy_data']['medal'], 'cup')
        self.assertEqual(
            response.data['trophy_data']['title'],
            'Champion 1ère Ligue',
        )
        self.assertEqual(
            Post.objects.filter(
                author=self.winner,
                trophy_challenge=self.challenge,
            ).count(),
            1,
        )

        repeated_response = self.client.post(self.url, {}, format='json')
        self.assertEqual(repeated_response.status_code, 200)
        self.assertEqual(repeated_response.data['id'], response.data['id'])

        feed_response = self.client.get('/api/posts/')
        feed_posts = feed_response.data.get('results', feed_response.data)
        published = next(
            post
            for post in feed_posts
            if post['id'] == response.data['id']
        )
        self.assertEqual(published['trophy_data']['opponent'], 'cup-opponent')
        self.assertEqual(published['trophy_data']['winner_score'], 230)

    def test_loser_cannot_publish_the_winners_trophy(self):
        self.client.force_authenticate(user=self.opponent)

        response = self.client.post(self.url, {}, format='json')

        self.assertEqual(response.status_code, 403)
        self.assertFalse(Post.objects.filter(trophy_challenge=self.challenge).exists())
