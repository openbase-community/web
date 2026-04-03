from django.contrib.sites.models import Site
from drf_spectacular.generators import SchemaGenerator


class TitleSettingGenerator(SchemaGenerator):
    def get_schema(self, request=None, public: bool = False):  # noqa: FBT001, FBT002
        full_schema = super().get_schema(request, public)
        if full_schema is None:
            return None

        current_site = Site.objects.get_current(request)
        info = dict(full_schema.get("info", {}))
        info["title"] = f"{current_site.name} API Schemas"
        info["description"] = f"Generated schemas for {current_site.name}"
        info.setdefault("version", "1.0.0")
        full_schema["info"] = info
        return full_schema
