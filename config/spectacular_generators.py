from drf_spectacular.generators import SchemaGenerator
from django.contrib.sites.models import Site


class TitleSettingGenerator(SchemaGenerator):
    def get_schema(self, request=None, public=False):
        current_site = Site.objects.get_current(request)
        schema = super().get_schema(request, public)
        schema["info"]["title"] = f"{current_site.name} API"
        schema["info"]["description"] = f"API for {current_site.name}"
        return schema
