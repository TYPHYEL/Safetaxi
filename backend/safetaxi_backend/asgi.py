import os
from django.core.asgi import get_asgi_application
from channels.routing import ProtocolTypeRouter, URLRouter
from channels.auth import AuthMiddlewareStack

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'safetaxi_backend.settings')

django_asgi_app = get_asgi_application()

from django.urls import path
from trips.consumers import TripConsumer

application = ProtocolTypeRouter({
	'http': django_asgi_app,
	'websocket': AuthMiddlewareStack(
		URLRouter([
			path('ws/trips/<int:trip_id>/', TripConsumer.as_asgi()),
		])
	),
})
