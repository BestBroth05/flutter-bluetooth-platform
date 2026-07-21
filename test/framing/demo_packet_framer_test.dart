import 'package:bluetooth_platform/demo_protocol/demo_packet_codec.dart';
import 'package:bluetooth_platform/demo_protocol/demo_packet_framer.dart';
import 'package:bluetooth_platform/demo_protocol/demo_protocol_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DemoPacketFramer', () {
    late DemoPacketFramer framer;

    setUp(() {
      framer = DemoPacketFramer();
    });

    test('reassembles a complete frame in one chunk', () {
      final frame = DemoPacketCodec.encode(const <int>[0x10, 0x20, 0x30]);

      final packets = framer.push(frame);

      expect(packets, hasLength(1));
      expect(packets.single.payload, <int>[0x10, 0x20, 0x30]);
      expect(packets.single.rawBytes, frame);
      expect(framer.bufferedLength, 0);
    });

    test('reassembles one frame fragmented across multiple chunks', () {
      final frame = DemoPacketCodec.encode(const <int>[0xAA, 0xBB, 0xCC, 0xDD]);
      final first = frame.sublist(0, 4);
      final second = frame.sublist(4);

      expect(framer.push(first), isEmpty);
      expect(framer.bufferedLength, first.length);

      final packets = framer.push(second);

      expect(packets, hasLength(1));
      expect(packets.single.payload, <int>[0xAA, 0xBB, 0xCC, 0xDD]);
      expect(framer.bufferedLength, 0);
    });

    test('extracts multiple frames from one chunk', () {
      final first = DemoPacketCodec.encode(const <int>[0x01]);
      final second = DemoPacketCodec.encode(const <int>[0x02, 0x03]);
      final chunk = <int>[...first, ...second];

      final packets = framer.push(chunk);

      expect(packets, hasLength(2));
      expect(packets[0].payload, <int>[0x01]);
      expect(packets[1].payload, <int>[0x02, 0x03]);
    });

    test('handles a complete frame followed by a partial frame', () {
      final complete = DemoPacketCodec.encode(const <int>[0x11]);
      final partial = DemoPacketCodec.encode(const <int>[
        0x22,
        0x33,
      ]).sublist(0, 4);
      final chunk = <int>[...complete, ...partial];

      final packets = framer.push(chunk);

      expect(packets, hasLength(1));
      expect(packets.single.payload, <int>[0x11]);
      expect(framer.bufferedLength, partial.length);
    });

    test('ignores malformed magic and recovers on valid frame', () {
      final garbage = <int>[0x00, 0x01, 0x02, 0x50, 0x00];
      final valid = DemoPacketCodec.encode(const <int>[0x7E]);

      expect(framer.push(garbage), isEmpty);

      final packets = framer.push(valid);

      expect(packets, hasLength(1));
      expect(packets.single.payload, <int>[0x7E]);
    });

    test('rejects excessive frame length and resynchronizes', () {
      final bogusHeader = <int>[
        ...DemoProtocolConstants.magic,
        0xFF, // claims 0xFFFF payload bytes
        0xFF,
        0x01,
        0x02,
      ];
      final valid = DemoPacketCodec.encode(const <int>[0x42]);

      expect(framer.push(bogusHeader), isEmpty);

      final packets = framer.push(valid);

      expect(packets, hasLength(1));
      expect(packets.single.payload, <int>[0x42]);
    });

    test('reset clears buffered partial data', () {
      final partial = DemoPacketCodec.encode(const <int>[
        0x01,
        0x02,
      ]).sublist(0, 3);
      framer.push(partial);
      expect(framer.bufferedLength, greaterThan(0));

      framer.reset();

      expect(framer.bufferedLength, 0);
    });
  });
}
