import unittest
from unittest.mock import patch

from core.base_mailbox import create_mailbox


class SkyMailMailboxTests(unittest.TestCase):
    def _build_mailbox(self, extra=None):
        values = {
            "skymail_api_base": "https://cloudmail.example.invalid",
            "skymail_token": "cloudmail-token",
            "skymail_domain": "mail.example.invalid",
        }
        values.update(extra or {})
        return create_mailbox("skymail", extra=values)

    @patch("requests.post")
    def test_get_email_keeps_default_headers_without_cloudflare_access(self, mock_post):
        mock_post.return_value.status_code = 200
        mock_post.return_value.json.return_value = {"code": 200}

        mailbox = self._build_mailbox()

        mailbox.get_email()

        headers = mock_post.call_args.kwargs["headers"]
        self.assertEqual(headers["authorization"], "cloudmail-token")
        self.assertNotIn("CF-Access-Client-Id", headers)
        self.assertNotIn("CF-Access-Client-Secret", headers)

    @patch("requests.post")
    def test_get_email_adds_cloudflare_access_headers_when_configured(self, mock_post):
        mock_post.return_value.status_code = 200
        mock_post.return_value.json.return_value = {"code": 200}

        mailbox = self._build_mailbox(
            {
                "skymail_cf_access_client_id": "access-id",
                "skymail_cf_access_client_secret": "access-secret",
            }
        )

        mailbox.get_email()

        headers = mock_post.call_args.kwargs["headers"]
        self.assertEqual(headers["authorization"], "cloudmail-token")
        self.assertEqual(headers["CF-Access-Client-Id"], "access-id")
        self.assertEqual(headers["CF-Access-Client-Secret"], "access-secret")


if __name__ == "__main__":
    unittest.main()
