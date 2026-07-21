import 'package:equatable/equatable.dart';

/// A complete framed packet extracted from a byte stream.
final class FramedPacket extends Equatable {
  const FramedPacket({required this.payload, required this.rawBytes});

  /// Application payload without framing headers.
  final List<int> payload;

  /// Full on-wire bytes including magic and length header.
  final List<int> rawBytes;

  @override
  List<Object?> get props => [payload, rawBytes];
}
