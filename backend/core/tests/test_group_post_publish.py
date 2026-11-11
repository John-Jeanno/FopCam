from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework.test import APITestCase, APIClient

from core.models import Group, GroupPost


class GroupPostMediaPublishTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(username='tester', email='tester@example.com', password='password123')
        self.group = Group.objects.create(name='Test Group', creator=self.user)
        self.client = APIClient()
        self.client.force_authenticate(user=self.user)
        self.url = '/api/group-posts/'

    def test_publish_image_post(self):
        image_content = (
            b'\x89PNG\r\n\x1a\n'
            b'\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde'
            b'\x00\x00\x00\x0cIDATx\x9cc\xf8\xff\xff?\x00\x05\xfe\x02\xfe\r\xefF\xb8'
            b'\x00\x00\x00\x00IEND\xaeB`\x82'
        )
        image_file = SimpleUploadedFile('post.png', image_content, content_type='image/png')

        response = self.client.post(self.url, {
            'group': self.group.id,
            'content': 'Publication image de test',
            'post_type': 'image',
            'privacy': 'public',
            'image': image_file,
        }, format='multipart')

        self.assertEqual(response.status_code, 201, response.data)
        self.assertIn('id', response.data)
        self.assertEqual(response.data['post_type'], 'image')
        self.assertTrue(response.data.get('image'))
        self.assertIsNone(response.data.get('video'))

        post = GroupPost.objects.get(id=response.data['id'])
        self.assertEqual(post.author, self.user)
        self.assertEqual(post.group, self.group)
        self.assertEqual(post.post_type, 'image')
        self.assertTrue(post.image.name)

    def test_publish_video_post(self):
        video_content = b"\x00\x00\x00\x18ftypmp42\x00\x00\x00\x00mp42isom\x00\x00\x00\x08free\x00\x00\x02\x44mdat"
        video_file = SimpleUploadedFile('post.mp4', video_content, content_type='video/mp4')

        response = self.client.post(self.url, {
            'group': self.group.id,
            'content': 'Publication vidéo de test',
            'post_type': 'video',
            'privacy': 'public',
            'video': video_file,
        }, format='multipart')

        self.assertEqual(response.status_code, 201, response.data)
        self.assertIn('id', response.data)
        self.assertEqual(response.data['post_type'], 'video')
        self.assertTrue(response.data.get('video'))
        self.assertIsNone(response.data.get('image'))

        post = GroupPost.objects.get(id=response.data['id'])
        self.assertEqual(post.author, self.user)
        self.assertEqual(post.group, self.group)
        self.assertEqual(post.post_type, 'video')
        self.assertTrue(post.video.name)
