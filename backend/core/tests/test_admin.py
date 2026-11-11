from urllib.parse import parse_qs, urlsplit

from django.test import RequestFactory, SimpleTestCase, override_settings
from django.urls import get_script_prefix, set_script_prefix
from django.contrib.auth.models import AnonymousUser

from core.admin import admin_site


class AdminScriptPrefixTests(SimpleTestCase):
    @override_settings(FORCE_SCRIPT_NAME="/fopcam-api")
    def test_login_redirect_keeps_admin_url_under_script_prefix(self):
        previous_prefix = get_script_prefix()
        set_script_prefix("/fopcam-api/")
        try:
            request = RequestFactory().get("/admin/")
            request.user = AnonymousUser()

            response = admin_site.admin_view(lambda request: None)(request)

            self.assertEqual(response.status_code, 302)
            location = urlsplit(response["Location"])
            self.assertEqual(location.path, "/fopcam-api/admin/login/")
            self.assertEqual(
                parse_qs(location.query)["next"],
                ["/fopcam-api/admin/"],
            )
        finally:
            set_script_prefix(previous_prefix)
