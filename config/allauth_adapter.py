from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from allauth.account.adapter import DefaultAccountAdapter
from allauth.account.utils import user_display
from allauth.core import context
from allauth.headless.adapter import DefaultHeadlessAdapter
from django.contrib.sites.shortcuts import get_current_site

from sites.utils import get_current_site_attributes
from users.email import send_email_via_resend


class AccountAdapter(DefaultAccountAdapter):
    def get_from_email(self) -> str:
        """
        Formats the given email subject.
        """
        site = get_current_site(context.request)
        site_attributes = get_current_site_attributes(context.request)
        if site is None:
            msg = "Current site is required to determine the from email address."
            raise ValueError(msg)
        if site_attributes is None:
            msg = "Current site attributes are required to determine the from email address."
            raise ValueError(msg)

        return f"{site.name} <{site_attributes.from_email}>"

    def send_mail(self, template_prefix: str, email: str, template_context: dict) -> None:
        request = context.request
        ctx = {
            "request": request,
            "email": email,
            "current_site": get_current_site(request),
        }
        ctx.update(template_context)
        msg = self.render_mail(template_prefix, email, ctx)

        text_body = None
        html_body = None
        if msg.content_subtype == "html":
            html_body = msg.body
        else:
            text_body = msg.body

        for alternative in getattr(msg, "alternatives", ()):
            if alternative.mimetype == "text/html":
                html_body = alternative.content

        send_email_via_resend(
            subject=msg.subject,
            to=msg.to,
            from_email=msg.from_email or self.get_from_email(),
            html=html_body,
            text=text_body,
        )


@dataclass
class UserDataclass:
    id: int
    email: str
    first_name: str
    last_name: str
    display: str


class HeadlessAdapter(DefaultHeadlessAdapter):
    def get_user_dataclass(self):
        return UserDataclass

    def user_as_dataclass(self, user):
        return UserDataclass(
            id=user.id,
            email=user.email,
            first_name=user.first_name,
            last_name=user.last_name,
            display=user_display(user),
        )

    def serialize_user(self, user) -> dict[str, Any]:
        """
        From allauth docs: Do not override this method if you would like your customized user payloads
        to be reflected in the (dynamically rendered) OpenAPI specification. In that
        case, override ``get_user_dataclass()`` and ``user_as_dataclass`` instead.
        """
        return {
            "id": user.id,
            "email": user.email,
            "first_name": user.first_name,
            "last_name": user.last_name,
            "display": user_display(user),
            "has_usable_password": user.has_usable_password(),
        }
