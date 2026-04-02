from __future__ import annotations

from django.contrib.sites.models import Site
from django.core.management import BaseCommand

from sites.models import SiteAttributes


class Command(BaseCommand):
    help = "Ensure the default local development sites and their site attributes exist."

    def handle(self, *args, **options):
        site_definitions = (
            (1, {"name": "localhost", "domain": "0.0.0.0:8000"}),
            (2, {"name": "localhost", "domain": "localhost"}),
        )
        site_attribute_defaults = {
            "s3_frontend_folder": "only-used-in-production",
            "stripe_product_id": "prod_implementme",
            "stripe_price_cents": 2000,
            "from_email": "team@my-app.openbase.app",
        }

        for site_id, site_defaults in site_definitions:
            site, _created = Site.objects.update_or_create(id=site_id, defaults=site_defaults)
            SiteAttributes.objects.get_or_create(site=site, defaults=site_attribute_defaults)

        self.stdout.write(self.style.SUCCESS("Ensured default development sites and attributes."))
