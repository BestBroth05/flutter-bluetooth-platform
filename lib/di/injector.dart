import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../ble/application/ble_session_coordinator.dart';
import '../ble/domain/framing/packet_framer.dart';
import '../ble/domain/policies/reconnection_policy.dart';
import '../ble/domain/policies/retry_policy.dart';
import '../ble/domain/policies/timeout_policy.dart';
import '../ble/domain/repositories/ble_transport.dart';
import '../ble/domain/repositories/paired_device_store.dart';
import '../ble/infrastructure/fake/fake_ble_transport.dart';
import '../ble/infrastructure/persistence/shared_preferences_paired_device_store.dart';
import '../core/utils/clock.dart';
import '../demo_protocol/demo_packet_framer.dart';

final GetIt getIt = GetIt.instance;

/// Registers portfolio default dependencies (simulator transport).
Future<void> configureDependencies({
  SharedPreferences? sharedPreferences,
  BleTransport? bleTransport,
  PacketFramer? packetFramer,
  Clock clock = const SystemClock(),
}) async {
  if (getIt.isRegistered<Clock>()) {
    await getIt.reset();
  }

  final prefs = sharedPreferences ?? await SharedPreferences.getInstance();

  getIt
    ..registerSingleton<Clock>(clock)
    ..registerSingleton<TimeoutPolicy>(const TimeoutPolicy())
    ..registerSingleton<RetryPolicy>(RetryPolicy(clock: clock))
    ..registerSingleton<ReconnectionPolicy>(
      ReconnectionPolicy(retryPolicy: getIt<RetryPolicy>(), clock: clock),
    )
    ..registerSingleton<PacketFramer>(packetFramer ?? DemoPacketFramer())
    ..registerSingleton<PairedDeviceStore>(
      SharedPreferencesPairedDeviceStore(prefs),
    )
    ..registerSingleton<BleTransport>(
      bleTransport ?? FakeBleTransport(clock: clock),
    )
    ..registerLazySingleton<BleSessionCoordinator>(
      () => BleSessionCoordinator(
        transport: getIt<BleTransport>(),
        pairedDeviceStore: getIt<PairedDeviceStore>(),
        packetFramer: getIt<PacketFramer>(),
        timeoutPolicy: getIt<TimeoutPolicy>(),
        retryPolicy: getIt<RetryPolicy>(),
        reconnectionPolicy: getIt<ReconnectionPolicy>(),
        clock: getIt<Clock>(),
      ),
    );
}
