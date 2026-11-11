from django.test import TestCase
from django.contrib.auth.models import User
from rest_framework.test import APIClient
from rest_framework import status
from core.models import Group, GroupPost, GroupMember


class GroupPostEditDeleteTestCase(TestCase):
    def setUp(self):
        # Créer des utilisateurs
        self.author = User.objects.create_user(username='author1', password='testpass123')
        self.other_user = User.objects.create_user(username='other1', password='testpass123')
        
        # Créer un groupe
        self.group = Group.objects.create(
            name='Test Group',
            description='Test group description',
            group_type='public',
            creator=self.author
        )
        
        # Ajouter les utilisateurs au groupe
        GroupMember.objects.create(group=self.group, user=self.author, is_active=True)
        GroupMember.objects.create(group=self.group, user=self.other_user, is_active=True)
        
        # Créer un post
        self.post = GroupPost.objects.create(
            group=self.group,
            author=self.author,
            content='Test post',
            post_type='text',
            privacy='public'
        )
        
        self.client = APIClient()

    def test_edit_own_post(self):
        """L'auteur peut modifier son propre post"""
        self.client.force_authenticate(user=self.author)
        
        response = self.client.patch(
            f'/api/group-posts/{self.post.id}/',
            {'content': 'Updated content'},
            format='json'
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.post.refresh_from_db()
        self.assertEqual(self.post.content, 'Updated content')

    def test_cannot_edit_others_post(self):
        """Impossible de modifier le post d'un autre utilisateur"""
        self.client.force_authenticate(user=self.other_user)
        
        response = self.client.patch(
            f'/api/group-posts/{self.post.id}/',
            {'content': 'Updated content'},
            format='json'
        )
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.post.refresh_from_db()
        self.assertEqual(self.post.content, 'Test post')

    def test_delete_own_post(self):
        """L'auteur peut supprimer son propre post"""
        self.client.force_authenticate(user=self.author)
        post_id = self.post.id
        
        response = self.client.delete(f'/api/group-posts/{post_id}/')
        
        self.assertEqual(response.status_code, status.HTTP_204_NO_CONTENT)
        
        # Vérifier que le post est marqué comme inactif (soft delete)
        self.post.refresh_from_db()
        self.assertFalse(self.post.is_active)

    def test_cannot_delete_others_post(self):
        """Impossible de supprimer le post d'un autre utilisateur"""
        self.client.force_authenticate(user=self.other_user)
        
        response = self.client.delete(f'/api/group-posts/{self.post.id}/')
        
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.post.refresh_from_db()
        self.assertTrue(self.post.is_active)

    def test_edit_post_with_image(self):
        """Modifier un post avec une image"""
        from django.core.files.uploadedfile import SimpleUploadedFile
        
        # Créer un post avec image
        image = SimpleUploadedFile(
            "test.jpg",
            b"file_content",
            content_type="image/jpeg"
        )
        post_with_image = GroupPost.objects.create(
            group=self.group,
            author=self.author,
            content='Post with image',
            post_type='image',
            privacy='public',
            image=image
        )
        
        self.client.force_authenticate(user=self.author)
        
        response = self.client.patch(
            f'/api/group-posts/{post_with_image.id}/',
            {'content': 'Updated post with image'},
            format='json'
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        post_with_image.refresh_from_db()
        self.assertEqual(post_with_image.content, 'Updated post with image')

    def test_edit_post_privacy(self):
        """Modifier la confidentialité du post"""
        self.client.force_authenticate(user=self.author)
        
        response = self.client.patch(
            f'/api/group-posts/{self.post.id}/',
            {'privacy': 'friends'},
            format='json'
        )
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.post.refresh_from_db()
        self.assertEqual(self.post.privacy, 'friends')

    def test_unauthenticated_cannot_edit(self):
        """Un utilisateur non authentifié ne peut pas modifier"""
        response = self.client.patch(
            f'/api/group-posts/{self.post.id}/',
            {'content': 'Updated content'},
            format='json'
        )
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)

    def test_unauthenticated_cannot_delete(self):
        """Un utilisateur non authentifié ne peut pas supprimer"""
        response = self.client.delete(f'/api/group-posts/{self.post.id}/')
        
        self.assertEqual(response.status_code, status.HTTP_401_UNAUTHORIZED)
