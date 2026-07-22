import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/error/ble_failure.dart';
import '../../core/utils/clock.dart';
import '../domain/models/ble_transport_mode.dart';
import '../domain/repositories/ble_transport.dart';
import '../infrastructure/fake/fake_ble_transport.dart';
import '../infrastructure/real/flutter_blue_plus_ble_transport.dart';

/// Creates [BleTransport] implementations without exposing plugin types to UI.
abstract final class BleTransportFactory {
  static bool get isRealBleSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static BleTransport create(
    BleTransportMode mode, {
    Clock clock = const SystemClock(),
    bool enableAutoTelemetry = true,
  }) {
    switch (mode) {
      case BleTransportMode.simulator:
        return FakeBleTransport(
          clock: clock,
          enableAutoTelemetry: enableAutoTelemetry,
        );
      case BleTransportMode.real:
        if (!isRealBleSupported) {
          throw const UnsupportedPlatformFailure();
        }
        return FlutterBluePlusBleTransport(clock: clock);
    }
  }
}
