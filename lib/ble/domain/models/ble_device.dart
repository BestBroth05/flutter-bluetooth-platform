import 'package:equatable/equatable.dart';

import 'signal_strength.dart';

/// A Bluetooth Low Energy peripheral discovered during a scan.
final class BleDevice extends Equatable {
  const BleDevice({
    required this.id,
    required this.name,
    required this.signalStrength,
    this.isConnectable = true,
  });

  /// Platform remote identifier for the peripheral.
  final String id;

  /// Advertised local name, or a placeholder when unnamed.
  final String name;

  final SignalStrength signalStrength;

  final bool isConnectable;

  BleDevice copyWith({
    String? id,
    String? name,
    SignalStrength? signalStrength,
    bool? isConnectable,
  }) {
    return BleDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      signalStrength: signalStrength ?? this.signalStrength,
      isConnectable: isConnectable ?? this.isConnectable,
    );
  }

  @override
  List<Object?> get props => [id, name, signalStrength, isConnectable];
}
