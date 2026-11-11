import io
import tempfile
import time
from pathlib import Path
from unittest.mock import patch

import cv2
import numpy as np
from django.contrib.auth.models import User
from django.core.files import File
from django.core.files.base import ContentFile
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import SimpleTestCase, override_settings
from rest_framework.test import APITestCase

from core.models import Reel
from core.reel_video_effects import (
    _draw_sticker,
    _create_thumbnail,
    _encode_video,
    _render_effect_video,
    _soften_faces,
    process_reel_video,
)


class ReelVideoEffectTests(SimpleTestCase):
    def test_light_filter_changes_rendered_video_frames(self):
        with tempfile.TemporaryDirectory() as temp_directory:
            source = Path(temp_directory) / 'source.avi'
            rendered = Path(temp_directory) / 'rendered.avi'
            writer = cv2.VideoWriter(
                str(source),
                cv2.VideoWriter_fourcc(*'MJPG'),
                10,
                (64, 48),
            )
            self.assertTrue(writer.isOpened())
            for _ in range(10):
                writer.write(np.full((48, 64, 3), 100, dtype=np.uint8))
            writer.release()

            duration, _ = _render_effect_video(
                source,
                rendered,
                'light',
                '',
                time.monotonic(),
                duration=1,
            )
            capture = cv2.VideoCapture(str(rendered))
            ok, frame = capture.read()
            capture.release()

        self.assertAlmostEqual(duration, 1, places=1)
        self.assertTrue(ok)
        self.assertGreater(int(frame[24, 32, 0]), 100)

    def test_video_thumbnail_is_a_decodable_jpeg(self):
        with tempfile.TemporaryDirectory() as temp_directory:
            source = Path(temp_directory) / 'source.avi'
            writer = cv2.VideoWriter(
                str(source),
                cv2.VideoWriter_fourcc(*'MJPG'),
                10,
                (64, 48),
            )
            self.assertTrue(writer.isOpened())
            for _ in range(10):
                writer.write(np.full((48, 64, 3), 100, dtype=np.uint8))
            writer.release()

            thumbnail = _create_thumbnail(source, 1)

        try:
            image = cv2.imdecode(
                np.frombuffer(thumbnail.read(), dtype=np.uint8),
                cv2.IMREAD_COLOR,
            )
        finally:
            thumbnail.close()

        self.assertIsNotNone(image)
        self.assertEqual(image.shape[:2], (48, 64))

    def test_processed_file_remains_readable_after_temp_directory_cleanup(self):
        def write_output(source_path, rendered_path, output_path, duration, started_at):
            output_path.write_bytes(b'processed video')

        with (
            patch(
                'core.reel_video_effects._probe_video',
                return_value=(1.25, 16, 16),
            ),
            patch(
                'core.reel_video_effects._encode_video',
                side_effect=write_output,
            ),
            patch(
                'core.reel_video_effects._create_thumbnail',
                return_value=ContentFile(b'jpeg', name='reel.jpg'),
            ),
        ):
            processed, duration, thumbnail = process_reel_video(
                SimpleUploadedFile('clip.mp4', b'source bytes'),
                effect='none',
                sticker='',
            )

        try:
            self.assertEqual(processed.read(), b'processed video')
            self.assertEqual(duration, 1.25)
            self.assertEqual(thumbnail.read(), b'jpeg')
        finally:
            processed.close()
            thumbnail.close()

    def test_encoder_maps_audio_as_optional_for_source_and_rendered_video(self):
        source = Path('source.mp4')
        rendered = Path('rendered.avi')
        output = Path('output.mp4')
        with patch('core.reel_video_effects.subprocess.run') as run:
            _encode_video(source, None, output, 1, time.monotonic())
            source_command = run.call_args.args[0]
            source_maps = [
                source_command[index + 1]
                for index, value in enumerate(source_command[:-1])
                if value == '-map'
            ]

            _encode_video(source, rendered, output, 1, time.monotonic())
            rendered_command = run.call_args.args[0]
            rendered_maps = [
                rendered_command[index + 1]
                for index, value in enumerate(rendered_command[:-1])
                if value == '-map'
            ]

        self.assertEqual(source_maps, ['0:v:0', '0:a?'])
        self.assertEqual(rendered_maps, ['0:v:0', '1:a?'])

    def test_light_filter_changes_the_frame(self):
        frame = np.full((80, 80, 3), 100, dtype=np.uint8)
        filtered = cv2.convertScaleAbs(frame, alpha=1.08, beta=12)
        self.assertGreater(int(filtered[40, 40, 0]), int(frame[40, 40, 0]))

    def test_sticker_draws_pixels_on_the_frame(self):
        frame = np.zeros((160, 160, 3), dtype=np.uint8)
        _draw_sticker(frame, 'star')
        self.assertGreater(int(frame.sum()), 0)

    def test_face_effect_softens_detected_face_region(self):
        class FaceDetector:
            def detectMultiScale(self, image, **kwargs):
                return [(20, 20, 40, 40)]

        frame = np.zeros((80, 80, 3), dtype=np.uint8)
        frame[20:60, 20:60] = np.indices((40, 40)).sum(axis=0)[:, :, None] % 2 * 255
        original = frame.copy()

        detected = _soften_faces(frame, FaceDetector())

        self.assertTrue(detected)
        self.assertFalse(np.array_equal(frame[20:60, 20:60], original[20:60, 20:60]))


