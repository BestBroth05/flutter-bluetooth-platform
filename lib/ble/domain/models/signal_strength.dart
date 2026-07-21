import 'package:equatable/equatable.dart';

/// Received signal strength indicator for a discovered or connected device.
final class SignalStrength extends Equatable {
  const SignalStrength(this.rssiDbm);

  /// RSSI in dBm. More negative values indicate a weaker signal.
  final int rssiDbm;

  @override
  List<Object?> get props => [rssiDbm];
}
