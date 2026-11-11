import jwt
import json
import logging
import re
import secrets
import urllib.error
import urllib.request
from django.conf import settings
from django.contrib.auth.models import User
from django.contrib.auth.hashers import check_password, make_password
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError
from django.core.files.storage import default_storage
from django.core import signing
from django.core.mail import send_mail
from django.http import FileResponse, Http404
from django.db import models, transaction
from django.db.models import Q, F, Count, Sum, Exists, OuterRef, Subquery, Prefetch
from django.db.models.functions import Lower, TruncDate
from datetime import timedelta
from decimal import Decimal, InvalidOperation
from django.utils import timezone
from rest_framework import generics, viewsets, permissions, serializers, status
from rest_framework.decorators import action
from rest_framework.parsers import MultiPartParser, FormParser, JSONParser
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework.pagination import PageNumberPagination
from rest_framework.generics import ListAPIView
from rest_framework.exceptions import PermissionDenied, ValidationError
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.token_blacklist.models import OutstandingToken, BlacklistedToken
from django.shortcuts import get_object_or_404
from django.urls import reverse
from urllib.parse import urlencode
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from uuid import uuid4

logger = logging.getLogger(__name__)
from .permissions import IsOwnerOrReadOnly, IsGroupAdminOrReadOnly, CanAccessSecretGroup
from .chat_utils import private_room_participant_ids

GAME_CHALLENGE_ROUND_DURATIONS_SECONDS = (50, 45, 40)
GAME_CHALLENGE_START_DELAY_SECONDS = 8
GAME_CHALLENGE_ROUND_START_DELAY_SECONDS = 3
SILVER_MEDAL_SCORE_THRESHOLD = 250
PROFILE_ROLE_CHANGE_LIMIT = 3


def _record_product_analytics(product_ids, event_type, viewer_id=None):
    products = Product.objects.filter(pk__in=product_ids)
    if viewer_id is not None:
        products = products.exclude(shop__owner_id=viewer_id)
    ProductAnalyticsEvent.objects.bulk_create(
        ProductAnalyticsEvent(product_id=product_id, event_type=event_type)
        for product_id in products.values_list('pk', flat=True)
    )


def _record_profile_analytics(event_type, owner_ids, viewer_id=None):
    unique_owner_ids = {
        owner_id
        for owner_id in owner_ids
        if owner_id and owner_id != viewer_id
    }
    if unique_owner_ids:
        ProfileAnalyticsEvent.objects.bulk_create(
            ProfileAnalyticsEvent(owner_id=owner_id, event_type=event_type)
            for owner_id in unique_owner_ids
        )


def _record_post_impressions(posts, viewer_id=None):
    events = [
        ProfileAnalyticsEvent(
            owner_id=post.author_id,
            event_type='post_impression',
            post=post,
        )
        for post in posts
        if post.author_id != viewer_id
    ]
    if events:
        ProfileAnalyticsEvent.objects.bulk_create(events)


def _profile_role_change_period():
    period_start = timezone.localtime().replace(
        day=1,
        hour=0,
        minute=0,
        second=0,
        microsecond=0,
    )
    next_period_start = (period_start + timedelta(days=32)).replace(day=1)
    return period_start, next_period_start


def _profile_role_change_quota(user):
    period_start, next_period_start = _profile_role_change_period()
    change_count = ProfileRoleChange.objects.filter(
        user=user,
        created_at__gte=period_start,
        created_at__lt=next_period_start,
    ).count()
    return {
        'remaining_changes': max(PROFILE_ROLE_CHANGE_LIMIT - change_count, 0),
        'monthly_limit': PROFILE_ROLE_CHANGE_LIMIT,
        'resets_at': next_period_start,
    }


def _record_profile_role_change(user, old_role, new_role):
    if old_role == new_role:
        return
    quota = _profile_role_change_quota(user)
    if quota['remaining_changes'] == 0:
        raise ValidationError({
            'role': 'Vous avez atteint la limite de 3 changements de type ce mois-ci.',
        })
    ProfileRoleChange.objects.create(
        user=user,
        old_role=old_role,
        new_role=new_role,
    )


class SmallPageNumberPagination(PageNumberPagination):
    page_size = 6
    page_size_query_param = 'page_size'
    max_page_size = 100


def _generate_unique_username(prefix):
    username = prefix
    counter = 1
    while User.objects.filter(username__iexact=username).exists():
        username = f"{prefix}_{counter}"
        counter += 1
    return username


def _get_jwks_public_key(token, jwks_url):
    jwk_client = jwt.PyJWKClient(jwks_url)
    signing_key = jwk_client.get_signing_key_from_jwt(token)
    return signing_key.key


def verify_google_id_token(id_token):
    if not settings.GOOGLE_CLIENT_ID:
        raise ValidationError({'id_token': 'GOOGLE_CLIENT_ID n\'est pas configuré'})
    try:
        public_key = _get_jwks_public_key(id_token, 'https://www.googleapis.com/oauth2/v3/certs')
        return jwt.decode(
            id_token,
            public_key,
            algorithms=['RS256'],
            audience=settings.GOOGLE_CLIENT_ID,
            issuer=['https://accounts.google.com', 'accounts.google.com']
        )
    except jwt.ExpiredSignatureError:
        raise ValidationError({'id_token': 'Le token Google ID a expiré'})
    except jwt.InvalidAudienceError:
        raise ValidationError({'id_token': f'Désaccord d\'audience du token Google ID. Attendu: {settings.GOOGLE_CLIENT_ID}'})
    except jwt.InvalidIssuerError:
        raise ValidationError({'id_token': 'Désaccord d\'émetteur du token Google ID'})
    except jwt.DecodeError as e:
        raise ValidationError({'id_token': f'Erreur de décodage JWT: {str(e)}'})
    except Exception as e:
        raise ValidationError({'id_token': f'Token Google ID invalide: {str(e)}'})


def verify_apple_id_token(id_token):
    if not settings.APPLE_CLIENT_ID:
        raise ValidationError({'id_token': 'APPLE_CLIENT_ID n\'est pas configuré'})
    try:
        public_key = _get_jwks_public_key(id_token, 'https://appleid.apple.com/auth/keys')
        return jwt.decode(
            id_token,
            public_key,
            algorithms=['RS256'],
            audience=settings.APPLE_CLIENT_ID,
            issuer='https://appleid.apple.com'
        )
    except jwt.ExpiredSignatureError:
        raise ValidationError({'id_token': 'Le token Apple ID a expiré'})
    except jwt.InvalidAudienceError:
        raise ValidationError({'id_token': 'Désaccord d\'audience du token Apple ID'})
    except jwt.InvalidIssuerError:
        raise ValidationError({'id_token': 'Désaccord d\'émetteur du token Apple ID'})
    except Exception:
        raise ValidationError({'id_token': 'Token Apple ID invalide'})
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from dj_rest_auth.views import LoginView, LogoutView
from dj_rest_auth.jwt_auth import set_jwt_cookies
from .serializers import (
    UserSerializer,
    RegisterSerializer,
    UserProfileSerializer,
    CustomTokenObtainPairSerializer,
    ShopSerializer,
    ProductSerializer,
    SellerProductSerializer,
    StockMovementSerializer,
    CategorySerializer,
    MessageSerializer,
    NotificationSerializer,
    FollowSerializer,
    FriendSerializer,
    UserDirectorySerializer,
    UserPublicProfileSerializer,
    PostSerializer,
    LikeSerializer,
    CommentSerializer,
    ProducerReviewSerializer,
    CouponSerializer,
    LoyaltyProgramSerializer,
    ReferralSerializer,
    FavoriteSerializer,
    ProductViewSerializer,
    RecommendationSerializer,
    ShareSerializer,
    JobPostingSerializer,
    JobSeekerPostSerializer,
    JobApplicationSerializer,
    ProfileRoleChangeSerializer,
    StorySerializer,
    StoryCreateSerializer,
    StoryViewSerializer,
    StoryLikeSerializer,
    GroupSerializer,
    GroupCreateSerializer,
    GroupMemberSerializer,
    GroupPostSerializer,
    GroupPostCreateSerializer,
    GroupPostUpdateSerializer,
    GroupPostLikeSerializer,
    GroupPostCommentSerializer,
    GroupPostCommentCreateSerializer,
    GroupEventSerializer,
    GroupEventCreateSerializer,
    GroupEventAttendeeSerializer,
    ReelSerializer,
    ReelCreateSerializer,
    ReelCommentSerializer,
    ReactionSerializer,
    MarketplaceListingSerializer,
    HashtagSerializer,
)
from .models import PROFILE_ROLE_CHANGE_CHOICES, UserProfile, ProfileRoleChange, ProfileAnalyticsEvent, Shop, ShopAnalyticsEvent, ShopLike, ShopVote, ShopShare, ShopRating, Product, ProductAnalyticsEvent, ProductImage, StockMovement, Category, Message, Notification, Follow, Friend, Post, Like, Comment, Coupon, LoyaltyProgram, Referral, ProducerReview, Favorite, ProductView, Recommendation, Share, JobPosting, JobSeekerPost, JobApplication, Story, StoryView, StoryLike, Group, GroupMember, GroupPost, GroupPostLike, GroupPostComment, GroupEvent, GroupEventAttendee, Reel, ReelLike, ReelComment, ReelView, Reaction, MarketplaceListing, MarketplaceFavorite, Hashtag, Mention, GameReward, GameChallenge, GameDuelReward, GameTournament, GameTournamentEntry, GameTournamentMatch, GameTournamentSupport, PasswordResetCode
from .order_serializers import OrderCreateSerializer, OrderSerializer, SellerOrderSerializer
from .models import Order, OrderItem
from .seed_data import load_sample_data, create_sample_products_for_shop


class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = (permissions.AllowAny,)
    serializer_class = RegisterSerializer
    parser_classes = (MultiPartParser, FormParser, JSONParser)
    
    def create(self, request, *args, **kwargs):
        """Override create to return user data after registration"""
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = self.perform_create(serializer)
        
        # Return user data instead of serializer data
        user_data = {
            'id': user.id,
            'username': user.username,
            'email': user.email,
            'first_name': user.first_name,
            'last_name': user.last_name
        }
        
        return Response(user_data, status=status.HTTP_201_CREATED)
    
    def perform_create(self, serializer):
        """Return the created user instance"""
        return serializer.save()


class CustomLoginView(LoginView):
    """Custom login view that sets JWT cookies"""
    
    def get_response(self):
        response = super().get_response()
        
        # Set JWT cookies for the authenticated user
        if self.user and self.user.is_authenticated:
            refresh = RefreshToken.for_user(self.user)
            set_jwt_cookies(response, refresh.access_token, refresh)
        
        # Remove tokens from JSON response
        if 'access' in response.data:
            del response.data['access']
        if 'refresh' in response.data:
            del response.data['refresh']
            
        return response


class CustomTokenObtainPairView(TokenObtainPairView):
    serializer_class = CustomTokenObtainPairSerializer
    
    def post(self, request, *args, **kwargs):
        response = super().post(request, *args, **kwargs)
        
        # Set JWT cookies
        if response.status_code == 200:
            refresh = response.data.get('refresh')
            if refresh:
                refresh_token = RefreshToken(refresh)
                set_jwt_cookies(response, refresh_token.access_token, refresh_token)
                
                # Keep tokens in JSON response for localStorage fallback
                # response.data['access'] and response.data['refresh'] are already there
        
        return response


class MeView(generics.RetrieveAPIView):
    serializer_class = UserSerializer
    permission_classes = (permissions.IsAuthenticated,)

    def get_object(self):
        return self.request.user


class GameRewardClaimSerializer(serializers.Serializer):
    score = serializers.IntegerField(min_value=177)


def _game_reward_title(reward):
    if reward.duel_medal == 'cup_pro':
        return 'Champion League Pro'
    if reward.duel_medal == 'cup':
        return 'Champion 1ère Ligue'
    return reward.title


