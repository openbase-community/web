from __future__ import annotations

import os
import unittest
from unittest.mock import patch

import resend

from users.email import send_email_via_resend


class SendEmailViaResendTests(unittest.TestCase):
    def test_sends_html_email(self):
        with (
            patch.dict(os.environ, {"RESEND_API_KEY": "re_test_key"}, clear=False),
            patch("users.email.resend.Emails.send", return_value={"id": "email_123"}) as mock_send,
        ):
            send_email_via_resend(
                subject="Welcome",
                to="person@example.com",
                from_email="app@example.com",
                html="<strong>Hello</strong>",
            )

        assert resend.api_key == "re_test_key"  # noqa: S101
        mock_send.assert_called_once_with(
            {
                "from": "app@example.com",
                "to": "person@example.com",
                "subject": "Welcome",
                "html": "<strong>Hello</strong>",
            }
        )

    def test_sends_text_and_html_email(self):
        with (
            patch.dict(os.environ, {"RESEND_API_KEY": "re_test_key"}, clear=False),
            patch("users.email.resend.Emails.send", return_value={"id": "email_456"}) as mock_send,
        ):
            send_email_via_resend(
                subject="Reset your password",
                to=["person@example.com"],
                from_email="Support <support@example.com>",
                html="<p>Reset</p>",
                text="Reset",
            )

        mock_send.assert_called_once_with(
            {
                "from": "Support <support@example.com>",
                "to": ["person@example.com"],
                "subject": "Reset your password",
                "html": "<p>Reset</p>",
                "text": "Reset",
            }
        )
