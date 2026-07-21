import 'package:equatable/equatable.dart';

/// Battery level reported by a sensor, as a percentage from 0 to 100.
final class BatteryLevel extends Equatable {
  const BatteryLevel(this.percent)
    : assert(percent >= 0 && percent <= 100, 'percent must be 0..100');

  final int percent;

  @override
  List<Object?> get props => [percent];
}
