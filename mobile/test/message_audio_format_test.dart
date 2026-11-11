import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/message_audio_format.dart';

void main() {
  test('detects WAV bytes even when the server reports an MP4 MIME type', () {
    final wav = Uint8List.fromList([
      ...'RIFF'.codeUnits,
      0,
      0,
      0,
      0,
      ...'WAVE'.codeUnits,
    ]);

    expect(
      MessageAudioFormat.detect(
        wav,
        contentType: 'audio/mp4',
        sourceUrl: 'https://example.test/voice.m4a',
      ),
      const MessageAudioFormat(extension: 'wav', mimeType: 'audio/wav'),
    );
  });

  test('detects AAC in an M4A container from its file signature', () {
    final m4a = Uint8List.fromList([
      0,
      0,
      0,
      24,
      ...'ftyp'.codeUnits,
      ...'M4A '.codeUnits,
    ]);

    expect(
      MessageAudioFormat.detect(m4a),
      const MessageAudioFormat(extension: 'm4a', mimeType: 'audio/mp4'),
    );
  });

  test('uses the URL extension when bytes and MIME type are unavailable', () {
    expect(
      MessageAudioFormat.detect(
        Uint8List.fromList([0, 1, 2]),
        contentType: 'application/octet-stream',
        sourceUrl: 'https://example.test/voice.wav',
      ),
      const MessageAudioFormat(extension: 'wav', mimeType: 'audio/wav'),
    );
  });

  test('rejects an M4A file containing only its file type header', () {
    final emptyM4a = Uint8List.fromList([
      0,
      0,
      0,
      28,
      ...'ftypM4A '.codeUnits,
      0,
      0,
      0,
      0,
      ...'M4A mp42isom'.codeUnits,
    ]);

    expect(MessageAudioFormat.hasAudioPayload(emptyM4a), isFalse);
  });

  test('accepts an M4A file with media data', () {
    final m4a = Uint8List.fromList([
      0,
      0,
      0,
      16,
      ...'ftypM4A '.codeUnits,
      0,
      0,
      0,
      0,
      0,
      0,
      1,
      8,
      ...'mdat'.codeUnits,
      ...List<int>.filled(256, 1),
    ]);

    expect(MessageAudioFormat.hasAudioPayload(m4a), isTrue);
  });

  test('rejects a WAV file with an empty data chunk', () {
    final wav = Uint8List(44);
    final data = ByteData.sublistView(wav)
      ..setUint32(4, 36, Endian.little)
      ..setUint32(16, 16, Endian.little)
      ..setUint32(40, 0, Endian.little);
    wav.setRange(0, 4, 'RIFF'.codeUnits);
    wav.setRange(8, 12, 'WAVE'.codeUnits);
    wav.setRange(12, 16, 'fmt '.codeUnits);
    wav.setRange(36, 40, 'data'.codeUnits);

    expect(MessageAudioFormat.hasAudioPayload(wav), isFalse);
    expect(data.getUint32(40, Endian.little), 0);
  });

  test('accepts a WAV file containing recorded PCM samples', () {
    const sampleCount = 160;
    final wav = Uint8List(44 + sampleCount * 2);
    final data = ByteData.sublistView(wav)
      ..setUint32(4, 36 + sampleCount * 2, Endian.little)
      ..setUint16(20, 1, Endian.little)
      ..setUint16(22, 1, Endian.little)
      ..setUint32(24, 16000, Endian.little)
      ..setUint32(28, 32000, Endian.little)
      ..setUint16(32, 2, Endian.little)
      ..setUint16(34, 16, Endian.little)
      ..setUint32(40, sampleCount * 2, Endian.little);
    wav.setRange(0, 4, 'RIFF'.codeUnits);
    wav.setRange(8, 12, 'WAVE'.codeUnits);
    wav.setRange(12, 16, 'fmt '.codeUnits);
    data.setUint32(16, 16, Endian.little);
    wav.setRange(36, 40, 'data'.codeUnits);

    expect(MessageAudioFormat.hasAudioPayload(wav), isTrue);
    expect(
      MessageAudioFormat.detect(wav),
      const MessageAudioFormat(extension: 'wav', mimeType: 'audio/wav'),
    );
  });
}
