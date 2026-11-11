from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status
from core.models import Group, GroupMember


class GroupManagementTestCase(TestCase):
    def setUp(self):
        self.admin_user = User.objects.create_user(username='adminuser', password='testpass123')
        self.member_user = User.objects.create_user(username='memberuser', password='testpass123')
        self.invited_user = User.objects.create_user(username='inviteuser', password='testpass123')

        self.group = Group.objects.create(
            name='Test Group',
            description='Test group description',
            group_type='private',
            creator=self.admin_user
        )
        GroupMember.objects.create(group=self.group, user=self.admin_user, role='admin', is_active=True)
        GroupMember.objects.create(group=self.group, user=self.member_user, role='member', is_active=True)

        self.client = APIClient()

    def test_archive_group_as_admin(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.post(f'/api/groups/{self.group.id}/archive/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.group.refresh_from_db()
        self.assertFalse(self.group.is_active)

    def test_cannot_archive_group_as_member(self):
        self.client.force_authenticate(user=self.member_user)
        response = self.client.post(f'/api/groups/{self.group.id}/archive/')

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.group.refresh_from_db()
        self.assertTrue(self.group.is_active)

    def test_invite_member_creates_active_membership(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.post(
            f'/api/groups/{self.group.id}/invite_member/',
            {'username': self.invited_user.username},
            format='json'
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        membership = GroupMember.objects.filter(group=self.group, user=self.invited_user).first()
        self.assertIsNotNone(membership)
        self.assertTrue(membership.is_active)
        self.assertEqual(membership.role, 'member')

    def test_invite_member_requires_username(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.post(
            f'/api/groups/{self.group.id}/invite_member/',
            {},
            format='json'
        )

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)

    def test_join_group_public_updates_member_count(self):
        public_group = Group.objects.create(
            name='Public Group',
            description='Public group description',
            group_type='public',
            creator=self.admin_user
        )
        GroupMember.objects.create(group=public_group, user=self.admin_user, role='admin', is_active=True)

        self.client.force_authenticate(user=self.member_user)
        response = self.client.post(f'/api/groups/{public_group.id}/join/')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        public_group.refresh_from_db()
        self.assertEqual(public_group.member_count, 2)
