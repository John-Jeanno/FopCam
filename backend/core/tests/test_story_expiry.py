import io
import tempfile

from django.test import TestCase
from django.test import override_settings
from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework import status
from PIL import Image
from core.models import Story, Category, Product, Post
from core.seed_data import load_sample_data


class StoryExpiryTestCase(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='storyuser', password='testpass123')
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)

    def test_story_create_sets_24h_expiration(self):
        response = self.client.post(
            '/api/stories/',
            {
                'story_type': 'text',
                'content': 'Test story expires in 24h',
                'background_color': '#ffffff',
                'text_color': '#000000',
                'font_size': 24,
            },
            format='json'
        )

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        data = response.json()
        self.assertIn('expires_at', data)

        expires_at = timezone.datetime.fromisoformat(data['expires_at'].replace('Z', '+00:00'))
        expected_cutoff = timezone.now() + timezone.timedelta(hours=24)
        self.assertTrue(expires_at > timezone.now())
        self.assertTrue(expires_at <= expected_cutoff + timezone.timedelta(seconds=5))

    def test_image_and_video_stories_can_be_published(self):
        image_buffer = io.BytesIO()
        Image.new('RGB', (2, 2), color='blue').save(image_buffer, format='PNG')
        image_buffer.seek(0)

        with tempfile.TemporaryDirectory() as media_root:
            with override_settings(MEDIA_ROOT=media_root):
                image_response = self.client.post(
                    '/api/stories/',
                    {
                        'story_type': 'image',
                        'content': 'Photo du jour',
                        'image': SimpleUploadedFile(
                            'story.png',
                            image_buffer.read(),
                            content_type='image/png',
                        ),
                    },
                    format='multipart',
                )
                self.assertEqual(
                    image_response.status_code,
                    status.HTTP_201_CREATED,
                    image_response.data,
                )
                self.assertEqual(image_response.data['story_type'], 'image')
                self.assertTrue(image_response.data['image'])

                video_response = self.client.post(
                    '/api/stories/',
                    {
                        'story_type': 'video',
                        'content': 'Vidéo du jour',
                        'video': SimpleUploadedFile(
                            'story.mp4',
                            b'\x00\x00\x00\x18ftypmp42',
                            content_type='video/mp4',
                        ),
                    },
                    format='multipart',
                )
                self.assertEqual(
                    video_response.status_code,
                    status.HTTP_201_CREATED,
                    video_response.data,
                )
                self.assertEqual(video_response.data['story_type'], 'video')
                self.assertTrue(video_response.data['video'])

    def test_story_save_sets_24h_expiration_when_missing(self):
        story = Story(author=self.user, story_type='text', content='Auto-expiring story')
        story.save()

        self.assertIsNotNone(story.expires_at)
        self.assertGreater(story.expires_at, timezone.now())
        self.assertLessEqual(story.expires_at, timezone.now() + timezone.timedelta(hours=24, seconds=5))

    def test_load_sample_data_creates_service_categories_and_posts_with_images(self):
        created = load_sample_data()

        self.assertGreater(created['categories'], 0)
        self.assertGreater(created['products'], 0)
        self.assertGreater(created['posts'], 0)

        professional_categories = Category.objects.filter(category_type='professional')
        self.assertTrue(professional_categories.exists())

        products = Product.objects.filter(is_active=True)
        self.assertTrue(products.exists())

        image_posts = Post.objects.filter(post_type__in=['image', 'album'])
        self.assertTrue(image_posts.exists())

    def test_load_sample_data_creates_active_stories_for_feed_demo(self):
        created = load_sample_data()

        self.assertGreater(created['stories'], 0)
        self.assertTrue(Story.objects.filter(is_active=True).exists())

    def test_expired_stories_are_filtered_from_api(self):
        expired_story = Story.objects.create(
            author=self.user,
            story_type='text',
            content='Expired story',
            expires_at=timezone.now() - timezone.timedelta(minutes=10),
            background_color='#ffffff',
            text_color='#000000',
            font_size=24,
        )

        active_story = Story.objects.create(
            author=self.user,
            story_type='text',
            content='Active story',
            expires_at=timezone.now() + timezone.timedelta(hours=24),
            background_color='#ffffff',
            text_color='#000000',
            font_size=24,
        )

        response = self.client.get('/api/stories/')
        self.assertEqual(response.status_code, status.HTTP_200_OK)

        data = response.json()
        if isinstance(data, dict):
            stories = data.get('results', [])
        else:
            stories = data

        story_ids = [story['id'] for story in stories]
        self.assertIn(active_story.id, story_ids)
        self.assertNotIn(expired_story.id, story_ids)
