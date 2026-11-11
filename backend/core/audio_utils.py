def audio_extension(audio_bytes):
    if audio_bytes.startswith(b'RIFF') and audio_bytes[8:12] == b'WAVE':
        return 'wav'
    if len(audio_bytes) >= 8 and audio_bytes[4:8] == b'ftyp':
        return 'm4a'
    if audio_bytes.startswith(b'OggS'):
        return 'ogg'
    if audio_bytes.startswith(b'\x1a\x45\xdf\xa3'):
        return 'webm'
    if audio_bytes.startswith(b'fLaC'):
        return 'flac'
    if audio_bytes.startswith(b'ID3') or (
        len(audio_bytes) >= 2
        and audio_bytes[0] == 0xff
        and audio_bytes[1] & 0xe0 == 0xe0
    ):
        return 'mp3'
    if (
        len(audio_bytes) >= 2
        and audio_bytes[0] == 0xff
        and audio_bytes[1] & 0xf6 == 0xf0
    ):
        return 'aac'
    return None


def has_audio_payload(audio_bytes):
    extension = audio_extension(audio_bytes)
    if extension == 'wav':
        return _has_wav_payload(audio_bytes)
    if extension == 'm4a':
        return _has_mp4_payload(audio_bytes)
    return extension is not None and len(audio_bytes) > 128


def _has_wav_payload(audio_bytes):
    if len(audio_bytes) < 44:
        return False
    declared_length = int.from_bytes(audio_bytes[4:8], 'little') + 8
    if declared_length > len(audio_bytes):
        return False

    offset = 12
    while offset + 8 <= declared_length:
        chunk_type = audio_bytes[offset:offset + 4]
        chunk_length = int.from_bytes(audio_bytes[offset + 4:offset + 8], 'little')
        chunk_end = offset + 8 + chunk_length
        if chunk_end > declared_length:
            return False
        if chunk_type == b'data':
            return chunk_length > 0
        offset = chunk_end + (chunk_length & 1)
    return False


def _has_mp4_payload(audio_bytes):
    offset = 0
    while offset + 8 <= len(audio_bytes):
        atom_length = int.from_bytes(audio_bytes[offset:offset + 4], 'big')
        atom_type = audio_bytes[offset + 4:offset + 8]
        header_length = 8
        if atom_length == 1:
            if offset + 16 > len(audio_bytes):
                return False
            atom_length = int.from_bytes(audio_bytes[offset + 8:offset + 16], 'big')
            header_length = 16
        elif atom_length == 0:
            atom_length = len(audio_bytes) - offset

        if atom_length < header_length or offset + atom_length > len(audio_bytes):
            return False
        if atom_type == b'mdat':
            return atom_length - header_length > 16
        offset += atom_length
    return False


def upload_has_audio_payload(upload):
    position = upload.tell()
    try:
        return has_audio_payload(upload.read())
    finally:
        upload.seek(position)
