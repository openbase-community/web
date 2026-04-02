from __future__ import annotations

import os

import resend


def send_email_via_resend(
    *,
    subject: str,
    to: str | list[str],
    from_email: str,
    html: str | None = None,
    text: str | None = None,
):
    if html is None and text is None:
        msg = "Either html or text content is required to send an email."
        raise ValueError(msg)

    resend.api_key = os.environ["RESEND_API_KEY"]

    params: resend.Emails.SendParams = {
        "from": from_email,
        "to": to,
        "subject": subject,
    }
    if html is not None:
        params["html"] = html
    if text is not None:
        params["text"] = text

    return resend.Emails.send(params)
