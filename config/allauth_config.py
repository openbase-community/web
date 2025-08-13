from allauth.account.adapter import DefaultAccountAdapter
from allauth.core import context
from django.contrib.sites.shortcuts import get_current_site
from sites.utils import get_current_site_attributes


class AccountAdapter(DefaultAccountAdapter):
    def get_from_email(self) -> str:
        """
        Formats the given email subject.
        """
        site = get_current_site(context.request)
        site_attributes = get_current_site_attributes(context.request)
        assert site is not None
        assert site_attributes is not None

        return f"{site.name} <{site_attributes.from_email}>"
