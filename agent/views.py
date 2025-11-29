import os

import requests
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_http_methods

# Create your views here.


@csrf_exempt
@require_http_methods(["GET"])
def generate_token(request):
    api_key = os.getenv("OPENAI_API_KEY")

    if not api_key:
        return JsonResponse(
            {
                "error": "OpenAI API key not configured. Please set OPENAI_API_KEY environment variable.",
            },
            status=500,
        )

    try:
        response = requests.post(
            "https://api.openai.com/v1/realtime/sessions",
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json={
                "model": "gpt-4o-realtime-preview-2024-12-17",
                "voice": "alloy",
            },
        )

        if not response.ok:
            return JsonResponse(
                {
                    "error": "Failed to create OpenAI session",
                    "details": response.text,
                },
                status=response.status_code,
            )

        return JsonResponse(response.json())

    except Exception:
        return JsonResponse(
            {
                "error": "Failed to generate token",
            },
            status=500,
        )
