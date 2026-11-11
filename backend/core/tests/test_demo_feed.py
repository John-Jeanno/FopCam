from django.contrib.auth.models import User
from django.test import TestCase

from core.demo_feed import load_demo_feed
from core.models import Category, Post, UserProfile


class DemoFeedTests(TestCase):
    def test_demo_feed_is_public_varied_idempotent_and_uses_inactive_author(self):
        first_run = load_demo_feed()
        author = User.objects.get(username='fopcam-demo')
        profile = UserProfile.objects.get(user=author)
        posts = Post.objects.filter(author=author)

        self.assertFalse(author.is_active)
        self.assertFalse(author.has_usable_password())
        self.assertFalse(profile.is_active)
        self.assertEqual(posts.count(), 36)
        self.assertTrue(posts.filter(privacy='public', is_active=True).exists())
        self.assertTrue(posts.filter(post_type='text').exists())
        self.assertTrue(posts.filter(post_type='image').exists())
        self.assertTrue(posts.filter(post_type='video').exists())
        self.assertGreaterEqual(posts.filter(post_type='image').count(), 20)
        self.assertEqual(
            Category.objects.filter(
                slug__in=[
                    'agriculture-durable',
                    'education-numerique',
                    'innovation-technologique',
                    'artisanat-local',
                    'environnement',
                ],
            ).count(),
            5,
        )

        second_run = load_demo_feed()

        self.assertEqual(first_run['posts_created'], 36)
        self.assertEqual(second_run['posts_created'], 0)
        self.assertEqual(Post.objects.filter(author=author).count(), 36)
