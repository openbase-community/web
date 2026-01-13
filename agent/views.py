from __future__ import annotations

import os
from datetime import timedelta

from livekit import api as livekit_api
from rest_framework import serializers
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def create_livekit_room_token(request):
    """Create a LiveKit room token for the authenticated user"""
    api_key = os.environ.get("LIVEKIT_API_KEY")
    api_secret = os.environ.get("LIVEKIT_API_SECRET")

    if not api_key or not api_secret:
        raise serializers.ValidationError(
            {"detail": "LiveKit credentials not configured"}
        )

    room_name = request.data.get("room_name")
    if not room_name:
        raise serializers.ValidationError({"room_name": "Room name is required"})

    token = (
        livekit_api.AccessToken(api_key=api_key, api_secret=api_secret)
        .with_identity(request.user.email)
        .with_name(f"{request.user.first_name} {request.user.last_name}".strip())
        .with_grants(
            livekit_api.VideoGrants(
                room_join=True,
                room=room_name,
                can_publish=True,
                can_subscribe=True,
                can_publish_data=True,
            )
        )
        .with_ttl(timedelta(hours=1))
        .to_jwt()
    )

    return Response({"token": token, "room_name": room_name})