class GameRewardView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    @staticmethod
    def _serialize_reward(reward, already_claimed):
        return {
            'level': reward.level,
            'score': reward.score,
            'points': reward.points,
            'title': _game_reward_title(reward),
            'earned_at': reward.created_at,
            'already_claimed': already_claimed,
        }

    def post(self, request):
        serializer = GameRewardClaimSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        score = serializer.validated_data['score']
        display_name = request.user.first_name.strip() or request.user.username
        title = f'Trophée {display_name} · Légende FopCam'

        with transaction.atomic():
            locked_user = User.objects.select_for_update().get(pk=request.user.pk)
            reward, created = GameReward.objects.get_or_create(
                user=locked_user,
                defaults={
                    'score': score,
                    'points': 500,
                    'title': title,
                },
            )
            if not created and score > reward.score:
                reward.score = score
                reward.save(update_fields=('score', 'updated_at'))

        return Response(
            self._serialize_reward(reward, already_claimed=not created),
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


def _game_legend_data(request, user, reward):
    profile = UserProfile.objects.filter(
        user=user,
        is_active=True,
    ).order_by('-updated_at', '-id').first()
    avatar = None
    if profile and profile.profile_image:
        avatar = request.build_absolute_uri(profile.profile_image.url)
    display_name = user.get_full_name().strip() or user.username
    return {
        'id': user.id,
        'display_name': display_name,
        'username': user.username,
        'avatar_url': avatar,
        'score': reward.score,
        'title': _game_reward_title(reward),
        'duel_medal': reward.duel_medal,
        'duel_medals': reward.earned_duel_medals,
        'earned_at': reward.created_at,
    }


def _game_duel_tier(user_id):
    reward = GameReward.objects.filter(user_id=user_id).only('duel_medal').first()
    return reward.duel_medal if reward else None


_GAME_DUEL_TIER_RANKS = {
    'none': 0,
    'bronze': 1,
    'silver': 2,
    'gold': 3,
    'cup': 4,
    'cup_pro': 5,
}


def _game_duel_tier_rank(user_id):
    tier = _game_duel_tier(user_id)
    return _GAME_DUEL_TIER_RANKS.get(tier) if tier is not None else None


def _can_game_duel_challenge(challenger_id, challenged_id):
    challenger_rank = _game_duel_tier_rank(challenger_id)
    challenged_rank = _game_duel_tier_rank(challenged_id)
    return (
        challenger_rank is not None
        and challenged_rank is not None
        and challenger_rank >= challenged_rank
    )


def _game_challenge_data(request, challenge):
    user = request.user
    is_challenger = challenge.challenger_id == user.id
    opponent = challenge.challenged if is_challenger else challenge.challenger
    my_reward = GameReward.objects.filter(user=user).first()
    opponent_reward = GameReward.objects.filter(user=opponent).first()
    opponent_live_at = (
        challenge.challenged_live_at if is_challenger
        else challenge.challenger_live_at
    )
    opponent_live_state = (
        challenge.challenged_live_state if is_challenger
        else challenge.challenger_live_state
    )
    is_my_turn = (
        challenge.status == GameChallenge.PLAYING
        and is_challenger == challenge.challenger_turn
    )
    if is_my_turn or opponent_live_at is None:
        opponent_live_state = None
    winner_name = None
    if challenge.winner_id:
        winner_name = challenge.winner.get_full_name().strip() or challenge.winner.username
    loser_id = (
        challenge.challenged_id
        if challenge.winner_id == challenge.challenger_id
        else challenge.challenger_id
        if challenge.winner_id == challenge.challenged_id
        else None
    )
    root_challenge = challenge.rematch_of or challenge
    rematches_used = GameChallenge.objects.filter(
        rematch_of=root_challenge,
        rematch_requester=user,
    ).count()
    start_delay = (
        max(timedelta(), challenge.started_at - timezone.now())
        if challenge.started_at
        else None
    )
    return {
        'id': challenge.id,
        'status': challenge.status,
        'is_rematch': challenge.rematch_of_id is not None,
        'can_cancel': (
            user.id in (challenge.challenger_id, challenge.challenged_id)
            and challenge.status == GameChallenge.PENDING
            and challenge.tournament_match_id is None
        ),
        'can_delete': (
            user.id in (challenge.challenger_id, challenge.challenged_id)
            and challenge.status in (GameChallenge.DECLINED, GameChallenge.CANCELLED)
            and challenge.tournament_match_id is None
        ),
        'expires_at': challenge.expires_at,
        'seconds_until_expiry': max(
            0,
            int((challenge.expires_at - timezone.now()).total_seconds()),
        ),
        'is_draw': (
            challenge.status == GameChallenge.COMPLETED
            and challenge.winner_id is None
            and challenge.challenger_score is not None
            and challenge.challenged_score is not None
            and challenge.challenger_score == challenge.challenged_score
        ),
        'created_at': challenge.created_at,
        'opponent': _game_legend_data(request, opponent, opponent_reward) if opponent_reward else None,
        'challenger_score': challenge.challenger_score,
        'challenged_score': challenge.challenged_score,
        'my_score': (
            challenge.challenger_score if challenge.challenger_id == user.id
            else challenge.challenged_score
        ),
        'opponent_score': (
            challenge.challenged_score if challenge.challenger_id == user.id
            else challenge.challenger_score
        ),
        'is_my_turn': is_my_turn,
        'turn_player_name': (
            challenge.challenger.get_full_name().strip()
            or challenge.challenger.username
            if challenge.challenger_turn
            else challenge.challenged.get_full_name().strip()
            or challenge.challenged.username
        ),
        'opponent_live_state': opponent_live_state,
        'round_number': challenge.round_number,
        'round_duration_seconds': GAME_CHALLENGE_ROUND_DURATIONS_SECONDS[
            min(max(challenge.round_number - 1, 0), 2)
        ],
        'my_round_complete': (
            challenge.challenger_round_complete
            if challenge.challenger_id == user.id
            else challenge.challenged_round_complete
        ),
        'opponent_round_complete': (
            challenge.challenged_round_complete
            if challenge.challenger_id == user.id
            else challenge.challenger_round_complete
        ),
        'winner_id': challenge.winner_id,
        'winner_name': winner_name,
        'winner_by_score': challenge.winner_by_score,
        'duel_reward': (
            {
                'title': challenge.duel_reward.title,
                'description': challenge.duel_reward.description,
                'type': challenge.duel_reward.reward_type,
                'color': challenge.duel_reward.color,
                'sequence': challenge.duel_reward.sequence,
            }
            if hasattr(challenge, 'duel_reward')
            else None
        ),
        'can_request_rematch': (
            challenge.status == GameChallenge.COMPLETED
            and loser_id == user.id
            and rematches_used < 3
            and _can_game_duel_challenge(user.id, (
                challenge.challenged_id
                if challenge.challenger_id == user.id
                else challenge.challenger_id
            ))
        ),
        'rematches_used': rematches_used,
        'my_won': (
            challenge.winner_id == user.id
            if challenge.status == GameChallenge.COMPLETED
            and challenge.winner_id is not None
            else None
        ),
        'loser_id': loser_id,
        'is_incoming': challenge.challenged_id == user.id,
        'my_title': _game_reward_title(my_reward) if my_reward else None,
        'my_medal': my_reward.duel_medal if my_reward else None,
        'my_medals': my_reward.earned_duel_medals if my_reward else [],
        'opponent_title': (
            _game_reward_title(opponent_reward) if opponent_reward else None
        ),
        'opponent_medal': (
            opponent_reward.duel_medal if opponent_reward else None
        ),
        'opponent_medals': (
            opponent_reward.earned_duel_medals if opponent_reward else []
        ),
        'my_ready': (
            challenge.challenger_ready_at is not None
            if challenge.challenger_id == user.id
            else challenge.challenged_ready_at is not None
        ),
        'opponent_ready': (
            challenge.challenged_ready_at is not None
            if challenge.challenger_id == user.id
            else challenge.challenger_ready_at is not None
        ),
        'started_at': challenge.started_at,
        'starts_in_milliseconds': (
            int(start_delay.total_seconds() * 1000)
            if start_delay is not None
            else None
        ),
        'tournament_match_id': challenge.tournament_match_id,
    }


def _expire_game_challenges():
    now = timezone.now()
    expired_pending = GameChallenge.objects.filter(
        status=GameChallenge.PENDING,
        expires_at__lte=now,
        tournament_match__isnull=True,
    ).update(status=GameChallenge.EXPIRED, updated_at=now)
    expired_accepted = GameChallenge.objects.filter(
        status=GameChallenge.ACCEPTED,
        expires_at__lte=now,
        started_at__isnull=True,
        tournament_match__isnull=True,
    ).update(status=GameChallenge.EXPIRED, updated_at=now)
    return expired_pending + expired_accepted


def _user_has_active_game_challenge(user_id, *, exclude_id=None):
    challenges = GameChallenge.objects.filter(
        Q(challenger_id=user_id) | Q(challenged_id=user_id),
        status__in=(GameChallenge.ACCEPTED, GameChallenge.PLAYING),
    )
    if exclude_id is not None:
        challenges = challenges.exclude(pk=exclude_id)
    return challenges.exists()


def _is_champion_league_pro(user_id):
    return GameReward.objects.filter(
        user_id=user_id,
        duel_medal='cup_pro',
    ).exists()


def _tournament_match_data(match):
    challenge = match.challenge
    return {
        'id': match.id,
        'round': match.round_type,
        'group_number': match.group_number,
        'match_number': match.match_number,
        'status': match.status,
        'player_a': {
            'id': match.player_a_id,
            'name': match.player_a.get_full_name().strip() or match.player_a.username,
        },
        'player_b': {
            'id': match.player_b_id,
            'name': match.player_b.get_full_name().strip() or match.player_b.username,
        },
        'winner_id': match.winner_id,
        'challenge_id': challenge.id if challenge else None,
        'scores': (
            {
                str(challenge.challenger_id): challenge.challenger_score,
                str(challenge.challenged_id): challenge.challenged_score,
            }
            if challenge
            else None
        ),
    }


def _tournament_standings(tournament, group_number):
    entries = list(
        tournament.entries.filter(
            status=GameTournamentEntry.CONFIRMED,
            group_number=group_number,
        ).select_related('user')
    )
    stats = {
        entry.user_id: {
            'entry': entry,
            'played': 0,
            'points': 0,
            'wins': 0,
            'score_for': 0,
            'score_against': 0,
        }
        for entry in entries
    }
    matches = tournament.matches.filter(
        round_type=GameTournamentMatch.GROUP,
        group_number=group_number,
        status=GameTournamentMatch.COMPLETED,
    ).select_related('challenge')
    for match in matches:
        left, right = stats[match.player_a_id], stats[match.player_b_id]
        left['played'] += 1
        right['played'] += 1
        challenge = match.challenge
        if challenge and challenge.challenger_score is not None:
            scores = {
                challenge.challenger_id: challenge.challenger_score,
                challenge.challenged_id: challenge.challenged_score,
            }
            left['score_for'] += scores[match.player_a_id]
            left['score_against'] += scores[match.player_b_id]
            right['score_for'] += scores[match.player_b_id]
            right['score_against'] += scores[match.player_a_id]
        if match.winner_id:
            stats[match.winner_id]['points'] += 3
            stats[match.winner_id]['wins'] += 1
        else:
            left['points'] += 1
            right['points'] += 1
    return sorted(
        stats.values(),
        key=lambda item: (
            -item['points'],
            -(item['score_for'] - item['score_against']),
            -item['score_for'],
            item['entry'].joined_at or item['entry'].created_at,
            item['entry'].user_id,
        ),
    )


def _create_tournament_fixture(
    tournament,
    round_type,
    player_a_id,
    player_b_id,
    *,
    group_number=None,
    match_number=None,
):
    if match_number is None:
        match_number = tournament.matches.filter(
            round_type=round_type,
        ).count() + 1
    return GameTournamentMatch.objects.create(
        tournament=tournament,
        round_type=round_type,
        group_number=group_number,
        match_number=match_number,
        player_a_id=player_a_id,
        player_b_id=player_b_id,
    )


def _latest_tournament_matches(matches):
    latest_by_players = {}
    for match in matches.order_by('match_number', 'id'):
        player_pair = tuple(sorted((match.player_a_id, match.player_b_id)))
        latest_by_players[player_pair] = match
    return sorted(
        latest_by_players.values(),
        key=lambda match: (match.match_number, match.id),
    )


def _advance_game_tournament(tournament):
    current_round = {
        GameTournament.GROUPS: GameTournamentMatch.GROUP,
        GameTournament.QUARTERFINALS: GameTournamentMatch.QUARTERFINAL,
        GameTournament.SEMIFINALS: GameTournamentMatch.SEMIFINAL,
        GameTournament.FINAL: GameTournamentMatch.FINAL,
    }.get(tournament.status)
    if not current_round:
        return
    matches = tournament.matches.filter(round_type=current_round)
    if not matches.exists() or matches.exclude(
        status=GameTournamentMatch.COMPLETED,
    ).exists():
        return
    decisive_matches = _latest_tournament_matches(matches)

    if current_round == GameTournamentMatch.GROUP:
        group_count = tournament.capacity // 3
        qualifiers = []
        for group_number in range(1, group_count + 1):
            standings = _tournament_standings(tournament, group_number)
            qualifiers.extend(
                item['entry'].user_id for item in standings[:2]
            )
        if tournament.capacity == 6:
            tournament.status = GameTournament.SEMIFINALS
            round_type = GameTournamentMatch.SEMIFINAL
        else:
            tournament.status = GameTournament.QUARTERFINALS
            round_type = GameTournamentMatch.QUARTERFINAL
            # Each group winner meets the runner-up from the next group.
            winners = []
            runners_up = []
            for group_number in range(1, group_count + 1):
                standings = _tournament_standings(tournament, group_number)
                winners.append(standings[0]['entry'].user_id)
                runners_up.append(standings[1]['entry'].user_id)
            for index, winner_id in enumerate(winners):
                _create_tournament_fixture(
                    tournament,
                    round_type,
                    winner_id,
                    runners_up[(index + 1) % group_count],
                )
            tournament.save(update_fields=('status', 'updated_at'))
            return
        pairings = [(qualifiers[0], qualifiers[3]), (qualifiers[1], qualifiers[2])]
    elif current_round == GameTournamentMatch.QUARTERFINAL:
        winners = [match.winner_id for match in decisive_matches]
        if any(winner_id is None for winner_id in winners):
            return
        tournament.status = GameTournament.SEMIFINALS
        pairings = [(winners[0], winners[1]), (winners[2], winners[3])]
        round_type = GameTournamentMatch.SEMIFINAL
    elif current_round == GameTournamentMatch.SEMIFINAL:
        winners = [match.winner_id for match in decisive_matches]
        if any(winner_id is None for winner_id in winners):
            return
        tournament.status = GameTournament.FINAL
        pairings = [(winners[0], winners[1])]
        round_type = GameTournamentMatch.FINAL
    else:
        final = decisive_matches[-1] if decisive_matches else None
        if final and final.winner_id:
            tournament.status = GameTournament.COMPLETED
            tournament.winner_id = final.winner_id
            tournament.trophy_title = (
                'Champion FopCam Pro'
                if tournament.capacity == 6
                else 'Champion FopCam Roi'
            )
            tournament.completed_at = timezone.now()
            tournament.save(
                update_fields=(
                    'status',
                    'winner',
                    'trophy_title',
                    'completed_at',
                    'updated_at',
                )
            )
        return

    for player_a_id, player_b_id in pairings:
        _create_tournament_fixture(
            tournament,
            round_type,
            player_a_id,
            player_b_id,
        )
    tournament.save(update_fields=('status', 'updated_at'))


def _complete_game_tournament_fixture(challenge):
    match = GameTournamentMatch.objects.filter(
        challenge=challenge,
    ).select_related('tournament').first()
    if not match:
        return
    match.status = GameTournamentMatch.COMPLETED
    match.winner_id = challenge.winner_id
    match.save(update_fields=('status', 'winner', 'updated_at'))
    tournament = match.tournament
    if (
        challenge.winner_id is None
        and match.round_type != GameTournamentMatch.GROUP
    ):
        _create_tournament_fixture(
            tournament,
            match.round_type,
            match.player_a_id,
            match.player_b_id,
            match_number=match.match_number,
        )
        return
    _advance_game_tournament(tournament)


def _game_tournament_data(request, tournament):
    entries = list(
        tournament.entries.select_related('user').order_by(
            'group_number',
            'joined_at',
            'created_at',
        )
    )
    entry_data = [
        {
            'user_id': entry.user_id,
            'name': entry.user.get_full_name().strip() or entry.user.username,
            'username': entry.user.username,
            'status': entry.status,
            'group_number': entry.group_number,
            'is_me': entry.user_id == request.user.id,
        }
        for entry in entries
    ]
    matches = list(
        tournament.matches.select_related(
            'player_a',
            'player_b',
            'challenge',
        )
    )
    support_counts = {}
    my_support = None
    viewer_entry = next(
        (entry for entry in entries if entry.user_id == request.user.id),
        None,
    )
    supporters_by_player = {}
    for vote in tournament.support_votes.select_related('supporter'):
        support_counts[vote.participant_id] = (
            support_counts.get(vote.participant_id, 0) + 1
        )
        if vote.supporter_id == request.user.id:
            my_support = vote.participant_id
        supporters_by_player.setdefault(str(vote.participant_id), []).append(
            vote.supporter.get_full_name().strip() or vote.supporter.username,
        )
    standings = []
    if tournament.status != GameTournament.REGISTRATION:
        for group_number in range(1, tournament.capacity // 3 + 1):
            for position, row in enumerate(
                _tournament_standings(tournament, group_number),
                start=1,
            ):
                standings.append(
                    {
                        'group_number': group_number,
                        'position': position,
                        'user_id': row['entry'].user_id,
                        'name': (
                            row['entry'].user.get_full_name().strip()
                            or row['entry'].user.username
                        ),
                        'played': row['played'],
                        'wins': row['wins'],
                        'points': row['points'],
                        'score_for': row['score_for'],
                        'score_against': row['score_against'],
                    }
                )
    return {
        'id': tournament.id,
        'organizer_id': tournament.organizer_id,
        'organizer_name': (
            tournament.organizer.get_full_name().strip()
            or tournament.organizer.username
        ),
        'capacity': tournament.capacity,
        'status': tournament.status,
        'trophy_title': tournament.trophy_title,
        'winner_id': tournament.winner_id,
        'created_at': tournament.created_at,
        'started_at': tournament.started_at,
        'completed_at': tournament.completed_at,
        'entries': entry_data,
        'matches': [_tournament_match_data(match) for match in matches],
        'standings': standings,
        'support_counts': {
            str(user_id): count for user_id, count in support_counts.items()
        },
        'supporters': supporters_by_player,
        'my_supported_user_id': my_support,
        'is_champion_pro': _is_champion_league_pro(request.user.id),
        'is_organizer': tournament.organizer_id == request.user.id,
        'can_join': (
            tournament.status == GameTournament.REGISTRATION
            and _is_champion_league_pro(request.user.id)
            and (
                viewer_entry is None
                or viewer_entry.status == GameTournamentEntry.INVITED
            )
            and (
                viewer_entry is not None
                or len(entry_data) < tournament.capacity
            )
        ),
        'can_start': (
            tournament.organizer_id == request.user.id
            and tournament.status == GameTournament.REGISTRATION
            and sum(
                entry['status'] == GameTournamentEntry.CONFIRMED
                for entry in entry_data
            ) == tournament.capacity
        ),
    }


class GameChallengeCreateSerializer(serializers.Serializer):
    legend_id = serializers.IntegerField(min_value=1)


class GameChallengeResponseSerializer(serializers.Serializer):
    accept = serializers.BooleanField()


class GameTournamentCreateSerializer(serializers.Serializer):
    capacity = serializers.ChoiceField(choices=(6, 12))
    invited_ids = serializers.ListField(
        child=serializers.IntegerField(min_value=1),
        required=False,
        allow_empty=True,
    )

    def validate_invited_ids(self, value):
        if len(value) != len(set(value)):
            raise serializers.ValidationError('Un joueur ne peut être invité qu’une fois.')
        return value


class GameTournamentInviteSerializer(serializers.Serializer):
    user_ids = serializers.ListField(
        child=serializers.IntegerField(min_value=1),
        allow_empty=False,
    )

    def validate_user_ids(self, value):
        if len(value) != len(set(value)):
            raise serializers.ValidationError('Un joueur ne peut être invité qu’une fois.')
        return value


class GameTournamentSupportSerializer(serializers.Serializer):
    participant_id = serializers.IntegerField(min_value=1)


class GameChallengeEliminationSerializer(serializers.Serializer):
    score = serializers.IntegerField(min_value=0)


class GameChallengeRoundSerializer(serializers.Serializer):
    round_number = serializers.IntegerField(min_value=1, max_value=3)
    score = serializers.IntegerField(min_value=0)


class GameChallengeLiveObjectSerializer(serializers.Serializer):
    id = serializers.IntegerField(required=False, min_value=0, max_value=2147483647)
    x = serializers.FloatField(min_value=0, max_value=1)
    y = serializers.FloatField(min_value=0, max_value=1)
    type = serializers.ChoiceField(
        choices=(
            'bird',
            'obstacle',
            'shield',
            'bonus',
            'reward',
            'trap',
            'reward_bird',
            'trap_bird',
        ),
    )
    direction = serializers.FloatField(min_value=-1, max_value=1, required=False)


class GameChallengeLiveEventSerializer(serializers.Serializer):
    id = serializers.IntegerField(min_value=1, max_value=2147483647)
    x = serializers.FloatField(min_value=0, max_value=1)
    y = serializers.FloatField(min_value=0, max_value=1)
    type = serializers.ChoiceField(
        choices=(
            'collision',
            'dodge',
            'shield_pickup',
            'bonus_pickup',
            'reward_pickup',
            'trap_pickup',
        ),
    )


class GameChallengeLiveStateSerializer(serializers.Serializer):
    round_number = serializers.IntegerField(min_value=1, max_value=3)
    score = serializers.IntegerField(min_value=0, max_value=1000000)
    remaining_seconds = serializers.FloatField(min_value=0, max_value=50)
    player_x = serializers.FloatField(min_value=0, max_value=1)
    player_y = serializers.FloatField(min_value=0, max_value=1)
    player_target_x = serializers.FloatField(
        min_value=0,
        max_value=1,
        required=False,
    )
    player_target_y = serializers.FloatField(
        min_value=0,
        max_value=1,
        required=False,
    )
    shield_active = serializers.BooleanField(required=False)
    score_multiplier = serializers.FloatField(
        min_value=1,
        max_value=2,
        required=False,
    )
    events = serializers.ListField(
        child=GameChallengeLiveEventSerializer(),
        max_length=8,
        required=False,
    )
    objects = serializers.ListField(
        child=GameChallengeLiveObjectSerializer(),
        max_length=60,
    )


def _award_game_challenge_winner(challenge):
    winner = challenge.winner
    if winner is None:
        return

    winner = User.objects.select_for_update().get(pk=winner.pk)
    reward = GameReward.objects.select_for_update().get(user=winner)
    opponents = set()
    for challenger_id, challenged_id in GameChallenge.objects.filter(
        winner=winner,
        status=GameChallenge.COMPLETED,
    ).values_list('challenger_id', 'challenged_id'):
        opponents.add(
            challenged_id if challenger_id == winner.id else challenger_id
        )

    if len(opponents) >= 5:
        reward.duel_medal = 'cup_pro'
        reward.title = 'Champion League Pro'
    elif len(opponents) == 4:
        reward.duel_medal = 'cup'
        reward.title = 'Champion 1ère Ligue'
    elif len(opponents) == 3:
        reward.duel_medal = 'gold'
        reward.title = 'Champion FopCam'
    elif len(opponents) == 2:
        reward.duel_medal = 'silver'
        if reward.title not in (
            'Champion FopCam',
            'Champion 1ère Ligue',
            'Champion League Pro',
        ):
            display_name = winner.first_name.strip() or winner.username
            reward.title = f'Légende + · {display_name}'
    elif len(opponents) == 1:
        reward.duel_medal = 'bronze'
        if reward.title not in (
            'Champion FopCam',
            'Champion 1ère Ligue',
            'Champion League Pro',
        ):
            display_name = winner.first_name.strip() or winner.username
            reward.title = f'Légende + · {display_name}'
    if reward.duel_medal != 'none':
        earned_medals = list(reward.earned_duel_medals or [])
        if reward.duel_medal not in earned_medals:
            earned_medals.append(reward.duel_medal)
        reward.earned_duel_medals = earned_medals
    reward.save(
        update_fields=(
            'duel_medal',
            'earned_duel_medals',
            'title',
            'updated_at',
        ),
    )

    if challenge.rematch_of_id:
        sequence = (
            GameDuelReward.objects.filter(user=winner).count() + 1
        )
        reward_styles = (
            ('Flamme de revanche', 'flame', '#EF4444'),
            ('Éclat du champion', 'star', '#F59E0B'),
            ('Aile de légende', 'wing', '#38BDF8'),
            ('Bouclier invincible', 'shield', '#8B5CF6'),
            ('Couronne de victoire', 'crown', '#FACC15'),
            ('Étoile du duel', 'duel_star', '#34D399'),
        )
        title, reward_type, color = reward_styles[(sequence - 1) % len(reward_styles)]
        GameDuelReward.objects.get_or_create(
            challenge=challenge,
            defaults={
                'user': winner,
                'sequence': sequence,
                'title': f'{title} n°{sequence}',
                'description': (
                    f'Récompense personnalisée remportée par '
                    f'{winner.get_full_name().strip() or winner.username} '
                    'après une victoire en duel de revanche.'
                ),
                'reward_type': reward_type,
                'color': color,
            },
        )

class GameLegendsView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request):
        rewards = GameReward.objects.select_related('user').order_by('-score', 'created_at')
        return Response([
            {
                **_game_legend_data(request, reward.user, reward),
                'rank': rank,
            }
            for rank, reward in enumerate(rewards, start=1)
        ])


class GameTournamentsView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request):
        tournaments = GameTournament.objects.select_related(
            'organizer',
            'winner',
        ).prefetch_related(
            'entries__user',
            'support_votes',
        )[:100]
        return Response([
            _game_tournament_data(request, tournament)
            for tournament in tournaments
        ])

    def post(self, request):
        if not _is_champion_league_pro(request.user.id):
            return Response(
                {'detail': 'Seuls les Champions League Pro peuvent organiser un championnat.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        serializer = GameTournamentCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        capacity = serializer.validated_data['capacity']
        invited_ids = serializer.validated_data.get('invited_ids', [])
        invited_ids = [user_id for user_id in invited_ids if user_id != request.user.id]
        if len(invited_ids) > capacity - 1:
            return Response(
                {'detail': 'Le nombre d’invitations dépasse les places disponibles.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        qualified_ids = set(
            GameReward.objects.filter(
                user_id__in=invited_ids,
                duel_medal='cup_pro',
            ).values_list('user_id', flat=True)
        )
        if qualified_ids != set(invited_ids):
            return Response(
                {'detail': 'Tous les participants invités doivent être Champion League Pro.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        with transaction.atomic():
            tournament = GameTournament.objects.create(
                organizer=request.user,
                capacity=capacity,
            )
            GameTournamentEntry.objects.create(
                tournament=tournament,
                user=request.user,
                status=GameTournamentEntry.CONFIRMED,
                joined_at=timezone.now(),
            )
            for user_id in invited_ids:
                GameTournamentEntry.objects.create(
                    tournament=tournament,
                    user_id=user_id,
                    status=GameTournamentEntry.INVITED,
                )
                Notification.objects.create(
                    user_id=user_id,
                    title='Invitation au championnat',
                    message=(
                        f'{request.user.get_full_name().strip() or request.user.username} '
                        f'vous invite à un championnat de {capacity} joueurs.'
                    ),
                    type='game_tournament',
                    data={'tournament_id': tournament.id},
                )
        return Response(
            _game_tournament_data(request, tournament),
            status=status.HTTP_201_CREATED,
        )


class GameTournamentDetailView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request, tournament_id):
        tournament = get_object_or_404(
            GameTournament.objects.select_related('organizer', 'winner')
            .prefetch_related('entries__user', 'support_votes'),
            pk=tournament_id,
        )
        return Response(_game_tournament_data(request, tournament))


class GameTournamentJoinView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, tournament_id):
        if not _is_champion_league_pro(request.user.id):
            return Response(
                {'detail': 'Seuls les Champions League Pro peuvent participer.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        with transaction.atomic():
            tournament = get_object_or_404(
                GameTournament.objects.select_for_update(),
                pk=tournament_id,
            )
            if tournament.status != GameTournament.REGISTRATION:
                return Response(
                    {'detail': 'Les inscriptions à ce championnat sont terminées.'},
                    status=status.HTTP_409_CONFLICT,
                )
            entry = GameTournamentEntry.objects.filter(
                tournament=tournament,
                user=request.user,
            ).first()
            if entry:
                if entry.status == GameTournamentEntry.CONFIRMED:
                    return Response(
                        {'detail': 'Tu es déjà inscrit à ce championnat.'},
                        status=status.HTTP_409_CONFLICT,
                    )
                entry.status = GameTournamentEntry.CONFIRMED
                entry.joined_at = timezone.now()
                entry.save(update_fields=('status', 'joined_at', 'updated_at'))
            else:
                if tournament.entries.count() >= tournament.capacity:
                    return Response(
                        {'detail': 'Il n’y a plus de place disponible.'},
                        status=status.HTTP_409_CONFLICT,
                    )
                GameTournamentEntry.objects.create(
                    tournament=tournament,
                    user=request.user,
                    status=GameTournamentEntry.CONFIRMED,
                    joined_at=timezone.now(),
                )
            Notification.objects.create(
                user=tournament.organizer,
                title='Nouvelle inscription au championnat',
                message=(
                    f'{request.user.get_full_name().strip() or request.user.username} '
                    'a rejoint ton championnat.'
                ),
                type='game_tournament',
                data={'tournament_id': tournament.id},
            )
        return Response(_game_tournament_data(request, tournament))


class GameTournamentInviteView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, tournament_id):
        serializer = GameTournamentInviteSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user_ids = serializer.validated_data['user_ids']
        if request.user.id in user_ids:
            return Response(
                {'detail': 'Tu es déjà inscrit en tant qu’organisateur.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        qualified_ids = set(
            GameReward.objects.filter(
                user_id__in=user_ids,
                duel_medal='cup_pro',
            ).values_list('user_id', flat=True)
        )
        if qualified_ids != set(user_ids):
            return Response(
                {'detail': 'Tous les joueurs invités doivent être Champion League Pro.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        with transaction.atomic():
            tournament = get_object_or_404(
                GameTournament.objects.select_for_update(),
                pk=tournament_id,
            )
            if tournament.organizer_id != request.user.id:
                return Response(
                    {'detail': 'Seul l’organisateur peut inviter des joueurs.'},
                    status=status.HTTP_403_FORBIDDEN,
                )
            if tournament.status != GameTournament.REGISTRATION:
                return Response(
                    {'detail': 'Les inscriptions sont terminées.'},
                    status=status.HTTP_409_CONFLICT,
                )
            existing_ids = set(
                tournament.entries.values_list('user_id', flat=True)
            )
            new_ids = [user_id for user_id in user_ids if user_id not in existing_ids]
            free_places = tournament.capacity - tournament.entries.count()
            if len(new_ids) > free_places:
                return Response(
                    {'detail': 'Il n’y a pas assez de places libres.'},
                    status=status.HTTP_409_CONFLICT,
                )
            for user_id in new_ids:
                GameTournamentEntry.objects.create(
                    tournament=tournament,
                    user_id=user_id,
                    status=GameTournamentEntry.INVITED,
                )
                Notification.objects.create(
                    user_id=user_id,
                    title='Invitation au championnat',
                    message=(
                        f'{request.user.get_full_name().strip() or request.user.username} '
                        f'vous invite à un championnat de {tournament.capacity} joueurs.'
                    ),
                    type='game_tournament',
                    data={'tournament_id': tournament.id},
                )
        return Response(_game_tournament_data(request, tournament))


class GameTournamentStartView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, tournament_id):
        with transaction.atomic():
            tournament = get_object_or_404(
                GameTournament.objects.select_for_update(),
                pk=tournament_id,
            )
            if tournament.organizer_id != request.user.id:
                return Response(
                    {'detail': 'Seul l’organisateur peut démarrer le championnat.'},
                    status=status.HTTP_403_FORBIDDEN,
                )
            if tournament.status != GameTournament.REGISTRATION:
                return Response(
                    {'detail': 'Ce championnat a déjà démarré.'},
                    status=status.HTTP_409_CONFLICT,
                )
            entries = list(
                tournament.entries.filter(
                    status=GameTournamentEntry.CONFIRMED,
                ).select_related('user').order_by('joined_at', 'id')
            )
            if len(entries) != tournament.capacity:
                return Response(
                    {'detail': f'Il faut {tournament.capacity} joueurs inscrits pour démarrer.'},
                    status=status.HTTP_409_CONFLICT,
                )
            import random
            random.SystemRandom().shuffle(entries)
            for index, entry in enumerate(entries):
                entry.group_number = index // 3 + 1
                entry.save(update_fields=('group_number', 'updated_at'))
            for group_number in range(1, tournament.capacity // 3 + 1):
                group_players = [
                    entry.user_id
                    for entry in entries
                    if entry.group_number == group_number
                ]
                for left_index, player_a_id in enumerate(group_players):
                    for player_b_id in group_players[left_index + 1:]:
                        _create_tournament_fixture(
                            tournament,
                            GameTournamentMatch.GROUP,
                            player_a_id,
                            player_b_id,
                            group_number=group_number,
                        )
            tournament.status = GameTournament.GROUPS
            tournament.started_at = timezone.now()
            tournament.save(update_fields=('status', 'started_at', 'updated_at'))
        return Response(_game_tournament_data(request, tournament))


class GameTournamentSupportView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, tournament_id):
        serializer = GameTournamentSupportSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        tournament = get_object_or_404(GameTournament, pk=tournament_id)
        participant_id = serializer.validated_data['participant_id']
        if tournament.status in (GameTournament.REGISTRATION, GameTournament.COMPLETED):
            return Response(
                {'detail': 'Le soutien est ouvert pendant les phases de jeu.'},
                status=status.HTTP_409_CONFLICT,
            )
        if tournament.entries.filter(user=request.user).exists():
            return Response(
                {'detail': 'Les participants ne peuvent pas voter comme spectateurs.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        if not tournament.entries.filter(
            user_id=participant_id,
            status=GameTournamentEntry.CONFIRMED,
        ).exists():
            return Response(
                {'detail': 'Ce joueur ne participe pas à ce championnat.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        GameTournamentSupport.objects.update_or_create(
            tournament=tournament,
            supporter=request.user,
            defaults={'participant_id': participant_id},
        )
        return Response(_game_tournament_data(request, tournament))


class GameTournamentMatchPlayView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, tournament_id, match_id):
        with transaction.atomic():
            match = get_object_or_404(
                GameTournamentMatch.objects.select_for_update().select_related(
                    'tournament',
                    'player_a',
                    'player_b',
                ),
                pk=match_id,
                tournament_id=tournament_id,
            )
            if request.user.id not in (match.player_a_id, match.player_b_id):
                return Response(
                    {'detail': 'Seuls les deux joueurs du match peuvent le démarrer.'},
                    status=status.HTTP_403_FORBIDDEN,
                )
            list(
                User.objects.select_for_update()
                .filter(pk__in=(match.player_a_id, match.player_b_id))
                .order_by('pk')
            )
            if match.status != GameTournamentMatch.SCHEDULED:
                return Response(
                    {'detail': 'Ce match a déjà commencé ou est terminé.'},
                    status=status.HTTP_409_CONFLICT,
                )
            if _user_has_active_game_challenge(match.player_a_id) or _user_has_active_game_challenge(match.player_b_id):
                return Response(
                    {'detail': 'Un des joueurs dispute déjà un duel. Le match reste à jouer.'},
                    status=status.HTTP_409_CONFLICT,
                )
            challenge = GameChallenge.objects.create(
                challenger=match.player_a,
                challenged=match.player_b,
                status=GameChallenge.ACCEPTED,
                tournament_match=match,
            )
            match.challenge = challenge
            match.status = GameTournamentMatch.PLAYING
            match.save(update_fields=('challenge', 'status', 'updated_at'))
        return Response(_game_challenge_data(request, challenge), status=status.HTTP_201_CREATED)


class GameChallengesView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request):
        _expire_game_challenges()
        challenges = GameChallenge.objects.filter(
            Q(challenger=request.user) | Q(challenged=request.user)
        ).exclude(
            status=GameChallenge.EXPIRED,
        ).select_related(
            'challenger',
            'challenged',
            'winner',
        )
        return Response([_game_challenge_data(request, item) for item in challenges])

    def post(self, request):
        _expire_game_challenges()
        serializer = GameChallengeCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        legend_id = serializer.validated_data['legend_id']
        challenger_rank = _game_duel_tier_rank(request.user.id)
        if challenger_rank is None:
            return Response(
                {'detail': 'Seules les légendes peuvent envoyer des défis.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        if legend_id == request.user.id:
            return Response(
                {'detail': 'Tu ne peux pas te défier toi-même.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        challenged_rank = _game_duel_tier_rank(legend_id)
        if challenged_rank is None:
            return Response(
                {'detail': 'Ce joueur n’a pas encore atteint le rang de légende.'},
                status=status.HTTP_404_NOT_FOUND,
            )
        if challenger_rank < challenged_rank:
            return Response(
                {
                    'detail': (
                        'Tu peux défier une légende de ton niveau ou d’un '
                        'niveau inférieur.'
                    )
                },
                status=status.HTTP_400_BAD_REQUEST,
            )

        open_challenge = GameChallenge.objects.filter(
            status__in=(
                GameChallenge.PENDING,
                GameChallenge.ACCEPTED,
                GameChallenge.PLAYING,
            )
        ).filter(
            (Q(challenger=request.user, challenged_id=legend_id) |
             Q(challenger_id=legend_id, challenged=request.user))
        ).exists()
        if open_challenge:
            return Response(
                {'detail': 'Un défi entre ces deux légendes est déjà en cours.'},
                status=status.HTTP_409_CONFLICT,
            )

        challenge = GameChallenge.objects.create(
            challenger=request.user,
            challenged_id=legend_id,
        )
        Notification.objects.create(
            user_id=legend_id,
            title='Défi légendaire',
            message=(
                f'{request.user.get_full_name().strip() or request.user.username} '
                'vous invite à un duel de légendes.'
            ),
            type='game_challenge',
            data={
                'challenge_id': challenge.id,
                'challenger_id': request.user.id,
            },
        )
        return Response(
            _game_challenge_data(request, challenge),
            status=status.HTTP_201_CREATED,
        )


class GameChallengePendingCountView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request):
        _expire_game_challenges()
        count = GameChallenge.objects.filter(
            challenged=request.user,
            status=GameChallenge.PENDING,
        ).count()
        return Response({'count': count})


class GameChallengeCancelView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    @transaction.atomic
    def post(self, request, challenge_id):
        _expire_game_challenges()
        challenge = get_object_or_404(
            GameChallenge.objects.select_for_update(of=('self',)).select_related(
                'challenger',
                'challenged',
                'winner',
            ),
            pk=challenge_id,
        )
        if request.user.id not in (
            challenge.challenger_id,
            challenge.challenged_id,
        ):
            return Response(
                {'detail': 'Seul un participant à ce défi peut l’annuler.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        if challenge.tournament_match_id is not None:
            return Response(
                {'detail': 'Un défi de championnat ne peut pas être annulé ici.'},
                status=status.HTTP_409_CONFLICT,
            )
        if challenge.status != GameChallenge.PENDING:
            return Response(
                {'detail': 'Seul un défi en attente peut être annulé.'},
                status=status.HTTP_409_CONFLICT,
            )

        challenge.status = GameChallenge.CANCELLED
        challenge.save(update_fields=('status', 'updated_at'))
        opponent = (
            challenge.challenged
            if challenge.challenger_id == request.user.id
            else challenge.challenger
        )
        Notification.objects.create(
            user=opponent,
            title='Défi annulé',
            message=(
                f'{request.user.get_full_name().strip() or request.user.username} '
                'a annulé son invitation de duel.'
            ),
            type='game_challenge_cancelled',
            data={'challenge_id': challenge.id},
        )
        return Response(_game_challenge_data(request, challenge))


class GameChallengeDismissView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def delete(self, request, challenge_id):
        challenge = get_object_or_404(
            GameChallenge.objects.select_related(
                'challenger',
                'challenged',
                'winner',
            ),
            pk=challenge_id,
        )
        if request.user.id not in (challenge.challenger_id, challenge.challenged_id):
            return Response(
                {'detail': 'Tu ne participes pas à ce défi.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        if challenge.tournament_match_id is not None:
            return Response(
                {'detail': 'Un défi de championnat ne peut pas être supprimé ici.'},
                status=status.HTTP_409_CONFLICT,
            )
        if challenge.status not in (
            GameChallenge.DECLINED,
            GameChallenge.CANCELLED,
        ):
            return Response(
                {'detail': 'Seuls les défis annulés ou refusés peuvent être supprimés.'},
                status=status.HTTP_409_CONFLICT,
            )

        challenge.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class GameChallengeResponseView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    @transaction.atomic
    def post(self, request, challenge_id):
        _expire_game_challenges()
        serializer = GameChallengeResponseSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        challenge = get_object_or_404(
            GameChallenge.objects.select_for_update(of=('self',)).select_related(
                'challenger',
                'challenged',
                'winner',
            ),
            pk=challenge_id,
        )
        if challenge.challenged_id != request.user.id:
            return Response(
                {'detail': 'Seul le joueur invité peut répondre à ce défi.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        list(
            User.objects.select_for_update()
            .filter(pk__in=(challenge.challenger_id, challenge.challenged_id))
            .order_by('pk')
        )
        if challenge.status == GameChallenge.EXPIRED:
            return Response(
                {'detail': 'Cette invitation a expiré après 30 minutes.'},
                status=status.HTTP_410_GONE,
            )
        if challenge.status != GameChallenge.PENDING:
            return Response(
                {'detail': 'Ce défi a déjà reçu une réponse.'},
                status=status.HTTP_409_CONFLICT,
            )
        if challenge.expires_at <= timezone.now():
            challenge.status = GameChallenge.EXPIRED
            challenge.save(update_fields=('status', 'updated_at'))
            return Response(
                {'detail': 'Cette invitation a expiré après 30 minutes.'},
                status=status.HTTP_410_GONE,
            )
        if serializer.validated_data['accept'] and (
            _user_has_active_game_challenge(
                challenge.challenger_id,
                exclude_id=challenge.id,
            )
            or _user_has_active_game_challenge(
                challenge.challenged_id,
                exclude_id=challenge.id,
            )
        ):
            return Response(
                {
                    'detail': (
                        'Termine d’abord ton duel en cours. Cette invitation '
                        'restera dans tes défis en attente.'
                    )
                },
                status=status.HTTP_409_CONFLICT,
            )
        if (
            serializer.validated_data['accept']
            and not _can_game_duel_challenge(
                challenge.challenger_id,
                challenge.challenged_id,
            )
        ):
            return Response(
                {
                    'detail': (
                        'Le challenger doit être du même niveau ou d’un '
                        'niveau supérieur.'
                    )
                },
                status=status.HTTP_409_CONFLICT,
            )

        challenge.status = (
            GameChallenge.ACCEPTED if serializer.validated_data['accept']
            else GameChallenge.DECLINED
        )
        update_fields = ['status', 'updated_at']
        if serializer.validated_data['accept']:
            challenge.expires_at = timezone.now() + timedelta(hours=1)
            update_fields.append('expires_at')
        challenge.save(update_fields=update_fields)
        Notification.objects.create(
            user=challenge.challenger,
            title='Réponse à votre défi',
            message=(
                f'{request.user.get_full_name().strip() or request.user.username} '
                f'a{" accepté" if serializer.validated_data["accept"] else " refusé"} '
                'votre invitation de duel.'
            ),
            type='game_challenge_response',
            data={
                'challenge_id': challenge.id,
                'accepted': serializer.validated_data['accept'],
            },
        )
        return Response(_game_challenge_data(request, challenge))


class GameChallengeReadyView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, challenge_id):
        _expire_game_challenges()
        with transaction.atomic():
            challenge = get_object_or_404(
                GameChallenge.objects.select_for_update().select_related(
                    'challenger', 'challenged'
                ),
                pk=challenge_id,
            )
            if request.user.id not in (
                challenge.challenger_id,
                challenge.challenged_id,
            ):
                return Response(
                    {'detail': 'Tu ne participes pas à ce défi.'},
                    status=status.HTTP_403_FORBIDDEN,
                )
            if challenge.status == GameChallenge.PLAYING:
                return Response(_game_challenge_data(request, challenge))
            if challenge.status == GameChallenge.EXPIRED:
                return Response(
                    {'detail': 'Le délai d’une heure pour démarrer ce duel est expiré.'},
                    status=status.HTTP_410_GONE,
                )
            if challenge.status != GameChallenge.ACCEPTED:
                return Response(
                    {'detail': 'Ce défi n’est pas prêt à démarrer.'},
                    status=status.HTTP_409_CONFLICT,
                )

            now = timezone.now()
            ready_times = (
                challenge.challenger_ready_at,
                challenge.challenged_ready_at,
            )
            if any(
                ready_at is not None
                and ready_at < now - timedelta(minutes=2)
                for ready_at in ready_times
            ):
                challenge.challenger_ready_at = None
                challenge.challenged_ready_at = None

            if request.user.id == challenge.challenger_id:
                if challenge.challenger_ready_at is None:
                    challenge.challenger_ready_at = now
            elif challenge.challenged_ready_at is None:
                challenge.challenged_ready_at = now

            if (
                challenge.challenger_ready_at is not None
                and challenge.challenged_ready_at is not None
            ):
                challenge.status = GameChallenge.PLAYING
                challenge.started_at = now + timedelta(
                    seconds=GAME_CHALLENGE_START_DELAY_SECONDS
                )

            challenge.save(
                update_fields=(
                    'challenger_ready_at',
                    'challenged_ready_at',
                    'status',
                    'started_at',
                    'updated_at',
                )
            )
            challenge.refresh_from_db()
        return Response(_game_challenge_data(request, challenge))


class GameChallengeScoreView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, challenge_id):
        return Response(
            {'detail': 'Utilise la validation de manche pour enregistrer ton score.'},
            status=status.HTTP_409_CONFLICT,
        )


class GameChallengeEliminationView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, challenge_id):
        serializer = GameChallengeEliminationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        score = serializer.validated_data['score']

        with transaction.atomic():
            challenge = get_object_or_404(
                GameChallenge.objects.select_for_update().select_related(
                    'challenger', 'challenged'
                ),
                pk=challenge_id,
            )
            if request.user.id not in (
                challenge.challenger_id,
                challenge.challenged_id,
            ):
                return Response(
                    {'detail': 'Tu ne participes pas à ce défi.'},
                    status=status.HTTP_403_FORBIDDEN,
                )
            if challenge.status == GameChallenge.COMPLETED:
                return Response(_game_challenge_data(request, challenge))
            if (
                challenge.status != GameChallenge.PLAYING
                or challenge.started_at is None
                or timezone.now() < challenge.started_at
            ):
                return Response(
                    {'detail': 'Le duel n’est pas encore commencé.'},
                    status=status.HTTP_409_CONFLICT,
                )

            score_field = (
                'challenger_score'
                if request.user.id == challenge.challenger_id
                else 'challenged_score'
            )
            if (
                (request.user.id == challenge.challenger_id)
                != challenge.challenger_turn
            ):
                return Response(
                    {'detail': 'Ce n’est pas ton tour de jouer.'},
                    status=status.HTTP_409_CONFLICT,
                )
            challenge.status = GameChallenge.COMPLETED
            challenge.winner_by_score = False
            challenge.winner = (
                challenge.challenged
                if request.user.id == challenge.challenger_id
                else challenge.challenger
            )
            setattr(
                challenge,
                score_field,
                (getattr(challenge, score_field) or 0) + score,
            )
            challenge.save(
                update_fields=(
                    'status',
                    'winner',
                    'winner_by_score',
                    score_field,
                    'updated_at',
                )
            )
            _award_game_challenge_winner(challenge)
            _complete_game_tournament_fixture(challenge)
            challenge.refresh_from_db()

        return Response(_game_challenge_data(request, challenge))


class GameChallengeLiveStateView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request, challenge_id):
        challenge = get_object_or_404(
            GameChallenge.objects.select_related(
                'challenger',
                'challenged',
                'winner',
                'rematch_of',
            ),
            pk=challenge_id,
        )
        if request.user.id not in (
            challenge.challenger_id,
            challenge.challenged_id,
        ):
            return Response(
                {'detail': 'Tu ne participes pas à ce défi.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        return Response(_game_challenge_data(request, challenge))

    def post(self, request, challenge_id):
        serializer = GameChallengeLiveStateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        with transaction.atomic():
            challenge = get_object_or_404(
                GameChallenge.objects.select_for_update().select_related(
                    'challenger', 'challenged', 'winner',
                ),
                pk=challenge_id,
            )
            if request.user.id not in (
                challenge.challenger_id,
                challenge.challenged_id,
            ):
                return Response(
                    {'detail': 'Tu ne participes pas à ce défi.'},
                    status=status.HTTP_403_FORBIDDEN,
                )
            is_challenger = request.user.id == challenge.challenger_id
            if (
                challenge.status != GameChallenge.PLAYING
                or is_challenger != challenge.challenger_turn
                or challenge.started_at is None
                or timezone.now() < challenge.started_at
            ):
                return Response(
                    {'detail': 'Tu ne peux pas publier un état hors de ton tour.'},
                    status=status.HTTP_409_CONFLICT,
                )
            state = serializer.validated_data
            if state['round_number'] != challenge.round_number:
                return Response(
                    {'detail': 'Cette manche n’est plus active.'},
                    status=status.HTTP_409_CONFLICT,
                )
            state_field = (
                'challenger_live_state' if is_challenger
                else 'challenged_live_state'
            )
            time_field = (
                'challenger_live_at' if is_challenger
                else 'challenged_live_at'
            )
            setattr(challenge, state_field, state)
            setattr(challenge, time_field, timezone.now())
            challenge.save(update_fields=(state_field, time_field, 'updated_at'))
        return Response(_game_challenge_data(request, challenge))


class GameChallengePublicListView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request):
        challenges = (
            GameChallenge.objects.filter(status=GameChallenge.PLAYING)
            .exclude(
                Q(challenger=request.user) | Q(challenged=request.user)
            )
            .select_related('challenger', 'challenged')
            .order_by('-updated_at')[:30]
        )
        return Response([
            {
                'id': challenge.id,
                'challenger_name': (
                    challenge.challenger.get_full_name().strip()
                    or challenge.challenger.username
                ),
                'challenged_name': (
                    challenge.challenged.get_full_name().strip()
                    or challenge.challenged.username
                ),
                'challenger_score': challenge.challenger_score or 0,
                'challenged_score': challenge.challenged_score or 0,
                'round_number': challenge.round_number,
                'has_live_state': (
                    challenge.challenger_live_state is not None
                    if challenge.challenger_turn
                    else challenge.challenged_live_state is not None
                ),
            }
            for challenge in challenges
        ])


class GameChallengePublicStateView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request, challenge_id):
        challenge = get_object_or_404(
            GameChallenge.objects.select_related('challenger', 'challenged'),
            pk=challenge_id,
        )
        if request.user.id in (
            challenge.challenger_id,
            challenge.challenged_id,
        ):
            return Response(
                {'detail': 'Les joueurs ne peuvent pas suivre leur propre duel.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        if challenge.status != GameChallenge.PLAYING:
            return Response(
                {'detail': 'Duel terminé.'},
                status=status.HTTP_410_GONE,
            )
        is_challenger_turn = challenge.challenger_turn
        raw_state = (
            challenge.challenger_live_state
            if is_challenger_turn
            else challenge.challenged_live_state
        )
        state = None
        if raw_state is not None:
            state = {
                key: raw_state[key]
                for key in (
                    'round_number',
                    'score',
                    'remaining_seconds',
                    'player_x',
                    'player_y',
                    'player_target_x',
                    'player_target_y',
                    'shield_active',
                    'score_multiplier',
                    'objects',
                    'events',
                )
                if key in raw_state
            }
        return Response({
            'id': challenge.id,
            'challenger_name': (
                challenge.challenger.get_full_name().strip()
                or challenge.challenger.username
            ),
            'challenged_name': (
                challenge.challenged.get_full_name().strip()
                or challenge.challenged.username
            ),
            'challenger_score': challenge.challenger_score or 0,
            'challenged_score': challenge.challenged_score or 0,
            'round_number': challenge.round_number,
            'active_player_name': (
                challenge.challenger.get_full_name().strip()
                or challenge.challenger.username
                if is_challenger_turn
                else challenge.challenged.get_full_name().strip()
                or challenge.challenged.username
            ),
            'state': state,
        })


class GameChallengeShareTrophyView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, challenge_id):
        with transaction.atomic():
            challenge = get_object_or_404(
                GameChallenge.objects.select_for_update().select_related(
                    'challenger',
                    'challenged',
                ),
                pk=challenge_id,
            )
            if challenge.status != GameChallenge.COMPLETED:
                return Response(
                    {'detail': 'Le trophée sera disponible à la fin du duel.'},
                    status=status.HTTP_409_CONFLICT,
                )
            if challenge.winner_id != request.user.id:
                return Response(
                    {'detail': 'Seul le vainqueur peut publier ce trophée.'},
                    status=status.HTTP_403_FORBIDDEN,
                )

            existing_post = Post.objects.filter(
                author=request.user,
                trophy_challenge=challenge,
            ).first()
            if existing_post is not None:
                return Response(
                    PostSerializer(existing_post, context={'request': request}).data,
                    status=status.HTTP_200_OK,
                )

            reward = GameReward.objects.filter(user=request.user).first()
            if reward is None or reward.duel_medal == 'none':
                return Response(
                    {'detail': 'Aucun trophée de duel n’est associé à cette victoire.'},
                    status=status.HTTP_409_CONFLICT,
                )

            opponent = (
                challenge.challenged
                if challenge.winner_id == challenge.challenger_id
                else challenge.challenger
            )
            trophy_data = {
                'medal': reward.duel_medal,
                'title': _game_reward_title(reward),
                'opponent': (
                    opponent.get_full_name().strip() or opponent.username
                ),
                'winner_score': (
                    challenge.challenger_score
                    if challenge.winner_id == challenge.challenger_id
                    else challenge.challenged_score
                ),
                'opponent_score': (
                    challenge.challenged_score
                    if challenge.winner_id == challenge.challenger_id
                    else challenge.challenger_score
                ),
            }
            post = Post.objects.create(
                author=request.user,
                content=(
                    f'{trophy_data["title"]} · {trophy_data["medal"].title()}'
                    f' — victoire contre {trophy_data["opponent"]}'
                ),
                post_type='trophy',
                privacy='public',
                trophy_challenge=challenge,
                trophy_data=trophy_data,
            )
        return Response(
            PostSerializer(post, context={'request': request}).data,
            status=status.HTTP_201_CREATED,
        )


class GameChallengeRoundView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, challenge_id):
        serializer = GameChallengeRoundSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        round_number = serializer.validated_data['round_number']
        score = serializer.validated_data['score']

        with transaction.atomic():
            challenge = get_object_or_404(
                GameChallenge.objects.select_for_update().select_related(
                    'challenger', 'challenged'
                ),
                pk=challenge_id,
            )
            if request.user.id not in (
                challenge.challenger_id,
                challenge.challenged_id,
            ):
                return Response(
                    {'detail': 'Tu ne participes pas à ce défi.'},
                    status=status.HTTP_403_FORBIDDEN,
                )
            if challenge.status == GameChallenge.COMPLETED:
                return Response(_game_challenge_data(request, challenge))
            if challenge.status != GameChallenge.PLAYING:
                return Response(
                    {'detail': 'Le duel en direct n’est pas en cours.'},
                    status=status.HTTP_409_CONFLICT,
                )
            if round_number < challenge.round_number:
                return Response(_game_challenge_data(request, challenge))
            if round_number != challenge.round_number:
                return Response(
                    {'detail': 'Cette manche n’est pas encore disponible.'},
                    status=status.HTTP_409_CONFLICT,
                )
            is_challenger = request.user.id == challenge.challenger_id
            complete_field = (
                'challenger_round_complete'
                if is_challenger
                else 'challenged_round_complete'
            )
            if getattr(challenge, complete_field):
                return Response(_game_challenge_data(request, challenge))
            if is_challenger != challenge.challenger_turn:
                return Response(
                    {'detail': 'Ce n’est pas ton tour de jouer.'},
                    status=status.HTTP_409_CONFLICT,
                )
            round_duration = GAME_CHALLENGE_ROUND_DURATIONS_SECONDS[
                round_number - 1
            ]
            if (
                challenge.started_at is None
                or timezone.now()
                < challenge.started_at
                + timedelta(seconds=round_duration - 1)
            ):
                return Response(
                    {'detail': f'La manche de {round_duration} secondes n’est pas terminée.'},
                    status=status.HTTP_409_CONFLICT,
                )

            score_field = (
                'challenger_score' if is_challenger else 'challenged_score'
            )
            setattr(
                challenge,
                score_field,
                (getattr(challenge, score_field) or 0) + score,
            )
            setattr(challenge, complete_field, True)
            challenge.challenger_live_state = None
            challenge.challenged_live_state = None
            challenge.challenger_live_at = None
            challenge.challenged_live_at = None

            update_fields = [
                'challenger_round_complete',
                'challenged_round_complete',
                'challenger_score',
                'challenged_score',
                'challenger_turn',
                'challenger_live_state',
                'challenged_live_state',
                'challenger_live_at',
                'challenged_live_at',
                'status',
                'round_number',
                'started_at',
                'updated_at',
            ]
            if challenge.challenger_round_complete and challenge.challenged_round_complete:
                if challenge.round_number == len(
                    GAME_CHALLENGE_ROUND_DURATIONS_SECONDS
                ):
                    challenge.status = GameChallenge.COMPLETED
                    if challenge.challenger_score > challenge.challenged_score:
                        challenge.winner = challenge.challenger
                        challenge.winner_by_score = True
                    elif challenge.challenged_score > challenge.challenger_score:
                        challenge.winner = challenge.challenged
                        challenge.winner_by_score = True
                else:
                    challenge.round_number += 1
                    challenge.challenger_turn = True
                    challenge.started_at = timezone.now() + timedelta(
                        seconds=GAME_CHALLENGE_ROUND_START_DELAY_SECONDS
                    )
                    challenge.challenger_round_complete = False
                    challenge.challenged_round_complete = False
            else:
                challenge.challenger_turn = not is_challenger
                challenge.started_at = timezone.now() + timedelta(
                    seconds=GAME_CHALLENGE_ROUND_START_DELAY_SECONDS
                )

            if challenge.status == GameChallenge.COMPLETED:
                update_fields.append('winner')
                update_fields.append('winner_by_score')
            challenge.save(update_fields=update_fields)
            if challenge.status == GameChallenge.COMPLETED and challenge.winner_id:
                _award_game_challenge_winner(challenge)
            if challenge.status == GameChallenge.COMPLETED:
                _complete_game_tournament_fixture(challenge)
            challenge.refresh_from_db()

        return Response(_game_challenge_data(request, challenge))


class GameChallengeRematchView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, challenge_id):
        with transaction.atomic():
            challenge = get_object_or_404(
                GameChallenge.objects.select_for_update(of=('self',)).select_related(
                    'challenger',
                    'challenged',
                    'winner',
                    'rematch_of',
                ),
                pk=challenge_id,
            )
            loser_id = (
                challenge.challenged_id
                if challenge.winner_id == challenge.challenger_id
                else challenge.challenger_id
                if challenge.winner_id == challenge.challenged_id
                else None
            )
            if challenge.status != GameChallenge.COMPLETED or loser_id is None:
                return Response(
                    {'detail': 'Une revanche est possible après une défaite.'},
                    status=status.HTTP_409_CONFLICT,
                )
            if request.user.id != loser_id:
                return Response(
                    {'detail': 'Seule la légende vaincue peut demander une revanche.'},
                    status=status.HTTP_403_FORBIDDEN,
                )

            root_challenge = (
                get_object_or_404(
                    GameChallenge.objects.select_for_update(),
                    pk=challenge.rematch_of_id,
                )
                if challenge.rematch_of_id
                else challenge
            )
            rematches_used = GameChallenge.objects.filter(
                rematch_of=root_challenge,
                rematch_requester=request.user,
            ).count()
            if rematches_used >= 3:
                return Response(
                    {'detail': 'Tu as déjà utilisé tes trois demandes de revanche.'},
                    status=status.HTTP_409_CONFLICT,
                )

            opponent_id = (
                challenge.challenged_id
                if challenge.challenger_id == request.user.id
                else challenge.challenger_id
            )
            if not _can_game_duel_challenge(request.user.id, opponent_id):
                return Response(
                    {
                        'detail': (
                            'Une revanche n’est possible que si tu es du même '
                            'niveau ou d’un niveau supérieur à ton adversaire.'
                        )
                    },
                    status=status.HTTP_409_CONFLICT,
                )
            open_challenge = GameChallenge.objects.filter(
                status__in=(
                    GameChallenge.PENDING,
                    GameChallenge.ACCEPTED,
                    GameChallenge.PLAYING,
                )
            ).filter(
                Q(challenger=request.user, challenged_id=opponent_id)
                | Q(challenger_id=opponent_id, challenged=request.user)
            ).exists()
            if open_challenge:
                return Response(
                    {'detail': 'Un défi entre ces deux légendes est déjà en cours.'},
                    status=status.HTTP_409_CONFLICT,
                )

            rematch = GameChallenge.objects.create(
                challenger=request.user,
                challenged_id=opponent_id,
                rematch_of=root_challenge,
                rematch_requester=request.user,
            )
            Notification.objects.create(
                user_id=opponent_id,
                title='Revanche légendaire',
                message=(
                    f'{request.user.get_full_name().strip() or request.user.username} '
                    'vous demande une revanche.'
                ),
                type='game_rematch',
                data={
                    'challenge_id': rematch.id,
                    'rematch_of': root_challenge.id,
                    'requester_id': request.user.id,
                },
            )
        return Response(_game_challenge_data(request, rematch), status=status.HTTP_201_CREATED)


class PasswordResetRequestSerializer(serializers.Serializer):
    channel = serializers.ChoiceField(choices=('email', 'whatsapp'))
    identifier = serializers.CharField(max_length=254, trim_whitespace=True)


class PasswordResetConfirmSerializer(serializers.Serializer):
    channel = serializers.ChoiceField(choices=('email', 'whatsapp'))
    identifier = serializers.CharField(max_length=254, trim_whitespace=True)
    code = serializers.RegexField(r'^\d{6}$')
    new_password = serializers.CharField(min_length=8, max_length=128)


class LogoutSerializer(serializers.Serializer):
    refresh = serializers.CharField()


def _password_reset_user(channel, identifier):
    if channel == PasswordResetCode.EMAIL:
        return User.objects.filter(
            email__iexact=identifier.strip(),
            is_active=True,
        ).order_by('id').first()

    normalized_identifier = re.sub(r'\D', '', identifier)
    if not normalized_identifier:
        return None
    matches = {
        profile.user
        for profile in UserProfile.objects.select_related('user').filter(
            user__is_active=True,
        )
        if profile.phone
        and re.sub(r'\D', '', profile.phone) == normalized_identifier
    }
    return next(iter(matches)) if len(matches) == 1 else None


def _send_password_reset_code(user, channel, identifier, code):
    if channel == PasswordResetCode.EMAIL:
        return send_mail(
            subject='Code de réinitialisation de votre mot de passe FopCam',
            message=(
                f'Votre code de réinitialisation est : {code}\n\n'
                'Ce code expire dans 10 minutes. Si vous n’avez pas demandé '
                'cette réinitialisation, ignorez ce message.'
            ),
            from_email=settings.DEFAULT_FROM_EMAIL,
            recipient_list=[user.email],
            fail_silently=False,
        ) == 1

    profile = next(
        (
            item
            for item in UserProfile.objects.filter(user=user)
            if item.phone
            and re.sub(r'\D', '', item.phone)
            == re.sub(r'\D', '', identifier)
        ),
        None,
    )
    if profile is None or not profile.phone.strip().startswith('+'):
        return False

    phone_number = re.sub(r'\D', '', profile.phone)
    endpoint = (
        f'https://graph.facebook.com/{settings.WHATSAPP_GRAPH_API_VERSION}/'
        f'{settings.WHATSAPP_PHONE_NUMBER_ID}/messages'
    )
    payload = {
        'messaging_product': 'whatsapp',
        'to': phone_number,
        'type': 'template',
        'template': {
            'name': settings.WHATSAPP_TEMPLATE_NAME,
            'language': {'code': settings.WHATSAPP_TEMPLATE_LANGUAGE},
            'components': [
                {
                    'type': 'body',
                    'parameters': [{'type': 'text', 'text': code}],
                },
            ],
        },
    }
    outbound_request = urllib.request.Request(
        endpoint,
        data=json.dumps(payload).encode('utf-8'),
        headers={
            'Authorization': f'Bearer {settings.WHATSAPP_ACCESS_TOKEN}',
            'Content-Type': 'application/json',
        },
        method='POST',
    )
    try:
        with urllib.request.urlopen(outbound_request, timeout=10) as response:
            return 200 <= response.status < 300
    except (urllib.error.HTTPError, urllib.error.URLError, TimeoutError) as error:
        logger.error(
            'WhatsApp password reset delivery failed (%s).',
            type(error).__name__,
        )
        return False


class PasswordResetRequestView(APIView):
    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        channel = serializer.validated_data['channel']
        identifier = serializer.validated_data['identifier']

        if channel == PasswordResetCode.EMAIL and not settings.EMAIL_HOST:
            return Response(
                {'detail': 'La récupération par email est temporairement indisponible.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )
        if channel == PasswordResetCode.WHATSAPP and not (
            settings.WHATSAPP_PHONE_NUMBER_ID
            and settings.WHATSAPP_ACCESS_TOKEN
        ):
            return Response(
                {'detail': 'La récupération WhatsApp n’est pas encore configurée.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        user = _password_reset_user(channel, identifier)
        if user is None:
            return Response({
                'detail': (
                    'Si un compte correspond à ces informations, '
                    'un code lui sera envoyé.'
                ),
            })

        now = timezone.now()
        with transaction.atomic():
            locked_user = User.objects.select_for_update().get(pk=user.pk)
            recent_request = PasswordResetCode.objects.filter(
                user=locked_user,
                channel=channel,
                created_at__gte=now - timedelta(minutes=1),
            ).exists()
            if recent_request:
                return Response({
                    'detail': (
                        'Si un compte correspond à ces informations, '
                        'un code lui sera envoyé.'
                    ),
                })
            PasswordResetCode.objects.filter(
                user=locked_user,
                channel=channel,
                consumed_at__isnull=True,
            ).update(consumed_at=now)
            code = f'{secrets.randbelow(1_000_000):06d}'
            reset_code = PasswordResetCode.objects.create(
                user=locked_user,
                channel=channel,
                code_hash=make_password(code),
                expires_at=now + timedelta(minutes=10),
            )

        try:
            delivered = _send_password_reset_code(
                locked_user,
                channel,
                identifier,
                code,
            )
        except (OSError, TimeoutError) as error:
            logger.error(
                'Password reset delivery failed (%s).',
                type(error).__name__,
            )
            delivered = False
        if not delivered:
            reset_code.consumed_at = timezone.now()
            reset_code.save(update_fields=('consumed_at', 'updated_at'))
            logger.error(
                'Password reset code could not be delivered through %s.',
                channel,
            )
        return Response({
            'detail': (
                'Si un compte correspond à ces informations, '
                'un code lui sera envoyé.'
            ),
        })


class PasswordResetConfirmView(APIView):
    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        serializer = PasswordResetConfirmSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        channel = serializer.validated_data['channel']
        user = _password_reset_user(
            channel,
            serializer.validated_data['identifier'],
        )
        if user is None:
            return Response(
                {'detail': 'Code invalide ou expiré.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        with transaction.atomic():
            reset_code = PasswordResetCode.objects.select_for_update().filter(
                user=user,
                channel=channel,
                consumed_at__isnull=True,
            ).order_by('-created_at').first()
            if (
                reset_code is None
                or reset_code.expires_at <= timezone.now()
                or reset_code.attempts >= 5
            ):
                return Response(
                    {'detail': 'Code invalide ou expiré.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            if not check_password(
                serializer.validated_data['code'],
                reset_code.code_hash,
            ):
                reset_code.attempts += 1
                if reset_code.attempts >= 5:
                    reset_code.consumed_at = timezone.now()
                reset_code.save(
                    update_fields=('attempts', 'consumed_at', 'updated_at'),
                )
                return Response(
                    {'detail': 'Code invalide ou expiré.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )

            try:
                validate_password(serializer.validated_data['new_password'], user)
            except DjangoValidationError as error:
                raise ValidationError({'new_password': error.messages}) from error

            user.set_password(serializer.validated_data['new_password'])
            user.save(update_fields=('password',))
            reset_code.consumed_at = timezone.now()
            reset_code.save(update_fields=('consumed_at', 'updated_at'))
            for outstanding_token in OutstandingToken.objects.filter(user=user):
                BlacklistedToken.objects.get_or_create(token=outstanding_token)

        return Response({'detail': 'Votre mot de passe a été réinitialisé.'})


class LogoutView(APIView):
    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        serializer = LogoutSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        try:
            RefreshToken(serializer.validated_data['refresh']).blacklist()
        except TokenError:
            pass
        return Response(status=status.HTTP_205_RESET_CONTENT)


class GoogleAuthView(APIView):
    """Handle Google OAuth authentication"""
    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        """
        Expects: {
            'id_token': 'google_id_token'
        }
        """
        import logging
        logger = logging.getLogger(__name__)

        id_token = request.data.get('id_token')
        if not id_token:
            logger.error("No id_token provided in Google auth request")
            return Response({'error': 'id_token est requis'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            logger.info(f"Verifying Google ID token for user")
            payload = verify_google_id_token(id_token)
            logger.info(f"Google token verified successfully for email: {payload.get('email')}")
        except ValidationError as exc:
            logger.error(f"Google token validation failed: {exc.detail}")
            return Response({'error': exc.detail}, status=status.HTTP_400_BAD_REQUEST)

        email = payload.get('email')
        if not email:
            return Response({'error': 'Le token Google ne contient pas d\'email'}, status=status.HTTP_400_BAD_REQUEST)

        first_name = payload.get('given_name', '') or request.data.get('first_name', '')
        last_name = payload.get('family_name', '') or request.data.get('last_name', '')
        provider = request.data.get('provider', 'google')

        username = _generate_unique_username(email.split('@')[0] + '_' + provider)
        user, created = User.objects.get_or_create(
            email=email,
            defaults={
                'username': username,
                'first_name': first_name,
                'last_name': last_name,
            }
        )

        profile, _ = UserProfile.objects.get_or_create(
            user=user,
            defaults={
                'role': 'buyer',
                'address': '',
                'city': '',
                'country': ''
            }
        )

        refresh = RefreshToken.for_user(user)
        response_data = {
            'user': {
                'id': user.id,
                'username': user.username,
                'email': user.email,
                'first_name': user.first_name,
                'last_name': user.last_name
            },
            'access': str(refresh.access_token),
            'refresh': str(refresh)
        }
        
        # Create response and set JWT cookies
        response = Response(response_data, status=status.HTTP_200_OK)
        set_jwt_cookies(response, refresh.access_token, refresh)
        
        return response


class AppleAuthView(APIView):
    """Handle Apple OAuth authentication"""
    permission_classes = (permissions.AllowAny,)

    def post(self, request):
        """
        Expects: {
            'id_token': 'apple_id_token'
        }
        """
        id_token = request.data.get('id_token')
        if not id_token:
            return Response({'error': 'id_token est requis'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            payload = verify_apple_id_token(id_token)
        except ValidationError as exc:
            return Response({'error': exc.detail}, status=status.HTTP_400_BAD_REQUEST)

        email = payload.get('email')
        if not email:
            return Response({'error': 'Le token Apple ne contient pas d\'email'}, status=status.HTTP_400_BAD_REQUEST)

        first_name = request.data.get('first_name', 'Apple')
        last_name = request.data.get('last_name', 'User')
        username = _generate_unique_username(email.split('@')[0] + '_apple')

        user, created = User.objects.get_or_create(
            email=email,
            defaults={
                'username': username,
                'first_name': first_name,
                'last_name': last_name
            }
        )

        profile, _ = UserProfile.objects.get_or_create(
            user=user,
            defaults={
                'role': 'buyer',
                'address': '',
                'city': '',
                'country': ''
            }
        )

        refresh = RefreshToken.for_user(user)
        response_data = {
            'user': {
                'id': user.id,
                'username': user.username,
                'email': user.email,
                'first_name': user.first_name,
                'last_name': user.last_name
            }
        }
        
        # Create response and set JWT cookies
        response = Response(response_data, status=status.HTTP_200_OK)
        set_jwt_cookies(response, refresh.access_token, refresh)
        
        return response


class ProfileView(APIView):
    permission_classes = (permissions.IsAuthenticated,)
    parser_classes = (MultiPartParser, FormParser, JSONParser)

    def _get_profile(self, user):
        profile = UserProfile.objects.filter(
            user=user,
            is_active=True,
        ).order_by('-updated_at', '-id').first()
        if profile is not None:
            return profile

        profile = UserProfile.objects.filter(user=user).order_by(
            '-updated_at',
            '-id',
        ).first()
        if profile is None:
            return UserProfile.objects.create(
                user=user,
                role='particular',
                is_active=True,
            )

        UserProfile.objects.filter(user=user).exclude(pk=profile.pk).update(
            is_active=False,
        )
        profile.is_active = True
        profile.save(update_fields=('is_active', 'updated_at'))
        return profile

    def get(self, request):
        """Récupère le profil actif de l'utilisateur"""
        profile = self._get_profile(request.user)
        serializer = UserProfileSerializer(profile, context={'request': request})
        return Response(serializer.data)

    def put(self, request):
        """Met à jour le profil actif"""
        if 'role' in request.data:
            return Response(
                {'role': 'Utilisez le changement de type de profil dédié.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        profile = self._get_profile(request.user)
        serializer = UserProfileSerializer(
            profile,
            data=request.data,
            partial=True,
            context={'request': request},
        )
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def patch(self, request):
        """Mise à jour partielle du profil actif"""
        if 'role' in request.data:
            return Response(
                {'role': 'Utilisez le changement de type de profil dédié.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        profile = self._get_profile(request.user)
        serializer = UserProfileSerializer(
            profile,
            data=request.data,
            partial=True,
            context={'request': request},
        )
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ProfileRoleChangeView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def _active_profile(self, user):
        profile = UserProfile.objects.select_for_update().filter(
            user=user,
            is_active=True,
        ).order_by('-updated_at', '-id').first()
        if profile is None:
            profile = UserProfile.objects.select_for_update().filter(
                user=user,
            ).order_by('-updated_at', '-id').first()
        if profile is None:
            return UserProfile.objects.create(
                user=user,
                role='particular',
                is_active=True,
            )
        if not profile.is_active:
            UserProfile.objects.filter(user=user).exclude(pk=profile.pk).update(
                is_active=False,
            )
            profile.is_active = True
            profile.save(update_fields=('is_active', 'updated_at'))
        return profile

    def get(self, request):
        with transaction.atomic():
            locked_user = User.objects.select_for_update().get(
                pk=request.user.pk,
            )
            profile = self._active_profile(locked_user)
        return Response({
            'role': profile.role,
            **_profile_role_change_quota(locked_user),
        })

    def post(self, request):
        serializer = ProfileRoleChangeSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        new_role = serializer.validated_data['role']
        with transaction.atomic():
            locked_user = User.objects.select_for_update().get(pk=request.user.pk)
            profile = self._active_profile(locked_user)
            _record_profile_role_change(
                locked_user,
                profile.role,
                new_role,
            )
            if profile.role != new_role:
                profile.role = new_role
                profile.save(update_fields=('role', 'updated_at'))
            response_data = {
                'role': profile.role,
                **_profile_role_change_quota(locked_user),
            }
        return Response(response_data)


class ProfileAnalyticsView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    @staticmethod
    def _percentage_change(current, previous):
        if previous == 0:
            return None
        return round((current - previous) * 100 / previous)

    def get(self, request):
        now = timezone.localtime()
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        week_start = today_start - timedelta(days=6)
        previous_week_start = week_start - timedelta(days=7)
        events = ProfileAnalyticsEvent.objects.filter(owner=request.user)

        def count_events(event_type, start, end=None):
            queryset = events.filter(
                event_type=event_type,
                created_at__gte=start,
            )
            if end is not None:
                queryset = queryset.filter(created_at__lt=end)
            return queryset.count()

        impressions_7d = count_events('post_impression', week_start)
        impressions_previous_7d = count_events(
            'post_impression',
            previous_week_start,
            week_start,
        )
        profile_views_90d = count_events(
            'profile_view',
            timezone.now() - timedelta(days=90),
        )
        profile_views_7d = count_events('profile_view', week_start)
        profile_views_previous_7d = count_events(
            'profile_view',
            previous_week_start,
            week_start,
        )
        searches_7d = count_events('search_appearance', week_start)
        searches_previous_7d = count_events(
            'search_appearance',
            previous_week_start,
            week_start,
        )

        daily_impressions = {
            entry['day']: entry['total']
            for entry in events.filter(
                event_type='post_impression',
                created_at__gte=week_start,
            )
            .annotate(day=TruncDate('created_at', tzinfo=timezone.get_current_timezone()))
            .values('day')
            .annotate(total=Count('id'))
        }
        weekly_progress = [
            {
                'date': (week_start.date() + timedelta(days=day)).isoformat(),
                'impressions': daily_impressions.get(
                    week_start.date() + timedelta(days=day),
                    0,
                ),
            }
            for day in range(7)
        ]

        follows = Follow.objects.filter(followed=request.user)
        followers_total = follows.count()
        new_followers_7d = follows.filter(created_at__gte=week_start).count()
        new_followers_previous_7d = follows.filter(
            created_at__gte=previous_week_start,
            created_at__lt=week_start,
        ).count()

        return Response({
            'post_impressions_7d': impressions_7d,
            'post_impressions_change_percent': self._percentage_change(
                impressions_7d,
                impressions_previous_7d,
            ),
            'followers_total': followers_total,
            'new_followers_7d': new_followers_7d,
            'followers_change_percent': self._percentage_change(
                new_followers_7d,
                new_followers_previous_7d,
            ),
            'profile_views_90d': profile_views_90d,
            'profile_views_7d': profile_views_7d,
            'profile_views_change_percent': self._percentage_change(
                profile_views_7d,
                profile_views_previous_7d,
            ),
            'search_appearances_7d': searches_7d,
            'search_appearances_change_percent': self._percentage_change(
                searches_7d,
                searches_previous_7d,
            ),
            'posts_published_7d': Post.objects.filter(
                author=request.user,
                is_active=True,
                created_at__gte=week_start,
            ).count(),
            'weekly_progress': weekly_progress,
        })


class UserProfilesView(APIView):
    """Gère tous les profils de l'utilisateur"""
    permission_classes = (permissions.IsAuthenticated,)

    def get(self, request):
        """Récupère tous les profils de l'utilisateur"""
        profiles = UserProfile.objects.filter(user=request.user)
        serializer = UserProfileSerializer(
            profiles,
            many=True,
            context={'request': request},
        )
        return Response(serializer.data)

    def post(self, request):
        """Crée un nouveau profil pour l'utilisateur"""
        role_field = serializers.ChoiceField(choices=PROFILE_ROLE_CHANGE_CHOICES)
        role = role_field.run_validation(request.data.get('role', 'particular'))
        profile_data = request.data.copy()
        profile_data.pop('role', None)
        profile_data.pop('user', None)
        serializer = UserProfileSerializer(data=profile_data)
        if serializer.is_valid():
            with transaction.atomic():
                locked_user = User.objects.select_for_update().get(
                    pk=request.user.pk,
                )
                current_profile = UserProfile.objects.select_for_update().filter(
                    user=locked_user,
                    is_active=True,
                ).order_by('-updated_at', '-id').first()
                if current_profile is not None:
                    _record_profile_role_change(
                        locked_user,
                        current_profile.role,
                        role,
                    )
                UserProfile.objects.filter(user=locked_user).update(
                    is_active=False,
                )
                profile = serializer.save(
                    user=locked_user,
                    role=role,
                    is_active=True,
                )
            return Response(
                UserProfileSerializer(
                    profile,
                    context={'request': request},
                ).data,
                status=status.HTTP_201_CREATED,
            )
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class SwitchProfileView(APIView):
    """Change le profil actif de l'utilisateur"""
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request):
        """Change vers un profil spécifique"""
        profile_id = request.data.get('profile_id')
        if not profile_id:
            return Response({'error': 'profile_id est requis'}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            locked_user = User.objects.select_for_update().get(
                pk=request.user.pk,
            )
            try:
                new_profile = UserProfile.objects.select_for_update().get(
                    id=profile_id,
                    user=locked_user,
                )
            except UserProfile.DoesNotExist:
                return Response(
                    {'error': 'Profil non trouvé'},
                    status=status.HTTP_404_NOT_FOUND,
                )
            if new_profile.role == 'admin' and not locked_user.is_staff:
                return Response(
                    {'error': 'Vous ne pouvez pas activer ce type de profil.'},
                    status=status.HTTP_403_FORBIDDEN,
                )
            current_profile = UserProfile.objects.select_for_update().filter(
                user=locked_user,
                is_active=True,
            ).order_by('-updated_at', '-id').first()
            if current_profile is not None:
                _record_profile_role_change(
                    locked_user,
                    current_profile.role,
                    new_profile.role,
                )
            UserProfile.objects.filter(user=locked_user).exclude(
                id=profile_id,
            ).update(is_active=False)
            new_profile.is_active = True
            new_profile.save(update_fields=('is_active', 'updated_at'))

        serializer = UserProfileSerializer(
            new_profile,
            context={'request': request},
        )
        return Response(serializer.data, status=status.HTTP_200_OK)


class UserProfileDetailView(generics.RetrieveAPIView):
    serializer_class = UserProfileSerializer
    permission_classes = (permissions.AllowAny,)
    queryset = UserProfile.objects.all()

    def get_object(self):
        username = self.kwargs.get('username')
        user = User.objects.get(username=username)
        profile, _ = UserProfile.objects.get_or_create(user=user)
        request_user = self.request.user
        is_owner = request_user.is_authenticated and request_user.pk == user.pk
        is_friend = request_user.is_authenticated and Friend.objects.filter(
            Q(requester=user, receiver=request_user)
            | Q(requester=request_user, receiver=user),
            status='accepted',
        ).exists()
        if profile.profile_visibility == 'private' and not (is_owner or is_friend):
            raise Http404
        return profile

    def retrieve(self, request, *args, **kwargs):
        response = super().retrieve(request, *args, **kwargs)
        if response.status_code == status.HTTP_200_OK:
            owner = response.data.get('user')
            if isinstance(owner, dict):
                _record_profile_analytics(
                    'profile_view',
                    [owner.get('id')],
                    viewer_id=request.user.pk if request.user.is_authenticated else None,
                )
        return response


class UserDirectoryView(ListAPIView):
    serializer_class = UserDirectorySerializer
    permission_classes = [permissions.IsAuthenticated]
    pagination_class = SmallPageNumberPagination

    def get_queryset(self):
        current_user = self.request.user
        relation = Friend.objects.filter(
            Q(requester=OuterRef('pk'), receiver=current_user)
            | Q(requester=current_user, receiver=OuterRef('pk')),
            status__in=('pending', 'accepted'),
        ).order_by('-updated_at', '-id')
        accepted_relation = Friend.objects.filter(
            Q(requester=OuterRef('pk'), receiver=current_user)
            | Q(requester=current_user, receiver=OuterRef('pk')),
            status='accepted',
        )
        active_visibility = UserProfile.objects.filter(
            user=OuterRef('pk'),
            is_active=True,
        ).order_by('-updated_at', '-id').values('profile_visibility')[:1]
        queryset = User.objects.filter(is_active=True).exclude(pk=current_user.pk)
        queryset = queryset.annotate(
            connection_status=Subquery(relation.values('status')[:1]),
            connection_request_id=Subquery(relation.values('id')[:1]),
            connection_requester_id=Subquery(relation.values('requester_id')[:1]),
            active_profile_visibility=Subquery(active_visibility),
            has_accepted_friendship=Exists(accepted_relation),
        ).prefetch_related(
            Prefetch(
                'profiles',
                queryset=UserProfile.objects.filter(is_active=True).order_by(
                    '-updated_at',
                    '-id',
                ),
                to_attr='active_profiles',
            )
        )
        queryset = queryset.filter(
            Q(active_profile_visibility__isnull=True)
            | Q(active_profile_visibility='public')
            | Q(has_accepted_friendship=True)
        )

        if self.request.query_params.get('online', '').lower() in {'1', 'true', 'yes'}:
            queryset = queryset.filter(
                profiles__is_active=True,
                profiles__last_seen_at__gte=timezone.now() - timedelta(minutes=5),
            )

        search = self.request.query_params.get('search', '').strip()
        if search:
            queryset = queryset.filter(
                Q(username__icontains=search)
                | Q(first_name__icontains=search)
                | Q(last_name__icontains=search)
                | Q(profiles__city__icontains=search)
            )
        return queryset.order_by('username').distinct()

    def list(self, request, *args, **kwargs):
        response = super().list(request, *args, **kwargs)
        search = request.query_params.get('search', '').strip()
        if response.status_code == status.HTTP_200_OK and search:
            rows = (
                response.data.get('results', [])
                if isinstance(response.data, dict)
                else response.data
            )
            _record_profile_analytics(
                'search_appearance',
                [row.get('id') for row in rows if isinstance(row, dict)],
                viewer_id=request.user.pk,
            )
        return response


class UserPresenceView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        profiles = UserProfile.objects.filter(user=request.user)
        profile = profiles.filter(is_active=True).order_by('-updated_at', '-id').first()
        if profile is None:
            profile = profiles.order_by('-updated_at', '-id').first()
            if profile is None:
                profile = UserProfile(user=request.user, role='particular')
            profile.is_active = True
            profiles.exclude(pk=profile.pk).update(is_active=False)

        profile.last_seen_at = timezone.now()
        profile.save(update_fields=('is_active', 'last_seen_at', 'updated_at'))
        return Response({'is_online': True, 'last_seen_at': profile.last_seen_at})


class UserPublicProfileView(generics.RetrieveAPIView):
    serializer_class = UserPublicProfileSerializer
    permission_classes = [permissions.AllowAny]
    lookup_field = 'username'

    def get_queryset(self):
        queryset = User.objects.filter(is_active=True)
        request_user = self.request.user
        if request_user.is_authenticated:
            relation = Friend.objects.filter(
                Q(requester=OuterRef('pk'), receiver=request_user)
                | Q(requester=request_user, receiver=OuterRef('pk')),
                status__in=('pending', 'accepted'),
            ).order_by('-updated_at', '-id')
            queryset = queryset.annotate(
                connection_status=Subquery(relation.values('status')[:1]),
                connection_request_id=Subquery(relation.values('id')[:1]),
                connection_requester_id=Subquery(relation.values('requester_id')[:1]),
                active_profile_visibility=Subquery(
                    UserProfile.objects.filter(
                        user=OuterRef('pk'),
                        is_active=True,
                    ).order_by('-updated_at', '-id').values(
                        'profile_visibility',
                    )[:1]
                ),
                has_accepted_friendship=Exists(
                    Friend.objects.filter(
                        (
                            Q(requester=OuterRef('pk'), receiver=request_user)
                            | Q(requester=request_user, receiver=OuterRef('pk'))
                        ),
                        status='accepted',
                    )
                ),
            )
            queryset = queryset.filter(
                Q(pk=request_user.pk)
                | Q(active_profile_visibility__isnull=True)
                | Q(active_profile_visibility='public')
                | Q(has_accepted_friendship=True)
            )
        else:
            queryset = queryset.annotate(
                active_profile_visibility=Subquery(
                    UserProfile.objects.filter(
                        user=OuterRef('pk'),
                        is_active=True,
                    ).order_by('-updated_at', '-id').values(
                        'profile_visibility',
                    )[:1]
                )
            ).filter(
                Q(active_profile_visibility__isnull=True)
                | Q(active_profile_visibility='public')
            )
        return queryset.prefetch_related(
            Prefetch(
                'profiles',
                queryset=UserProfile.objects.filter(is_active=True).order_by(
                    '-updated_at',
                    '-id',
                ),
                to_attr='active_profiles',
            )
        )

    def retrieve(self, request, *args, **kwargs):
        response = super().retrieve(request, *args, **kwargs)
        if response.status_code == status.HTTP_200_OK:
            _record_profile_analytics(
                'profile_view',
                [response.data.get('id')],
                viewer_id=request.user.pk if request.user.is_authenticated else None,
            )
        return response


class ShopViewSet(viewsets.ModelViewSet):
    queryset = Shop.objects.all()
    serializer_class = ShopSerializer

    permission_classes = [permissions.IsAuthenticatedOrReadOnly, IsOwnerOrReadOnly]

    def perform_destroy(self, instance):
        if instance.products.exists():
            raise ValidationError({
                'detail': (
                    'Cette boutique contient des produits conservés dans le catalogue. '
                    'Supprimez-les manuellement avant de supprimer la boutique.'
                )
            })
        instance.delete()

    def get_queryset(self):
        queryset = Shop.objects.all()
        if self.action == 'list':
            queryset = queryset.filter(active=True).order_by('-created_at')
            search = self.request.query_params.get('search', '').strip()
            if search:
                queryset = queryset.filter(
                    Q(name__icontains=search)
                    | Q(description__icontains=search)
                    | Q(location__icontains=search)
                    | Q(owner__username__icontains=search)
                    | Q(owner__first_name__icontains=search)
                    | Q(owner__last_name__icontains=search)
                )
        return queryset

    def list(self, request, *args, **kwargs):
        response = super().list(request, *args, **kwargs)
        search = request.query_params.get('search', '').strip()
        if response.status_code == status.HTTP_200_OK and search:
            rows = (
                response.data.get('results', [])
                if isinstance(response.data, dict)
                else response.data
            )
            shop_ids = [
                row.get('id')
                for row in rows
                if isinstance(row, dict) and row.get('id') is not None
            ]
            own_shop_ids = set(
                Shop.objects.filter(
                    owner=request.user,
                    id__in=shop_ids,
                ).values_list('id', flat=True)
            ) if request.user.is_authenticated else set()
            ShopAnalyticsEvent.objects.bulk_create(
                ShopAnalyticsEvent(shop_id=shop_id, event_type='search_appearance')
                for shop_id in set(shop_ids) - own_shop_ids
            )
        return response

    def retrieve(self, request, *args, **kwargs):
        response = super().retrieve(request, *args, **kwargs)
        if response.status_code == status.HTTP_200_OK:
            shop_id = response.data.get('id')
            owner = response.data.get('owner')
            owner_id = owner.get('id') if isinstance(owner, dict) else None
            if shop_id is not None and (
                not request.user.is_authenticated
                or owner_id != request.user.pk
            ):
                ShopAnalyticsEvent.objects.create(
                    shop_id=shop_id,
                    event_type='shop_view',
                )
        return response

    def perform_create(self, serializer):
        profile = UserProfile.objects.filter(
            user=self.request.user,
            is_active=True,
        ).order_by('-updated_at', '-id').first()
        if profile is None or profile.role != 'boutique':
            raise PermissionDenied(
                'Le type de profil Boutique est requis pour créer une boutique.'
            )
        serializer.save(owner=self.request.user)

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def like(self, request, pk=None):
        shop = self.get_object()
        like, created = ShopLike.objects.get_or_create(user=request.user, shop=shop)
        if not created:
            like.delete()
        return Response({
            'is_liked': created,
            'like_count': shop.likes.count(),
        })

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def vote(self, request, pk=None):
        shop = self.get_object()
        vote, created = ShopVote.objects.get_or_create(user=request.user, shop=shop)
        if not created:
            vote.delete()
        return Response({
            'is_voted': created,
            'vote_count': shop.votes.count(),
        })

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def share(self, request, pk=None):
        shop = self.get_object()
        ShopShare.objects.create(user=request.user, shop=shop)
        return Response({'share_count': shop.shares.count()}, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def rate(self, request, pk=None):
        shop = self.get_object()
        if shop.owner_id == request.user.id:
            return Response(
                {'detail': 'Vous ne pouvez pas noter votre propre boutique.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        rating = request.data.get('rating')
        if isinstance(rating, bool) or not isinstance(rating, int) or not 1 <= rating <= 5:
            return Response(
                {'rating': 'La note doit être un nombre entier entre 1 et 5.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        ShopRating.objects.update_or_create(
            user=request.user,
            shop=shop,
            defaults={'rating': rating},
        )
        return Response(
            {
                'average_rating': round(
                    shop.ratings.aggregate(average=models.Avg('rating'))['average'],
                    1,
                ),
                'rating_count': shop.ratings.count(),
                'user_rating': rating,
            }
        )

    @action(
        detail=True,
        methods=['get'],
        permission_classes=[permissions.IsAuthenticated],
    )
    def analytics(self, request, pk=None):
        shop = self.get_object()
        if shop.owner_id != request.user.pk:
            raise PermissionDenied(
                'Seul le propriétaire peut consulter les statistiques de cette boutique.'
            )

        now = timezone.localtime()
        today_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        week_start = today_start - timedelta(days=6)
        previous_week_start = week_start - timedelta(days=7)
        confirmed_statuses = ('paid', 'shipped', 'completed')
        relevant_statuses = (*confirmed_statuses, 'pending')
        events = ShopAnalyticsEvent.objects.filter(shop=shop)

        def event_count(event_type, start, end=None):
            queryset = events.filter(event_type=event_type, created_at__gte=start)
            if end is not None:
                queryset = queryset.filter(created_at__lt=end)
            return queryset.count()

        def percentage_change(current, previous):
            return None if previous == 0 else round((current - previous) * 100 / previous)

        views_7d = event_count('shop_view', week_start)
        previous_views_7d = event_count(
            'shop_view',
            previous_week_start,
            week_start,
        )
        searches_7d = event_count('search_appearance', week_start)
        previous_searches_7d = event_count(
            'search_appearance',
            previous_week_start,
            week_start,
        )

        items = OrderItem.objects.filter(
            product__shop=shop,
            order__status__in=confirmed_statuses,
        )
        revenue_expression = F('price') * (F('quantity') - F('returned_quantity'))

        def revenue_between(start, end=None):
            queryset = items.filter(order__created_at__gte=start)
            if end is not None:
                queryset = queryset.filter(order__created_at__lt=end)
            return queryset.aggregate(total=Sum(revenue_expression))['total'] or 0

        revenue_7d = revenue_between(week_start)
        previous_revenue_7d = revenue_between(previous_week_start, week_start)
        revenue_90d = revenue_between(now - timedelta(days=90))
        orders_7d = Order.objects.filter(
            items__product__shop=shop,
            status__in=relevant_statuses,
            created_at__gte=week_start,
        ).distinct().count()
        previous_orders_7d = Order.objects.filter(
            items__product__shop=shop,
            status__in=relevant_statuses,
            created_at__gte=previous_week_start,
            created_at__lt=week_start,
        ).distinct().count()
        views_by_day = {
            entry['day']: entry['total']
            for entry in events.filter(
                event_type='shop_view',
                created_at__gte=week_start,
            )
            .annotate(
                day=TruncDate(
                    'created_at',
                    tzinfo=timezone.get_current_timezone(),
                )
            )
            .values('day')
            .annotate(total=Count('id'))
        }
        revenue_by_day = {
            entry['day']: entry['total'] or 0
            for entry in items.filter(order__created_at__gte=week_start)
            .annotate(
                day=TruncDate(
                    'order__created_at',
                    tzinfo=timezone.get_current_timezone(),
                )
            )
            .values('day')
            .annotate(total=Sum(revenue_expression))
        }
        daily_activity = [
            {
                'date': (week_start.date() + timedelta(days=day)).isoformat(),
                'shop_views': views_by_day.get(
                    week_start.date() + timedelta(days=day),
                    0,
                ),
                'sales_revenue': str(
                    revenue_by_day.get(
                        week_start.date() + timedelta(days=day),
                        0,
                    )
                ),
            }
            for day in range(7)
        ]
        products = list(
            shop.products.filter(is_active=True, is_deleted=False)
            .order_by('title')
            .values('id', 'title', 'quantity', 'price')
        )
        product_ids = [product['id'] for product in products]
        product_events = {
            entry['product_id']: entry
            for entry in ProductAnalyticsEvent.objects.filter(
                product_id__in=product_ids,
            )
            .values('product_id')
            .annotate(
                views_total=Count(
                    'id',
                    filter=Q(event_type='product_view'),
                ),
                views_90d=Count(
                    'id',
                    filter=Q(
                        event_type='product_view',
                        created_at__gte=now - timedelta(days=90),
                    ),
                ),
                views_7d=Count(
                    'id',
                    filter=Q(
                        event_type='product_view',
                        created_at__gte=week_start,
                    ),
                ),
                search_appearances_7d=Count(
                    'id',
                    filter=Q(
                        event_type='search_appearance',
                        created_at__gte=week_start,
                    ),
                ),
            )
        }
        product_sales = {
            entry['product_id']: entry
            for entry in items.filter(
                product_id__in=product_ids,
                order__created_at__gte=now - timedelta(days=90),
            )
            .values('product_id')
            .annotate(
                units_sold=Sum(F('quantity') - F('returned_quantity')),
                revenue=Sum(revenue_expression),
                orders=Count('order_id', distinct=True),
            )
        }
        product_favorites = {
            entry['product_id']: entry['total']
            for entry in Favorite.objects.filter(
                product_id__in=product_ids,
            )
            .values('product_id')
            .annotate(total=Count('id'))
        }
        product_metrics = []
        for product in products:
            product_id = product['id']
            events_for_product = product_events.get(product_id, {})
            sales_for_product = product_sales.get(product_id, {})
            product_metrics.append({
                'product_id': product_id,
                'title': product['title'],
                'stock_quantity': product['quantity'],
                'price': str(product['price']),
                'views_total': events_for_product.get('views_total', 0),
                'views_90d': events_for_product.get('views_90d', 0),
                'views_7d': events_for_product.get('views_7d', 0),
                'search_appearances_7d': events_for_product.get(
                    'search_appearances_7d',
                    0,
                ),
                'units_sold_90d': sales_for_product.get('units_sold') or 0,
                'revenue_90d': str(sales_for_product.get('revenue') or 0),
                'orders_90d': sales_for_product.get('orders', 0),
                'favorites_total': product_favorites.get(product_id, 0),
            })
        product_metrics.sort(
            key=lambda item: (
                item['units_sold_90d'],
                item['views_total'],
                item['search_appearances_7d'],
            ),
            reverse=True,
        )
        rating = shop.ratings.aggregate(average= models.Avg('rating'))
        return Response({
            'shop_id': shop.pk,
            'shop_views_90d': event_count(
                'shop_view',
                timezone.now() - timedelta(days=90),
            ),
            'shop_views_7d': views_7d,
            'shop_views_change_percent': percentage_change(
                views_7d,
                previous_views_7d,
            ),
            'search_appearances_7d': searches_7d,
            'search_appearances_change_percent': percentage_change(
                searches_7d,
                previous_searches_7d,
            ),
            'orders_7d': orders_7d,
            'orders_change_percent': percentage_change(
                orders_7d,
                previous_orders_7d,
            ),
            'sales_revenue_7d': str(revenue_7d),
            'sales_revenue_change_percent': percentage_change(
                float(revenue_7d),
                float(previous_revenue_7d),
            ),
            'sales_revenue_90d': str(revenue_90d),
            'likes_total': shop.likes.count(),
            'shares_total': shop.shares.count(),
            'ratings_total': shop.ratings.count(),
            'average_rating': round(float(rating['average']), 1)
            if rating['average'] is not None else 0,
            'products_total': shop.products.filter(
                is_active=True,
                is_deleted=False,
            ).count(),
            'product_metrics': product_metrics,
            'daily_activity': daily_activity,
        })

    @action(detail=False, methods=['get'], permission_classes=[permissions.IsAuthenticated])
    def my(self, request):
        """Retourne la boutique du vendeur authentifié"""
        try:
            shop = Shop.objects.get(owner=request.user)
            serializer = self.get_serializer(shop)
            return Response(serializer.data)
        except Shop.DoesNotExist:
            return Response({'detail': 'Aucune boutique trouvée.'}, status=404)

    @action(detail=False, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def seed_products(self, request):
        """Ajoute des produits d'exemple à la boutique du vendeur connecté."""
        try:
            shop = Shop.objects.get(owner=request.user)
        except Shop.DoesNotExist:
            return Response({'detail': 'Aucune boutique trouvée.'}, status=404)

        created_count = create_sample_products_for_shop(shop)
        return Response({
            'detail': f'{created_count} produit(s) d’exemple ajoutés.',
            'created': created_count,
        })


class CategoryViewSet(viewsets.ReadOnlyModelViewSet):
    # Retourne les catégories triées par nom pour affichage alphabétique
    queryset = Category.objects.all().order_by('name')
    serializer_class = CategorySerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        queryset = Category.objects.all().order_by(Lower('name'))
        category_type = self.request.query_params.get('category_type')
        valid_category_types = {choice[0] for choice in Category.CATEGORY_TYPE_CHOICES}
        if category_type:
            if category_type not in valid_category_types:
                raise ValidationError({'category_type': 'Type de catégorie invalide.'})
            queryset = queryset.filter(category_type=category_type)
        search = self.request.query_params.get('search', '').strip()
        if search:
            queryset = queryset.filter(name__icontains=search)
        return queryset


class ProductViewSet(viewsets.ModelViewSet):
    queryset = Product.objects.filter(is_active=True, is_deleted=False)
    serializer_class = ProductSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly, IsOwnerOrReadOnly]
    parser_classes = (MultiPartParser, FormParser, JSONParser)

    def get_serializer_class(self):
        if self.action in ('create', 'update', 'partial_update', 'my'):
            return SellerProductSerializer
        return ProductSerializer

    def get_queryset(self):
        queryset = Product.objects.filter(
            is_active=True,
            is_deleted=False,
        ).order_by('-created_at')
        shop_id = self.request.query_params.get('shop')
        try:
            total_before = queryset.count()
        except Exception:
            total_before = 'unknown'

        if shop_id:
            queryset = queryset.filter(shop_id=shop_id)

        search = self.request.query_params.get('search', '').strip()
        if search:
            queryset = queryset.filter(
                Q(title__icontains=search)
                | Q(description__icontains=search)
                | Q(category__name__icontains=search)
                | Q(shop__name__icontains=search)
            )

        category_id = self.request.query_params.get('category')
        if category_id:
            try:
                queryset = queryset.filter(category_id=int(category_id))
            except ValueError as error:
                raise ValidationError({'category': 'Identifiant de catégorie invalide.'}) from error

        category_name = self.request.query_params.get('category_name', '').strip()
        if category_name:
            queryset = queryset.filter(category__name__icontains=category_name)

        category_type = self.request.query_params.get('category_type')
        if category_type:
            if category_type not in ('product', 'professional'):
                raise ValidationError({
                    'category_type': 'Choisissez product ou professional.'
                })
            queryset = queryset.filter(category__category_type=category_type)

        price_min = self.request.query_params.get('price_min', '').strip()
        price_max = self.request.query_params.get('price_max', '').strip()
        parsed_prices = {}
        for name, value in (('price_min', price_min), ('price_max', price_max)):
            if not value:
                continue
            try:
                parsed_price = Decimal(value)
            except InvalidOperation as error:
                raise ValidationError({name: 'Saisissez un prix valide.'}) from error
            if not parsed_price.is_finite() or parsed_price < 0:
                raise ValidationError({name: 'Saisissez un prix positif valide.'})
            parsed_prices[name] = parsed_price

        if (
            'price_min' in parsed_prices
            and 'price_max' in parsed_prices
            and parsed_prices['price_min'] > parsed_prices['price_max']
        ):
            raise ValidationError({
                'price_max': 'Le prix maximum doit être supérieur au prix minimum.'
            })
        if 'price_min' in parsed_prices:
            queryset = queryset.filter(price__gte=parsed_prices['price_min'])
        if 'price_max' in parsed_prices:
            queryset = queryset.filter(price__lte=parsed_prices['price_max'])

        in_stock = self.request.query_params.get('in_stock', '').lower()
        if in_stock not in ('', 'true', 'false', '1', '0'):
            raise ValidationError({'in_stock': 'Valeur de disponibilité invalide.'})
        if in_stock in ('true', '1'):
            queryset = queryset.filter(quantity__gt=0)

        ordering = self.request.query_params.get('ordering', 'newest')
        orderings = {
            'newest': ('-created_at',),
            'price_asc': ('price', '-created_at'),
            'price_desc': ('-price', '-created_at'),
        }
        if ordering not in orderings:
            raise ValidationError({'ordering': 'Choisissez un tri valide.'})
        queryset = queryset.order_by(*orderings[ordering])

        try:
            total_after = queryset.count()
        except Exception:
            total_after = 'unknown'

        # Log useful debugging info to help track why products may be missing
        logger.info(f"ProductViewSet.get_queryset called by={getattr(self.request, 'user', None)} shop_param={shop_id} total_before={total_before} total_after={total_after}")

        return queryset

    def list(self, request, *args, **kwargs):
        response = super().list(request, *args, **kwargs)
        if request.query_params.get('search', '').strip():
            results = (
                response.data.get('results', [])
                if isinstance(response.data, dict)
                else response.data
            )
            _record_product_analytics(
                [item['id'] for item in results if item.get('id')],
                'search_appearance',
                request.user.pk if request.user.is_authenticated else None,
            )
        return response

    def retrieve(self, request, *args, **kwargs):
        response = super().retrieve(request, *args, **kwargs)
        _record_product_analytics(
            [response.data['id']],
            'product_view',
            request.user.pk if request.user.is_authenticated else None,
        )
        return response

    def perform_create(self, serializer):
        # Enforce that the shop belongs to the requesting user unless user is staff
        shop = serializer.validated_data.get('shop')
        user = self.request.user
        if not user.is_staff:
            if shop.owner != user:
                raise permissions.PermissionDenied('Vous devez être propriétaire de la boutique sélectionnée.')
        with transaction.atomic():
            instance = serializer.save(is_active=True)
            if instance.quantity:
                StockMovement.objects.create(
                    product=instance,
                    user=user,
                    movement_type='restock',
                    quantity_change=instance.quantity,
                    unit_cost=instance.purchase_price,
                    note='Stock initial',
                )

            images = (
                self.request.FILES.getlist('images')
                if self.request.FILES
                else []
            )
            self._save_product_images(instance, images)
            return instance

    @staticmethod
    def _save_product_images(instance, images):
        first_product_image = None
        for image in images:
            product_image = ProductImage.objects.create(
                product=instance,
                image=image,
            )
            if first_product_image is None:
                first_product_image = product_image

        if first_product_image is not None:
            instance.image = first_product_image.image.name
            instance.save(update_fields=['image'])

    def create(self, request, *args, **kwargs):
        # Validate number of uploaded images does not exceed 10 and only one video is allowed
        images = request.FILES.getlist('images') if request.FILES else []
        videos = request.FILES.getlist('video') if request.FILES else []
        if len(images) > 10:
            return Response({'detail': 'Maximum 10 images autorisées par produit.'}, status=status.HTTP_400_BAD_REQUEST)
        if len(videos) > 1:
            return Response({'detail': 'Une seule vidéo autorisée par produit.'}, status=status.HTTP_400_BAD_REQUEST)
        return super().create(request, *args, **kwargs)

    def perform_update(self, serializer):
        # Ensure owner is modifying their product
        user = self.request.user
        instance = self.get_object()
        if not user.is_staff and instance.shop.owner != user:
            raise permissions.PermissionDenied('Modification non autorisée.')
        with transaction.atomic():
            previous_quantity = instance.quantity
            instance = serializer.save()
            quantity_change = instance.quantity - previous_quantity
            if quantity_change:
                StockMovement.objects.create(
                    product=instance,
                    user=user,
                    movement_type='adjustment',
                    quantity_change=quantity_change,
                    unit_cost=instance.purchase_price,
                    note='Ajustement lors de la modification du produit',
                )

            images = (
                self.request.FILES.getlist('images')
                if self.request.FILES
                else []
            )
            self._save_product_images(instance, images)
            return instance

    def update(self, request, *args, **kwargs):
        # Validate uploaded images on update
        images = request.FILES.getlist('images') if request.FILES else []
        videos = request.FILES.getlist('video') if request.FILES else []
        if len(images) > 10:
            return Response({'detail': 'Maximum 10 images autorisées par produit.'}, status=status.HTTP_400_BAD_REQUEST)
        if len(videos) > 1:
            return Response({'detail': 'Une seule vidéo autorisée par produit.'}, status=status.HTTP_400_BAD_REQUEST)
        return super().update(request, *args, **kwargs)

    def perform_destroy(self, instance):
        user = self.request.user
        if not user.is_staff and instance.shop.owner != user:
            raise permissions.PermissionDenied('Suppression non autorisée.')
        instance.manual_delete(deleted_by=user)

    @action(detail=False, methods=['get'], permission_classes=[permissions.IsAuthenticated])
    def my(self, request):
        """Retourne les produits du vendeur authentifié"""
        qs = Product.objects.filter(
            shop__owner=request.user,
            is_deleted=False,
        )
        page = self.paginate_queryset(qs)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def stock(self, request, pk=None):
        product = self.get_object()
        if not request.user.is_staff and product.shop.owner_id != request.user.id:
            raise permissions.PermissionDenied(
                'Vous devez être propriétaire du produit pour gérer son stock.'
            )

        movement_type = request.data.get('movement_type')
        note = str(request.data.get('note', '')).strip()
        if movement_type not in ('restock', 'adjustment'):
            raise ValidationError(
                {'movement_type': 'Choisissez restock ou adjustment.'}
            )
        try:
            quantity = int(request.data.get('quantity'))
        except (TypeError, ValueError) as error:
            raise ValidationError({'quantity': 'Saisissez une quantité entière.'}) from error
        if quantity <= 0:
            raise ValidationError({'quantity': 'La quantité doit être supérieure à zéro.'})
        if not note:
            raise ValidationError({'note': 'Indiquez le motif du mouvement de stock.'})

        unit_cost = product.purchase_price
        if movement_type == 'restock':
            try:
                unit_cost = Decimal(str(request.data.get('purchase_price')))
            except InvalidOperation as error:
                raise ValidationError(
                    {'purchase_price': 'Saisissez un prix d’achat valide.'}
                ) from error
            if not unit_cost.is_finite() or unit_cost < 0:
                raise ValidationError(
                    {'purchase_price': 'Le prix d’achat doit être positif ou nul.'}
                )
        elif request.data.get('direction') == 'decrease':
            quantity = -quantity

        with transaction.atomic():
            product = Product.objects.select_for_update().get(pk=product.pk)
            if product.quantity + quantity < 0:
                raise ValidationError(
                    {'quantity': 'La quantité à retirer dépasse le stock disponible.'}
                )
            product.quantity += quantity
            update_fields = ['quantity']
            if movement_type == 'restock':
                product.purchase_price = unit_cost
                update_fields.append('purchase_price')
            product.save(update_fields=update_fields)
            movement = StockMovement.objects.create(
                product=product,
                user=request.user,
                movement_type=movement_type,
                quantity_change=quantity,
                unit_cost=unit_cost,
                note=note,
            )

        return Response(
            {
                'product': SellerProductSerializer(
                    product,
                    context=self.get_serializer_context(),
                ).data,
                'movement': StockMovementSerializer(movement).data,
            },
            status=status.HTTP_201_CREATED,
        )

    @action(detail=False, methods=['get'], permission_classes=[permissions.IsAuthenticated])
    def stock_movements(self, request):
        movements = StockMovement.objects.filter(
            product__shop__owner=request.user,
        ).select_related('product', 'order_item')
        page = self.paginate_queryset(movements)
        serializer = StockMovementSerializer(page or movements, many=True)
        if page is not None:
            return self.get_paginated_response(serializer.data)
        return Response(serializer.data)


class OrderViewSet(viewsets.ModelViewSet):
    queryset = Order.objects.all()
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.is_staff:
            return Order.objects.all()
        return Order.objects.filter(buyer=user)

    @action(detail=False, methods=['get'], url_path='sales')
    def sales(self, request):
        user = request.user
        qs = Order.objects.filter(items__product__shop__owner=user).distinct().order_by('-created_at')
        page = self.paginate_queryset(qs)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        serializer = self.get_serializer(qs, many=True)
        return Response(serializer.data)

    def get_serializer_class(self):
        if self.action in ['create', 'update', 'partial_update']:
            return OrderCreateSerializer
        if self.action == 'sales':
            return SellerOrderSerializer
        return OrderSerializer

    def perform_create(self, serializer):
        serializer.save(buyer=self.request.user)

    def _get_seller_order_item(self, request, order_id):
        item_id = request.data.get('item_id')
        if not item_id:
            raise ValidationError({'item_id': 'Un article de commande est requis.'})
        try:
            item = OrderItem.objects.select_related(
                'product',
                'product__shop',
                'order',
            ).get(
                pk=item_id,
                order_id=order_id,
                product__shop__owner=request.user,
            )
        except OrderItem.DoesNotExist as error:
            raise permissions.PermissionDenied(
                'Cet article ne fait pas partie de votre boutique.'
            ) from error
        return item

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def fulfillment(self, request, pk=None):
        item = self._get_seller_order_item(request, pk)
        next_status = request.data.get('status')
        allowed_transitions = {
            'pending': {'preparing', 'cancelled'},
            'preparing': {'in_delivery', 'cancelled'},
            'in_delivery': {'delivered'},
        }
        if next_status not in allowed_transitions.get(item.fulfillment_status, set()):
            raise ValidationError(
                {'status': 'Cette transition de livraison n’est pas autorisée.'}
            )

        with transaction.atomic():
            if next_status == 'cancelled':
                product = Product.objects.select_for_update().get(pk=item.product_id)
                product.quantity += item.quantity - item.returned_quantity
                product.save(update_fields=['quantity'])
                StockMovement.objects.create(
                    product=product,
                    user=request.user,
                    movement_type='cancellation',
                    quantity_change=item.quantity - item.returned_quantity,
                    unit_cost=item.purchase_price,
                    note=f'Annulation commande #{item.order_id}',
                    order_item=item,
                )
            item.fulfillment_status = next_status
            item.save(update_fields=['fulfillment_status'])
            Notification.objects.create(
                user=item.order.buyer,
                title='Mise à jour de votre commande',
                message=(
                    f'Votre article « {item.product.title} » est maintenant '
                    f'{item.get_fulfillment_status_display().lower()}.'
                ),
                type='order',
                data={'order_id': item.order_id, 'audience': 'buyer'},
            )
        return Response(
            SellerOrderSerializer(item.order, context=self.get_serializer_context()).data
        )

    @action(detail=True, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def accept_return(self, request, pk=None):
        item = self._get_seller_order_item(request, pk)
        if item.fulfillment_status != 'delivered':
            raise ValidationError(
                {'status': 'Seul un article livré peut être enregistré comme retour.'}
            )
        try:
            quantity = int(request.data.get('quantity'))
        except (TypeError, ValueError) as error:
            raise ValidationError({'quantity': 'Saisissez une quantité entière.'}) from error
        if quantity < 1 or quantity > item.quantity - item.returned_quantity:
            raise ValidationError(
                {'quantity': 'La quantité retournée dépasse le solde de la commande.'}
            )

        note = str(request.data.get('note', '')).strip() or 'Retour accepté par le vendeur'
        with transaction.atomic():
            product = Product.objects.select_for_update().get(pk=item.product_id)
            product.quantity += quantity
            product.save(update_fields=['quantity'])
            item.returned_quantity += quantity
            if item.returned_quantity == item.quantity:
                item.fulfillment_status = 'returned'
                item.save(update_fields=['returned_quantity', 'fulfillment_status'])
            else:
                item.save(update_fields=['returned_quantity'])
            StockMovement.objects.create(
                product=product,
                user=request.user,
                movement_type='return',
                quantity_change=quantity,
                unit_cost=item.purchase_price,
                note=note,
                order_item=item,
            )
            Notification.objects.create(
                user=item.order.buyer,
                title='Retour accepté',
                message=f'Le retour de {quantity} × {item.product.title} a été accepté.',
                type='order',
                data={'order_id': item.order_id, 'audience': 'buyer'},
            )
        return Response(
            SellerOrderSerializer(item.order, context=self.get_serializer_context()).data
        )


class MessageViewSet(viewsets.ModelViewSet):
    serializer_class = MessageSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = (JSONParser, MultiPartParser, FormParser)

    def _schedule_message_file_cleanup(self, messages):
        stored_files = {}
        for message in messages:
            for field_name in ('audio_file', 'attachment_file'):
                file_field = getattr(message, field_name, None)
                if file_field and file_field.name:
                    stored_files[(id(file_field.storage), file_field.name)] = (
                        file_field.storage,
                        file_field.name,
                    )

        message_ids = [message.id for message in messages]
        unreferenced_files = []
        for storage, name in stored_files.values():
            still_referenced = Message.objects.exclude(
                id__in=message_ids,
            ).filter(
                Q(audio_file=name) | Q(attachment_file=name),
            ).exists()
            if not still_referenced:
                unreferenced_files.append((storage, name))

        if unreferenced_files:
            transaction.on_commit(
                lambda: self._delete_message_files(unreferenced_files)
            )

    @staticmethod
    def _delete_message_files(stored_files):
        for storage, name in stored_files:
            try:
                storage.delete(name)
            except Exception:
                logger.exception('Impossible de supprimer le fichier du message %s', name)

    @staticmethod
    def _broadcast_deletion(room, event):
        channel_layer = get_channel_layer()
        if channel_layer is None:
            logger.error('Aucun channel layer configuré pour notifier %s', room)
            return

        try:
            async_to_sync(channel_layer.group_send)(
                f'chat_{room}',
                {'type': 'chat_message', 'message': json.dumps(event)},
            )
        except Exception:
            logger.exception('Impossible de notifier la suppression dans %s', room)

    def get_queryset(self):
        room = self.request.query_params.get('room')
        user = self.request.user

        if room:
            participants = private_room_participant_ids(room)
            if participants is None or user.id not in participants:
                raise PermissionDenied('Vous ne participez pas à cette discussion.')
            other_user_id = next(
                participant_id
                for participant_id in participants
                if participant_id != user.id
            )
            return Message.objects.filter(room=room).select_related(
                'user',
                'recipient',
                'reply_to',
                'reply_to__user',
            ).filter(
                Q(user=user, recipient_id=other_user_id)
                | Q(user_id=other_user_id, recipient=user)
            ).order_by('created_at')

        owned_messages = Message.objects.filter(
            Q(user=user) | Q(recipient=user),
        ).values_list('room', 'user_id', 'recipient_id')
        private_rooms = {}
        for room_name, sender_id, recipient_id in owned_messages:
            participants = private_room_participant_ids(room_name)
            if participants is None or user.id not in participants:
                continue
            other_user_id = (
                recipient_id if sender_id == user.id else sender_id
            )
            if other_user_id in participants and other_user_id != user.id:
                private_rooms[room_name] = other_user_id

        if not private_rooms:
            return Message.objects.none()

        participant_messages = Q()
        for room_name, other_user_id in private_rooms.items():
            participant_messages |= Q(
                room=room_name,
                user=user,
                recipient_id=other_user_id,
            ) | Q(
                room=room_name,
                user_id=other_user_id,
                recipient=user,
            )
        return Message.objects.filter(participant_messages).select_related(
            'user',
            'recipient',
            'reply_to',
            'reply_to__user',
        ).order_by('created_at')

    def perform_destroy(self, instance):
        if instance.user_id != self.request.user.id:
            raise PermissionDenied(
                'Seul l’auteur peut supprimer son message pour tous.'
            )

        room = instance.room
        message_id = instance.id
        with transaction.atomic():
            self._schedule_message_file_cleanup([instance])
            instance.delete()
            transaction.on_commit(
                lambda: self._broadcast_deletion(
                    room,
                    {'event': 'message_deleted', 'room': room, 'message_id': message_id},
                )
            )

    @action(detail=False, methods=['get'], permission_classes=[permissions.IsAuthenticated])
    def unread_count(self, request):
        count = self.get_queryset().filter(
            recipient=request.user,
            is_read=False,
        ).count()
        return Response({'count': count})

    @action(detail=False, methods=['get'], permission_classes=[permissions.IsAuthenticated])
    def conversations(self, request):
        direct_messages = self.get_queryset().filter(
            recipient__isnull=False,
        ).select_related('user', 'recipient').order_by('-created_at')
        unread_by_room = dict(
            self.get_queryset().filter(
                recipient=request.user,
                is_read=False,
            )
            .values('room')
            .annotate(total=Count('id'))
            .values_list('room', 'total')
        )
        conversations = {}
        for message in direct_messages:
            participants = private_room_participant_ids(message.room)
            if participants is None or request.user.id not in participants:
                continue
            if message.room in conversations:
                continue
            other_user = (
                message.recipient
                if message.user_id == request.user.id
                else message.user
            )
            if (
                other_user is None
                or other_user.id == request.user.id
                or other_user.id not in participants
            ):
                continue
            profile = UserProfile.objects.filter(user=other_user).order_by(
                '-updated_at',
                '-id',
            ).first()
            profile_image = (
                request.build_absolute_uri(profile.profile_image.url)
                if profile and profile.profile_image
                else None
            )
            conversations[message.room] = {
                'room_id': message.room,
                'profile': {
                    'id': other_user.id,
                    'username': other_user.username,
                    'first_name': other_user.first_name,
                    'last_name': other_user.last_name,
                    'profile_image': profile_image,
                },
                'last_message': message.content or message.get_message_type_display(),
                'message_type': message.message_type,
                'updated_at': message.created_at,
                'unread_count': unread_by_room.get(message.room, 0),
            }
        return Response(list(conversations.values()))

    @action(detail=False, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def mark_conversation_read(self, request):
        room = request.data.get('room')
        participants = private_room_participant_ids(room)
        if participants is None or request.user.id not in participants:
            raise ValidationError({'room': 'Salle privée invalide.'})
        unread_messages = Message.objects.filter(
            room=room,
            recipient=request.user,
            user_id=next(
                participant_id
                for participant_id in participants
                if participant_id != request.user.id
            ),
            is_read=False,
        )
        updated_count = unread_messages.update(is_read=True)
        return Response({'updated': updated_count})

    def perform_create(self, serializer):
        room = serializer.validated_data.get('room')
        participants = private_room_participant_ids(room)
        if participants is None or self.request.user.id not in participants:
            raise ValidationError({'room': 'Salle privée invalide.'})
        recipient = self._get_recipient_from_room(room, self.request.user)
        if recipient is None:
            raise ValidationError({'room': 'Destinataire de discussion invalide.'})

        attachment_file = serializer.validated_data.get('attachment_file')
        if not serializer.validated_data.get('content') and attachment_file:
            serializer.validated_data['content'] = getattr(attachment_file, 'name', '')

        if not serializer.validated_data.get('message_type') and attachment_file:
            content_type = getattr(attachment_file, 'content_type', '') or ''
            serializer.validated_data['message_type'] = self._infer_message_type_from_content_type(content_type)

        message = serializer.save(user=self.request.user, recipient=recipient)
        channel_layer = get_channel_layer()
        if channel_layer is None:
            logger.warning("No channel layer configured; chat message was not broadcast.")
            return

        payload = dict(self.get_serializer(message).data)
        payload['message'] = payload.get('content') or ''

        def broadcast_message():
            async_to_sync(channel_layer.group_send)(
                f'chat_{room}',
                {
                    'type': 'chat_message',
                    'message': json.dumps(payload, default=str),
                },
            )

        transaction.on_commit(broadcast_message)

    def _infer_message_type_from_content_type(self, content_type):
        if content_type.startswith('image/'):
            return 'image'
        if content_type.startswith('video/'):
            return 'video'
        if content_type.startswith('audio/'):
            return 'audio'
        return 'document'

    def _get_recipient_from_room(self, room_name, sender):
        participants = private_room_participant_ids(room_name)
        if participants is None or sender.id not in participants:
            return None

        recipient_id = next(user_id for user_id in participants if user_id != sender.id)
        return User.objects.filter(id=recipient_id).first()

    @action(detail=False, methods=['post'], permission_classes=[permissions.IsAuthenticated])
    def start_conversation(self, request):
        """Crée ou ouvre une conversation avec un utilisateur"""
        recipient_id = request.data.get('recipient_id')
        if not recipient_id:
            return Response({'error': 'recipient_id est requis'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            recipient = User.objects.get(id=recipient_id)
        except User.DoesNotExist:
            return Response({'error': 'Utilisateur non trouvé'}, status=status.HTTP_404_NOT_FOUND)

        if recipient.id == request.user.id:
            return Response({'error': 'Vous ne pouvez pas envoyer un message à vous-même'}, status=status.HTTP_400_BAD_REQUEST)
        # Crée une room_id unique pour cette conversation
        room_id = f"private_{min(request.user.id, recipient.id)}_{max(request.user.id, recipient.id)}"

        return Response({
            'room_id': room_id,
            'recipient': {
                'id': recipient.id,
                'username': recipient.username,
                'email': recipient.email,
                'first_name': recipient.first_name,
                'last_name': recipient.last_name,
            }
        }, status=status.HTTP_200_OK)

    @action(detail=False, methods=['delete'], permission_classes=[permissions.IsAuthenticated])
    def delete_conversation(self, request):
        room = str(request.data.get('room', '')).strip()
        participants = private_room_participant_ids(room)
        if participants is None:
            return Response(
                {'error': 'Cette discussion est invalide.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if request.user.id not in participants:
            raise PermissionDenied('Vous ne participez pas à cette discussion.')

        other_user_id = next(
            participant_id
            for participant_id in participants
            if participant_id != request.user.id
        )
        conversation_messages = Message.objects.filter(room=room).filter(
            Q(user=request.user, recipient_id=other_user_id)
            | Q(user_id=other_user_id, recipient=request.user)
        )

        with transaction.atomic():
            messages = list(conversation_messages.select_for_update())
            self._schedule_message_file_cleanup(messages)
            conversation_messages.delete()
            transaction.on_commit(
                lambda: self._broadcast_deletion(
                    room,
                    {'event': 'conversation_deleted', 'room': room},
                )
            )

        return Response({'success': True}, status=status.HTTP_200_OK)


class ProfileViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = UserProfile.objects.select_related('user').all()
    serializer_class = UserProfileSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]
    pagination_class = SmallPageNumberPagination

    def get_queryset(self):
        queryset = self.queryset
        if self.request.user.is_authenticated:
            accepted_friendship = Friend.objects.filter(
                Q(requester=OuterRef('user_id'), receiver=self.request.user)
                | Q(requester=self.request.user, receiver=OuterRef('user_id')),
                status='accepted',
            )
            queryset = queryset.annotate(
                is_visible_friend_profile=Exists(accepted_friendship),
            ).filter(
                Q(user=self.request.user)
                | Q(profile_visibility='public')
                | Q(is_visible_friend_profile=True)
            )
        else:
            queryset = queryset.filter(profile_visibility='public')
        role = self.request.query_params.get('role')
        if role:
            if role == 'producer':
                queryset = queryset.filter(
                    Q(role__in=('producer', 'boutique'))
                    | Q(user__shops__isnull=False)
                ).distinct()
            else:
                queryset = queryset.filter(role=role)

            if role == 'driver':
                shop_id = self.request.query_params.get('shop_id')
                if shop_id:
                    try:
                        shop = Shop.objects.get(id=shop_id)
                        if shop.latitude is not None and shop.longitude is not None:
                            try:
                                distance_km = float(self.request.query_params.get('distance_km', 20))
                            except (TypeError, ValueError):
                                distance_km = 20
                            delta = distance_km / 111.0
                            queryset = queryset.filter(
                                latitude__gte=shop.latitude - delta,
                                latitude__lte=shop.latitude + delta,
                                longitude__gte=shop.longitude - delta,
                                longitude__lte=shop.longitude + delta,
                            )
                    except Shop.DoesNotExist:
                        pass
        search = self.request.query_params.get('search', '').strip()
        if search:
            queryset = queryset.filter(
                Q(user__username__icontains=search)
                | Q(user__first_name__icontains=search)
                | Q(user__last_name__icontains=search)
                | Q(city__icontains=search)
                | Q(user__shops__name__icontains=search)
            ).distinct()
        if self.request.user.is_authenticated:
            queryset = queryset.exclude(user=self.request.user)
        queryset = queryset.order_by('user__username', '-updated_at', '-id').distinct()
        return queryset

    def list(self, request, *args, **kwargs):
        response = super().list(request, *args, **kwargs)
        search = request.query_params.get('search', '').strip()
        if response.status_code == status.HTTP_200_OK and search:
            rows = response.data.get('results', response.data)
            _record_profile_analytics(
                'search_appearance',
                [
                    row['user'].get('id')
                    for row in rows
                    if isinstance(row, dict) and isinstance(row.get('user'), dict)
                ],
                viewer_id=request.user.pk if request.user.is_authenticated else None,
            )
        return response


class ProducerReviewViewSet(viewsets.ModelViewSet):
    queryset = ProducerReview.objects.select_related('producer', 'user').all()
    serializer_class = ProducerReviewSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]
    pagination_class = SmallPageNumberPagination

    def get_queryset(self):
        queryset = self.queryset.order_by('-created_at')
        producer_id = self.request.query_params.get('producer_id')
        if producer_id:
            queryset = queryset.filter(producer__id=producer_id)
        return queryset

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        producer = serializer.validated_data['producer']
        if producer == request.user:
            raise ValidationError({'producer_id': 'Vous ne pouvez pas noter votre propre profil.'})
        existing = ProducerReview.objects.filter(user=request.user, producer=producer).first()
        if existing:
            existing.rating = serializer.validated_data.get('rating', existing.rating)
            existing.comment = serializer.validated_data.get('comment', existing.comment)
            existing.save()
            output = self.get_serializer(existing)
            return Response(output.data, status=status.HTTP_200_OK)
        self.perform_create(serializer)
        headers = self.get_success_headers(serializer.data)
        return Response(serializer.data, status=status.HTTP_201_CREATED, headers=headers)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class NotificationViewSet(viewsets.ModelViewSet):
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user)

    @action(detail=False, methods=['post'])
    def mark_all_read(self, request):
        updated = self.get_queryset().filter(is_read=False).update(is_read=True)
        return Response({'updated': updated})

    @action(detail=True, methods=['post'])
    def mark_read(self, request, pk=None):
        notification = self.get_object()
        notification.is_read = True
        notification.save()
        return Response({'status': 'marked as read'})


# ViewSets pour le réseau social
class FollowViewSet(viewsets.ModelViewSet):
    serializer_class = FollowSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Follow.objects.filter(follower=self.request.user)

    def perform_create(self, serializer):
        serializer.save(follower=self.request.user)


class FriendViewSet(viewsets.ModelViewSet):
    serializer_class = FriendSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Friend.objects.filter(Q(requester=self.request.user) | Q(receiver=self.request.user))

    @action(detail=False, methods=['get'], permission_classes=[permissions.IsAuthenticated])
    def pending_count(self, request):
        count = Friend.objects.filter(
            receiver=request.user,
            status='pending',
        ).count()
        return Response({'count': count})

    def perform_create(self, serializer):
        receiver = serializer.validated_data.get('receiver')
        requester = self.request.user
        if receiver == requester:
            raise ValidationError({'receiver_id': 'Vous ne pouvez pas envoyer une demande à vous-même.'})

        with transaction.atomic():
            list(
                User.objects.select_for_update()
                .filter(pk__in=sorted((requester.pk, receiver.pk)))
                .order_by('pk')
            )
            relationship = Friend.objects.filter(
                Q(requester=requester, receiver=receiver)
                | Q(requester=receiver, receiver=requester),
                status__in=('pending', 'accepted'),
            ).first()
            if relationship:
                raise ValidationError({
                    'detail': 'Une demande est déjà en attente ou vous êtes déjà amis.'
                })

            friend, created = Friend.objects.get_or_create(
                requester=requester,
                receiver=receiver,
                defaults={'status': 'pending'},
            )
            if not created:
                friend.status = 'pending'
                friend.save(update_fields=('status', 'updated_at'))
            serializer.instance = friend

            Notification.objects.create(
                user=receiver,
                title='Nouvelle demande de contact',
                message=f'{requester.username} vous a envoyé une demande.',
                type='friend_request',
                data={
                    'requester_id': requester.id,
                    'requester_username': requester.username,
                    'friend_request_id': friend.id,
                },
            )

    @action(detail=True, methods=['post'])
    def accept(self, request, pk=None):
        friend = self.get_object()
        if friend.receiver != request.user:
            return Response({'detail': 'Accès refusé.'}, status=status.HTTP_403_FORBIDDEN)
        if friend.status != 'pending':
            return Response({'detail': 'Cette demande ne peut pas être acceptée.'}, status=status.HTTP_400_BAD_REQUEST)
        friend.status = 'accepted'
        friend.save()
        self._mark_request_notification_resolved(friend)
        serializer = self.get_serializer(friend)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def decline(self, request, pk=None):
        friend = self.get_object()
        if friend.receiver != request.user:
            return Response({'detail': 'Accès refusé.'}, status=status.HTTP_403_FORBIDDEN)
        if friend.status != 'pending':
            return Response({'detail': 'Cette demande ne peut pas être déclinée.'}, status=status.HTTP_400_BAD_REQUEST)
        friend.status = 'declined'
        friend.save()
        self._mark_request_notification_resolved(friend)
        serializer = self.get_serializer(friend)
        return Response(serializer.data)

    def _mark_request_notification_resolved(self, friend):
        notifications = Notification.objects.filter(
            user=friend.receiver,
            type='friend_request',
            data__friend_request_id=friend.id,
        )
        for notification in notifications:
            notification.data = {
                **(notification.data or {}),
                'status': friend.status,
            }
            notification.is_read = True
            notification.save(update_fields=('data', 'is_read', 'updated_at'))


class PostViewSet(viewsets.ModelViewSet):
    serializer_class = PostSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly, IsOwnerOrReadOnly]
    parser_classes = (MultiPartParser, FormParser, JSONParser)
    pagination_class = SmallPageNumberPagination

    def get_queryset(self):
        # Toutes les publications publiques sont visibles par tout le monde
        return Post.objects.filter(is_active=True, privacy='public').order_by('-created_at')

    def list(self, request, *args, **kwargs):
        queryset = self.filter_queryset(self.get_queryset())
        page = self.paginate_queryset(queryset)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            response = self.get_paginated_response(serializer.data)
            posts = page
        else:
            posts = list(queryset)
            serializer = self.get_serializer(posts, many=True)
            response = Response(serializer.data)
        if response.status_code == status.HTTP_200_OK:
            _record_post_impressions(
                posts,
                viewer_id=request.user.pk if request.user.is_authenticated else None,
            )
        return response

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context

    def create(self, request, *args, **kwargs):
        request_data = request.data.copy()
        if request.FILES:
            request_data.pop('images', None)
            request_data.pop('images[]', None)

        serializer = self.get_serializer(data=request_data)
        serializer.is_valid(raise_exception=True)
        self.perform_create(serializer)
        headers = self.get_success_headers(serializer.data)
        return Response(self.get_serializer(serializer.instance).data, status=status.HTTP_201_CREATED, headers=headers)

    def perform_create(self, serializer):
        repost_of = serializer.validated_data.get('repost_of')
        if repost_of:
            if not serializer.validated_data.get('image') and repost_of.image:
                serializer.validated_data['image'] = repost_of.image
            if not serializer.validated_data.get('video') and repost_of.video:
                serializer.validated_data['video'] = repost_of.video
            if not serializer.validated_data.get('category') and repost_of.category:
                serializer.validated_data['category'] = repost_of.category
            repost_of.shares_count = (repost_of.shares_count or 0) + 1
            repost_of.save(update_fields=['shares_count'])

        post = serializer.save(author=self.request.user, is_active=True)
        self._attach_uploaded_images(post)

    def _attach_uploaded_images(self, post):
        request = self.request
        if not request.FILES:
            return

        images = list(request.FILES.getlist('images'))
        if not images:
            images = list(request.FILES.getlist('images[]'))

        if images:
            image_urls = []
            for image in images:
                filename = f'posts/{post.id}/{uuid4().hex}_{image.name}'
                path = default_storage.save(filename, image)
                url = default_storage.url(path)
                if getattr(request, '_request', None) is not None:
                    url = request._request.build_absolute_uri(url)
                image_urls.append(url)

            post.images = image_urls
            if len(image_urls) > 1:
                post.post_type = 'album'
            elif len(image_urls) == 1 and post.post_type == 'text':
                post.post_type = 'image'

            if len(image_urls) == 1 and not post.image:
                post.image = images[0]

            update_fields = ['images', 'post_type']
            if post.image:
                update_fields.append('image')
            post.save(update_fields=update_fields)
            return

        if request.FILES.get('image') and post.image and not post.images:
            image_url = post.image.url
            if not image_url.startswith('http') and getattr(request, '_request', None) is not None:
                image_url = request._request.build_absolute_uri(image_url)
            post.images = [image_url]
            if post.post_type == 'text':
                post.post_type = 'image'
            post.save(update_fields=['images', 'post_type'])
            return

        # support image_1, image_2, ... names if needed
        image_urls = []
        image_index = 1
        while f'image_{image_index}' in request.FILES:
            image = request.FILES[f'image_{image_index}']
            filename = f'posts/{post.id}/{uuid4().hex}_{image.name}'
            path = default_storage.save(filename, image)
            url = default_storage.url(path)
            if getattr(request, '_request', None) is not None:
                url = request._request.build_absolute_uri(url)
            image_urls.append(url)
            image_index += 1

        if image_urls:
            post.images = image_urls
            if len(image_urls) > 1:
                post.post_type = 'album'
            elif len(image_urls) == 1 and post.post_type == 'text':
                post.post_type = 'image'

            if len(image_urls) == 1 and not post.image:
                post.image = request.FILES.get('image_1')

            update_fields = ['images', 'post_type']
            if post.image:
                update_fields.append('image')
            post.save(update_fields=update_fields)

    def perform_update(self, serializer):
        serializer.save()

    def perform_destroy(self, instance):
        instance.is_active = False
        instance.save()


class LikeViewSet(viewsets.ModelViewSet):
    serializer_class = LikeSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Like.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        post = serializer.validated_data.get('post')
        existing_like = Like.objects.filter(user=self.request.user, post=post).first()
        if existing_like:
            # Si le like existe déjà, on renvoie une réponse claire plutôt que d'échouer
            raise ValidationError({'detail': 'Vous avez déjà aimé ce post.'})
        serializer.save(user=self.request.user)


class CommentViewSet(viewsets.ModelViewSet):
    serializer_class = CommentSerializer
    permission_classes = [
        permissions.IsAuthenticatedOrReadOnly,
        IsOwnerOrReadOnly,
    ]

    def get_queryset(self):
        queryset = Comment.objects.all()
        post_id = self.request.query_params.get('post')
        if post_id:
            queryset = queryset.filter(post__id=post_id)
        return queryset

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


# ViewSets pour coupons et fidélité
class CouponViewSet(viewsets.ModelViewSet):
    queryset = Coupon.objects.filter(is_active=True)
    serializer_class = CouponSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]


class LoyaltyProgramViewSet(viewsets.ModelViewSet):
    serializer_class = LoyaltyProgramSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return LoyaltyProgram.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class ReferralViewSet(viewsets.ModelViewSet):
    serializer_class = ReferralSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Referral.objects.filter(referrer=self.request.user)

    def perform_create(self, serializer):
        serializer.save(referrer=self.request.user)


class SeedDataView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, format=None):
        if not request.user.is_staff:
            return Response({'detail': 'Accès refusé.'}, status=403)

        created = load_sample_data()
        return Response({'detail': 'Données d’exemple générées.', 'created': created})


class FavoriteViewSet(viewsets.ModelViewSet):
    serializer_class = FavoriteSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Favorite.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    @action(detail=False, methods=['post'])
    def toggle(self, request):
        product_id = request.data.get('product_id')
        if not product_id:
            return Response({'detail': 'product_id requis.'}, status=400)

        try:
            product = Product.objects.get(id=product_id)
        except Product.DoesNotExist:
            return Response({'detail': 'Produit non trouvé.'}, status=404)

        favorite, created = Favorite.objects.get_or_create(
            user=request.user,
            product=product,
            defaults={'user': request.user, 'product': product}
        )

        if not created:
            favorite.delete()
            return Response({'action': 'removed', 'is_favorited': False})

        return Response({'action': 'added', 'is_favorited': True})


class ProductViewViewSet(viewsets.ModelViewSet):
    serializer_class = ProductViewSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return ProductView.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class RecommendationViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = RecommendationSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Recommendation.objects.filter(user=self.request.user).order_by('-score')

    @action(detail=False, methods=['post'])
    def generate(self, request):
        """Generate personalized recommendations for the user"""
        user = request.user

        # Clear old recommendations
        Recommendation.objects.filter(user=user).delete()

        recommendations = []

        # 1. Based on user's favorites
        user_favorites = Favorite.objects.filter(user=user).values_list('product__category', flat=True)
        if user_favorites:
            similar_products = Product.objects.filter(
                category__in=user_favorites
            ).exclude(
                favorited_by__user=user
            ).distinct()[:10]

            for product in similar_products:
                recommendations.append(Recommendation(
                    user=user,
                    product=product,
                    score=0.8,
                    reason='based_on_favorites'
                ))

        # 2. Popular products (high favorite count)
        popular_products = Product.objects.annotate(
            fav_count=models.Count('favorited_by')
        ).filter(fav_count__gt=0).exclude(
            favorited_by__user=user
        ).order_by('-fav_count')[:5]

        for product in popular_products:
            if not any(r.product == product for r in recommendations):
                recommendations.append(Recommendation(
                    user=user,
                    product=product,
                    score=0.6,
                    reason='popular'
                ))

        # 3. New products from followed producers
        followed_producers = Follow.objects.filter(follower=user).values_list('followed', flat=True)
        if followed_producers:
            new_products = Product.objects.filter(
                shop__owner__in=followed_producers
            ).exclude(
                favorited_by__user=user
            ).order_by('-created_at')[:5]

            for product in new_products:
                if not any(r.product == product for r in recommendations):
                    recommendations.append(Recommendation(
                        user=user,
                        product=product,
                        score=0.7,
                        reason='from_followed_producer'
                    ))

        # Save recommendations
        Recommendation.objects.bulk_create(recommendations)

        return Response({
            'detail': f'{len(recommendations)} recommandations générées.',
            'count': len(recommendations)
        })


# Nouveaux ViewSets pour le réseau social étendu
class ShareViewSet(viewsets.ModelViewSet):
    serializer_class = ShareSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Share.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)


class JobPostingViewSet(viewsets.ModelViewSet):
    serializer_class = JobPostingSerializer
    permission_classes = [permissions.IsAuthenticated]
    http_method_names = ['get', 'post', 'head', 'options']

    def get_queryset(self):
        return JobPosting.objects.filter(is_active=True).order_by('-created_at')

    def perform_create(self, serializer):
        serializer.save(employer=self.request.user)


class JobSeekerPostViewSet(viewsets.ModelViewSet):
    serializer_class = JobSeekerPostSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser, JSONParser]
    http_method_names = ['get', 'post', 'head', 'options']

    def get_queryset(self):
        return JobSeekerPost.objects.filter(is_active=True).select_related(
            'author',
        )

    def perform_create(self, serializer):
        serializer.save(author=self.request.user)

    @action(detail=True, methods=['get'], url_path='resume-links')
    def resume_links(self, request, pk=None):
        post = self.get_object()
        is_recruiter = JobPosting.objects.filter(
            employer=request.user,
            is_active=True,
        ).exists()
        if (
            request.user != post.author
            and not request.user.is_staff
            and not is_recruiter
        ):
            return Response(
                {'detail': 'Réservé aux recruteurs et au candidat.'},
                status=status.HTTP_403_FORBIDDEN,
            )
        if not post.resume:
            return Response(
                {'detail': 'Ce candidat n’a pas joint de CV.'},
                status=status.HTTP_404_NOT_FOUND,
            )
        return Response(_job_resume_links(request, 'job_seeker_post', post.pk))


class JobApplicationViewSet(viewsets.ModelViewSet):
    serializer_class = JobApplicationSerializer
    permission_classes = [permissions.IsAuthenticated]
    parser_classes = (MultiPartParser, FormParser, JSONParser)
    http_method_names = ['get', 'post', 'head', 'options']

    def get_queryset(self):
        user = self.request.user
        return JobApplication.objects.filter(
            Q(applicant=user) | Q(job__employer=user),
        ).select_related('applicant', 'job', 'job__employer').distinct()

    @action(detail=True, methods=['get'], url_path='resume-links')
    def resume_links(self, request, pk=None):
        application = self.get_object()
        if not application.resume:
            return Response(
                {'detail': 'Cette candidature ne contient pas de CV.'},
                status=status.HTTP_404_NOT_FOUND,
            )
        return Response(
            _job_resume_links(request, 'job_application', application.pk),
        )

    def perform_create(self, serializer):
        with transaction.atomic():
            job = get_object_or_404(
                JobPosting.objects.select_for_update(),
                pk=serializer.validated_data['job'].pk,
                is_active=True,
            )
            if JobApplication.objects.filter(
                applicant=self.request.user,
                job=job,
            ).exists():
                raise ValidationError({
                    'job_id': 'Vous avez déjà postulé à cette offre.',
                })
            application = serializer.save(
                applicant=self.request.user,
                job=job,
            )
            job.applications_count += 1
            job.save(update_fields=('applications_count', 'updated_at'))
            Notification.objects.create(
                user=job.employer,
                title='Nouvelle candidature',
                message=(
                    f'{self.request.user.get_full_name().strip() or self.request.user.username} '
                    f'a postulé à votre offre « {job.title} ».'
                ),
                type='job_application',
                data={
                    'job_id': job.pk,
                    'job_application_id': application.pk,
                    'applicant_id': self.request.user.pk,
                },
            )


def _job_resume_links(request, kind, object_id):
    token = signing.dumps(
        {'kind': kind, 'id': object_id},
        salt='core.job-resume',
    )
    path = reverse('job_resume_file')
    return {
        'view_url': request.build_absolute_uri(
            f'{path}?{urlencode({"token": token})}',
        ),
        'download_url': request.build_absolute_uri(
            f'{path}?{urlencode({"token": token, "download": "1"})}',
        ),
    }


class JobResumeFileView(APIView):
    permission_classes = (permissions.AllowAny,)

    def get(self, request):
        token = request.query_params.get('token', '')
        try:
            payload = signing.loads(
                token,
                salt='core.job-resume',
                max_age=15 * 60,
            )
        except signing.BadSignature:
            raise Http404('Lien de CV invalide ou expiré.')

        kind = payload.get('kind')
        object_id = payload.get('id')
        if kind == 'job_application':
            instance = get_object_or_404(JobApplication, pk=object_id)
        elif kind == 'job_seeker_post':
            instance = get_object_or_404(JobSeekerPost, pk=object_id)
        else:
            raise Http404('Lien de CV invalide.')
        if not instance.resume:
            raise Http404('CV introuvable.')

        resume = instance.resume
        resume.open('rb')
        content_type = (
            'application/pdf'
            if resume.name.lower().endswith('.pdf')
            else 'image/png'
            if resume.name.lower().endswith('.png')
            else 'image/jpeg'
        )
        return FileResponse(
            resume,
            as_attachment=request.query_params.get('download') == '1',
            filename=resume.name.rsplit('/', 1)[-1],
            content_type=content_type,
        )


# ViewSets pour les Stories éphémères
class StoryViewSet(viewsets.ModelViewSet):
    serializer_class = StorySerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]
    parser_classes = (MultiPartParser, FormParser, JSONParser)

    def get_serializer_class(self):
        if self.action == 'create':
            return StoryCreateSerializer
        return StorySerializer

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context

    def get_queryset(self):
        # Retourner les stories actives et non expirées des utilisateurs suivis + les siennes
        from django.utils import timezone
        user = self.request.user

        if user.is_authenticated:
            # Stories de l'utilisateur lui-même
            user_stories = Story.objects.filter(
                author=user,
                is_active=True,
                expires_at__gt=timezone.now()
            )

            # Stories des utilisateurs suivis
            followed_users = Follow.objects.filter(follower=user).values_list('followed', flat=True)
            followed_stories = Story.objects.filter(
                author__in=followed_users,
                is_active=True,
                expires_at__gt=timezone.now()
            )

            # Combiner et trier par date de création
            return (user_stories | followed_stories).distinct().order_by('-created_at')
        else:
            # Pour les utilisateurs non authentifiés, retourner toutes les stories actives
            return Story.objects.filter(
                is_active=True,
                expires_at__gt=timezone.now()
            ).order_by('-created_at')

    def perform_create(self, serializer):
        serializer.save(author=self.request.user)

    @action(detail=True, methods=['post'])
    def view(self, request, pk=None):
        """Marquer une story comme vue"""
        story = self.get_object()
        view_obj, created = StoryView.objects.get_or_create(
            viewer=request.user,
            story=story
        )

        # Incrémenter le compteur de vues
        if created:
            story.views_count += 1
            story.save()

        serializer = StoryViewSerializer(view_obj)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def like(self, request, pk=None):
        """Aimer ou désaimer une story"""
        story = self.get_object()
        like_obj, created = StoryLike.objects.get_or_create(
            user=request.user,
            story=story
        )

        if not created:
            # Si déjà aimé, supprimer le like
            like_obj.delete()
            likes_count = story.likes.count()
            return Response({'action': 'unliked', 'is_liked': False, 'likes_count': likes_count})

        serializer = StoryLikeSerializer(like_obj)
        likes_count = story.likes.count()
        return Response({
            'action': 'liked',
            'is_liked': True,
            'likes_count': likes_count,
            'like': serializer.data
        })

    @action(detail=False, methods=['get'])
    def my_stories(self, request):
        """Retourner les stories de l'utilisateur connecté"""
        from django.utils import timezone
        stories = Story.objects.filter(
            author=request.user,
            is_active=True,
            expires_at__gt=timezone.now()
        ).order_by('-created_at')

        serializer = self.get_serializer(stories, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['get'])
    def viewers(self, request, pk=None):
        """Retourner la liste des visioneurs d'une story"""
        story = self.get_object()
        viewers = story.views.all().values(
            'viewer__username',
            'viewer__profile__profile_image',
            'created_at'
        ).annotate(
            username=F('viewer__username'),
            profile_image=F('viewer__profile__profile_image'),
            viewed_at=F('created_at')
        ).values('username', 'profile_image', 'viewed_at')

        return Response(list(viewers))

    @action(detail=False, methods=['delete'])
    def delete_expired(self, request):
        """Supprimer les stories expirées (admin seulement)"""
        if not request.user.is_staff:
            return Response({'detail': 'Accès refusé.'}, status=403)

        from django.utils import timezone
        expired_stories = Story.objects.filter(
            expires_at__lte=timezone.now(),
            is_active=True
        )

        count = expired_stories.update(is_active=False)
        return Response({'detail': f'{count} stories expirées supprimées.'})


# Views pour les groupes/communautés
def _refresh_group_member_count(group):
    group.member_count = group.members.filter(is_active=True).count()
    group.save(update_fields=['member_count'])


class GroupViewSet(viewsets.ModelViewSet):
    queryset = Group.objects.filter(is_active=True)
    serializer_class = GroupSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly, CanAccessSecretGroup]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_permissions(self):
        if self.action in ['update', 'partial_update', 'destroy']:
            permission_classes = [permissions.IsAuthenticated, IsGroupAdminOrReadOnly, CanAccessSecretGroup]
        else:
            permission_classes = [permissions.IsAuthenticatedOrReadOnly, CanAccessSecretGroup]
        return [permission() for permission in permission_classes]

    def get_serializer_class(self):
        if self.action == 'create':
            return GroupCreateSerializer
        return GroupSerializer

    def get_queryset(self):
        queryset = Group.objects.filter(is_active=True)
        
        # Masquer les groupes secrets pour les non-membres
        if self.request.user and self.request.user.is_authenticated:
            # L'utilisateur connecté voit ses groupes secrets + groupes publics/privés
            from django.db.models import Q
            secret_groups_user_is_member = GroupMember.objects.filter(
                user=self.request.user,
                is_active=True,
                group__group_type='secret'
            ).values_list('group_id', flat=True)
            
            queryset = queryset.filter(
                Q(group_type__in=['public', 'private']) |
                Q(id__in=secret_groups_user_is_member)
            )
        else:
            # Non connecté: voir seulement groupes publics/privés
            queryset = queryset.filter(group_type__in=['public', 'private'])
        
        search = self.request.query_params.get('search', None)
        category = self.request.query_params.get('category', None)
        group_type = self.request.query_params.get('type', None)
        location = self.request.query_params.get('location', None)

        if search:
            queryset = queryset.filter(
                Q(name__icontains=search) |
                Q(description__icontains=search) |
                Q(category__name__icontains=search)
            )
        if category:
            queryset = queryset.filter(category_id=category)
        if group_type:
            queryset = queryset.filter(group_type=group_type)
        if location:
            queryset = queryset.filter(location__icontains=location)

        return queryset.order_by('-created_at')

    def perform_create(self, serializer):
        group = serializer.save()
        # Créer automatiquement une adhésion pour le créateur avec le rôle admin
        GroupMember.objects.create(
            group=group,
            user=self.request.user,
            role='admin',
            is_active=True
        )
        _refresh_group_member_count(group)

    def get_object(self):
        """Override pour vérifier les permissions sur le groupe secret"""
        obj = super().get_object()
        self.check_object_permissions(self.request, obj)
        return obj

    @action(detail=True, methods=['post'])
    def join(self, request, pk=None):
        """Rejoindre un groupe"""
        group = self.get_object()
        user = request.user

        # Vérifier si l'utilisateur est déjà membre ou en attente
        existing_membership = GroupMember.objects.filter(group=group, user=user).first()
        if existing_membership:
            if existing_membership.is_active:
                return Response({'detail': 'Vous êtes déjà membre de ce groupe.'}, status=400)
            return Response({'detail': 'Votre demande d’adhésion est en attente.'}, status=400)

        # Créer la demande d'adhésion
        is_active = group.group_type == 'public'
        membership = GroupMember.objects.create(
            group=group,
            user=user,
            role='member',
            is_active=is_active
        )

        _refresh_group_member_count(group)
        serializer = GroupMemberSerializer(membership)
        return Response(serializer.data, status=201)

    @action(detail=True, methods=['post'])
    def leave(self, request, pk=None):
        """Quitter un groupe"""
        group = self.get_object()
        user = request.user

        membership = GroupMember.objects.filter(group=group, user=user, is_active=True).first()
        if not membership:
            return Response({'detail': 'Vous n\'êtes pas membre de ce groupe.'}, status=400)

        # Ne pas permettre au créateur de quitter son propre groupe
        if group.creator == user:
            return Response({'detail': 'Le créateur ne peut pas quitter son groupe.'}, status=400)

        membership.delete()
        _refresh_group_member_count(group)
        return Response({'detail': 'Vous avez quitté le groupe.'})

    @action(detail=True, methods=['get'])
    def members(self, request, pk=None):
        """Lister les membres du groupe"""
        group = self.get_object()
        memberships = group.members.filter(is_active=True).order_by('-joined_at')
        page = self.paginate_queryset(memberships)
        if page is not None:
            serializer = GroupMemberSerializer(page, many=True)
            return self.get_paginated_response(serializer.data)

        serializer = GroupMemberSerializer(memberships, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['get'])
    def pending_members(self, request, pk=None):
        """Lister les demandes d'adhésion en attente (pour modérateurs/admins)"""
        group = self.get_object()
        user_membership = group.members.filter(user=request.user, is_active=True).first()

        if not user_membership or user_membership.role not in ['moderator', 'admin']:
            return Response({'detail': 'Accès refusé.'}, status=403)

        memberships = group.members.filter(is_active=False).order_by('joined_at')
        serializer = GroupMemberSerializer(memberships, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def approve_member(self, request, pk=None):
        """Approuver une demande d'adhésion (pour modérateurs/admins)"""
        group = self.get_object()
        member_id = request.data.get('member_id')

        user_membership = group.members.filter(user=request.user, is_active=True).first()
        if not user_membership or user_membership.role not in ['moderator', 'admin']:
            return Response({'detail': 'Accès refusé.'}, status=403)

        try:
            membership = GroupMember.objects.get(id=member_id, group=group, is_active=False)
            membership.is_active = True
            membership.save()
            _refresh_group_member_count(group)
            serializer = GroupMemberSerializer(membership)
            return Response(serializer.data)
        except GroupMember.DoesNotExist:
            return Response({'detail': 'Demande d\'adhésion non trouvée.'}, status=404)

    @action(detail=True, methods=['post'])
    def reject_member(self, request, pk=None):
        """Rejeter une demande d'adhésion (pour modérateurs/admins)"""
        group = self.get_object()
        member_id = request.data.get('member_id')

        user_membership = group.members.filter(user=request.user, is_active=True).first()
        if not user_membership or user_membership.role not in ['moderator', 'admin']:
            return Response({'detail': 'Accès refusé.'}, status=403)

        try:
            membership = GroupMember.objects.get(id=member_id, group=group, is_active=False)
            membership.delete()
            return Response({'detail': 'Demande d\'adhésion rejetée.'})
        except GroupMember.DoesNotExist:
            return Response({'detail': 'Demande d\'adhésion non trouvée.'}, status=404)

    @action(detail=True, methods=['post'])
    def promote(self, request, pk=None):
        """Promouvoir un membre (member → moderator → admin)"""
        group = self.get_object()
        member_id = request.data.get('member_id')

        # Vérifier que l'utilisateur est admin du groupe
        user_membership = group.members.filter(user=request.user, is_active=True).first()
        if not user_membership or user_membership.role != 'admin':
            return Response({'detail': 'Seul un admin peut promouvoir des membres.'}, status=403)

        try:
            membership = GroupMember.objects.get(id=member_id, group=group, is_active=True)
            
            # Ordre de promotion: member → moderator → admin
            roles = ['member', 'moderator', 'admin']
            current_idx = roles.index(membership.role)
            if current_idx < len(roles) - 1:
                membership.role = roles[current_idx + 1]
                membership.save()
                serializer = GroupMemberSerializer(membership)
                return Response(serializer.data)
            else:
                return Response({'detail': f'{membership.user.username} est déjà admin.'}, status=400)
        except GroupMember.DoesNotExist:
            return Response({'detail': 'Membre non trouvé.'}, status=404)

    @action(detail=True, methods=['post'])
    def demote(self, request, pk=None):
        """Rétrograder un membre (admin → moderator → member)"""
        group = self.get_object()
        member_id = request.data.get('member_id')

        # Vérifier que l'utilisateur est admin du groupe
        user_membership = group.members.filter(user=request.user, is_active=True).first()
        if not user_membership or user_membership.role != 'admin':
            return Response({'detail': 'Seul un admin peut rétrograder des membres.'}, status=403)

        try:
            membership = GroupMember.objects.get(id=member_id, group=group, is_active=True)
            
            # Vérifier que ce n'est pas le créateur
            if membership.user == group.creator:
                return Response({'detail': 'Impossible de rétrograder le créateur du groupe.'}, status=400)
            
            # Ordre de rétrogradation: admin → moderator → member
            roles = ['member', 'moderator', 'admin']
            current_idx = roles.index(membership.role)
            if current_idx > 0:
                membership.role = roles[current_idx - 1]
                membership.save()
                serializer = GroupMemberSerializer(membership)
                return Response(serializer.data)
            else:
                return Response({'detail': f'{membership.user.username} est déjà member.'}, status=400)
        except GroupMember.DoesNotExist:
            return Response({'detail': 'Membre non trouvé.'}, status=404)

    @action(detail=True, methods=['post'])
    def invite_member(self, request, pk=None):
        """Inviter un utilisateur dans le groupe"""
        group = self.get_object()
        username = request.data.get('username')
        user_id = request.data.get('user_id')

        user_membership = group.members.filter(user=request.user, is_active=True).first()
        if not user_membership or user_membership.role not in ['moderator', 'admin']:
            return Response({'detail': 'Accès refusé.'}, status=403)

        if not username and not user_id:
            return Response({'detail': 'Le nom d\'utilisateur ou l\'identifiant est requis.'}, status=400)

        try:
            if user_id:
                invited_user = User.objects.get(id=user_id)
            else:
                invited_user = User.objects.get(username__iexact=username)
        except User.DoesNotExist:
            return Response({'detail': 'Utilisateur introuvable.'}, status=404)

        if invited_user == request.user:
            return Response({'detail': 'Vous ne pouvez pas vous inviter vous-même.'}, status=400)

        membership, created = GroupMember.objects.get_or_create(
            group=group,
            user=invited_user,
            defaults={'role': 'member', 'is_active': True}
        )

        if not created:
            if membership.is_active:
                return Response({'detail': 'Cet utilisateur est déjà membre du groupe.'}, status=400)
            membership.is_active = True
            membership.role = 'member'
            membership.save()

        _refresh_group_member_count(group)
        serializer = GroupMemberSerializer(membership)
        return Response(serializer.data, status=201)

    @action(detail=True, methods=['post'])
    def archive(self, request, pk=None):
        """Archiver un groupe pour le désactiver sans le supprimer"""
        group = self.get_object()
        user_membership = group.members.filter(user=request.user, is_active=True).first()
        if not user_membership or user_membership.role != 'admin':
            return Response({'detail': 'Seul un admin peut archiver ce groupe.'}, status=403)

        group.is_active = False
        group.save(update_fields=['is_active'])
        return Response({'detail': 'Le groupe a été archivé.'})

    @action(detail=True, methods=['post'])
    def remove_member(self, request, pk=None):
        """Retirer/bannir un membre du groupe"""
        group = self.get_object()
        member_id = request.data.get('member_id')

        # Vérifier que l'utilisateur est admin ou moderator du groupe
        user_membership = group.members.filter(user=request.user, is_active=True).first()
        if not user_membership or user_membership.role not in ['moderator', 'admin']:
            return Response({'detail': 'Accès refusé.'}, status=403)

        try:
            membership = GroupMember.objects.get(id=member_id, group=group)
            
            # Ne pas permettre de retirer le créateur
            if membership.user == group.creator:
                return Response({'detail': 'Impossible de retirer le créateur du groupe.'}, status=400)
            
            # Ne pas permettre à un moderator de retirer un admin
            if user_membership.role == 'moderator' and membership.role == 'admin':
                return Response({'detail': 'Un modérateur ne peut pas retirer un admin.'}, status=403)
            
            membership.delete()
            _refresh_group_member_count(group)
            return Response({'detail': f'{membership.user.username} a été retiré du groupe.'})
        except GroupMember.DoesNotExist:
            return Response({'detail': 'Membre non trouvé.'}, status=404)

    @action(detail=True, methods=['get'])
    def my_groups(self, request):
        """Lister les groupes de l'utilisateur connecté"""
        memberships = GroupMember.objects.filter(
            user=request.user,
            is_active=True
        ).select_related('group')
        groups = [membership.group for membership in memberships]
        serializer = self.get_serializer(groups, many=True)
        return Response(serializer.data)


class GroupPostViewSet(viewsets.ModelViewSet):
    queryset = GroupPost.objects.filter(is_active=True)
    serializer_class = GroupPostSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly, IsOwnerOrReadOnly]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_serializer_class(self):
        if self.action == 'create':
            return GroupPostCreateSerializer
        elif self.action in ['update', 'partial_update']:
            return GroupPostUpdateSerializer
        return GroupPostSerializer

    def get_queryset(self):
        queryset = GroupPost.objects.filter(is_active=True).select_related('author', 'group')
        group_id = self.request.query_params.get('group', None)

        if group_id:
            queryset = queryset.filter(group_id=group_id)

        if self.request.user.is_authenticated:
            user = self.request.user
            friend_ids = set()
            for friend in Friend.objects.filter(status='accepted').filter(
                models.Q(requester=user) | models.Q(receiver=user)
            ):
                friend_ids.add(friend.requester_id)
                friend_ids.add(friend.receiver_id)
            friend_ids.discard(user.id)

            queryset = queryset.filter(
                models.Q(privacy='public') |
                models.Q(privacy='friends', author=user) |
                models.Q(privacy='friends', author_id__in=friend_ids)
            )
        else:
            queryset = queryset.filter(privacy='public')

        return queryset.order_by('-is_pinned', '-created_at')

    def perform_create(self, serializer):
        repost_of = serializer.validated_data.get('repost_of')
        if repost_of:
            if not serializer.validated_data.get('image') and repost_of.image:
                serializer.validated_data['image'] = repost_of.image
            if not serializer.validated_data.get('video') and repost_of.video:
                serializer.validated_data['video'] = repost_of.video
            if not serializer.validated_data.get('images') and repost_of.images:
                serializer.validated_data['images'] = repost_of.images
            repost_of.shares_count = (repost_of.shares_count or 0) + 1
            repost_of.save(update_fields=['shares_count'])

        post = serializer.save()
        group = post.group
        if group.group_type in ['private', 'secret']:
            membership = GroupMember.objects.filter(
                group=group,
                user=self.request.user,
                is_active=True
            ).first()
            if not membership:
                post.delete()
                raise ValidationError('Vous devez être membre du groupe pour publier.')

    def perform_destroy(self, instance):
        # Soft delete - marquer comme inactif au lieu de supprimer
        instance.is_active = False
        instance.save(update_fields=['is_active'])

    @action(detail=True, methods=['get'])
    def comments(self, request, pk=None):
        """Lister les commentaires d'un post"""
        post = self.get_object()
        comments = post.comments.filter(is_active=True).order_by('created_at')
        serializer = GroupPostCommentSerializer(comments, many=True, context={'request': request})
        return Response(serializer.data)


class GroupPostCommentViewSet(viewsets.ModelViewSet):
    queryset = GroupPostComment.objects.filter(is_active=True)
    serializer_class = GroupPostCommentSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]

    def get_serializer_class(self):
        if self.action == 'create':
            return GroupPostCommentCreateSerializer
        return GroupPostCommentSerializer

    def get_queryset(self):
        queryset = GroupPostComment.objects.filter(is_active=True).select_related('author', 'post')
        post_id = self.request.query_params.get('post', None)

        if post_id:
            queryset = queryset.filter(post_id=post_id)

        return queryset.order_by('created_at')

    def perform_create(self, serializer):
        comment = serializer.save()
        group = comment.post.group
        if group.group_type in ['private', 'secret']:
            membership = GroupMember.objects.filter(
                group=group,
                user=self.request.user,
                is_active=True
            ).first()
            if not membership:
                comment.delete()
                raise ValidationError('Vous devez être membre du groupe pour commenter.')


class GroupEventViewSet(viewsets.ModelViewSet):
    queryset = GroupEvent.objects.filter(is_active=True)
    serializer_class = GroupEventSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get_permissions(self):
        if self.action in ('attend', 'attendees'):
            return [permissions.IsAuthenticated()]
        return super().get_permissions()

    def get_serializer_class(self):
        if self.action == 'create':
            return GroupEventCreateSerializer
        return GroupEventSerializer

    def get_queryset(self):
        queryset = GroupEvent.objects.filter(is_active=True).select_related('creator', 'group')
        group_id = self.request.query_params.get('group', None)

        if group_id:
            queryset = queryset.filter(group_id=group_id)

        return queryset.order_by('start_date')

    def perform_create(self, serializer):
        event = serializer.save()
        if event.group_id:
            membership = GroupMember.objects.filter(
                group=event.group,
                user=self.request.user,
                is_active=True
            ).first()
            if not membership:
                event.delete()
                raise ValidationError('Vous devez être membre du groupe pour créer un événement.')

    @action(detail=True, methods=['post'])
    def attend(self, request, pk=None):
        """Participer à un événement"""
        event = self.get_object()
        user = request.user
        status = request.data.get('status', 'going')

        if event.group_id:
            membership = GroupMember.objects.filter(
                group=event.group,
                user=user,
                is_active=True
            ).first()
            if not membership:
                return Response({'detail': 'Vous devez être membre du groupe pour participer à cet événement.'}, status=403)

        attendee, created = GroupEventAttendee.objects.get_or_create(
            event=event,
            user=user,
            defaults={'status': status}
        )

        if not created:
            attendee.status = status
            attendee.save()

        serializer = GroupEventAttendeeSerializer(attendee)
        return Response(serializer.data, status=201 if created else 200)

    @action(detail=True, methods=['get'])
    def attendees(self, request, pk=None):
        """Lister les participants à un événement"""
        event = self.get_object()
        attendees = event.attendees.filter(status='going').order_by('created_at')
        serializer = GroupEventAttendeeSerializer(attendees, many=True)
        return Response(serializer.data)


# Reels ViewSets
class ReelViewSet(viewsets.ModelViewSet):
    serializer_class = ReelSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]
    parser_classes = (MultiPartParser, FormParser, JSONParser)

    def get_queryset(self):
        return Reel.objects.filter(is_active=True).order_by('-created_at')

    def get_serializer_class(self):
        if self.action == 'create':
            return ReelCreateSerializer
        return ReelSerializer

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context

    def perform_create(self, serializer):
        serializer.save(author=self.request.user)

    @action(detail=True, methods=['post'])
    def like(self, request, pk=None):
        """Aimer ou désaimer un reel"""
        reel = self.get_object()
        like, created = ReelLike.objects.get_or_create(reel=reel, user=request.user)

        if not created:
            like.delete()
            reel.likes_count = max(0, reel.likes_count - 1)
            action = 'unliked'
        else:
            reel.likes_count += 1
            action = 'liked'

        reel.save(update_fields=['likes_count'])
        return Response({'action': action, 'likes_count': reel.likes_count})

    @action(detail=True, methods=['post'])
    def view(self, request, pk=None):
        """Enregistrer une vue sur un reel"""
        reel = self.get_object()
        ReelView.objects.get_or_create(reel=reel, viewer=request.user)
        reel.views_count += 1
        reel.save(update_fields=['views_count'])
        return Response({'views_count': reel.views_count})


class ReelCommentViewSet(viewsets.ModelViewSet):
    serializer_class = ReelCommentSerializer  # À définir
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return ReelComment.objects.filter(is_active=True).order_by('created_at')

    def perform_create(self, serializer):
        serializer.save(author=self.request.user)


# Reactions ViewSet
class ReactionViewSet(viewsets.ModelViewSet):
    serializer_class = ReactionSerializer
    permission_classes = [permissions.IsAuthenticated]

    def get_queryset(self):
        return Reaction.objects.filter(
            models.Q(post__isnull=False) |
            models.Q(group_post__isnull=False) |
            models.Q(reel__isnull=False)
        ).order_by('-created_at')

    def perform_create(self, serializer):
        # Supprimer les réactions existantes de cet utilisateur sur ce contenu
        Reaction.objects.filter(
            user=self.request.user,
            post=serializer.validated_data.get('post'),
            group_post=serializer.validated_data.get('group_post'),
            reel=serializer.validated_data.get('reel')
        ).delete()

        serializer.save(user=self.request.user)


# Marketplace ViewSets
class MarketplaceListingViewSet(viewsets.ModelViewSet):
    serializer_class = MarketplaceListingSerializer
    permission_classes = [permissions.IsAuthenticatedOrReadOnly]
    parser_classes = (MultiPartParser, FormParser, JSONParser)

    def get_queryset(self):
        return MarketplaceListing.objects.filter(is_active=True).order_by('-created_at')

    def get_serializer_context(self):
        context = super().get_serializer_context()
        context['request'] = self.request
        return context

    def perform_create(self, serializer):
        serializer.save(seller=self.request.user)

    @action(detail=True, methods=['post'])
    def favorite(self, request, pk=None):
        """Ajouter ou retirer des favoris"""
        listing = self.get_object()
        favorite, created = MarketplaceFavorite.objects.get_or_create(
            listing=listing, user=request.user
        )

        if not created:
            favorite.delete()
            listing.favorites_count = max(0, listing.favorites_count - 1)
            action = 'unfavorited'
        else:
            listing.favorites_count += 1
            action = 'favorited'

        listing.save(update_fields=['favorites_count'])
        return Response({'action': action, 'favorites_count': listing.favorites_count})

    @action(detail=True, methods=['post'])
    def view(self, request, pk=None):
        """Enregistrer une vue sur une annonce"""
        listing = self.get_object()
        listing.views_count += 1
        listing.save(update_fields=['views_count'])
        return Response({'views_count': listing.views_count})


# Hashtags ViewSet
class HashtagViewSet(viewsets.ReadOnlyModelViewSet):
    serializer_class = HashtagSerializer
    permission_classes = [permissions.AllowAny]

    def get_queryset(self):
        return Hashtag.objects.order_by('-usage_count', '-created_at')

    @action(detail=True, methods=['get'])
    def posts(self, request, pk=None):
        """Récupérer les posts avec ce hashtag"""
        hashtag = self.get_object()
        posts = Post.objects.filter(
            hashtags__icontains=hashtag.name,
            is_active=True
        ).order_by('-created_at')[:50]

        serializer = PostSerializer(posts, many=True, context={'request': request})
        return Response(serializer.data)
