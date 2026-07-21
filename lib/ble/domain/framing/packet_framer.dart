import 'framed_packet.dart';

/// Reassembles a byte stream into complete framed packets.
///
/// Implementations must tolerate fragmented chunks, multiple frames in one
/// chunk, and malformed input with buffer recovery.
abstract class PacketFramer {
  /// Push a chunk of bytes and return zero or more complete frames.
  List<FramedPacket> push(List<int> chunk);

  /// Clears any buffered partial data.
  void reset();

  /// Current number of buffered bytes awaiting a complete frame.
  int get bufferedLength;
}
