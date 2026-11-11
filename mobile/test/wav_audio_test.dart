import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/utils/wav_audio.dart';

void main() {
  test('wraps PCM16 bytes in a valid mono WAV header', () {
    final wav = wavFromPcm16(
      Uint8List.fromList([1, 2, 3, 4]),
      sampleRate: 16000,
    );
    final header = ByteData.sublistView(wav);

    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(header.getUint32(4, Endian.little), 40);
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(header.getUint16(20, Endian.little), 1);
    expect(header.getUint16(22, Endian.little), 1);
    expect(header.getUint32(24, Endian.little), 16000);
    expect(header.getUint32(28, Endian.little), 32000);
    expect(header.getUint16(34, Endian.little), 16);
    expect(header.getUint32(40, Endian.little), 4);
    expect(wav.sublist(44), [1, 2, 3, 4]);
  });
}
