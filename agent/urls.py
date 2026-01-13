from __future__ import annotations

from django.urls import path

from . import views

app_name = "agents"

urlpatterns = [
    path("livekit/create-room-token/", views.create_livekit_room_token),
]
