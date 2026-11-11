from datetime import timedelta

from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.test import APITestCase

from core.models import Follow, Post, ProfileAnalyticsEvent, UserProfile


class ProfileAnalyticsTests(APITestCase):
    def setUp(self):
        self.owner = User.objects.create_user(
            username='creator',
            password='password123',
        )
        self.viewer = User.objects.create_user(
            username='viewer',
            password='password123',
        )
        UserProfile.objects.create(user=self.owner, role='particular')
        UserProfile.objects.create(user=self.viewer, role='particular')
        self.client.force_authenticate(user=self.viewer)

    def test_feed_records_other_users_posts_but_not_own_posts(self):
        Post.objects.create(author=self.owner, content='Creator post')
        Post.objects.create(author=self.viewer, content='Viewer post')

        response = self.client.get('/api/posts/')

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(
            ProfileAnalyticsEvent.objects.filter(
                owner=self.owner,
                event_type='post_impression',
            ).count(),
            1,
        )
        self.assertFalse(
            ProfileAnalyticsEvent.objects.filter(
                owner=self.viewer,
                event_type='post_impression',
            ).exists()
        )

    def test_public_profile_view_is_recorded_without_recording_owner_views(self):
        response = self.client.get(f'/api/users/{self.owner.username}/')

        self.assertEqual(response.status_code, 200, response.data)
        self.assertTrue(
            ProfileAnalyticsEvent.objects.filter(
                owner=self.owner,
                event_type='profile_view',
            ).exists()
        )
        self.client.force_authenticate(user=self.owner)
        self.client.get(f'/api/users/{self.owner.username}/')
        self.assertEqual(
            ProfileAnalyticsEvent.objects.filter(
                owner=self.owner,
                event_type='profile_view',
            ).count(),
            1,
        )

    def test_search_records_only_profiles_returned_to_other_users(self):
        response = self.client.get(
            '/api/users/directory/',
            {'search': 'creator'},
        )

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(
            ProfileAnalyticsEvent.objects.filter(
                owner=self.owner,
                event_type='search_appearance',
            ).count(),
            1,
        )
        self.assertFalse(
            ProfileAnalyticsEvent.objects.filter(
                owner=self.viewer,
                event_type='search_appearance',
            ).exists()
        )

    def test_profile_search_records_search_appearances(self):
        response = self.client.get('/api/profiles/', {'search': 'creator'})

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(
            ProfileAnalyticsEvent.objects.filter(
                owner=self.owner,
                event_type='search_appearance',
            ).count(),
            1,
        )

    def test_analytics_endpoint_returns_real_counts_and_comparisons(self):
        now = timezone.now()
        previous_week_event = ProfileAnalyticsEvent.objects.create(
            owner=self.viewer,
            event_type='post_impression',
        )
        previous_week_event.created_at = now - timedelta(days=9)
        previous_week_event.save(update_fields=('created_at',))
        for _ in range(2):
            event = ProfileAnalyticsEvent.objects.create(
                owner=self.viewer,
                event_type='post_impression',
            )
            event.created_at = now - timedelta(days=1)
            event.save(update_fields=('created_at',))
        profile_view = ProfileAnalyticsEvent.objects.create(
            owner=self.viewer,
            event_type='profile_view',
        )
        profile_view.created_at = now - timedelta(days=1)
        profile_view.save(update_fields=('created_at',))
        Follow.objects.create(follower=self.owner, followed=self.viewer)

        response = self.client.get('/api/auth/profile/analytics/')

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['post_impressions_7d'], 2)
        self.assertEqual(response.data['post_impressions_change_percent'], 100)
        self.assertEqual(response.data['followers_total'], 1)
        self.assertEqual(response.data['profile_views_90d'], 1)
        self.assertEqual(response.data['search_appearances_7d'], 0)
        self.assertEqual(len(response.data['weekly_progress']), 7)
        self.assertEqual(
            sum(day['impressions'] for day in response.data['weekly_progress']),
            2,
        )

    def test_analytics_endpoint_requires_authentication(self):
        self.client.force_authenticate(user=None)

        response = self.client.get('/api/auth/profile/analytics/')

        self.assertEqual(response.status_code, 401)
