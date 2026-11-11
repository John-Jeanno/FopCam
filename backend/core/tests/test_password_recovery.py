import re
from datetime import timedelta

from django.contrib.auth.models import User
from django.core import mail
from django.test import TestCase, override_settings
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework_simplejwt.exceptions import TokenError
from rest_framework_simplejwt.tokens import RefreshToken

from core.models import PasswordResetCode, UserProfile


@override_settings(
    EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend',
    EMAIL_HOST='smtp.example.test',
)
class PasswordRecoveryTests(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='reset-user',
            email='reset@example.test',
            password='old-password-123',
        )
        UserProfile.objects.create(
            user=self.user,
            phone='+221 77 123 45 67',
        )
        self.client = APIClient()

    def request_email_code(self):
        return self.client.post(
            '/api/auth/password-reset/request/',
            {'channel': 'email', 'identifier': 'RESET@example.test'},
            format='json',
        )

    def test_email_code_resets_password_and_revokes_existing_refresh_tokens(self):
        refresh_token = str(RefreshToken.for_user(self.user))

        requested = self.request_email_code()

        self.assertEqual(requested.status_code, 200)
        self.assertEqual(len(mail.outbox), 1)
        self.assertIn('10 minutes', mail.outbox[0].body)
        code = re.search(r'\b(\d{6})\b', mail.outbox[0].body).group(1)

        confirmed = self.client.post(
            '/api/auth/password-reset/confirm/',
            {
                'channel': 'email',
                'identifier': self.user.email,
                'code': code,
                'new_password': 'brand-new-password-456',
            },
            format='json',
        )

        self.assertEqual(confirmed.status_code, 200)
        self.user.refresh_from_db()
        self.assertTrue(self.user.check_password('brand-new-password-456'))
        with self.assertRaises(TokenError):
            RefreshToken(refresh_token)
        reused = self.client.post(
            '/api/auth/password-reset/confirm/',
            {
                'channel': 'email',
                'identifier': self.user.email,
                'code': code,
                'new_password': 'another-new-password-789',
            },
            format='json',
        )
        self.assertEqual(reused.status_code, 400)

    def test_unknown_email_receives_same_response_without_sending_mail(self):
        response = self.client.post(
            '/api/auth/password-reset/request/',
            {'channel': 'email', 'identifier': 'missing@example.test'},
            format='json',
        )

        self.assertEqual(response.status_code, 200)
        self.assertIn('Si un compte correspond', response.data['detail'])
        self.assertEqual(len(mail.outbox), 0)
        self.assertEqual(PasswordResetCode.objects.count(), 0)

    def test_reset_code_is_rate_limited_expires_and_is_single_use(self):
        self.assertEqual(self.request_email_code().status_code, 200)
        first_code = re.search(r'\b(\d{6})\b', mail.outbox[0].body).group(1)

        self.assertEqual(self.request_email_code().status_code, 200)
        self.assertEqual(len(mail.outbox), 1)

        reset_code = PasswordResetCode.objects.get(user=self.user)
        reset_code.expires_at = timezone.now() - timedelta(seconds=1)
        reset_code.save(update_fields=('expires_at',))
        expired = self.client.post(
            '/api/auth/password-reset/confirm/',
            {
                'channel': 'email',
                'identifier': self.user.email,
                'code': first_code,
                'new_password': 'brand-new-password-456',
            },
            format='json',
        )

        self.assertEqual(expired.status_code, 400)
        self.assertTrue(self.user.check_password('old-password-123'))

    def test_fifth_incorrect_code_attempt_consumes_the_code(self):
        self.assertEqual(self.request_email_code().status_code, 200)
        correct_code = re.search(r'\b(\d{6})\b', mail.outbox[0].body).group(1)
        wrong_code = '000000' if correct_code != '000000' else '000001'

        for _ in range(5):
            response = self.client.post(
                '/api/auth/password-reset/confirm/',
                {
                    'channel': 'email',
                    'identifier': self.user.email,
                    'code': wrong_code,
                    'new_password': 'brand-new-password-456',
                },
                format='json',
            )
            self.assertEqual(response.status_code, 400)

        reset_code = PasswordResetCode.objects.get(user=self.user)
        self.assertIsNotNone(reset_code.consumed_at)
        self.assertEqual(reset_code.attempts, 5)
        self.assertTrue(self.user.check_password('old-password-123'))

    def test_whatsapp_channel_requires_server_provider_configuration(self):
        response = self.client.post(
            '/api/auth/password-reset/request/',
            {'channel': 'whatsapp', 'identifier': '+221771234567'},
            format='json',
        )

        self.assertEqual(response.status_code, 503)
        self.assertIn('WhatsApp', response.data['detail'])
