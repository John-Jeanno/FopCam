import io

from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework.test import APITestCase, APIClient

from core.models import Post
from core.serializers import PostSerializer


class PostMediaPublishTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='media_tester',
            email='media_tester@example.com',
            password='password123'
        )
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)
        self.url = '/api/posts/'

    def make_image_file(self, name):
        buffer = io.BytesIO()
        buffer.write(
            b'\x89PNG\r\n\x1a\n'
            b'\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde'
            b'\x00\x00\x00\x0cIDATx\x9cc\xf8\xff\xff?\x00\x05\xfe\x02\xfe\r\xefF\xb8'
            b'\x00\x00\x00\x00IEND\xaeB`\x82'
        )
        buffer.seek(0)
        return SimpleUploadedFile(name, buffer.read(), content_type='image/png')

    def test_publish_single_image_post(self):
        image_file = self.make_image_file('post.png')

        response = self.client.post(self.url, {
            'content': 'Publication image unique',
            'post_type': 'image',
            'privacy': 'public',
            'image': image_file,
        }, format='multipart')

        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['post_type'], 'image')
        self.assertTrue(response.data.get('image'))
        self.assertIsNone(response.data.get('video'))
        self.assertEqual(response.data.get('images'), [response.data['image']])

        post = Post.objects.get(id=response.data['id'])
        self.assertEqual(post.author, self.user)
        self.assertEqual(post.post_type, 'image')
        self.assertTrue(post.image.name)
        self.assertEqual(post.images, response.data['images'])

    def test_publish_album_images_post(self):
        image_file1 = self.make_image_file('post1.png')
        image_file2 = self.make_image_file('post2.png')

        response = self.client.post(self.url, {
            'content': 'Publication album',
            'post_type': 'album',
            'privacy': 'public',
            'images': [image_file1, image_file2],
        }, format='multipart')

        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['post_type'], 'album')
        self.assertIsNone(response.data.get('video'))
        self.assertIsNotNone(response.data.get('images'))
        self.assertEqual(len(response.data['images']), 2)

        post = Post.objects.get(id=response.data['id'])
        self.assertEqual(post.author, self.user)
        self.assertEqual(post.post_type, 'album')
        self.assertEqual(len(post.images), 2)
        self.assertTrue(all(img.startswith('/media/') or img.startswith('http') for img in post.images))

    def test_external_video_url_is_returned_without_media_prefix(self):
        video_url = 'https://interactive-examples.mdn.mozilla.net/media/cc0-videos/flower.mp4'
        post = Post.objects.create(
            author=self.user,
            content='Vidéo de démonstration',
            post_type='video',
            video=video_url,
        )

        serialized = PostSerializer(post).data

        self.assertEqual(serialized['video'], video_url)

    def test_non_author_cannot_edit_or_delete_a_post(self):
        post = Post.objects.create(
            author=self.user,
            content='Publication de départ',
            post_type='text',
            privacy='public',
        )
        other_user = User.objects.create_user(
            username='other_post_author',
            password='password123',
        )
        other_client = APIClient()
        other_client.force_authenticate(user=other_user)
        detail_url = f'{self.url}{post.id}/'

        update = other_client.patch(
            detail_url,
            {'content': 'Tentative de modification'},
            format='json',
        )
        delete = other_client.delete(detail_url)

        self.assertEqual(update.status_code, 403)
        self.assertEqual(delete.status_code, 403)
        post.refresh_from_db()
        self.assertEqual(post.content, 'Publication de départ')
        self.assertTrue(post.is_active)
