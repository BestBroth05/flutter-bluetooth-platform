import 'package:equatable/equatable.dart';

/// A generic command payload written to a writable GATT characteristic.
final class BleCommand extends Equatable {
  const BleCommand(this.bytes);

  final List<int> bytes;

  @override
  List<Object?> get props => [bytes];
}
