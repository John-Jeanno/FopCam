import json
import math
import subprocess
import time
from contextlib import ExitStack
from pathlib import Path
from tempfile import TemporaryDirectory

import cv2
import numpy as np
from django.core.files import File
from django.core.files.base import ContentFile
from django.core.files.uploadedfile import UploadedFile


MAX_REEL_SECONDS = 60
MAX_REEL_SIZE_BYTES = 100 * 1024 * 1024
MAX_PROCESSING_SECONDS = 240
MAX_FRAME_WIDTH = 1920
MAX_FRAME_HEIGHT = 1080
STICKERS = {'sparkle', 'heart', 'star', 'cool'}


class ReelVideoProcessingError(Exception):
    pass


def _save_upload(upload: UploadedFile, destination: Path) -> None:
    if upload.size > MAX_REEL_SIZE_BYTES:
        raise ReelVideoProcessingError('Une vidéo ne peut pas dépasser 100 Mo.')

    upload.seek(0)
    with destination.open('wb') as output:
        for chunk in upload.chunks():
            output.write(chunk)
    upload.seek(0)


def _probe_video(path: Path) -> tuple[float, int, int]:
    try:
        result = subprocess.run(
            [
                'ffprobe',
                '-v',
                'error',
                '-select_streams',
                'v:0',
                '-show_entries',
                'format=duration:stream=width,height',
                '-of',
                'json',
                str(path),
            ],
            check=True,
            capture_output=True,
            text=True,
            timeout=15,
        )
        data = json.loads(result.stdout)
        video_stream = next(
            stream for stream in data.get('streams', []) if stream.get('width')
        )
        duration = float(data['format']['duration'])
        width = int(video_stream['width'])
        height = int(video_stream['height'])
    except (
        OSError,
        subprocess.SubprocessError,
        KeyError,
        StopIteration,
        TypeError,
        ValueError,
        json.JSONDecodeError,
    ) as error:
        raise ReelVideoProcessingError(
            'Le fichier sélectionné ne contient pas une vidéo lisible.'
        ) from error

    if not math.isfinite(duration) or duration <= 0:
        raise ReelVideoProcessingError('La durée de la vidéo est invalide.')
    if duration > MAX_REEL_SECONDS:
        raise ReelVideoProcessingError(
            'La durée maximale d’un clip est de 60 secondes.'
        )
    if width <= 0 or height <= 0:
        raise ReelVideoProcessingError('La résolution de la vidéo est invalide.')
    return duration, width, height


def _fit_to_canvas(frame, width: int, height: int):
    frame_height, frame_width = frame.shape[:2]
    ratio = min(width / frame_width, height / frame_height)
    resized = cv2.resize(
        frame,
        (max(1, round(frame_width * ratio)), max(1, round(frame_height * ratio))),
        interpolation=cv2.INTER_AREA,
    )
    canvas = np.zeros((height, width, 3), dtype=np.uint8)
    x = (width - resized.shape[1]) // 2
    y = (height - resized.shape[0]) // 2
    canvas[y : y + resized.shape[0], x : x + resized.shape[1]] = resized
    return canvas


def _star_points(center_x: int, center_y: int, radius: int):
    return np.array(
        [
            (
                round(
                    center_x
                    + (radius if index % 2 == 0 else radius * 0.42)
                    * math.cos(index * math.pi / 5 - math.pi / 2)
                ),
                round(
                    center_y
                    + (radius if index % 2 == 0 else radius * 0.42)
                    * math.sin(index * math.pi / 5 - math.pi / 2)
                ),
            )
            for index in range(10)
        ],
        dtype=np.int32,
    )


