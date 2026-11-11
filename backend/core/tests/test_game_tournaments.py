from datetime import timedelta

from django.contrib.auth.models import User
from django.test import TestCase
from django.utils import timezone
from rest_framework import status
from rest_framework.test import APIClient

from core.models import (
    GameChallenge,
    GameReward,
    GameTournament,
    GameTournamentEntry,
    GameTournamentMatch,
    GameTournamentSupport,
)
from core.views import _advance_game_tournament


class GameTournamentTests(TestCase):
    tournaments_url = '/api/game/tournaments/'

    def setUp(self):
        self.players = [
            User.objects.create_user(
                username=f'pro_{index}',
                first_name=f'Champion {index}',
                password='password123',
            )
            for index in range(7)
        ]
        for player in self.players[:6]:
            GameReward.objects.create(
                user=player,
                score=500,
                points=500,
                title=f'Trophée {player.username}',
                duel_medal='cup_pro',
                earned_duel_medals=['bronze', 'silver', 'gold', 'cup', 'cup_pro'],
            )
        self.spectator = User.objects.create_user(
            username='spectator',
            password='password123',
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.players[0])

    def create_tournament(self, capacity=6, invited_ids=None):
        return self.client.post(
            self.tournaments_url,
            {'capacity': capacity, 'invited_ids': invited_ids or []},
            format='json',
        )

    def test_only_champion_pro_can_create_and_invite_same_tier(self):
        self.client.force_authenticate(user=self.spectator)
        denied = self.create_tournament()
        self.assertEqual(denied.status_code, status.HTTP_403_FORBIDDEN)

        self.client.force_authenticate(user=self.players[0])
        response = self.create_tournament(invited_ids=[self.players[1].id])
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['capacity'], 6)
        self.assertEqual(len(response.data['entries']), 2)

    def test_invited_and_open_players_join_then_six_player_groups_are_created(self):
        created = self.create_tournament(
            invited_ids=[player.id for player in self.players[1:3]],
        )
        self.assertEqual(created.status_code, status.HTTP_201_CREATED)
        tournament_id = created.data['id']

        for player in self.players[1:6]:
            self.client.force_authenticate(user=player)
            tournament = self.client.get(
                f'{self.tournaments_url}{tournament_id}/',
            )
            self.assertTrue(tournament.data['can_join'])
            joined = self.client.post(
                f'{self.tournaments_url}{tournament_id}/join/',
                format='json',
            )
            self.assertEqual(joined.status_code, status.HTTP_200_OK)

        self.client.force_authenticate(user=self.players[0])
        started = self.client.post(
            f'{self.tournaments_url}{tournament_id}/start/',
            format='json',
        )
        self.assertEqual(started.status_code, status.HTTP_200_OK)
        tournament = GameTournament.objects.get(pk=tournament_id)
        self.assertEqual(tournament.status, GameTournament.GROUPS)
        self.assertEqual(
            list(
                tournament.entries.order_by('group_number')
                .values_list('group_number', flat=True)
            ).count(1),
            3,
        )
        self.assertEqual(
            tournament.matches.filter(round_type=GameTournamentMatch.GROUP).count(),
            6,
        )

    def test_spectator_support_is_changeable_and_players_cannot_vote(self):
        created = self.create_tournament(
            invited_ids=[player.id for player in self.players[1:6]],
        )
        tournament_id = created.data['id']
        for player in self.players[1:6]:
            self.client.force_authenticate(user=player)
            self.client.post(
                f'{self.tournaments_url}{tournament_id}/join/',
                format='json',
            )
        self.client.force_authenticate(user=self.players[0])
        self.client.post(
            f'{self.tournaments_url}{tournament_id}/start/',
            format='json',
        )

        self.client.force_authenticate(user=self.spectator)
        first_vote = self.client.post(
            f'{self.tournaments_url}{tournament_id}/support/',
            {'participant_id': self.players[0].id},
            format='json',
        )
        self.assertEqual(first_vote.status_code, status.HTTP_200_OK)
        self.client.post(
            f'{self.tournaments_url}{tournament_id}/support/',
            {'participant_id': self.players[1].id},
            format='json',
        )
        self.assertEqual(
            GameTournamentSupport.objects.filter(
                tournament_id=tournament_id,
                supporter=self.spectator,
            ).count(),
            1,
        )
        self.client.force_authenticate(user=self.players[0])
        player_vote = self.client.post(
            f'{self.tournaments_url}{tournament_id}/support/',
            {'participant_id': self.players[1].id},
            format='json',
        )
        self.assertEqual(player_vote.status_code, status.HTTP_403_FORBIDDEN)

    def test_six_player_bracket_advances_to_semifinals_and_awards_pro_trophy(self):
        tournament = GameTournament.objects.create(
            organizer=self.players[0],
            capacity=6,
            status=GameTournament.GROUPS,
        )
        groups = [self.players[:3], self.players[3:6]]
        for group_number, group_players in enumerate(groups, start=1):
            for player in group_players:
                GameTournamentEntry.objects.create(
                    tournament=tournament,
                    user=player,
                    status=GameTournamentEntry.CONFIRMED,
                    group_number=group_number,
                    joined_at=timezone.now(),
                )
            group_matches = [
                (group_players[0], group_players[1], group_players[0]),
                (group_players[0], group_players[2], group_players[0]),
                (group_players[1], group_players[2], group_players[1]),
            ]
            for match_number, (player_a, player_b, winner) in enumerate(
                group_matches,
                start=1,
            ):
                GameTournamentMatch.objects.create(
                    tournament=tournament,
                    round_type=GameTournamentMatch.GROUP,
                    group_number=group_number,
                    match_number=match_number,
                    player_a=player_a,
                    player_b=player_b,
                    winner=winner,
                    status=GameTournamentMatch.COMPLETED,
                )

        _advance_game_tournament(tournament)
        tournament.refresh_from_db()
        self.assertEqual(tournament.status, GameTournament.SEMIFINALS)
        semifinals = list(
            tournament.matches.filter(
                round_type=GameTournamentMatch.SEMIFINAL,
            )
        )
        self.assertEqual(len(semifinals), 2)
        for match in semifinals:
            match.winner = match.player_a
            match.status = GameTournamentMatch.COMPLETED
            match.save(update_fields=('winner', 'status'))

        _advance_game_tournament(tournament)
        tournament.refresh_from_db()
        final = tournament.matches.get(round_type=GameTournamentMatch.FINAL)
        self.assertEqual(tournament.status, GameTournament.FINAL)
        final.winner = final.player_b
        final.status = GameTournamentMatch.COMPLETED
        final.save(update_fields=('winner', 'status'))

        _advance_game_tournament(tournament)
        tournament.refresh_from_db()
        self.assertEqual(tournament.status, GameTournament.COMPLETED)
        self.assertEqual(tournament.winner_id, final.player_b_id)
        self.assertEqual(tournament.trophy_title, 'Champion FopCam Pro')

    def test_twelve_player_bracket_qualifies_four_group_winners_and_runners_up(self):
        additional_players = [
            User.objects.create_user(username=f'pro_extra_{index}')
            for index in range(6)
        ]
        for player in additional_players:
            GameReward.objects.create(
                user=player,
                score=500,
                points=500,
                title=f'Trophée {player.username}',
                duel_medal='cup_pro',
                earned_duel_medals=['bronze', 'silver', 'gold', 'cup', 'cup_pro'],
            )
        players = self.players[:6] + additional_players
        tournament = GameTournament.objects.create(
            organizer=self.players[0],
            capacity=12,
            status=GameTournament.GROUPS,
        )
        for group_number in range(1, 5):
            group_players = players[(group_number - 1) * 3:group_number * 3]
            for player in group_players:
                GameTournamentEntry.objects.create(
                    tournament=tournament,
                    user=player,
                    status=GameTournamentEntry.CONFIRMED,
                    group_number=group_number,
                    joined_at=timezone.now(),
                )
            for index, player_a in enumerate(group_players):
                for player_b in group_players[index + 1:]:
                    GameTournamentMatch.objects.create(
                        tournament=tournament,
                        round_type=GameTournamentMatch.GROUP,
                        group_number=group_number,
                        match_number=GameTournamentMatch.objects.filter(
                            tournament=tournament,
                            round_type=GameTournamentMatch.GROUP,
                        ).count() + 1,
                        player_a=player_a,
                        player_b=player_b,
                        winner=player_a,
                        status=GameTournamentMatch.COMPLETED,
                    )

        _advance_game_tournament(tournament)

        tournament.refresh_from_db()
        self.assertEqual(tournament.status, GameTournament.QUARTERFINALS)
        self.assertEqual(
            tournament.matches.filter(
                round_type=GameTournamentMatch.QUARTERFINAL,
            ).count(),
            4,
        )

    def test_challenges_expire_and_active_duel_does_not_remove_other_requests(self):
        incoming = self.client.post(
            '/api/game/challenges/',
            {'legend_id': self.players[1].id},
            format='json',
        )
        challenge = GameChallenge.objects.get(pk=incoming.data['id'])
        self.assertAlmostEqual(
            (challenge.expires_at - challenge.created_at).total_seconds(),
            timedelta(minutes=30).total_seconds(),
            delta=1,
        )
        challenge.expires_at = timezone.now() - timedelta(seconds=1)
        challenge.save(update_fields=('expires_at',))
        self.client.force_authenticate(user=self.players[1])
        expired_response = self.client.post(
            f"/api/game/challenges/{challenge.id}/respond/",
            {'accept': True},
            format='json',
        )
        self.assertEqual(expired_response.status_code, status.HTTP_410_GONE)
        challenge.refresh_from_db()
        self.assertEqual(challenge.status, GameChallenge.EXPIRED)
        self.assertEqual(
            self.client.get('/api/game/challenges/').data,
            [],
        )

        active = GameChallenge.objects.create(
            challenger=self.players[0],
            challenged=self.players[1],
            status=GameChallenge.PLAYING,
        )
        pending = self.client.post(
            '/api/game/challenges/',
            {'legend_id': self.players[2].id},
            format='json',
        )
        self.assertEqual(pending.status_code, status.HTTP_201_CREATED)
        self.client.force_authenticate(user=self.players[2])
        accepted = self.client.post(
            f"/api/game/challenges/{pending.data['id']}/respond/",
            {'accept': True},
            format='json',
        )
        self.assertEqual(accepted.status_code, status.HTTP_409_CONFLICT)
        self.assertEqual(
            GameChallenge.objects.get(pk=pending.data['id']).status,
            GameChallenge.PENDING,
        )
        self.client.force_authenticate(user=self.players[3])
        other_request = self.client.post(
            '/api/game/challenges/',
            {'legend_id': self.players[1].id},
            format='json',
        )
        self.assertEqual(other_request.status_code, status.HTTP_201_CREATED)
        self.client.force_authenticate(user=self.players[1])
        blocked_accept = self.client.post(
            f"/api/game/challenges/{other_request.data['id']}/respond/",
            {'accept': True},
            format='json',
        )
        self.assertEqual(blocked_accept.status_code, status.HTTP_409_CONFLICT)
        self.assertEqual(
            GameChallenge.objects.get(pk=other_request.data['id']).status,
            GameChallenge.PENDING,
        )
        active.delete()
