import 'package:bluetooth_platform/core/codec/byte_codecs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ByteCodecs', () {
    test('parses spaced and contiguous hex', () {
      expect(ByteCodecs.parseHex('01 02 03'), <int>[0x01, 0x02, 0x03]);
      expect(ByteCodecs.parseHex('0102FF'), <int>[0x01, 0x02, 0xFF]);
    });

    test('rejects invalid hex', () {
      expect(() => ByteCodecs.parseHex('01 0'), throwsFormatException);
      expect(() => ByteCodecs.parseHex('zz'), throwsFormatException);
    });

    test('encodes utf8/ascii text', () {
      expect(ByteCodecs.encodeUtf8('PING'), 'PING'.codeUnits);
    });

    test('decodes printable text only', () {
      expect(
        ByteCodecs.tryDecodePrintable(<int>[0x50, 0x49, 0x4E, 0x47]),
        'PING',
      );
      expect(ByteCodecs.tryDecodePrintable(<int>[0x00, 0x01]), isNull);
    });
  });
}
