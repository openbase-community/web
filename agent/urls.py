from django.urls import path

from . import views

app_name = "agents"

urlpatterns = [
    path("token/", views.generate_token, name="generate_token"),
]
