import 'package:equatable/equatable.dart';

/// A decoded telemetry sample produced after packet reassembly.
final class TelemetrySample extends Equatable {
  const TelemetrySample({required this.payload, required this.receivedAt});

  final List<int> payload;
  final DateTime receivedAt;

  @override
  List<Object?> get props => [payload, receivedAt];
}
