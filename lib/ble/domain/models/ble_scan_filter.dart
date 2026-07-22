import 'package:equatable/equatable.dart';

/// Optional filters applied during a BLE scan.
final class BleScanFilter extends Equatable {
  const BleScanFilter({
    this.nameContains,
    this.serviceUuids = const <String>[],
    this.minRssiDbm,
  });

  /// Case-insensitive substring match against the advertised name.
  final String? nameContains;

  /// Match devices that advertise any of these service UUIDs.
  final List<String> serviceUuids;

  /// Drop devices weaker than this RSSI (more negative = weaker).
  final int? minRssiDbm;

  bool get isEmpty =>
      (nameContains == null || nameContains!.trim().isEmpty) &&
      serviceUuids.isEmpty &&
      minRssiDbm == null;

  @override
  List<Object?> get props => [nameContains, serviceUuids, minRssiDbm];
}
