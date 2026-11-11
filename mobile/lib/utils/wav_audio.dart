import 'dart:typed_data';

Uint8List wavFromPcm16(Uint8List pcmData, {required int sampleRate}) {
  const channels = 1;
  const bitsPerSample = 16;
  final header = ByteData(44);
  final byteRate = sampleRate * channels * bitsPerSample ~/ 8;

  void writeTag(int offset, String tag) {
    for (var index = 0; index < tag.length; index++) {
      header.setUint8(offset + index, tag.codeUnitAt(index));
    }
  }

  writeTag(0, 'RIFF');
  header.setUint32(4, 36 + pcmData.length, Endian.little);
  writeTag(8, 'WAVE');
  writeTag(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little);
  header.setUint16(34, bitsPerSample, Endian.little);
  writeTag(36, 'data');
  header.setUint32(40, pcmData.length, Endian.little);

  final wavData = Uint8List(header.lengthInBytes + pcmData.length)
    ..setRange(0, header.lengthInBytes, header.buffer.asUint8List())
    ..setRange(
      header.lengthInBytes,
      header.lengthInBytes + pcmData.length,
      pcmData,
    );
  return wavData;
}
