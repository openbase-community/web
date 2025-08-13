from django.urls import path
from django.views.decorators.csrf import csrf_exempt

from payment import views

urlpatterns = [
    path("add-value/", csrf_exempt(views.AddValueView.as_view()), name="add_value"),
    path(
        "add-value-history/",
        views.AddValueHistoryView.as_view(),
        name="add_value_history",
    ),
    path(
        "customer-portal/",
        views.StripeCustomerPortalView.as_view(),
        name="customer_portal",
    ),
    path(
        "create-checkout-session/",
        views.StripeCheckoutView.as_view(),
        name="create_checkout_session",
    ),
    path(
        "stripe-webhook/",
        csrf_exempt(views.StripeWebhookView.as_view()),
        name="stripe_webhook",
    ),
]
