import '../ble/domain/framing/framed_packet.dart';
import '../ble/domain/framing/packet_framer.dart';
import 'demo_protocol_constants.dart';

/// Generic demo framer that reassembles invented `PKT` length-prefixed frames.
///
/// This implementation is original portfolio code and is not derived from any
/// commercial device protocol.
final class DemoPacketFramer implements PacketFramer {
  final List<int> _buffer = <int>[];

  @override
  int get bufferedLength => _buffer.length;

  @override
  void reset() => _buffer.clear();

  @override
  List<FramedPacket> push(List<int> chunk) {
    _buffer.addAll(chunk);
    final frames = <FramedPacket>[];

    while (true) {
      final magicIndex = _indexOfMagic(_buffer);
      if (magicIndex < 0) {
        _trimUnmatchedPrefix();
        break;
      }

      if (magicIndex > 0) {
        _buffer.removeRange(0, magicIndex);
      }

      if (_buffer.length < DemoProtocolConstants.headerLength) {
        break;
      }

      final payloadLength =
          (_buffer[DemoProtocolConstants.magicLength] << 8) |
          _buffer[DemoProtocolConstants.magicLength + 1];

      if (payloadLength > DemoProtocolConstants.maxPayloadLength) {
        // Drop the bogus magic byte and resynchronize.
        _buffer.removeAt(0);
        continue;
      }

      final totalLength = DemoProtocolConstants.headerLength + payloadLength;
      if (_buffer.length < totalLength) {
        break;
      }

      final rawBytes = List<int>.from(_buffer.sublist(0, totalLength));
      final payload = List<int>.from(
        rawBytes.sublist(DemoProtocolConstants.headerLength),
      );
      _buffer.removeRange(0, totalLength);
      frames.add(FramedPacket(payload: payload, rawBytes: rawBytes));
    }

    return frames;
  }

  void _trimUnmatchedPrefix() {
    if (_buffer.length <= DemoProtocolConstants.magicLength - 1) {
      return;
    }
    // Keep a short suffix that might be a partial magic marker.
    final keep = DemoProtocolConstants.magicLength - 1;
    _buffer.removeRange(0, _buffer.length - keep);
  }

  int _indexOfMagic(List<int> bytes) {
    final magic = DemoProtocolConstants.magic;
    for (var i = 0; i <= bytes.length - magic.length; i++) {
      var matched = true;
      for (var j = 0; j < magic.length; j++) {
        if (bytes[i + j] != magic[j]) {
          matched = false;
          break;
        }
      }
      if (matched) {
        return i;
      }
    }
    return -1;
  }
}
