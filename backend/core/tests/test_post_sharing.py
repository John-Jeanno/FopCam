from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework.test import APIClient

from core.models import Post, Share, UserProfile


class PostSharingTests(TestCase):
    def setUp(self):
        self.author = User.objects.create_user(username='post-author')
        self.sharer = User.objects.create_user(username='post-sharer')
        self.post = Post.objects.create(
            author=self.author,
            content='Publication à partager',
            privacy='public',
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.sharer)

    def test_share_endpoint_records_share_and_includes_post(self):
        response = self.client.post(
            '/api/shares/',
            {'post_id': self.post.id},
            format='json',
        )

        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['post']['id'], self.post.id)
        self.assertEqual(Share.objects.filter(post=self.post, user=self.sharer).count(), 1)
        self.assertEqual(response.data['post']['shares_count'], 1)

    def test_like_and_comment_actions_persist_for_the_post(self):
        like_response = self.client.post(
            '/api/likes/',
            {'post': self.post.id},
            format='json',
        )
        comment_response = self.client.post(
            '/api/comments/',
            {'post': self.post.id, 'content': 'Très belle publication.'},
            format='json',
        )

        self.assertEqual(like_response.status_code, 201, like_response.data)
        self.assertEqual(comment_response.status_code, 201, comment_response.data)
        self.assertEqual(comment_response.data['user']['username'], self.sharer.username)
        comments_response = self.client.get(
            f'/api/comments/?post={self.post.id}'
        )
        self.assertEqual(comments_response.status_code, 200)
        self.assertEqual(len(comments_response.data), 1)

    def test_comment_author_can_edit_and_delete_but_other_users_cannot(self):
        comment_response = self.client.post(
            '/api/comments/',
            {'post': self.post.id, 'content': 'Commentaire initial'},
            format='json',
        )
        self.assertEqual(comment_response.status_code, 201)
        comment_id = comment_response.data['id']
        detail_url = f'/api/comments/{comment_id}/'

        owner_edit = self.client.patch(
            detail_url,
            {'content': 'Commentaire modifié'},
            format='json',
        )
        self.assertEqual(owner_edit.status_code, 200, owner_edit.data)
        self.assertEqual(owner_edit.data['content'], 'Commentaire modifié')

        other_client = APIClient()
        other_client.force_authenticate(user=self.author)
        forbidden_edit = other_client.patch(
            detail_url,
            {'content': 'Modification non autorisée'},
            format='json',
        )
        forbidden_delete = other_client.delete(detail_url)
        self.assertEqual(forbidden_edit.status_code, 403)
        self.assertEqual(forbidden_delete.status_code, 403)

        owner_delete = self.client.delete(detail_url)
        self.assertEqual(owner_delete.status_code, 204)

    def test_published_text_post_appears_in_the_public_feed(self):
        response = self.client.post(
            '/api/posts/',
            {
                'content': 'Ma nouvelle publication',
                'privacy': 'public',
                'location': 'Dakar',
                'hashtags': ['FopCam'],
                'background_color': '#E0F2FE',
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['background_color'], '#E0F2FE')
        feed_response = self.client.get('/api/posts/')
        self.assertEqual(feed_response.status_code, 200)
        feed_posts = (
            feed_response.data.get('results', [])
            if isinstance(feed_response.data, dict)
            else feed_response.data
        )
        published = next(
            item for item in feed_posts if item['id'] == response.data['id']
        )
        self.assertEqual(published['content'], 'Ma nouvelle publication')
        self.assertEqual(published['location'], 'Dakar')
        self.assertEqual(published['hashtags'], ['FopCam'])
        self.assertEqual(published['background_color'], '#E0F2FE')

    def test_rejects_invalid_post_background_colors(self):
        response = self.client.post(
            '/api/posts/',
            {
                'content': 'Couleur incorrecte',
                'background_color': 'red',
            },
            format='json',
        )

        self.assertEqual(response.status_code, 400)
        self.assertIn('background_color', response.data)

    def test_feed_serializes_users_with_duplicate_profiles(self):
        UserProfile.objects.create(user=self.author)
        UserProfile.objects.create(user=self.author)
        UserProfile.objects.create(user=self.author)

        response = self.client.get('/api/posts/')

        self.assertEqual(response.status_code, 200, response.data)
        posts = response.data.get('results', [])
        self.assertEqual(posts[0]['author']['username'], self.author.username)