def _draw_sticker(frame, sticker: str) -> None:
    height, width = frame.shape[:2]
    scale = max(0.7, min(width, height) / 720)
    center = (width - round(72 * scale), round(72 * scale))
    radius = round(36 * scale)
    white = (255, 255, 255)
    if sticker in {'sparkle', 'star'}:
        color = (0, 220, 255) if sticker == 'sparkle' else (40, 190, 255)
        cv2.fillPoly(frame, [_star_points(*center, radius)], color)
        if sticker == 'sparkle':
            cv2.fillPoly(
                frame,
                [_star_points(center[0] - radius, center[1] + radius, radius // 2)],
                white,
            )
    elif sticker == 'heart':
        cx, cy = center
        points = np.array(
            [
                (cx, cy + radius),
                (cx - radius, cy - radius // 4),
                (cx - radius, cy - radius),
                (cx - radius // 2, cy - radius),
                (cx, cy - radius // 2),
                (cx + radius // 2, cy - radius),
                (cx + radius, cy - radius),
                (cx + radius, cy - radius // 4),
            ],
            dtype=np.int32,
        )
        cv2.fillPoly(frame, [points], (40, 60, 240))
    elif sticker == 'cool':
        left = (center[0] - radius, center[1] - radius // 4)
        right = (center[0] + radius, center[1] - radius // 4)
        cv2.rectangle(
            frame,
            (left[0] - radius // 2, left[1] - radius // 2),
            (left[0] + radius // 2, left[1] + radius // 2),
            (25, 25, 25),
            -1,
        )
        cv2.rectangle(
            frame,
            (right[0] - radius // 2, right[1] - radius // 2),
            (right[0] + radius // 2, right[1] + radius // 2),
            (25, 25, 25),
            -1,
        )
        cv2.line(
            frame,
            (center[0] - radius // 2, left[1]),
            (center[0] + radius // 2, right[1]),
            white,
            max(2, round(3 * scale)),
        )


def _soften_faces(frame, detector) -> bool:
    height, width = frame.shape[:2]
    detection_width = min(width, 480)
    detection_scale = detection_width / width
    detection_frame = (
        frame
        if detection_scale == 1
        else cv2.resize(
            frame,
            (
                detection_width,
                max(1, round(height * detection_scale)),
            ),
            interpolation=cv2.INTER_AREA,
        )
    )
    gray = cv2.cvtColor(detection_frame, cv2.COLOR_BGR2GRAY)
    faces = detector.detectMultiScale(
        gray,
        scaleFactor=1.1,
        minNeighbors=5,
        minSize=(28, 28),
    )
    detected = False
    for x, y, face_width, face_height in faces:
        x = max(0, round(x / detection_scale))
        y = max(0, round(y / detection_scale))
        face_width = min(width - x, round(face_width / detection_scale))
        face_height = min(height - y, round(face_height / detection_scale))
        if face_width <= 0 or face_height <= 0:
            continue
        region = frame[y : y + face_height, x : x + face_width]
        blurred = cv2.GaussianBlur(
            region,
            (0, 0),
            sigmaX=max(1, min(face_width, face_height) * 0.035),
        )
        mask = np.zeros((face_height, face_width), dtype=np.uint8)
        cv2.ellipse(
            mask,
            (face_width // 2, face_height // 2),
            (max(1, face_width // 2), max(1, face_height // 2)),
            0,
            0,
            360,
            255,
            -1,
        )
        mask = cv2.GaussianBlur(mask, (0, 0), sigmaX=max(1, face_width * 0.04))
        alpha = (mask.astype(np.float32) / 255 * 0.35)[:, :, np.newaxis]
        region[:] = (
            region.astype(np.float32) * (1 - alpha)
            + blurred.astype(np.float32) * alpha
        ).astype(np.uint8)
        detected = True
    return detected


def _open_capture(path: Path):
    capture = cv2.VideoCapture(str(path))
    if not capture.isOpened():
        capture.release()
        raise ReelVideoProcessingError('Impossible de lire la vidéo sélectionnée.')
    fps = capture.get(cv2.CAP_PROP_FPS)
    if not math.isfinite(fps) or fps < 1 or fps > 240:
        fps = 30
    return capture, fps


def _render_effect_video(
    source_path: Path,
    output_path: Path,
    effect: str,
    sticker: str,
    started_at: float,
    before_path: Path | None = None,
    duration: float | None = None,
) -> tuple[float, float]:
    with ExitStack() as resources:
        after_capture, after_fps = _open_capture(source_path)
        resources.callback(after_capture.release)
        before_capture = None
        before_fps = after_fps
        if before_path is not None:
            before_capture, before_fps = _open_capture(before_path)
            resources.callback(before_capture.release)

        output_fps = min(30.0, after_fps, before_fps)
        if duration is None:
            duration = float(after_capture.get(cv2.CAP_PROP_FRAME_COUNT)) / after_fps
        writer_size = (1280, 720) if before_capture is not None else None
        if writer_size is None:
            width = int(after_capture.get(cv2.CAP_PROP_FRAME_WIDTH))
            height = int(after_capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
            if width <= 0 or height <= 0:
                raise ReelVideoProcessingError(
                    'Impossible de lire la résolution de la vidéo.'
                )
            scale = min(1.0, MAX_FRAME_WIDTH / width, MAX_FRAME_HEIGHT / height)
            writer_size = (
                max(1, round(width * scale)),
                max(1, round(height * scale)),
            )

        writer = cv2.VideoWriter(
            str(output_path),
            cv2.VideoWriter_fourcc(*'MJPG'),
            output_fps,
            writer_size,
        )
        resources.callback(writer.release)
        if not writer.isOpened():
            raise ReelVideoProcessingError(
                'Impossible de préparer le rendu vidéo sur le serveur.'
            )

        detector = None
        if effect == 'face':
            cascade_path = (
                Path(cv2.data.haarcascades) / 'haarcascade_frontalface_default.xml'
            )
            detector = cv2.CascadeClassifier(str(cascade_path))
            if detector.empty():
                raise ReelVideoProcessingError(
                    'Le détecteur de visage est indisponible sur le serveur.'
                )

        frame_index = -1
        before_index = -1
        after_frame = None
        before_frame = None
        rendered_frames = 0
        detected_faces = False
        target_frames = math.ceil(duration * output_fps)
        for output_index in range(target_frames):
            if time.monotonic() - started_at > MAX_PROCESSING_SECONDS:
                raise ReelVideoProcessingError(
                    'Le traitement dépasse le délai autorisé. '
                    'Choisissez une vidéo plus courte.'
                )
            target_time = output_index / output_fps
            target_after_index = round(target_time * after_fps)
            while frame_index < target_after_index:
                ok, next_frame = after_capture.read()
                if not ok:
                    after_frame = None
                    break
                frame_index += 1
                after_frame = next_frame
            if after_frame is None:
                break

            frame = after_frame
            if before_capture is not None:
                target_before_index = round(target_time * before_fps)
                while before_index < target_before_index:
                    ok, next_frame = before_capture.read()
                    if not ok:
                        before_frame = None
                        break
                    before_index += 1
                    before_frame = next_frame
                if before_frame is None:
                    break
                before_canvas = _fit_to_canvas(before_frame, 640, 720)
                after_canvas = _fit_to_canvas(after_frame, 640, 720)
                cv2.putText(
                    before_canvas,
                    'AVANT',
                    (24, 52),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    1,
                    (255, 255, 255),
                    2,
                    cv2.LINE_AA,
                )
                cv2.putText(
                    after_canvas,
                    'APRES',
                    (24, 52),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    1,
                    (255, 255, 255),
                    2,
                    cv2.LINE_AA,
                )
                frame = cv2.hconcat((before_canvas, after_canvas))
            else:
                frame_height, frame_width = frame.shape[:2]
                if (frame_width, frame_height) != writer_size:
                    frame = cv2.resize(
                        frame,
                        writer_size,
                        interpolation=cv2.INTER_AREA,
                    )

                if effect == 'light':
                    frame = cv2.convertScaleAbs(frame, alpha=1.08, beta=12)
                elif effect == 'stickers':
                    _draw_sticker(frame, sticker)
                elif effect == 'face':
                    detected_faces = _soften_faces(frame, detector) or detected_faces

            writer.write(frame)
            rendered_frames += 1

    if rendered_frames == 0:
        raise ReelVideoProcessingError('Aucune image vidéo n’a pu être traitée.')
    if effect == 'face' and not detected_faces:
        raise ReelVideoProcessingError(
            'Aucun visage de face détecté. Choisissez une vidéo où le visage '
            'est bien visible.'
        )
    return rendered_frames / output_fps, output_fps


def _encode_video(
    source_path: Path,
    rendered_path: Path | None,
    output_path: Path,
    duration: float,
    started_at: float,
) -> None:
    command = [
        'ffmpeg',
        '-nostdin',
        '-hide_banner',
        '-loglevel',
        'error',
        '-y',
        '-i',
        str(rendered_path or source_path),
    ]
    if rendered_path is not None:
        command.extend(['-i', str(source_path)])

    command.extend(
        [
            '-map',
            '0:v:0',
            '-map',
            '1:a?',
            '-c:v',
            'libx264',
            '-preset',
            'veryfast',
            '-crf',
            '23',
            '-pix_fmt',
            'yuv420p',
            '-c:a',
            'aac',
            '-b:a',
            '128k',
            '-t',
            f'{duration:.3f}',
            '-movflags',
            '+faststart',
            str(output_path),
        ]
    )
    if rendered_path is None:
        command[command.index('1:a?')] = '0:a?'

    try:
        subprocess.run(
            command,
            check=True,
            capture_output=True,
            text=True,
            timeout=MAX_PROCESSING_SECONDS,
        )
    except FileNotFoundError as error:
        raise ReelVideoProcessingError(
            'Le moteur vidéo est indisponible sur le serveur.'
        ) from error
    except subprocess.TimeoutExpired as error:
        raise ReelVideoProcessingError(
            'Le traitement dépasse le délai autorisé. Choisissez une vidéo plus courte.'
        ) from error
    except subprocess.CalledProcessError as error:
        raise ReelVideoProcessingError(
            'Le serveur n’a pas pu encoder cette vidéo. Vérifiez son format.'
        ) from error

    if time.monotonic() - started_at > MAX_PROCESSING_SECONDS:
        raise ReelVideoProcessingError(
            'Le traitement dépasse le délai autorisé. '
            'Choisissez une vidéo plus courte.'
        )


def _create_thumbnail(video_path: Path, duration: float) -> ContentFile:
    capture, _ = _open_capture(video_path)
    try:
        timestamp = min(1000.0, duration * 500)
        capture.set(cv2.CAP_PROP_POS_MSEC, timestamp)
        ok, frame = capture.read()
        if not ok:
            raise ReelVideoProcessingError(
                'Impossible de créer l’aperçu de cette vidéo.'
            )
        height, width = frame.shape[:2]
        scale = min(1.0, 640 / width)
        if scale < 1:
            frame = cv2.resize(
                frame,
                (max(1, round(width * scale)), max(1, round(height * scale))),
                interpolation=cv2.INTER_AREA,
            )
        ok, encoded = cv2.imencode(
            '.jpg',
            frame,
            [cv2.IMWRITE_JPEG_QUALITY, 85],
        )
        if not ok:
            raise ReelVideoProcessingError(
                'Impossible de créer l’aperçu de cette vidéo.'
            )
        return ContentFile(encoded.tobytes(), name='reel.jpg')
    finally:
        capture.release()


def process_reel_video(
    video: UploadedFile,
    *,
    effect: str,
    sticker: str,
    before_video: UploadedFile | None = None,
) -> tuple[File, float, ContentFile]:
    if effect not in {'none', 'light', 'stickers', 'before_after', 'face'}:
        raise ReelVideoProcessingError('L’effet vidéo sélectionné est invalide.')
    if effect == 'stickers' and sticker not in STICKERS:
        raise ReelVideoProcessingError('L’autocollant sélectionné est invalide.')
    if effect == 'before_after' and before_video is None:
        raise ReelVideoProcessingError(
            'Choisissez également la vidéo « avant » pour créer le montage.'
        )
    if effect != 'before_after' and before_video is not None:
        raise ReelVideoProcessingError(
            'La vidéo « avant » ne peut être jointe qu’au montage avant/après.'
        )

    started_at = time.monotonic()
    try:
        with TemporaryDirectory(prefix='fopcam-reel-') as temp_directory:
            directory = Path(temp_directory)
            after_path = directory / 'after_upload'
            _save_upload(video, after_path)
            after_duration, _, _ = _probe_video(after_path)
            before_path = None
            duration = after_duration
            if before_video is not None:
                before_path = directory / 'before_upload'
                _save_upload(before_video, before_path)
                before_duration, _, _ = _probe_video(before_path)
                duration = min(duration, before_duration)

            rendered_path = None
            if effect in {'light', 'stickers', 'before_after', 'face'}:
                rendered_path = directory / 'rendered.avi'
                duration, _ = _render_effect_video(
                    after_path,
                    rendered_path,
                    effect,
                    sticker,
                    started_at,
                    before_path=before_path,
                    duration=duration,
                )

            output_path = directory / 'reel.mp4'
            _encode_video(
                after_path,
                rendered_path,
                output_path,
                duration,
                started_at,
            )
            thumbnail = _create_thumbnail(output_path, duration)
            processed = File(output_path.open('rb'), name='reel.mp4')
            return processed, duration, thumbnail
    except ReelVideoProcessingError:
        raise
    except (cv2.error, OSError, ValueError) as error:
        raise ReelVideoProcessingError(
            'Le traitement de la vidéo a échoué. Vérifiez le fichier et réessayez.'
        ) from error
