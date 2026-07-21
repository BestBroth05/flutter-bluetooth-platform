import 'demo_protocol_constants.dart';

/// Encodes and validates demonstration-only framed packets.
///
/// Wire format (big-endian):
/// `[ 'P', 'K', 'T' ][ uint16 payloadLength ][ payload... ]`
abstract final class DemoPacketCodec {
  /// Builds a complete on-wire frame for [payload].
  static List<int> encode(List<int> payload) {
    if (payload.length > DemoProtocolConstants.maxPayloadLength) {
      throw ArgumentError(
        'Payload length ${payload.length} exceeds '
        '${DemoProtocolConstants.maxPayloadLength}.',
      );
    }

    final length = payload.length;
    return <int>[
      ...DemoProtocolConstants.magic,
      (length >> 8) & 0xFF,
      length & 0xFF,
      ...payload,
    ];
  }
}
