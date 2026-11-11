from django.urls import path, include
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from .views import RegisterView, CustomTokenObtainPairView, CustomLoginView, MeView, ProfileView, ProfileAnalyticsView, ProfileRoleChangeView, UserProfileDetailView, UserProfilesView, SwitchProfileView, ProfileViewSet, UserDirectoryView, UserPresenceView, UserPublicProfileView, ShopViewSet, CategoryViewSet, ProductViewSet, OrderViewSet, MessageViewSet, NotificationViewSet, FollowViewSet, FriendViewSet, PostViewSet, LikeViewSet, CommentViewSet, ProducerReviewViewSet, CouponViewSet, LoyaltyProgramViewSet, ReferralViewSet, SeedDataView, FavoriteViewSet, ProductViewViewSet, RecommendationViewSet, GoogleAuthView, AppleAuthView, ShareViewSet, JobPostingViewSet, JobSeekerPostViewSet, JobApplicationViewSet, JobResumeFileView, StoryViewSet, GroupViewSet, GroupPostViewSet, GroupPostCommentViewSet, GroupEventViewSet, ReelViewSet, ReactionViewSet, MarketplaceListingViewSet, HashtagViewSet, GameRewardView, GameLegendsView, GameChallengesView, GameChallengePendingCountView, GameChallengeCancelView, GameChallengeDismissView, GameChallengeResponseView, GameChallengeReadyView, GameChallengeScoreView, GameChallengeEliminationView, GameChallengeLiveStateView, GameChallengePublicListView, GameChallengePublicStateView, GameChallengeShareTrophyView, GameChallengeRoundView, GameChallengeRematchView, GameTournamentsView, GameTournamentDetailView, GameTournamentJoinView, GameTournamentInviteView, GameTournamentStartView, GameTournamentSupportView, GameTournamentMatchPlayView, PasswordResetRequestView, PasswordResetConfirmView, LogoutView
from .payments import PaymentViewSet
from .live_streams import LiveStreamDetailView, LiveStreamJoinView, LiveStreamsView

router = DefaultRouter()
router.register(r'shops', ShopViewSet, basename='shop')
router.register(r'categories', CategoryViewSet, basename='category')
router.register(r'products', ProductViewSet, basename='product')
router.register(r'orders', OrderViewSet, basename='order')
router.register(r'payments', PaymentViewSet, basename='payment')
router.register(r'messages', MessageViewSet, basename='message')
router.register(r'notifications', NotificationViewSet, basename='notification')
router.register(r'profiles', ProfileViewSet, basename='profile')
router.register(r'follows', FollowViewSet, basename='follow')
router.register(r'friends', FriendViewSet, basename='friend')
router.register(r'posts', PostViewSet, basename='post')
router.register(r'likes', LikeViewSet, basename='like')
router.register(r'comments', CommentViewSet, basename='comment')
router.register(r'producer-reviews', ProducerReviewViewSet, basename='producerreview')
router.register(r'coupons', CouponViewSet, basename='coupon')
router.register(r'loyalty', LoyaltyProgramViewSet, basename='loyalty')
router.register(r'referrals', ReferralViewSet, basename='referral')
router.register(r'favorites', FavoriteViewSet, basename='favorite')
router.register(r'product-views', ProductViewViewSet, basename='productview')
router.register(r'recommendations', RecommendationViewSet, basename='recommendation')
router.register(r'shares', ShareViewSet, basename='share')
router.register(r'job-postings', JobPostingViewSet, basename='jobposting')
router.register(r'job-seeker-posts', JobSeekerPostViewSet, basename='jobseekerpost')
router.register(r'job-applications', JobApplicationViewSet, basename='jobapplication')
router.register(r'stories', StoryViewSet, basename='story')
router.register(r'groups', GroupViewSet, basename='group')
router.register(r'group-posts', GroupPostViewSet, basename='grouppost')
router.register(r'group-post-comments', GroupPostCommentViewSet, basename='grouppostcomment')
router.register(r'group-events', GroupEventViewSet, basename='groupevent')
router.register(r'reels', ReelViewSet, basename='reel')
router.register(r'reactions', ReactionViewSet, basename='reaction')
router.register(r'marketplace', MarketplaceListingViewSet, basename='marketplace')
router.register(r'hashtags', HashtagViewSet, basename='hashtag')

