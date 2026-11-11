from channels.generic.websocket import AsyncWebsocketConsumer
import json
from .models import Message, Notification
from channels.db import database_sync_to_async
from django.contrib.auth.models import User
from .chat_utils import private_room_participant_ids


class ChatConsumer(AsyncWebsocketConsumer):
    async def connect(self):
        self.room_name = self.scope['url_route']['kwargs']['room_name']
        self.room_group_name = f'chat_{self.room_name}'
        user = self.scope.get('user')
        participant_ids = private_room_participant_ids(self.room_name)
        if (
            user is None
            or not user.is_authenticated
            or participant_ids is None
            or user.id not in participant_ids
            or not await self.private_room_users_exist(participant_ids)
        ):
            await self.close(code=4403)
            return

        await self.channel_layer.group_add(self.room_group_name, self.channel_name)
        await self.accept()

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.room_group_name, self.channel_name)

    async def receive(self, text_data=None, bytes_data=None):
        data = json.loads(text_data)
        user = self.scope.get('user')

        if user and user.is_authenticated:
            room = self.room_name
            event_type = data.get('event') or data.get('event_type')

            if event_type == 'typing':
                payload = {
                    'event': 'typing',
                    'room': self.room_name,
                    'user': {
                        'id': user.id,
                        'username': user.username,
                        'profile_image': await self.get_user_profile_image(user)
                    }
                }
                await self.channel_layer.group_send(self.room_group_name, {'type': 'chat_typing', 'message': json.dumps(payload)})
                return

            message_type = data.get('message_type', 'text')
            
            # Extract recipient from room name
            recipient = await self.get_recipient_from_room(room, user)
            
            if message_type == 'text':
                message_content = data.get('message', '')
                # Save text message to DB
                try:
                    message_obj = await self.save_message(
                        room,
                        user,
                        message_content,
                        recipient,
                        'text',
                        data.get('reply_to_id'),
                    )
                except ValueError as error:
                    await self.send(text_data=json.dumps({
                        'event': 'error',
                        'message': str(error),
                    }))
                    return
                reply_preview = (
                    await self.get_message_reply_preview(message_obj.reply_to_id)
                    if message_obj.reply_to_id is not None
                    else None
                )
                
                # Create notification for recipient
                if recipient:
                    await self.create_notification(recipient, user, message_content, room)
                
                payload = {
                    'id': message_obj.id,
                    'room': room,
                    'message': message_content,
                    'user': {
                        'id': user.id,
                        'username': user.username,
                        'profile_image': await self.get_user_profile_image(user)
                    },
                    'timestamp': str(await self.get_timestamp()),
                    'message_type': 'text',
                    'reply_to': reply_preview,
                }
                
            elif message_type == 'audio':
                audio_data = data.get('audio_data')
                audio_duration = data.get('audio_duration', 0)
                
                # Save audio message to DB
                try:
                    message_obj = await self.save_audio_message(
                        room,
                        user,
                        audio_data,
                        audio_duration,
                        recipient,
                    )
                except ValueError as error:
                    await self.send(text_data=json.dumps({
                        'event': 'error',
                        'message': str(error),
                    }))
                    return
                
                # Create notification for recipient
                if recipient:
                    await self.create_notification(recipient, user, 'Message vocal', room)
                
                payload = {
                    'id': message_obj.id,
                    'room': room,
                    'message': f'Audio message ({audio_duration}s)',
                    'user': {
                        'id': user.id,
                        'username': user.username,
                        'profile_image': await self.get_user_profile_image(user)
                    },
                    'timestamp': str(await self.get_timestamp()),
                    'message_type': 'audio',
                    'audio_duration': audio_duration,
                    'audio_file': message_obj.audio_file.url if message_obj.audio_file else None,
                    'attachment_file': message_obj.attachment_file.url if message_obj.attachment_file else None,
                    'attachment_type': message_obj.attachment_type,
                    'attachment_name': message_obj.attachment_file.name.split('/')[-1] if message_obj.attachment_file else None
                }
            elif data.get('attachment_data'):
                attachment_data = data.get('attachment_data')
                attachment_name = data.get('attachment_name') or 'attachment'
                attachment_type = data.get('attachment_type') or 'document'
                message_text = data.get('message', attachment_name)

                message_obj = await self.save_attachment_message(
                    room,
                    user,
                    attachment_data,
                    attachment_name,
                    attachment_type,
                    recipient,
                    message_type
                )

                if recipient:
                    await self.create_notification(recipient, user, message_text, room)

                payload = {
                    'id': message_obj.id,
                    'room': room,
                    'message': message_text,
                    'user': {
                        'id': user.id,
                        'username': user.username,
                        'profile_image': await self.get_user_profile_image(user)
                    },
                    'timestamp': str(await self.get_timestamp()),
                    'message_type': message_obj.message_type,
                    'attachment_file': message_obj.attachment_file.url if message_obj.attachment_file else None,
                    'attachment_type': message_obj.attachment_type,
                    'attachment_name': message_obj.attachment_file.name.split('/')[-1] if message_obj.attachment_file else None
                }
            
            await self.channel_layer.group_send(self.room_group_name, {'type': 'chat_message', 'message': json.dumps(payload)})
        else:
            await self.send(text_data=json.dumps({'error': 'Authentication required'}))

    async def chat_message(self, event):
        await self.send(text_data=event['message'])

    async def chat_typing(self, event):
        await self.send(text_data=event['message'])

    @database_sync_to_async
    def private_room_users_exist(self, participant_ids):
        return User.objects.filter(id__in=participant_ids).count() == 2

    @database_sync_to_async
    def get_recipient_from_room(self, room_name, sender):
        participant_ids = private_room_participant_ids(room_name)
        if participant_ids is None or sender.id not in participant_ids:
            return None
        recipient_id = next(user_id for user_id in participant_ids if user_id != sender.id)
        return User.objects.filter(id=recipient_id).first()

    @database_sync_to_async
    def get_user_profile_image(self, user):
        profile = getattr(user, 'profile', None)
        if profile and getattr(profile, 'profile_image', None):
            try:
                return profile.profile_image.url
            except ValueError:
                return None
        return None

    @database_sync_to_async
    def save_message(
        self,
        room,
        user,
        content,
        recipient,
        message_type='text',
        reply_to_id=None,
    ):
        reply_to = None
        if reply_to_id is not None:
            try:
                reply_to_id = int(reply_to_id)
            except (TypeError, ValueError) as error:
                raise ValueError(
                    'Le message cité est invalide.',
                ) from error
            reply_to = Message.objects.filter(
                pk=reply_to_id,
                room=room,
            ).first()
            if reply_to is None:
                raise ValueError(
                    'Le message cité doit appartenir à cette discussion.',
                )
        return Message.objects.create(
            room=room,
            user=user,
            content=content,
            recipient=recipient,
            message_type=message_type,
            reply_to=reply_to,
        )

    @database_sync_to_async
    def get_message_reply_preview(self, message_id):
        message = Message.objects.select_related('user').get(pk=message_id)
        return {
            'id': message.id,
            'content': message.content,
            'message_type': message.message_type,
            'user': {
                'id': message.user_id,
                'username': message.user.username,
            },
        }

    @database_sync_to_async
    def save_audio_message(self, room, user, audio_data, audio_duration, recipient):
        import base64
        import binascii
        from django.core.files.base import ContentFile
        from django.utils import timezone
        from .audio_utils import audio_extension, has_audio_payload
        
        try:
            audio_bytes = base64.b64decode(audio_data, validate=True)
        except (binascii.Error, TypeError, ValueError) as error:
            raise ValueError('Le fichier vocal transmis est invalide.') from error
        if not has_audio_payload(audio_bytes):
            raise ValueError(
                'Le fichier vocal ne contient pas de son lisible. '
                'Vérifiez le microphone et réessayez.'
            )

        timestamp = timezone.now().isoformat().replace(':', '-')
        extension = audio_extension(audio_bytes)
        filename = (
            f"voice_message_{user.username}_{timestamp}."
            f"{extension}"
        )
        
        return Message.objects.create(
            room=room,
            user=user,
            recipient=recipient,
            message_type='audio',
            audio_file=ContentFile(audio_bytes, name=filename),
            attachment_file=ContentFile(audio_bytes, name=filename),
            attachment_type='audio',
            audio_duration=audio_duration
        )

    @database_sync_to_async
    def save_attachment_message(self, room, user, attachment_data, attachment_name, attachment_type, recipient, message_type='document'):
        import base64
        from django.core.files.base import ContentFile
        from django.utils import timezone

        attachment_bytes = base64.b64decode(attachment_data)
        timestamp = timezone.now().isoformat().replace(':', '-')
        safe_name = attachment_name.replace(' ', '_')
        filename = f"{attachment_type}_{user.username}_{timestamp}_{safe_name}"
        attachment_file = ContentFile(attachment_bytes, name=filename)

        return Message.objects.create(
            room=room,
            user=user,
            recipient=recipient,
            content=attachment_name,
            message_type=message_type,
            attachment_file=attachment_file,
            attachment_type=attachment_type
        )

    @database_sync_to_async
    def create_notification(self, recipient, sender, content, room):
        Notification.objects.create(
            user=recipient,
            title=f'Nouveau message de {sender.username}',
            message=content[:100],
            type='message',
            data={'room': room},
        )

    @database_sync_to_async
    def get_timestamp(self):
        from django.utils import timezone
        return timezone.now().isoformat()
