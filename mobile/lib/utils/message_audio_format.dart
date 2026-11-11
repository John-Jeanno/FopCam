import 'dart:typed_data';

class MessageAudioFormat {
  const MessageAudioFormat({required this.extension, required this.mimeType});

  final String extension;
  final String mimeType;

  static MessageAudioFormat detect(
    Uint8List bytes, {
    String? contentType,
    String? sourceUrl,
  }) {
    if (_matches(bytes, 0, const [0x52, 0x49, 0x46, 0x46]) &&
        _matches(bytes, 8, const [0x57, 0x41, 0x56, 0x45])) {
      return const MessageAudioFormat(extension: 'wav', mimeType: 'audio/wav');
    }
    if (_matches(bytes, 0, const [0x66, 0x4c, 0x61, 0x43])) {
      return const MessageAudioFormat(
        extension: 'flac',
        mimeType: 'audio/flac',
      );
    }
    if (_matches(bytes, 0, const [0x4f, 0x67, 0x67, 0x53])) {
      return const MessageAudioFormat(extension: 'ogg', mimeType: 'audio/ogg');
    }
    if (_matches(bytes, 0, const [0x1a, 0x45, 0xdf, 0xa3])) {
      return const MessageAudioFormat(
        extension: 'webm',
        mimeType: 'audio/webm',
      );
    }
    if (_matches(bytes, 0, const [0x49, 0x44, 0x33]) ||
        (bytes.length >= 2 && bytes[0] == 0xff && (bytes[1] & 0xe0) == 0xe0)) {
      return const MessageAudioFormat(extension: 'mp3', mimeType: 'audio/mpeg');
    }
    if (bytes.length >= 8 &&
        _matches(bytes, 4, const [0x66, 0x74, 0x79, 0x70])) {
      return const MessageAudioFormat(extension: 'm4a', mimeType: 'audio/mp4');
    }

    final fromContentType = _fromMimeType(contentType);
    if (fromContentType != null) return fromContentType;

    final path = Uri.tryParse(sourceUrl ?? '')?.path.toLowerCase() ?? '';
    final extension = path.split('.').last;
    return switch (extension) {
      'wav' => const MessageAudioFormat(
        extension: 'wav',
        mimeType: 'audio/wav',
      ),
      'mp3' => const MessageAudioFormat(
        extension: 'mp3',
        mimeType: 'audio/mpeg',
      ),
      'ogg' || 'oga' => const MessageAudioFormat(
        extension: 'ogg',
        mimeType: 'audio/ogg',
      ),
      'webm' => const MessageAudioFormat(
        extension: 'webm',
        mimeType: 'audio/webm',
      ),
      'aac' => const MessageAudioFormat(
        extension: 'aac',
        mimeType: 'audio/aac',
      ),
      'flac' => const MessageAudioFormat(
        extension: 'flac',
        mimeType: 'audio/flac',
      ),
      _ => const MessageAudioFormat(extension: 'm4a', mimeType: 'audio/mp4'),
    };
  }

  static bool hasAudioPayload(Uint8List bytes) {
    if (bytes.length < 12) return false;
    if (_matches(bytes, 0, const [0x52, 0x49, 0x46, 0x46]) &&
        _matches(bytes, 8, const [0x57, 0x41, 0x56, 0x45])) {
      return _hasWavAudioPayload(bytes);
    }
    if (_matches(bytes, 4, const [0x66, 0x74, 0x79, 0x70])) {
      return _hasMp4AudioPayload(bytes);
    }
    return bytes.length > 128;
  }

  static bool _hasWavAudioPayload(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    final declaredLength = data.getUint32(4, Endian.little) + 8;
    if (declaredLength > bytes.length) return false;
    var offset = 12;
    while (offset + 8 <= declaredLength) {
      final chunkLength = data.getUint32(offset + 4, Endian.little);
      final chunkEnd = offset + 8 + chunkLength;
      if (chunkEnd > declaredLength) return false;
      if (_matches(bytes, offset, const [0x64, 0x61, 0x74, 0x61])) {
        return chunkLength > 0;
      }
      offset = chunkEnd + (chunkLength.isOdd ? 1 : 0);
    }
    return false;
  }

  static bool _hasMp4AudioPayload(Uint8List bytes) {
    final data = ByteData.sublistView(bytes);
    var offset = 0;
    while (offset + 8 <= bytes.length) {
      final atomLength = data.getUint32(offset, Endian.big);
      final atomType = String.fromCharCodes(
        bytes.sublist(offset + 4, offset + 8),
      );
      var headerLength = 8;
      var length = atomLength;
      if (atomLength == 1) {
        if (offset + 16 > bytes.length) return false;
        length = data.getUint64(offset + 8, Endian.big);
        headerLength = 16;
      } else if (atomLength == 0) {
        length = bytes.length - offset;
      }
      if (length < headerLength || offset + length > bytes.length) return false;
      if (atomType == 'mdat') return length > headerLength + 16;
      offset += length;
    }
    return false;
  }

  static bool _matches(Uint8List bytes, int offset, List<int> signature) =>
      bytes.length >= offset + signature.length &&
      signature.indexed.every((entry) => bytes[offset + entry.$1] == entry.$2);

  static MessageAudioFormat? _fromMimeType(String? contentType) {
    final mimeType = contentType?.split(';').first.trim().toLowerCase();
    return switch (mimeType) {
      'audio/wav' || 'audio/wave' || 'audio/x-wav' => const MessageAudioFormat(
        extension: 'wav',
        mimeType: 'audio/wav',
      ),
      'audio/mpeg' || 'audio/mp3' => const MessageAudioFormat(
        extension: 'mp3',
        mimeType: 'audio/mpeg',
      ),
      'audio/ogg' || 'audio/opus' => const MessageAudioFormat(
        extension: 'ogg',
        mimeType: 'audio/ogg',
      ),
      'audio/webm' => const MessageAudioFormat(
        extension: 'webm',
        mimeType: 'audio/webm',
      ),
      'audio/aac' => const MessageAudioFormat(
        extension: 'aac',
        mimeType: 'audio/aac',
      ),
      'audio/flac' => const MessageAudioFormat(
        extension: 'flac',
        mimeType: 'audio/flac',
      ),
      'audio/mp4' || 'audio/x-m4a' => const MessageAudioFormat(
        extension: 'm4a',
        mimeType: 'audio/mp4',
      ),
      _ => null,
    };
  }
}
