import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../domain/models/ble_adapter_state.dart';

/// Maps FlutterBluePlus adapter states into domain [BleAdapterState] values.
abstract final class BleAdapterMonitor {
  static BleAdapterState map(BluetoothAdapterState state) {
    return switch (state) {
      BluetoothAdapterState.unknown => BleAdapterState.unknown,
      BluetoothAdapterState.unavailable => BleAdapterState.unsupported,
      BluetoothAdapterState.unauthorized => BleAdapterState.unauthorized,
      BluetoothAdapterState.turningOn => BleAdapterState.turningOn,
      BluetoothAdapterState.on => BleAdapterState.on,
      BluetoothAdapterState.turningOff => BleAdapterState.turningOff,
      BluetoothAdapterState.off => BleAdapterState.off,
    };
  }

  static Stream<BleAdapterState> watch() {
    return FlutterBluePlus.adapterState.map(map);
  }

  static Future<BleAdapterState> current() async {
    return map(await FlutterBluePlus.adapterState.first);
  }
}
