import json
from datetime import datetime, timedelta, timezone
from uuid import uuid4

from asgiref.sync import async_to_sync
from django.conf import settings
from livekit import api
from livekit.protocol.room import CreateRoomRequest, DeleteRoomRequest, ListRoomsRequest


ROOM_PREFIX = 'fopcam-live-'


class LiveKitNotConfiguredError(RuntimeError):
    pass


def _ensure_configured():
    if not all((
        settings.LIVEKIT_URL,
        settings.LIVEKIT_API_KEY,
        settings.LIVEKIT_API_SECRET,
    )):
        raise LiveKitNotConfiguredError(
            'Le service vidéo LiveKit doit être configuré sur le serveur.'
        )


def _call_livekit(operation):
    _ensure_configured()

    async def run():
        client = api.LiveKitAPI(
            settings.LIVEKIT_URL,
            settings.LIVEKIT_API_KEY,
            settings.LIVEKIT_API_SECRET,
        )
        try:
            return await operation(client)
        finally:
            await client.aclose()

    return async_to_sync(run)()


def _metadata(room):
    try:
        metadata = json.loads(room.metadata or '{}')
    except (TypeError, json.JSONDecodeError):
        return None
    return metadata if isinstance(metadata, dict) else None


def _room_data(room):
    metadata = _metadata(room)
    if not room.name.startswith(ROOM_PREFIX) or metadata is None:
        return None

    try:
        owner_id = int(metadata['owner_id'])
        started_at = datetime.fromtimestamp(
            int(room.creation_time), tz=timezone.utc
        ).isoformat()
    except (KeyError, TypeError, ValueError, OverflowError):
        return None

    return {
        'id': room.name,
        'room_name': room.name,
        'title': str(metadata.get('title') or 'Direct FopCam'),
        'category': str(metadata.get('category') or 'Commerce'),
        'owner_id': owner_id,
        'viewers': max(0, int(room.num_participants) - 1),
        'started_at': started_at,
        'is_live': True,
    }


def list_live_rooms():
    async def list_rooms(client):
        return await client.room.list_rooms(ListRoomsRequest())

    response = _call_livekit(list_rooms)
    return [data for room in response.rooms if (data := _room_data(room))]


def find_live_room(room_name):
    if not room_name.startswith(ROOM_PREFIX):
        return None

    async def list_rooms(client):
        return await client.room.list_rooms(ListRoomsRequest(names=[room_name]))

    response = _call_livekit(list_rooms)
    for room in response.rooms:
        data = _room_data(room)
        if data is not None and data['room_name'] == room_name:
            return data
    return None


def _participant_token(room_name, identity, can_publish):
    return (
        api.AccessToken(settings.LIVEKIT_API_KEY, settings.LIVEKIT_API_SECRET)
        .with_identity(identity)
        .with_ttl(timedelta(hours=2))
        .with_grants(api.VideoGrants(
            room_join=True,
            room=room_name,
            can_publish=can_publish,
            can_subscribe=True,
            can_publish_data=can_publish,
        ))
        .to_jwt()
    )


def create_live_room(owner_id, title, category):
    _ensure_configured()
    room_name = f'{ROOM_PREFIX}{uuid4().hex}'
    token = _participant_token(room_name, f'host-{uuid4().hex}', True)
    metadata = json.dumps({
        'owner_id': owner_id,
        'title': title,
        'category': category,
    })

    async def create_room(client):
        return await client.room.create_room(CreateRoomRequest(
            name=room_name,
            empty_timeout=300,
            max_participants=100,
            metadata=metadata,
        ))

    _call_livekit(create_room)
    return {'room_name': room_name, 'url': settings.LIVEKIT_URL, 'token': token}


def create_viewer_token(room_name):
    _ensure_configured()
    return _participant_token(
        room_name,
        f'viewer-{uuid4().hex}',
        False,
    )


def end_live_room(room_name):
    async def delete_room(client):
        await client.room.delete_room(DeleteRoomRequest(room=room_name))

    _call_livekit(delete_room)