class ReelEffectApiTests(APITestCase):
    def setUp(self):
        self.user = User.objects.create_user(
            username='reel_creator',
            password='test-password',
        )
        self.client.force_authenticate(user=self.user)
        self.media_directory = tempfile.TemporaryDirectory()
        self.media_settings = override_settings(MEDIA_ROOT=self.media_directory.name)
        self.media_settings.enable()

    def tearDown(self):
        self.media_settings.disable()
        self.media_directory.cleanup()

    def _video(self):
        return SimpleUploadedFile(
            'clip.mp4',
            b'uploaded video bytes',
            content_type='video/mp4',
        )

    def test_effect_and_theme_are_saved_with_processed_video(self):
        processed_video = File(io.BytesIO(b'processed mp4 bytes'), name='reel.mp4')
        thumbnail = ContentFile(b'thumbnail bytes', name='reel.jpg')
        with patch(
            'core.reel_video_effects.process_reel_video',
            return_value=(processed_video, 8.6, thumbnail),
        ) as process_video:
            response = self.client.post(
                '/api/reels/',
                {
                    'title': 'Présentation',
                    'description': 'Un nouveau produit.',
                    'video': self._video(),
                    'theme': 'Recettes',
                    'effect': 'light',
                    'sticker': '',
                },
                format='multipart',
            )

        self.assertEqual(response.status_code, 201, response.data)
        reel = Reel.objects.get(title='Présentation')
        self.assertEqual(reel.theme, 'Recettes')
        self.assertEqual(reel.effect, 'light')
        self.assertEqual(reel.duration.total_seconds(), 9)
        self.assertTrue(reel.thumbnail.name.endswith('.jpg'))
        self.assertEqual(reel.thumbnail.read(), b'thumbnail bytes')
        process_video.assert_called_once()

    def test_before_after_effect_requires_both_videos(self):
        with patch('core.reel_video_effects.process_reel_video') as process_video:
            response = self.client.post(
                '/api/reels/',
                {
                    'title': 'Avant et après',
                    'video': self._video(),
                    'theme': 'Produits',
                    'effect': 'before_after',
                },
                format='multipart',
            )

        self.assertEqual(response.status_code, 400, response.data)
        self.assertIn('before_video', response.data)
        process_video.assert_not_called()

    def test_sticker_effect_requires_a_supported_sticker(self):
        response = self.client.post(
            '/api/reels/',
            {
                'title': 'Un clip',
                'video': self._video(),
                'theme': 'Produits',
                'effect': 'stickers',
            },
            format='multipart',
        )

        self.assertEqual(response.status_code, 400, response.data)
        self.assertIn('sticker', response.data)
