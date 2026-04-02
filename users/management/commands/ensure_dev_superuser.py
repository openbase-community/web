from __future__ import annotations

from allauth.account.models import EmailAddress
from django.contrib.auth import get_user_model
from django.core.management import BaseCommand, call_command


class Command(BaseCommand):
    help = "Create a development superuser if needed and ensure its profile defaults are set."

    def handle(self, *args, **options):
        User = get_user_model()
        superuser = User.objects.filter(is_superuser=True).first()

        if superuser is None:
            self.stdout.write("No superuser found. Creating superuser (press CTRL+C to skip)...")
            try:
                call_command("createsuperuser")
            except KeyboardInterrupt:
                self.stdout.write("Skipping superuser creation.")
                return
            superuser = User.objects.filter(is_superuser=True).first()
            if superuser is None:
                self.stdout.write("No superuser was created.")
                return
        else:
            self.stdout.write("Superuser already exists, skipping creation...")

        superuser.first_name = "Test"
        superuser.last_name = "User"
        superuser.save()

        email_address, _created = EmailAddress.objects.get_or_create(
            user=superuser,
            email=superuser.email,
            defaults={"verified": True, "primary": True},
        )
        if not email_address.verified or not email_address.primary:
            email_address.verified = True
            email_address.primary = True
            email_address.save(update_fields=["verified", "primary"])

        self.stdout.write(self.style.SUCCESS(f"Prepared development superuser {superuser.email}."))
