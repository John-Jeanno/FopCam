import logging

from django.conf import settings
from django.contrib.auth import get_user_model
from rest_framework import permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView

from . import livekit_service


logger = logging.getLogger(__name__)


def _service_error(error):
    if isinstance(error, livekit_service.LiveKitNotConfiguredError):
        return Response({'detail': str(error)}, status=status.HTTP_503_SERVICE_UNAVAILABLE)
    logger.exception('LiveKit request failed')
    return Response(
        {'detail': 'Le service de diffusion vidéo est momentanément indisponible.'},
        status=status.HTTP_502_BAD_GATEWAY,
    )


class LiveStreamsView(APIView):
    def get_permissions(self):
        permission = (
            permissions.AllowAny
            if self.request.method == 'GET'
            else permissions.IsAuthenticated
        )
        return [permission()]

    def get(self, request):
        try:
            streams = livekit_service.list_live_rooms()
        except Exception as error:
            return _service_error(error)

        owner_ids = {stream['owner_id'] for stream in streams}
        usernames = dict(
            get_user_model().objects.filter(pk__in=owner_ids)
            .values_list('pk', 'username')
        )
        for stream in streams:
            owner_id = stream.pop('owner_id')
            stream['host'] = {
                'id': owner_id,
                'username': usernames.get(owner_id, 'Utilisateur'),
                'role': 'buyer',
            }
        return Response(streams)

    def post(self, request):
        title = request.data.get('title') if isinstance(request.data, dict) else None
        category = request.data.get('category', 'Commerce') if isinstance(request.data, dict) else 'Commerce'
        if not isinstance(title, str) or not title.strip():
            return Response(
                {'title': 'Donnez un titre à votre direct.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        title = title.strip()
        if len(title) > 120:
            return Response(
                {'title': 'Le titre ne peut pas dépasser 120 caractères.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not isinstance(category, str):
            return Response(
                {'category': 'La catégorie doit être du texte.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        try:
            credentials = livekit_service.create_live_room(
                request.user.pk,
                title,
                category.strip()[:80] or 'Commerce',
            )
        except Exception as error:
            return _service_error(error)
        return Response(credentials, status=status.HTTP_201_CREATED)


class LiveStreamJoinView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request, room_name):
        try:
            stream = livekit_service.find_live_room(room_name)
            if stream is None:
                return Response(
                    {'detail': 'Cette diffusion n’existe plus.'},
                    status=status.HTTP_404_NOT_FOUND,
                )
            token = livekit_service.create_viewer_token(room_name)
        except Exception as error:
            return _service_error(error)
        return Response({'url': settings.LIVEKIT_URL, 'token': token})


class LiveStreamDetailView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def delete(self, request, room_name):
        try:
            stream = livekit_service.find_live_room(room_name)
            if stream is None:
                return Response(
                    {'detail': 'Cette diffusion n’existe plus.'},
                    status=status.HTTP_404_NOT_FOUND,
                )
            if stream['owner_id'] != request.user.pk:
                return Response(
                    {'detail': 'Seul l’hôte peut terminer cette diffusion.'},
                    status=status.HTTP_403_FORBIDDEN,
                )
            livekit_service.end_live_room(room_name)
        except Exception as error:
            return _service_error(error)
        return Response(status=status.HTTP_204_NO_CONTENT)
