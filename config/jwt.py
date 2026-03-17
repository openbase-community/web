from __future__ import annotations

from django.conf import settings
from django.http import JsonResponse

from allauth.core.internal import jwkkit
from allauth.headless.tokens.strategies.jwt import JWTTokenStrategy


class OpenbaseJWTTokenStrategy(JWTTokenStrategy):
    def get_claims(self, user) -> dict[str, str]:
        claims = super().get_claims(user)
        claims["iss"] = settings.HEADLESS_JWT_ISSUER
        claims["aud"] = settings.HEADLESS_JWT_AUDIENCE
        return claims


def jwks_view(_request):
    jwk_dict, _private_key = jwkkit.load_jwk_from_pem(settings.HEADLESS_JWT_PRIVATE_KEY)
    return JsonResponse({"keys": [jwk_dict]})
