from django.contrib.auth.models import User
from django.test import skipUnlessDBFeature
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient, APITestCase
from datetime import timedelta

from core.models import GameChallenge, GameDuelReward, GameReward, Notification
from core.views import _award_game_challenge_winner
from django.db import transaction


class GameChallengeTests(APITestCase):
    legends_url = '/api/game/legends/'
    challenges_url = '/api/game/challenges/'

    def setUp(self):
        self.player = User.objects.create_user(
            username='player_one',
            first_name='Awa',
            password='password123',
        )
        self.legend = User.objects.create_user(
            username='legend_two',
            first_name='Moussa',
            password='password123',
        )
        GameReward.objects.create(
            user=self.player,
            score=220,
            points=500,
            title='Trophée Awa · Légende FopCam',
        )
        GameReward.objects.create(
            user=self.legend,
            score=240,
            points=500,
            title='Trophée Moussa · Légende FopCam',
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.player)

    def test_legend_board_shows_qualified_players_by_score(self):
        player_reward = GameReward.objects.get(user=self.player)
        player_reward.duel_medal = 'silver'
        player_reward.earned_duel_medals = ['bronze', 'silver']
        player_reward.save(update_fields=('duel_medal', 'earned_duel_medals'))

        response = self.client.get(self.legends_url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual([legend['username'] for legend in response.data], [
            'legend_two',
            'player_one',
        ])
        self.assertEqual(response.data[0]['rank'], 1)
        self.assertIn('avatar_url', response.data[0])
        self.assertEqual(response.data[1]['duel_medals'], ['bronze', 'silver'])

    def test_only_qualified_other_players_can_be_challenged(self):
        self.assertEqual(
            self.client.post(
                self.challenges_url,
                {'legend_id': self.player.id},
                format='json',
            ).status_code,
            status.HTTP_400_BAD_REQUEST,
        )
        non_legend = User.objects.create_user(username='new_player')
        self.assertEqual(
            self.client.post(
                self.challenges_url,
                {'legend_id': non_legend.id},
                format='json',
            ).status_code,
            status.HTTP_404_NOT_FOUND,
        )
        challenge = self.client.post(
            self.challenges_url,
            {'legend_id': self.legend.id},
            format='json',
        )
        self.assertEqual(challenge.status_code, status.HTTP_201_CREATED)
        challenge_notification = Notification.objects.get(
            user=self.legend,
            type='game_challenge',
        )
        self.assertEqual(
            challenge_notification.data['challenge_id'],
            challenge.data['id'],
        )
        duplicate = self.client.post(
            self.challenges_url,
            {'legend_id': self.legend.id},
            format='json',
        )
        self.assertEqual(duplicate.status_code, status.HTTP_409_CONFLICT)

    def test_new_challenges_expire_after_30_minutes(self):
        response = self.client.post(
            self.challenges_url,
            {'legend_id': self.legend.id},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        challenge = GameChallenge.objects.get(pk=response.data['id'])
        self.assertAlmostEqual(
            (challenge.expires_at - challenge.created_at).total_seconds(),
            timedelta(minutes=30).total_seconds(),
            delta=1,
        )
        self.assertLessEqual(response.data['seconds_until_expiry'], 30 * 60)
        self.assertGreaterEqual(response.data['seconds_until_expiry'], 30 * 60 - 2)

    def test_accepting_challenge_gives_one_hour_to_start_the_duel(self):
        created = self.client.post(
            self.challenges_url,
            {'legend_id': self.legend.id},
            format='json',
        )
        self.client.force_authenticate(user=self.legend)

        accepted = self.client.post(
            f"{self.challenges_url}{created.data['id']}/respond/",
            {'accept': True},
            format='json',
        )

        self.assertEqual(accepted.status_code, status.HTTP_200_OK)
        challenge = GameChallenge.objects.get(pk=created.data['id'])
        self.assertEqual(challenge.status, GameChallenge.ACCEPTED)
        self.assertAlmostEqual(
            (challenge.expires_at - timezone.now()).total_seconds(),
            timedelta(hours=1).total_seconds(),
            delta=2,
        )

    def test_unstarted_accepted_challenge_disappears_after_one_hour(self):
        challenge = GameChallenge.objects.create(
            challenger=self.player,
            challenged=self.legend,
            status=GameChallenge.ACCEPTED,
            expires_at=timezone.now() - timedelta(seconds=1),
        )

        response = self.client.get(self.challenges_url)

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(response.data, [])
        challenge.refresh_from_db()
        self.assertEqual(challenge.status, GameChallenge.EXPIRED)

    def test_expired_accepted_challenge_cannot_be_started(self):
        challenge = GameChallenge.objects.create(
            challenger=self.player,
            challenged=self.legend,
            status=GameChallenge.ACCEPTED,
            expires_at=timezone.now() - timedelta(seconds=1),
        )

        response = self.client.post(
            f'{self.challenges_url}{challenge.id}/ready/',
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_410_GONE)
        challenge.refresh_from_db()
        self.assertEqual(challenge.status, GameChallenge.EXPIRED)

    def test_either_participant_can_cancel_pending_invitation_for_both(self):
        response = self.client.post(
            self.challenges_url,
            {'legend_id': self.legend.id},
            format='json',
        )
        cancel_url = f'{self.challenges_url}{response.data["id"]}/cancel/'

        self.client.force_authenticate(user=self.legend)
        self.assertTrue(self.client.get(self.challenges_url).data[0]['can_cancel'])
        cancelled = self.client.post(cancel_url)

        self.assertEqual(cancelled.status_code, status.HTTP_200_OK)
        self.assertEqual(cancelled.data['status'], GameChallenge.CANCELLED)
        self.assertFalse(cancelled.data['can_cancel'])
        self.assertTrue(
            Notification.objects.filter(
                user=self.player,
                type='game_challenge_cancelled',
                data__challenge_id=response.data['id'],
            ).exists()
        )
        self.client.force_authenticate(user=self.player)
        self.assertEqual(
            self.client.get(self.challenges_url).data[0]['status'],
            GameChallenge.CANCELLED,
        )
        self.client.force_authenticate(user=self.legend)
        self.assertEqual(
            self.client.get(self.challenges_url).data[0]['status'],
            GameChallenge.CANCELLED,
        )

    def test_non_participant_cannot_cancel_pending_invitation(self):
        response = self.client.post(
            self.challenges_url,
            {'legend_id': self.legend.id},
            format='json',
        )
        non_participant = User.objects.create_user(username='other_player')
        self.client.force_authenticate(user=non_participant)

        self.assertEqual(
            self.client.post(
                f'{self.challenges_url}{response.data["id"]}/cancel/',
            ).status_code,
            status.HTTP_403_FORBIDDEN,
        )

    def test_declined_challenge_deletion_removes_it_for_both_participants(self):
        challenge = GameChallenge.objects.create(
            challenger=self.player,
            challenged=self.legend,
            status=GameChallenge.DECLINED,
        )
        dismiss_url = f'{self.challenges_url}{challenge.id}/dismiss/'
        self.client.force_authenticate(user=self.legend)

        response = self.client.delete(dismiss_url)

        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        self.assertEqual(
            self.client.get(self.challenges_url).data,
            [],
        )
        self.client.force_authenticate(user=self.legend)
        self.assertEqual(
            self.client.get(self.challenges_url).data,
            [],
        )
        self.assertFalse(GameChallenge.objects.filter(pk=challenge.id).exists())

    def test_pending_challenge_cannot_be_deleted_or_hidden_by_non_participant(self):
        response = self.client.post(
            self.challenges_url,
            {'legend_id': self.legend.id},
            format='json',
        )
        dismiss_url = f'{self.challenges_url}{response.data["id"]}/dismiss/'
        non_participant = User.objects.create_user(username='other_player')
        self.client.force_authenticate(user=non_participant)
        self.assertEqual(
            self.client.delete(dismiss_url).status_code,
            status.HTTP_403_FORBIDDEN,
        )

        self.client.force_authenticate(user=self.player)
        self.assertEqual(
            self.client.delete(dismiss_url).status_code,
            status.HTTP_409_CONFLICT,
        )

    def test_non_legend_cannot_send_a_challenge(self):
        GameReward.objects.get(user=self.player).delete()

        response = self.client.post(
            self.challenges_url,
            {'legend_id': self.legend.id},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertFalse(GameChallenge.objects.exists())

    def test_lower_tier_cannot_challenge_a_higher_tier(self):
        player_reward = GameReward.objects.get(user=self.player)
        player_reward.duel_medal = 'bronze'
        player_reward.earned_duel_medals = ['bronze']
        player_reward.save(update_fields=('duel_medal', 'earned_duel_medals'))
        legend_reward = GameReward.objects.get(user=self.legend)
        legend_reward.duel_medal = 'silver'
        legend_reward.earned_duel_medals = ['bronze', 'silver']
        legend_reward.save(update_fields=('duel_medal', 'earned_duel_medals'))

        response = self.client.post(
            self.challenges_url,
            {'legend_id': self.legend.id},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertEqual(
            response.data['detail'],
            'Tu peux défier une légende de ton niveau ou d’un niveau inférieur.',
        )
        self.assertFalse(GameChallenge.objects.exists())

        legend_reward.duel_medal = 'bronze'
        legend_reward.earned_duel_medals = ['bronze']
        legend_reward.save(update_fields=('duel_medal', 'earned_duel_medals'))
        same_tier = self.client.post(
            self.challenges_url,
            {'legend_id': self.legend.id},
            format='json',
        )

        self.assertEqual(same_tier.status_code, status.HTTP_201_CREATED)

    def test_higher_tier_can_invite_a_lower_tier_to_a_duel(self):
        challenger_reward = GameReward.objects.get(user=self.player)
        challenger_reward.duel_medal = 'cup_pro'
        challenger_reward.earned_duel_medals = [
            'bronze',
            'silver',
            'gold',
            'cup',
            'cup_pro',
        ]
        challenger_reward.save(
            update_fields=('duel_medal', 'earned_duel_medals'),
        )
        challenged_reward = GameReward.objects.get(user=self.legend)
        challenged_reward.duel_medal = 'bronze'
        challenged_reward.earned_duel_medals = ['bronze']
        challenged_reward.save(
            update_fields=('duel_medal', 'earned_duel_medals'),
        )

        response = self.client.post(
            self.challenges_url,
            {'legend_id': self.legend.id},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.client.force_authenticate(user=self.legend)
        accepted = self.client.post(
            f"{self.challenges_url}{response.data['id']}/respond/",
            {'accept': True},
            format='json',
        )
        self.assertEqual(accepted.status_code, status.HTTP_200_OK)
        self.assertEqual(accepted.data['status'], GameChallenge.ACCEPTED)

    def test_lower_tier_loser_cannot_request_a_higher_tier_rematch(self):
        player_reward = GameReward.objects.get(user=self.player)
        player_reward.duel_medal = 'bronze'
        player_reward.save(update_fields=('duel_medal',))
        legend_reward = GameReward.objects.get(user=self.legend)
        legend_reward.duel_medal = 'silver'
        legend_reward.save(update_fields=('duel_medal',))
        challenge = GameChallenge.objects.create(
            challenger=self.legend,
            challenged=self.player,
            status=GameChallenge.COMPLETED,
            winner=self.legend,
            challenger_score=40,
            challenged_score=30,
        )

        response = self.client.get(self.challenges_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(response.data[0]['can_request_rematch'])

        rematch_response = self.client.post(
            f'{self.challenges_url}{challenge.id}/rematch/',
            format='json',
        )
        self.assertEqual(rematch_response.status_code, status.HTTP_409_CONFLICT)
        self.assertFalse(
            GameChallenge.objects.filter(rematch_of=challenge).exists(),
        )

    def test_incoming_challenge_cannot_be_accepted_if_tiers_changed(self):
        challenge_response = self.client.post(
            self.challenges_url,
            {'legend_id': self.legend.id},
            format='json',
        )
        legend_reward = GameReward.objects.get(user=self.legend)
        legend_reward.duel_medal = 'silver'
        legend_reward.earned_duel_medals = ['bronze', 'silver']
        legend_reward.save(update_fields=('duel_medal', 'earned_duel_medals'))
        self.client.force_authenticate(user=self.legend)

        response = self.client.post(
            f"{self.challenges_url}{challenge_response.data['id']}/respond/",
            {'accept': True},
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_409_CONFLICT)
        self.assertEqual(
            GameChallenge.objects.get(pk=challenge_response.data['id']).status,
            GameChallenge.PENDING,
        )

    def test_three_round_total_score_decides_winner_and_awards_bronze(self):
        create_response = self.client.post(
            self.challenges_url,
            {'legend_id': self.legend.id},
            format='json',
        )
        challenge_id = create_response.data['id']
        challenge = GameChallenge.objects.get(pk=challenge_id)

        self.client.force_authenticate(user=self.legend)
        accept_response = self.client.post(
            f'{self.challenges_url}{challenge_id}/respond/',
            {'accept': True},
            format='json',
        )
        self.assertEqual(accept_response.status_code, status.HTTP_200_OK)
        self.assertEqual(accept_response.data['status'], GameChallenge.ACCEPTED)

        self.assertEqual(
            self.client.post(
                f'{self.challenges_url}{challenge_id}/ready/',
                format='json',
            ).data['status'],
            GameChallenge.ACCEPTED,
        )
        self.client.force_authenticate(user=self.player)
        ready_response = self.client.post(
            f'{self.challenges_url}{challenge_id}/ready/',
            format='json',
        )
        self.assertEqual(ready_response.status_code, status.HTTP_200_OK)
        self.assertEqual(ready_response.data['status'], GameChallenge.PLAYING)
        self.assertTrue(ready_response.data['is_my_turn'])
        self.assertIsNotNone(ready_response.data['started_at'])
        self.assertIsInstance(ready_response.data['starts_in_milliseconds'], int)
        legacy_score = self.client.post(
            f'{self.challenges_url}{challenge_id}/score/',
            {'score': 75},
            format='json',
        )
        self.assertEqual(legacy_score.status_code, status.HTTP_409_CONFLICT)

        for round_number, duration in enumerate((50, 45, 40), start=1):
            players = ((self.player, 20), (self.legend, 25))
            for player, score in players:
                challenge.refresh_from_db()
                self.assertEqual(
                    challenge.challenger_turn,
                    player.id == challenge.challenger_id,
                    f'Unexpected turn order for round {round_number}.',
                )
                challenge.started_at = timezone.now() - timedelta(
                    seconds=duration + 1,
                )
                challenge.save(update_fields=('started_at',))
                self.client.force_authenticate(user=player)
                result = self.client.post(
                    f'{self.challenges_url}{challenge_id}/round/',
                    {'round_number': round_number, 'score': score},
                    format='json',
                )
                self.assertEqual(result.status_code, status.HTTP_200_OK)

        self.assertEqual(result.data['status'], GameChallenge.COMPLETED)
        self.assertFalse(result.data['is_draw'])
        self.assertEqual(result.data['challenger_score'], 60)
        self.assertEqual(result.data['challenged_score'], 75)
        self.assertEqual(result.data['winner_id'], self.legend.id)
        self.assertTrue(result.data['winner_by_score'])
        winner_reward = GameReward.objects.get(user=self.legend)
        self.assertEqual(winner_reward.duel_medal, 'bronze')
        self.assertEqual(winner_reward.earned_duel_medals, ['bronze'])
        self.assertTrue(winner_reward.title.startswith('Légende +'))

    def test_loser_can_request_at_most_three_rematches(self):
        challenge = GameChallenge.objects.create(
            challenger=self.player,
            challenged=self.legend,
            status=GameChallenge.COMPLETED,
            winner=self.legend,
            challenger_score=30,
            challenged_score=40,
        )
        for attempt in range(3):
            response = self.client.post(
                f'{self.challenges_url}{challenge.id}/rematch/',
                format='json',
            )
            self.assertEqual(response.status_code, status.HTTP_201_CREATED)
            self.assertEqual(response.data['status'], GameChallenge.PENDING)
            self.assertTrue(response.data['is_rematch'])
            self.assertFalse(response.data['is_incoming'])
            self.assertEqual(response.data['rematches_used'], attempt + 1)
            rematch = GameChallenge.objects.get(pk=response.data['id'])
            self.assertEqual(rematch.rematch_of_id, challenge.id)
            self.assertEqual(rematch.rematch_requester_id, self.player.id)
            rematch_notification = Notification.objects.filter(
                user=self.legend,
                type='game_rematch',
                data__challenge_id=rematch.id,
            ).latest('created_at')
            self.assertEqual(
                rematch_notification.data['challenge_id'],
                rematch.id,
            )
            rematch.status = GameChallenge.COMPLETED
            rematch.winner = self.legend
            rematch.save(update_fields=('status', 'winner'))

        exhausted = self.client.post(
            f'{self.challenges_url}{challenge.id}/rematch/',
            format='json',
        )
        self.assertEqual(exhausted.status_code, status.HTTP_409_CONFLICT)
        self.assertEqual(
            GameChallenge.objects.filter(rematch_of=challenge).count(),
            3,
        )

    def test_each_rematch_victory_receives_a_distinct_personalized_reward(self):
        root = GameChallenge.objects.create(
            challenger=self.player,
            challenged=self.legend,
            status=GameChallenge.COMPLETED,
            winner=self.legend,
        )
        rematch_rewards = []
        for _ in range(2):
            rematch = GameChallenge.objects.create(
                challenger=self.player,
                challenged=self.legend,
                rematch_of=root,
                rematch_requester=self.player,
                status=GameChallenge.COMPLETED,
                winner=self.legend,
            )
            with transaction.atomic():
                _award_game_challenge_winner(rematch)
            rematch_rewards.append(GameDuelReward.objects.get(challenge=rematch))

        self.assertNotEqual(rematch_rewards[0].title, rematch_rewards[1].title)
        self.assertNotEqual(rematch_rewards[0].reward_type, rematch_rewards[1].reward_type)
        self.assertEqual([item.sequence for item in rematch_rewards], [1, 2])
        self.assertIn('Moussa', rematch_rewards[0].description)

        response = self.client.get(self.challenges_url)
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        challenge_results = {
            item['id']: item for item in response.data
        }
        self.assertEqual(
            challenge_results[rematch_rewards[0].challenge_id]['duel_reward']['title'],
            rematch_rewards[0].title,
        )

    def test_only_the_loser_can_request_a_rematch(self):
        challenge = GameChallenge.objects.create(
            challenger=self.player,
            challenged=self.legend,
            status=GameChallenge.COMPLETED,
            winner=self.legend,
        )
        self.client.force_authenticate(user=self.legend)

        response = self.client.post(
            f'{self.challenges_url}{challenge.id}/rematch/',
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertFalse(GameChallenge.objects.filter(rematch_of=challenge).exists())

    @skipUnlessDBFeature('has_select_for_update_of')
    def test_loser_can_request_rematch_with_nullable_joins_on_postgresql(self):
        challenge = GameChallenge.objects.create(
            challenger=self.player,
            challenged=self.legend,
            status=GameChallenge.COMPLETED,
            winner=self.legend,
            challenger_score=30,
            challenged_score=40,
        )

        response = self.client.post(
            f'{self.challenges_url}{challenge.id}/rematch/',
            format='json',
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(
            Notification.objects.get(
                user=self.legend,
                type='game_rematch',
            ).data['challenge_id'],
            response.data['id'],
        )

    @skipUnlessDBFeature('has_select_for_update_of')
    def test_ready_endpoint_works_with_nullable_winner_on_postgresql(self):
        create_response = self.client.post(
            self.challenges_url,
            {'legend_id': self.legend.id},
            format='json',
        )
        challenge_id = create_response.data['id']

        self.client.force_authenticate(user=self.legend)
        self.client.post(
            f'{self.challenges_url}{challenge_id}/respond/',
            {'accept': True},
            format='json',
        )
        ready_response = self.client.post(
            f'{self.challenges_url}{challenge_id}/ready/',
            format='json',
        )

        self.assertEqual(ready_response.status_code, status.HTTP_200_OK)
        self.assertEqual(ready_response.data['status'], GameChallenge.ACCEPTED)

    def test_live_state_is_visible_only_to_spectator_and_turns_are_enforced(self):
        challenge_response = self.client.post(
            self.challenges_url,
            {'legend_id': self.legend.id},
            format='json',
        )
        challenge_id = challenge_response.data['id']
        self.client.force_authenticate(user=self.legend)
        self.client.post(
            f'{self.challenges_url}{challenge_id}/respond/',
            {'accept': True},
            format='json',
        )
        self.client.post(f'{self.challenges_url}{challenge_id}/ready/')
        self.client.force_authenticate(user=self.player)
        self.client.post(f'{self.challenges_url}{challenge_id}/ready/')

        challenge = GameChallenge.objects.get(pk=challenge_id)
        challenge.started_at = timezone.now() - timedelta(seconds=1)
        challenge.save(update_fields=('started_at',))
        live_state = {
            'round_number': 1,
            'score': 12,
            'remaining_seconds': 49.0,
            'player_x': 0.4,
            'player_y': 0.7,
            'objects': [{'x': 0.5, 'y': 0.3, 'type': 'obstacle'}],
        }
        extended_live_state = {
            **live_state,
            'player_target_x': 0.6,
            'player_target_y': 0.65,
            'shield_active': True,
            'score_multiplier': 2,
            'objects': [
                {'id': 7, 'x': 0.5, 'y': 0.3, 'type': 'obstacle'},
                {'id': 8, 'x': 0.25, 'y': 0.4, 'type': 'bonus'},
                {'id': 9, 'x': 0.6, 'y': 0.5, 'type': 'reward'},
                {'id': 10, 'x': 0.7, 'y': 0.6, 'type': 'trap'},
                {
                    'id': 11,
                    'x': 0.3,
                    'y': 0.2,
                    'type': 'reward_bird',
                    'direction': 1,
                },
                {
                    'id': 12,
                    'x': 0.8,
                    'y': 0.25,
                    'type': 'trap_bird',
                    'direction': -1,
                },
            ],
            'events': [
                {'id': 1, 'x': 0.5, 'y': 0.3, 'type': 'dodge'},
                {'id': 2, 'x': 0.6, 'y': 0.5, 'type': 'reward_pickup'},
                {'id': 3, 'x': 0.7, 'y': 0.6, 'type': 'trap_pickup'},
            ],
        }
        updated = self.client.post(
            f'{self.challenges_url}{challenge_id}/live-state/',
            live_state,
            format='json',
        )
        self.assertEqual(updated.status_code, status.HTTP_200_OK)
        self.assertTrue(updated.data['is_my_turn'])
        self.assertIsNone(updated.data['opponent_live_state'])

        self.client.force_authenticate(user=self.legend)
        spectator = self.client.get(self.challenges_url)
        self.assertFalse(spectator.data[0]['is_my_turn'])
        self.assertEqual(spectator.data[0]['opponent_live_state'], live_state)
        challenge.refresh_from_db()
        challenge.challenger_live_at = timezone.now() - timedelta(minutes=1)
        challenge.save(update_fields=('challenger_live_at',))
        delayed_spectator = self.client.get(
            f'{self.challenges_url}{challenge_id}/live-state/',
        )
        self.assertEqual(delayed_spectator.status_code, status.HTTP_200_OK)
        self.assertEqual(delayed_spectator.data['opponent_live_state'], live_state)
        rejected_live_state = self.client.post(
            f'{self.challenges_url}{challenge_id}/live-state/',
            live_state,
            format='json',
        )
        self.assertEqual(
            rejected_live_state.status_code,
            status.HTTP_409_CONFLICT,
        )
        rejected_turn = self.client.post(
            f'{self.challenges_url}{challenge_id}/round/',
            {'round_number': 1, 'score': 10},
            format='json',
        )
        self.assertEqual(rejected_turn.status_code, status.HTTP_409_CONFLICT)

        self.client.force_authenticate(user=self.player)
        challenge.refresh_from_db()
        challenge.started_at = timezone.now() - timedelta(seconds=51)
        challenge.save(update_fields=('started_at',))
        self.client.post(
            f'{self.challenges_url}{challenge_id}/round/',
            {'round_number': 1, 'score': 12},
            format='json',
        )
        self.client.force_authenticate(user=self.legend)
        challenge.refresh_from_db()
        challenge.started_at = timezone.now() - timedelta(seconds=51)
        challenge.save(update_fields=('started_at',))
        updated = self.client.post(
            f'{self.challenges_url}{challenge_id}/live-state/',
            extended_live_state,
            format='json',
        )
        self.assertEqual(updated.status_code, status.HTTP_200_OK)
        self.client.force_authenticate(user=self.player)
        spectator = self.client.get(self.challenges_url)
        self.assertEqual(
            spectator.data[0]['opponent_live_state'],
            extended_live_state,
        )
        self.assertEqual(
            spectator.data[0]['opponent_live_state']['objects'][1]['type'],
            'bonus',
        )
        self.assertEqual(
            spectator.data[0]['opponent_live_state']['objects'][2]['type'],
            'reward',
        )
        self.assertEqual(
            spectator.data[0]['opponent_live_state']['objects'][3]['type'],
            'trap',
        )
        self.assertEqual(
            spectator.data[0]['opponent_live_state']['objects'][4]['type'],
            'reward_bird',
        )
        self.assertEqual(
            spectator.data[0]['opponent_live_state']['events'][1]['type'],
            'reward_pickup',
        )

    def test_only_invited_player_can_respond_and_scores_are_single_use(self):
        challenge_response = self.client.post(
            self.challenges_url,
            {'legend_id': self.legend.id},
            format='json',
        )
        challenge_id = challenge_response.data['id']

        self.assertEqual(
            self.client.post(
                f'{self.challenges_url}{challenge_id}/respond/',
                {'accept': True},
                format='json',
            ).status_code,
            status.HTTP_403_FORBIDDEN,
        )

        self.client.force_authenticate(user=self.legend)
        accepted = self.client.post(
            f'{self.challenges_url}{challenge_id}/respond/',
            {'accept': True},
            format='json',
        )
        self.assertEqual(accepted.status_code, status.HTTP_200_OK)
        self.assertTrue(
            Notification.objects.filter(
                user=self.player,
                type='game_challenge_response',
                data__accepted=True,
            ).exists()
        )
        self.client.post(
            f'{self.challenges_url}{challenge_id}/ready/',
            format='json',
        )
        self.client.force_authenticate(user=self.player)
        self.client.post(
            f'{self.challenges_url}{challenge_id}/ready/',
            format='json',
        )
        challenge = GameChallenge.objects.get(pk=challenge_id)
        challenge.started_at = timezone.now() - timedelta(seconds=80)
        challenge.save(update_fields=('started_at',))
        self.client.force_authenticate(user=self.player)
        first_score = self.client.post(
            f'{self.challenges_url}{challenge_id}/round/',
            {'round_number': 1, 'score': 10},
            format='json',
        )
        second_score = self.client.post(
            f'{self.challenges_url}{challenge_id}/round/',
            {'round_number': 1, 'score': 100},
            format='json',
        )
        self.assertEqual(first_score.status_code, status.HTTP_200_OK)
        self.assertEqual(second_score.status_code, status.HTTP_200_OK)
        self.assertEqual(second_score.data['my_score'], 10)

    def test_first_demotion_completes_challenge_once_and_awards_opponent(self):
        challenge_response = self.client.post(
            self.challenges_url,
            {'legend_id': self.legend.id},
            format='json',
        )
        challenge_id = challenge_response.data['id']
        self.client.force_authenticate(user=self.legend)
        self.client.post(
            f'{self.challenges_url}{challenge_id}/respond/',
            {'accept': True},
            format='json',
        )
        self.client.post(f'{self.challenges_url}{challenge_id}/ready/')
        self.client.force_authenticate(user=self.player)
        ready = self.client.post(f'{self.challenges_url}{challenge_id}/ready/')
        self.assertEqual(ready.data['status'], GameChallenge.PLAYING)
        challenge = GameChallenge.objects.get(pk=challenge_id)
        challenge.started_at = timezone.now() + timedelta(minutes=1)
        challenge.save(update_fields=('started_at',))

        early_elimination = self.client.post(
            f'{self.challenges_url}{challenge_id}/eliminate/',
            {'score': 25},
            format='json',
        )
        self.assertEqual(
            early_elimination.status_code,
            status.HTTP_409_CONFLICT,
        )
        challenge = GameChallenge.objects.get(pk=challenge_id)
        challenge.started_at = timezone.now() - timedelta(seconds=1)
        challenge.save(update_fields=('started_at',))

        result = self.client.post(
            f'{self.challenges_url}{challenge_id}/eliminate/',
            {'score': 25},
            format='json',
        )
        self.assertEqual(result.status_code, status.HTTP_200_OK)
        self.assertEqual(result.data['status'], GameChallenge.COMPLETED)
        self.assertEqual(result.data['winner_id'], self.legend.id)
        self.assertFalse(result.data['winner_by_score'])
        self.assertFalse(result.data['my_won'])
        self.assertEqual(result.data['loser_id'], self.player.id)
        self.assertEqual(GameReward.objects.get(user=self.legend).duel_medal, 'bronze')

        repeated = self.client.post(
            f'{self.challenges_url}{challenge_id}/eliminate/',
            {'score': 999},
            format='json',
        )
        self.assertEqual(repeated.status_code, status.HTTP_200_OK)
        self.assertEqual(repeated.data['winner_id'], self.legend.id)
        challenge.refresh_from_db()
        self.assertEqual(challenge.challenger_score, 25)
        self.assertEqual(GameReward.objects.get(user=self.legend).duel_medal, 'bronze')

    def test_three_rounds_with_equal_totals_finish_as_a_draw(self):
        challenge_response = self.client.post(
            self.challenges_url,
            {'legend_id': self.legend.id},
            format='json',
        )
        challenge_id = challenge_response.data['id']
        self.client.force_authenticate(user=self.legend)
        self.client.post(
            f'{self.challenges_url}{challenge_id}/respond/',
            {'accept': True},
            format='json',
        )
        self.client.post(f'{self.challenges_url}{challenge_id}/ready/')
        self.client.force_authenticate(user=self.player)
        started = self.client.post(f'{self.challenges_url}{challenge_id}/ready/')
        self.assertEqual(started.data['round_number'], 1)
        self.assertEqual(started.data['round_duration_seconds'], 50)

        for round_number, duration in enumerate((50, 45, 40), start=1):
            challenge = GameChallenge.objects.get(pk=challenge_id)
            players = (self.player, self.legend)
            for index, player in enumerate(players):
                challenge.refresh_from_db()
                challenge.started_at = timezone.now() - timedelta(
                    seconds=duration + 1,
                )
                challenge.save(update_fields=('started_at',))
                self.client.force_authenticate(user=player)
                player_result = self.client.post(
                    f'{self.challenges_url}{challenge_id}/round/',
                    {'round_number': round_number, 'score': 100},
                    format='json',
                )
                self.assertEqual(player_result.status_code, status.HTTP_200_OK)
                if index == 0:
                    self.assertTrue(player_result.data['my_round_complete'])
                    self.assertFalse(player_result.data['opponent_round_complete'])
                    self.assertFalse(player_result.data['is_my_turn'])
                    repeated = self.client.post(
                        f'{self.challenges_url}{challenge_id}/round/',
                        {'round_number': round_number, 'score': 999},
                        format='json',
                    )
                    self.assertEqual(repeated.status_code, status.HTTP_200_OK)
                    self.assertEqual(repeated.data['my_score'], round_number * 100)
            opponent_result = player_result

            if round_number < 3:
                self.assertEqual(
                    opponent_result.data['round_number'],
                    round_number + 1,
                )
                self.assertEqual(
                    opponent_result.data['status'],
                    GameChallenge.PLAYING,
                )
                self.assertGreater(
                    opponent_result.data['starts_in_milliseconds'],
                    0,
                )
            else:
                self.assertEqual(
                    opponent_result.data['status'],
                    GameChallenge.COMPLETED,
                )
                self.assertTrue(opponent_result.data['is_draw'])
                self.assertFalse(opponent_result.data['winner_by_score'])
                self.assertIsNone(opponent_result.data['winner_id'])
                self.assertIsNone(opponent_result.data['winner_name'])

    def test_three_distinct_wins_award_gold_and_preserve_champion_title(self):
        opponents = [self.legend]
        for index in range(2):
            opponent = User.objects.create_user(username=f'legend_extra_{index}')
            GameReward.objects.create(
                user=opponent,
                score=200,
                points=500,
                title=f'Trophée {opponent.username}',
            )
            opponents.append(opponent)

        for index, opponent in enumerate(opponents):
            player_tier = GameReward.objects.get(user=self.player).duel_medal
            opponent_reward = GameReward.objects.get(user=opponent)
            opponent_reward.duel_medal = player_tier
            opponent_reward.save(update_fields=('duel_medal',))
            challenge_response = self.client.post(
                self.challenges_url,
                {'legend_id': opponent.id},
                format='json',
            )
            self.assertEqual(challenge_response.status_code, status.HTTP_201_CREATED)
            challenge_id = challenge_response.data['id']
            self.client.force_authenticate(user=opponent)
            self.client.post(
                f'{self.challenges_url}{challenge_id}/respond/',
                {'accept': True},
                format='json',
            )
            self.client.post(
                f'{self.challenges_url}{challenge_id}/ready/',
                format='json',
            )
            self.client.force_authenticate(user=self.player)
            self.client.post(
                f'{self.challenges_url}{challenge_id}/ready/',
                format='json',
            )
            challenge = GameChallenge.objects.get(pk=challenge_id)
            challenge.started_at = timezone.now() - timedelta(seconds=1)
            challenge.challenger_turn = False
            challenge.save(update_fields=('started_at', 'challenger_turn'))
            self.client.force_authenticate(user=opponent)
            elimination = self.client.post(
                f'{self.challenges_url}{challenge_id}/eliminate/',
                {'score': 20},
                format='json',
            )
            self.assertEqual(elimination.status_code, status.HTTP_200_OK)
            self.assertEqual(elimination.data['winner_id'], self.player.id)
            self.client.force_authenticate(user=self.player)
            expected_medal = ('bronze', 'silver', 'gold')[index]
            self.assertEqual(
                GameReward.objects.get(user=self.player).duel_medal,
                expected_medal,
            )

        reward = GameReward.objects.get(user=self.player)
        self.assertEqual(reward.duel_medal, 'gold')
        self.assertEqual(
            reward.earned_duel_medals,
            ['bronze', 'silver', 'gold'],
        )
        self.assertEqual(reward.title, 'Champion FopCam')

        new_run_reward = self.client.post(
            '/api/game/rewards/level-12/',
            {'score': 300},
            format='json',
        )
        self.assertEqual(new_run_reward.status_code, status.HTTP_200_OK)
        reward.refresh_from_db()
        self.assertEqual(reward.title, 'Champion FopCam')
        self.assertEqual(reward.duel_medal, 'gold')

    def test_four_distinct_wins_award_cup_and_first_league_title(self):
        opponents = [self.legend]
        for index in range(3):
            opponent = User.objects.create_user(
                username=f'cup_opponent_{index}',
            )
            opponents.append(opponent)

        for opponent in opponents:
            challenge = GameChallenge.objects.create(
                challenger=self.player,
                challenged=opponent,
                status=GameChallenge.COMPLETED,
                winner=self.player,
            )
            with transaction.atomic():
                _award_game_challenge_winner(challenge)
            self.client.force_authenticate(user=self.player)

        reward = GameReward.objects.get(user=self.player)
        self.assertEqual(reward.duel_medal, 'cup')
        self.assertEqual(
            reward.earned_duel_medals,
            ['bronze', 'silver', 'gold', 'cup'],
        )
        self.assertEqual(reward.title, 'Champion 1ère Ligue')
        legends = self.client.get(self.legends_url)
        player_legend = next(
            legend
            for legend in legends.data
            if legend['username'] == self.player.username
        )
        self.assertEqual(player_legend['duel_medal'], 'cup')
        self.assertEqual(player_legend['title'], 'Champion 1ère Ligue')

    def test_five_distinct_wins_award_champion_league_pro(self):
        opponents = [
            User.objects.create_user(username=f'pro_cup_opponent_{index}')
            for index in range(4)
        ]
        for opponent in opponents:
            challenge = GameChallenge.objects.create(
                challenger=self.player,
                challenged=opponent,
                status=GameChallenge.COMPLETED,
                winner=self.player,
            )
            with transaction.atomic():
                _award_game_challenge_winner(challenge)

        repeated_win = GameChallenge.objects.create(
            challenger=self.player,
            challenged=opponents[0],
            status=GameChallenge.COMPLETED,
            winner=self.player,
        )
        with transaction.atomic():
            _award_game_challenge_winner(repeated_win)
        self.assertEqual(GameReward.objects.get(user=self.player).duel_medal, 'cup')

        fifth_opponent = User.objects.create_user(username='pro_cup_opponent_4')
        fifth_win = GameChallenge.objects.create(
            challenger=self.player,
            challenged=fifth_opponent,
            status=GameChallenge.COMPLETED,
            winner=self.player,
        )
        with transaction.atomic():
            _award_game_challenge_winner(fifth_win)

        reward = GameReward.objects.get(user=self.player)
        self.assertEqual(reward.duel_medal, 'cup_pro')
        self.assertEqual(reward.title, 'Champion League Pro')
        self.assertEqual(
            reward.earned_duel_medals,
            ['bronze', 'silver', 'gold', 'cup', 'cup_pro'],
        )

    def test_live_duels_are_visible_only_to_non_players(self):
        challenge = GameChallenge.objects.create(
            challenger=self.player,
            challenged=self.legend,
            status=GameChallenge.PLAYING,
            challenger_turn=True,
            challenger_live_state={
                'round_number': 2,
                'score': 32,
                'remaining_seconds': 18.5,
                'player_x': 0.4,
                'player_y': 0.6,
                'objects': [{'id': 9, 'x': 0.5, 'y': 0.5, 'type': 'bird'}],
                'events': [],
                'private_field': 'not public',
            },
        )
        self.client.force_authenticate(user=self.player)
        self.assertEqual(
            self.client.get('/api/game/challenges/live/').data,
            [],
        )
        self.assertEqual(
            self.client.get(
                f'/api/game/challenges/live/{challenge.id}/',
            ).status_code,
            status.HTTP_403_FORBIDDEN,
        )

        spectator = User.objects.create_user(username='spectator')
        self.client.force_authenticate(user=spectator)
        listing = self.client.get('/api/game/challenges/live/')
        self.assertEqual(listing.status_code, status.HTTP_200_OK)
        self.assertEqual(listing.data[0]['id'], challenge.id)
        state = self.client.get(
            f'/api/game/challenges/live/{challenge.id}/',
        )
        self.assertEqual(state.status_code, status.HTTP_200_OK)
        self.assertEqual(state.data['state']['score'], 32)
        self.assertNotIn('private_field', state.data['state'])
