from django.contrib.auth.models import User
from rest_framework.test import APITestCase

from core.models import ProfileRoleChange, UserProfile


class ProfileRoleChangeTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='role-user',
            password='password123',
        )
        self.profile = UserProfile.objects.create(
            user=self.user,
            role='particular',
            is_active=True,
        )
        self.client.force_authenticate(user=self.user)
        self.url = '/api/auth/profile/change-role/'

    def test_profile_role_can_be_changed_three_times_per_month(self):
        roles = ('driver', 'prestataire', 'boutique')
        for role in roles:
            response = self.client.post(self.url, {'role': role}, format='json')
            self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['remaining_changes'], 0)
        self.assertEqual(ProfileRoleChange.objects.filter(user=self.user).count(), 3)

        rejected = self.client.post(
            self.url,
            {'role': 'enterprise'},
            format='json',
        )

        self.assertEqual(rejected.status_code, 400, rejected.data)
        self.profile.refresh_from_db()
        self.assertEqual(self.profile.role, 'boutique')
        self.assertEqual(ProfileRoleChange.objects.filter(user=self.user).count(), 3)

    def test_reselecting_current_role_does_not_use_monthly_quota(self):
        for role in ('driver', 'prestataire', 'boutique'):
            self.client.post(self.url, {'role': role}, format='json')

        response = self.client.post(
            self.url,
            {'role': 'boutique'},
            format='json',
        )

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['remaining_changes'], 0)
        self.assertEqual(ProfileRoleChange.objects.filter(user=self.user).count(), 3)

    def test_generic_profile_update_cannot_bypass_role_change_limit(self):
        response = self.client.patch(
            '/api/auth/profile/',
            {'role': 'driver'},
            format='json',
        )

        self.assertEqual(response.status_code, 400, response.data)
        self.profile.refresh_from_db()
        self.assertEqual(self.profile.role, 'particular')
        self.assertFalse(ProfileRoleChange.objects.filter(user=self.user).exists())

    def test_regular_users_cannot_assign_the_admin_profile_type(self):
        role_response = self.client.post(
            self.url,
            {'role': 'admin'},
            format='json',
        )
        profile_response = self.client.post(
            '/api/auth/profiles/',
            {'role': 'admin'},
            format='json',
        )

        self.assertEqual(role_response.status_code, 400, role_response.data)
        self.assertEqual(profile_response.status_code, 400, profile_response.data)
        self.profile.refresh_from_db()
        self.assertEqual(self.profile.role, 'particular')
        self.assertFalse(ProfileRoleChange.objects.filter(user=self.user).exists())

    def test_switching_profiles_is_counted_as_a_type_change(self):
        other_profile = UserProfile.objects.create(
            user=self.user,
            role='driver',
            is_active=False,
        )

        response = self.client.post(
            '/api/auth/switch-profile/',
            {'profile_id': other_profile.pk},
            format='json',
        )

        self.assertEqual(response.status_code, 200, response.data)
        self.assertEqual(response.data['role'], 'driver')
        self.assertTrue(
            ProfileRoleChange.objects.filter(
                user=self.user,
                old_role='particular',
                new_role='driver',
            ).exists()
        )