urlpatterns = [
    path('users/directory/', UserDirectoryView.as_view(), name='user_directory'),
    path('users/presence/', UserPresenceView.as_view(), name='user_presence'),
    path('users/<str:username>/', UserPublicProfileView.as_view(), name='user_public_profile'),
    path('auth/register/', RegisterView.as_view(), name='register'),
    path('auth/login/', CustomLoginView.as_view(), name='custom_login'),
    path('auth/token/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('auth/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/logout/', LogoutView.as_view(), name='logout'),
    path('auth/password-reset/request/', PasswordResetRequestView.as_view(), name='password_reset_request'),
    path('auth/password-reset/confirm/', PasswordResetConfirmView.as_view(), name='password_reset_confirm'),
    path('auth/me/', MeView.as_view(), name='me'),
    path('auth/profile/', ProfileView.as_view(), name='profile'),
    path('auth/profile/analytics/', ProfileAnalyticsView.as_view(), name='profile_analytics'),
    path('auth/profile/change-role/', ProfileRoleChangeView.as_view(), name='profile_role_change'),
    path('game/rewards/level-12/', GameRewardView.as_view(), name='game_level_12_reward'),
    path('game/legends/', GameLegendsView.as_view(), name='game_legends'),
    path('game/tournaments/', GameTournamentsView.as_view(), name='game_tournaments'),
    path('game/tournaments/<int:tournament_id>/', GameTournamentDetailView.as_view(), name='game_tournament_detail'),
    path('game/tournaments/<int:tournament_id>/join/', GameTournamentJoinView.as_view(), name='game_tournament_join'),
    path('game/tournaments/<int:tournament_id>/invite/', GameTournamentInviteView.as_view(), name='game_tournament_invite'),
    path('game/tournaments/<int:tournament_id>/start/', GameTournamentStartView.as_view(), name='game_tournament_start'),
    path('game/tournaments/<int:tournament_id>/support/', GameTournamentSupportView.as_view(), name='game_tournament_support'),
    path('game/tournaments/<int:tournament_id>/matches/<int:match_id>/play/', GameTournamentMatchPlayView.as_view(), name='game_tournament_match_play'),
    path('game/challenges/', GameChallengesView.as_view(), name='game_challenges'),
    path('game/challenges/live/', GameChallengePublicListView.as_view(), name='game_challenges_live'),
    path('game/challenges/live/<int:challenge_id>/', GameChallengePublicStateView.as_view(), name='game_challenge_live_public_state'),
    path('game/challenges/pending-count/', GameChallengePendingCountView.as_view(), name='game_challenge_pending_count'),
    path('game/challenges/<int:challenge_id>/cancel/', GameChallengeCancelView.as_view(), name='game_challenge_cancel'),
    path('game/challenges/<int:challenge_id>/dismiss/', GameChallengeDismissView.as_view(), name='game_challenge_dismiss'),
    path('game/challenges/<int:challenge_id>/respond/', GameChallengeResponseView.as_view(), name='game_challenge_respond'),
    path('game/challenges/<int:challenge_id>/ready/', GameChallengeReadyView.as_view(), name='game_challenge_ready'),
    path('game/challenges/<int:challenge_id>/score/', GameChallengeScoreView.as_view(), name='game_challenge_score'),
    path('game/challenges/<int:challenge_id>/eliminate/', GameChallengeEliminationView.as_view(), name='game_challenge_eliminate'),
    path('game/challenges/<int:challenge_id>/live-state/', GameChallengeLiveStateView.as_view(), name='game_challenge_live_state'),
    path('game/challenges/<int:challenge_id>/share-trophy/', GameChallengeShareTrophyView.as_view(), name='game_challenge_share_trophy'),
    path('game/challenges/<int:challenge_id>/round/', GameChallengeRoundView.as_view(), name='game_challenge_round'),
    path('game/challenges/<int:challenge_id>/rematch/', GameChallengeRematchView.as_view(), name='game_challenge_rematch'),
    path('job-resumes/', JobResumeFileView.as_view(), name='job_resume_file'),
    path('live-streams/', LiveStreamsView.as_view(), name='live_streams'),
    path('live-streams/<str:room_name>/join/', LiveStreamJoinView.as_view(), name='live_stream_join'),
    path('live-streams/<str:room_name>/', LiveStreamDetailView.as_view(), name='live_stream_detail'),
    path('auth/profiles/', UserProfilesView.as_view(), name='user_profiles'),
    path('auth/switch-profile/', SwitchProfileView.as_view(), name='switch_profile'),
    path('auth/google/', GoogleAuthView.as_view(), name='google_auth'),
    path('auth/apple/', AppleAuthView.as_view(), name='apple_auth'),
    path('profiles/<str:username>/', UserProfileDetailView.as_view(), name='user_profile_detail'),
    path('seed-sample-data/', SeedDataView.as_view(), name='seed_sample_data'),
    path('', include(router.urls)),
]
