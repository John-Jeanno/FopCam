from django.contrib.auth.models import User
from rest_framework.test import APITestCase

from core.models import JobPosting, UserProfile


class JobPostingTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='employer',
            password='password123',
        )
        UserProfile.objects.create(user=self.user, role='buyer')
        self.client.force_authenticate(user=self.user)

    def test_user_can_publish_job_without_optional_category(self):
        response = self.client.post(
            '/api/job-postings/',
            {
                'title': 'Community manager',
                'description': 'Créer du contenu et animer la communauté.',
                'company': 'Teranga Créations',
                'location': 'Dakar',
                'job_type': 'full_time',
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['title'], 'Community manager')
        self.assertIsNone(response.data['category'])
        self.assertTrue(
            JobPosting.objects.filter(
                employer=self.user,
                title='Community manager',
                is_active=True,
            ).exists()
        )

        list_response = self.client.get('/api/job-postings/')
        self.assertEqual(list_response.status_code, 200, list_response.data)
        jobs = list_response.data
        if isinstance(jobs, dict):
            jobs = jobs['results']
        self.assertEqual(
            jobs[0]['title'],
            'Community manager',
        )
