import 'package:equatable/equatable.dart';

import 'characteristic_ref.dart';

/// Raw notification or indication bytes from a subscribed characteristic.
final class BleNotificationEvent extends Equatable {
  const BleNotificationEvent({
    required this.characteristic,
    required this.bytes,
    required this.receivedAt,
  });

  final CharacteristicRef characteristic;
  final List<int> bytes;
  final DateTime receivedAt;

  @override
  List<Object?> get props => [characteristic, bytes, receivedAt];
}
