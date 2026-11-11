import os

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'fopcam.settings')

from channels.routing import ProtocolTypeRouter, URLRouter
from django.core.asgi import get_asgi_application
from django.urls import path

django_asgi_app = get_asgi_application()

from core.middleware import JWTAuthMiddleware
import core.routing

application = ProtocolTypeRouter({
	"http": django_asgi_app,
	"websocket": JWTAuthMiddleware(URLRouter(core.routing.websocket_urlpatterns)),
})
