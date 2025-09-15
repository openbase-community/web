import secrets

from django.db import models
from rest_framework import serializers


def generate_random_id(length=12):
    return secrets.token_hex(length // 2)


class OpaquePublicIdField(models.CharField):
    def __init__(self, *args, **kwargs):
        kwargs.setdefault("max_length", 20)
        kwargs.setdefault("unique", True)
        kwargs.setdefault("blank", True)
        kwargs.setdefault("editable", False)
        kwargs.setdefault("db_index", True)
        kwargs.setdefault("help_text", "Public-facing random ID")
        kwargs.setdefault("default", generate_random_id)
        super().__init__(*args, **kwargs)

    def pre_save(self, model_instance, add):
        value = super().pre_save(model_instance, add)
        if not value:
            value = generate_random_id()
            setattr(model_instance, self.attname, value)
        return value


class UserOwnedPrimaryKeyRelatedField(serializers.PrimaryKeyRelatedField):
    async def get_queryset(self):
        request = self.context.get("request", None)
        queryset = super().get_queryset()
        if not request or not queryset:
            return None
        return queryset.filter(user=request.user)
