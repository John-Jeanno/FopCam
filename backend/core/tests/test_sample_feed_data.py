from django.contrib.auth.models import User
from django.test import TestCase

from core.models import Category, Message, Post, UserProfile
from core.seed_data import load_sample_data


class SampleFeedDataTests(TestCase):
    def test_sample_feed_is_varied_idempotent_and_preserves_existing_accounts(self):
        existing_user = User.objects.create_user(
            username='producer4',
            first_name='Nom personnalisé',
            password='custom-password',
        )
        UserProfile.objects.create(
            user=existing_user,
            role='enterprise',
            city='Ville personnalisée',
        )
        existing_message = Message.objects.create(
            user=existing_user,
            room='private_1_2',
            content='Message réel à conserver.',
        )

        first_run = load_sample_data()
        existing_user.refresh_from_db()
        existing_profile = UserProfile.objects.get(user=existing_user)
        sample_posts = Post.objects.filter(content__startswith='Exemple —') | Post.objects.filter(
            content__startswith='Exemple vidéo'
        )

        self.assertTrue(existing_user.check_password('custom-password'))
        self.assertEqual(existing_user.first_name, 'Nom personnalisé')
        self.assertEqual(existing_profile.city, 'Ville personnalisée')
        self.assertEqual(first_run['messages'], 0)
        self.assertEqual(
            list(Message.objects.values_list('id', flat=True)),
            [existing_message.id],
        )
        self.assertEqual(sample_posts.count(), 6)
        self.assertTrue(sample_posts.filter(post_type='text').exists())
        self.assertTrue(sample_posts.filter(post_type='image').exists())
        self.assertTrue(sample_posts.filter(post_type='video').exists())
        self.assertTrue(
            Category.objects.filter(
                slug__in=(
                    'agriculture-durable',
                    'education-numerique',
                    'innovation-technologique',
                    'artisanat-local',
                    'environnement',
                )
            ).count()
            == 5
        )

        second_run = load_sample_data()

        self.assertEqual(first_run['posts'], Post.objects.count())
        self.assertEqual(second_run['posts'], 0)
        self.assertEqual(second_run['messages'], 0)
        self.assertEqual(Message.objects.count(), 1)
        self.assertEqual(sample_posts.count(), 6)
