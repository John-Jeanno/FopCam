import tempfile

from django.contrib.auth.models import User
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from rest_framework.test import APITestCase

from core.models import (
    JobApplication,
    JobPosting,
    JobSeekerPost,
    Notification,
)


class JobApplicationTests(APITestCase):
    def setUp(self):
        self.employer = User.objects.create_user(
            username='employer',
            password='password123',
        )
        self.applicant = User.objects.create_user(
            username='applicant',
            password='password123',
        )
        self.job = JobPosting.objects.create(
            employer=self.employer,
            title='Développeur',
            description='Développer des applications.',
        )
        self.client.force_authenticate(user=self.applicant)

    def make_resume(self, name='cv.pdf', content=b'%PDF-1.4\nCV'):
        return SimpleUploadedFile(
            name,
            content,
            content_type='application/pdf',
        )

    def test_applicant_can_submit_resume_and_employer_is_notified(self):
        response = self.client.post(
            '/api/job-applications/',
            {
                'job_id': self.job.pk,
                'cover_letter': 'Je souhaite rejoindre votre équipe.',
                'resume': self.make_resume(),
            },
            format='multipart',
        )

        self.assertEqual(response.status_code, 201, response.data)
        self.assertTrue(response.data['has_resume'])
        self.assertNotIn('resume', response.data)
        application = JobApplication.objects.get(pk=response.data['id'])
        self.assertEqual(application.applicant, self.applicant)
        self.assertEqual(application.job, self.job)
        notification = Notification.objects.get(user=self.employer)
        self.assertEqual(notification.type, 'job_application')
        self.assertEqual(
            notification.data['job_application_id'],
            application.pk,
        )
        self.job.refresh_from_db()
        self.assertEqual(self.job.applications_count, 1)

    def test_employer_can_view_and_download_candidate_resume(self):
        with tempfile.TemporaryDirectory() as media_root:
            with override_settings(MEDIA_ROOT=media_root):
                response = self.client.post(
                    '/api/job-applications/',
                    {
                        'job_id': self.job.pk,
                        'cover_letter': 'Candidature test.',
                        'resume': self.make_resume(),
                    },
                    format='multipart',
                )
                self.assertEqual(response.status_code, 201, response.data)
                application_id = response.data['id']

                self.client.force_authenticate(user=self.employer)
                links_response = self.client.get(
                    f'/api/job-applications/{application_id}/resume-links/',
                )
                self.assertEqual(links_response.status_code, 200)

                view_response = self.client.get(
                    links_response.data['view_url'],
                )
                self.assertEqual(view_response.status_code, 200)
                self.assertEqual(view_response['Content-Type'], 'application/pdf')
                self.assertIn('inline', view_response['Content-Disposition'])
                view_content = b''.join(view_response.streaming_content)
                self.assertTrue(view_content.startswith(b'%PDF-1.4'))

                download_response = self.client.get(
                    links_response.data['download_url'],
                )
                self.assertEqual(download_response.status_code, 200)
                self.assertIn(
                    'attachment',
                    download_response['Content-Disposition'],
                )

                outsider = User.objects.create_user(username='outsider')
                self.client.force_authenticate(user=outsider)
                denied = self.client.get(
                    f'/api/job-applications/{application_id}/resume-links/',
                )
                self.assertEqual(denied.status_code, 404)

    def test_application_requires_a_real_supported_resume(self):
        response = self.client.post(
            '/api/job-applications/',
            {
                'job_id': self.job.pk,
                'cover_letter': 'Ma candidature.',
                'resume': self.make_resume('cv.png', b'not a png'),
            },
            format='multipart',
        )

        self.assertEqual(response.status_code, 400, response.data)
        self.assertIn('resume', response.data)
        self.assertFalse(JobApplication.objects.exists())
        self.assertFalse(Notification.objects.exists())

    def test_employer_cannot_apply_to_own_job(self):
        self.client.force_authenticate(user=self.employer)

        response = self.client.post(
            '/api/job-applications/',
            {
                'job_id': self.job.pk,
                'cover_letter': 'Ma candidature.',
                'resume': self.make_resume(),
            },
            format='multipart',
        )

        self.assertEqual(response.status_code, 400, response.data)
        self.assertFalse(JobApplication.objects.exists())

    def test_duplicate_application_is_rejected(self):
        payload = {
            'job_id': self.job.pk,
            'cover_letter': 'Ma candidature.',
            'resume': self.make_resume(),
        }
        first_response = self.client.post(
            '/api/job-applications/',
            payload,
            format='multipart',
        )
        second_response = self.client.post(
            '/api/job-applications/',
            {
                **payload,
                'resume': self.make_resume(),
            },
            format='multipart',
        )

        self.assertEqual(first_response.status_code, 201, first_response.data)
        self.assertEqual(second_response.status_code, 400, second_response.data)
        self.assertEqual(JobApplication.objects.count(), 1)
        self.assertEqual(Notification.objects.filter(user=self.employer).count(), 1)


class JobSeekerPostTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='candidate',
            password='password123',
        )
        self.client.force_authenticate(user=self.user)

    def test_candidate_can_publish_a_job_search(self):
        response = self.client.post(
            '/api/job-seeker-posts/',
            {
                'title': 'Recherche un poste de développeur',
                'description': 'Expérience en développement mobile.',
                'location': 'Dakar',
                'job_type': 'full_time',
            },
            format='json',
        )

        self.assertEqual(response.status_code, 201, response.data)
        self.assertEqual(response.data['author']['username'], self.user.username)
        listing = self.client.get('/api/job-seeker-posts/')
        self.assertEqual(listing.status_code, 200, listing.data)
        self.assertEqual(listing.data[0]['id'], response.data['id'])
        self.assertFalse(response.data['has_resume'])
        self.assertNotIn('resume', response.data)

    def test_candidate_can_attach_resume_and_only_recruiters_can_access_it(self):
        employer = User.objects.create_user(username='recruiter')
        JobPosting.objects.create(
            employer=employer,
            title='Recruteur actif',
            description='Offre active.',
        )
        with tempfile.TemporaryDirectory() as media_root:
            with override_settings(MEDIA_ROOT=media_root):
                response = self.client.post(
                    '/api/job-seeker-posts/',
                    {
                        'title': 'Recherche un poste de développeur',
                        'description': 'Expérience mobile.',
                        'location': 'Dakar',
                        'job_type': 'full_time',
                        'resume': SimpleUploadedFile(
                            'cv.pdf',
                            b'%PDF-1.4\nCV candidat',
                            content_type='application/pdf',
                        ),
                    },
                    format='multipart',
                )

                self.assertEqual(response.status_code, 201, response.data)
                self.assertTrue(response.data['has_resume'])
                self.assertNotIn('resume', response.data)
                post = JobSeekerPost.objects.get(pk=response.data['id'])

                links_response = self.client.get(
                    f'/api/job-seeker-posts/{post.pk}/resume-links/',
                )
                self.assertEqual(links_response.status_code, 200)

                self.client.force_authenticate(user=employer)
                recruiter_links = self.client.get(
                    f'/api/job-seeker-posts/{post.pk}/resume-links/',
                )
                self.assertEqual(recruiter_links.status_code, 200)
                file_response = self.client.get(
                    recruiter_links.data['view_url'],
                )
                self.assertEqual(file_response.status_code, 200)
                file_content = b''.join(file_response.streaming_content)
                self.assertTrue(file_content.startswith(b'%PDF-1.4'))

                outsider = User.objects.create_user(username='non-recruiter')
                self.client.force_authenticate(user=outsider)
                denied = self.client.get(
                    f'/api/job-seeker-posts/{post.pk}/resume-links/',
                )
                self.assertEqual(denied.status_code, 403)
