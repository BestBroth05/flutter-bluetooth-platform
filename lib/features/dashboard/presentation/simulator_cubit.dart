import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../ble/application/ble_session_coordinator.dart';
import '../../../ble/application/ble_transport_factory.dart';
import '../../../ble/domain/models/ble_adapter_state.dart';
import '../../../ble/domain/models/ble_connection_state.dart';
import '../../../ble/domain/models/ble_device.dart';
import '../../../ble/domain/models/ble_notification_event.dart';
import '../../../ble/domain/models/ble_scan_filter.dart';
import '../../../ble/domain/models/ble_transport_mode.dart';
import '../../../ble/domain/models/ble_write_type.dart';
import '../../../ble/domain/models/characteristic_ref.dart';
import '../../../ble/domain/models/gatt_models.dart';
import '../../../ble/domain/models/paired_device.dart';
import '../../../ble/domain/models/telemetry_sample.dart';
import '../../../ble/domain/permissions/ble_permission_gateway.dart';
import '../../../ble/domain/permissions/ble_permission_status.dart';
import '../../../core/codec/byte_codecs.dart';
import '../../../core/error/ble_failure.dart';
import '../../../core/utils/clock.dart';
import '../../../di/injector.dart';

part 'simulator_state.dart';

/// Cubit driving the Phase 2 BLE platform dashboard.
final class SimulatorCubit extends Cubit<SimulatorState> {
  SimulatorCubit(
    this._coordinator,
    this._permissionGateway, {
    BleTransportMode initialMode = BleTransportMode.simulator,
    Clock clock = const SystemClock(),
  }) : _clock = clock,
       super(SimulatorState(transportMode: initialMode)) {
    _deviceSub = _coordinator.discoveredDevices.listen((devices) {
      emit(state.copyWith(devices: devices));
    });
    _connectionSub = _coordinator.connectionState.listen((connectionState) {
      emit(state.copyWith(connectionState: connectionState));
    });
    _adapterSub = _coordinator.adapterState.listen((adapterState) {
      emit(state.copyWith(adapterState: adapterState));
    });
    _telemetrySub = _coordinator.telemetry.listen((sample) {
      final next = <TelemetrySample>[sample, ...state.framedTelemetry];
      emit(
        state.copyWith(framedTelemetry: next.take(20).toList(growable: false)),
      );
    });
    _rawSub = _coordinator.rawNotifications.listen((event) {
      final next = <BleNotificationEvent>[event, ...state.rawNotifications];
      emit(
        state.copyWith(rawNotifications: next.take(40).toList(growable: false)),
      );
    });
    _errorSub = _coordinator.errors.listen((failure) {
      emit(state.copyWith(lastError: failure.message));
    });
  }

  final BleSessionCoordinator _coordinator;
  final BlePermissionGateway _permissionGateway;
  final Clock _clock;

  StreamSubscription<List<BleDevice>>? _deviceSub;
  StreamSubscription<BleConnectionState>? _connectionSub;
  StreamSubscription<BleAdapterState>? _adapterSub;
  StreamSubscription<TelemetrySample>? _telemetrySub;
  StreamSubscription<BleNotificationEvent>? _rawSub;
  StreamSubscription<BleFailure>? _errorSub;

  Future<void> bootstrap() async {
    await _coordinator.initialize();
    _coordinator.demoFramingEnabled = state.demoFramingEnabled;
    final paired = await _coordinator.loadPairedDevices();
    final permission = await _permissionGateway.status();
    emit(
      state.copyWith(
        pairedDevices: paired,
        permissionStatus: permission,
        adapterState: _coordinator.currentAdapterState,
        realBleSupported: BleTransportFactory.isRealBleSupported,
        clearError: true,
      ),
    );
  }

  Future<void> refreshPermissions() async {
    final permission = await _permissionGateway.status();
    emit(state.copyWith(permissionStatus: permission));
  }

  Future<void> requestPermissions() async {
    emit(state.copyWith(busy: true, clearError: true));
    final permission = await _permissionGateway.request();
    emit(state.copyWith(busy: false, permissionStatus: permission));
  }

  Future<void> switchTransportMode(BleTransportMode mode) async {
    if (mode == state.transportMode) {
      return;
    }
    if (mode == BleTransportMode.real &&
        !BleTransportFactory.isRealBleSupported) {
      emit(
        state.copyWith(lastError: const UnsupportedPlatformFailure().message),
      );
      return;
    }

    emit(state.copyWith(busy: true, clearError: true));
    try {
      final next = BleTransportFactory.create(
        mode,
        clock: _clock,
        enableAutoTelemetry: mode == BleTransportMode.simulator,
      );
      await _coordinator.replaceTransport(next);
      if (getIt.isRegistered<BleTransportMode>()) {
        getIt.unregister<BleTransportMode>();
        getIt.registerSingleton<BleTransportMode>(mode);
      }
      emit(
        state.copyWith(
          busy: false,
          transportMode: mode,
          devices: const <BleDevice>[],
          services: const <GattService>[],
          rawNotifications: const <BleNotificationEvent>[],
          framedTelemetry: const <TelemetrySample>[],
          connectionState: BleConnectionState.disconnected,
          adapterState: _coordinator.currentAdapterState,
          clearSelectedDevice: true,
        ),
      );
    } on BleFailure catch (failure) {
      emit(state.copyWith(busy: false, lastError: failure.message));
    } catch (error) {
      emit(state.copyWith(busy: false, lastError: error.toString()));
    }
  }

  Future<void> startScan() async {
    emit(state.copyWith(isScanning: true, clearError: true));
    final filter = BleScanFilter(
      nameContains: state.nameFilter,
      minRssiDbm: state.minRssiFilter,
    );
    final result = await _coordinator.startScan(filter: filter);
    final paired = await _coordinator.loadPairedDevices();
    result.fold(
      onSuccess: (devices) {
        emit(
          state.copyWith(
            isScanning: false,
            devices: devices,
            pairedDevices: paired,
          ),
        );
      },
      onFailure: (failure) {
        emit(
          state.copyWith(
            isScanning: false,
            lastError: failure.message,
            pairedDevices: paired,
          ),
        );
      },
    );
  }

  Future<void> stopScan() async {
    await _coordinator.stopScan();
    emit(state.copyWith(isScanning: false));
  }

  void updateNameFilter(String value) {
    emit(state.copyWith(nameFilter: value));
  }

  void updateMinRssiFilter(String value) {
    final parsed = int.tryParse(value.trim());
    emit(
      state.copyWith(minRssiFilter: parsed, clearMinRssi: value.trim().isEmpty),
    );
  }

  void setDemoFramingEnabled(bool enabled) {
    _coordinator.demoFramingEnabled = enabled;
    emit(state.copyWith(demoFramingEnabled: enabled));
  }

  Future<void> connect(BleDevice device) async {
    emit(state.copyWith(busy: true, clearError: true));
    final result = await _coordinator.connect(device);
    final paired = await _coordinator.loadPairedDevices();
    result.fold(
      onSuccess: (services) {
        emit(
          state.copyWith(
            busy: false,
            services: services,
            pairedDevices: paired,
            selectedDeviceId: device.id,
            selectedDeviceName: device.name,
            lastActivityAt: _clock.now(),
          ),
        );
      },
      onFailure: (failure) {
        emit(
          state.copyWith(
            busy: false,
            lastError: failure.message,
            pairedDevices: paired,
          ),
        );
      },
    );
  }

  Future<void> disconnect() async {
    emit(state.copyWith(busy: true, clearError: true));
    final result = await _coordinator.disconnect();
    result.fold(
      onSuccess: (_) {
        emit(
          state.copyWith(
            busy: false,
            services: const <GattService>[],
            framedTelemetry: const <TelemetrySample>[],
            rawNotifications: const <BleNotificationEvent>[],
            clearSelectedDevice: true,
            clearSelectedCharacteristic: true,
          ),
        );
      },
      onFailure: (failure) {
        emit(state.copyWith(busy: false, lastError: failure.message));
      },
    );
  }

  void selectCharacteristic(
    String serviceUuid,
    GattCharacteristic characteristic,
  ) {
    emit(
      state.copyWith(
        selectedCharacteristic: CharacteristicRef(
          serviceUuid: serviceUuid,
          characteristicUuid: characteristic.uuid,
        ),
        selectedCharacteristicProperties: characteristic.properties,
      ),
    );
  }

  Future<void> readSelectedCharacteristic() async {
    final ref = state.selectedCharacteristic;
    final properties = state.selectedCharacteristicProperties;
    if (ref == null || properties == null) {
      return;
    }
    if (!properties.canRead) {
      emit(
        state.copyWith(
          lastError: const UnsupportedOperationFailure(
            'Selected characteristic does not support read.',
          ).message,
        ),
      );
      return;
    }
    emit(state.copyWith(busy: true, clearError: true));
    final result = await _coordinator.readCharacteristic(ref);
    result.fold(
      onSuccess: (bytes) {
        emit(
          state.copyWith(
            busy: false,
            lastReadHex: ByteCodecs.toHex(bytes),
            lastReadText: ByteCodecs.tryDecodePrintable(bytes),
            lastActivityAt: _clock.now(),
            commandHistory: [
              'READ ${ref.characteristicUuid} -> ${ByteCodecs.toHex(bytes)}',
              ...state.commandHistory,
            ].take(30).toList(growable: false),
          ),
        );
      },
      onFailure: (failure) {
        emit(state.copyWith(busy: false, lastError: failure.message));
      },
    );
  }

  Future<void> writeSelectedCharacteristic({
    required bool asHex,
    BleWriteType writeType = BleWriteType.withResponse,
  }) async {
    final ref = state.selectedCharacteristic;
    final properties = state.selectedCharacteristicProperties;
    if (ref == null || properties == null) {
      return;
    }
    final supportsWrite =
        properties.canWrite ||
        (writeType == BleWriteType.withoutResponse &&
            properties.canWriteWithoutResponse);
    if (!supportsWrite) {
      emit(
        state.copyWith(
          lastError: const UnsupportedOperationFailure(
            'Selected characteristic does not support the requested write.',
          ).message,
        ),
      );
      return;
    }

    emit(state.copyWith(busy: true, clearError: true));
    try {
      final bytes = asHex
          ? ByteCodecs.parseHex(state.commandInput)
          : ByteCodecs.encodeUtf8(state.commandInput);
      final result = await _coordinator.writeCharacteristic(
        ref,
        bytes,
        writeType: writeType,
      );
      result.fold(
        onSuccess: (_) {
          emit(
            state.copyWith(
              busy: false,
              lastActivityAt: _clock.now(),
              commandHistory: [
                'WRITE ${ref.characteristicUuid} ${ByteCodecs.toHex(bytes)}',
                ...state.commandHistory,
              ].take(30).toList(growable: false),
            ),
          );
        },
        onFailure: (failure) {
          emit(state.copyWith(busy: false, lastError: failure.message));
        },
      );
    } on FormatException catch (error) {
      emit(state.copyWith(busy: false, lastError: error.message));
    }
  }

  Future<void> sendDemoCommand() async {
    emit(state.copyWith(busy: true, clearError: true));
    final result = await _coordinator.writeCommand(const <int>[0xC0, 0x01]);
    result.fold(
      onSuccess: (_) => emit(
        state.copyWith(
          busy: false,
          commandHistory: [
            'DEMO WRITE c0 01',
            ...state.commandHistory,
          ].take(30).toList(growable: false),
        ),
      ),
      onFailure: (failure) {
        emit(state.copyWith(busy: false, lastError: failure.message));
      },
    );
  }

  void updateCommandInput(String value) {
    emit(state.copyWith(commandInput: value));
  }

  Future<void> subscribeSelected() async {
    final ref = state.selectedCharacteristic;
    final properties = state.selectedCharacteristicProperties;
    if (ref == null || properties == null) {
      return;
    }
    if (!properties.canSubscribe) {
      emit(
        state.copyWith(
          lastError: const UnsupportedOperationFailure(
            'Selected characteristic does not support notify/indicate.',
          ).message,
        ),
      );
      return;
    }
    emit(state.copyWith(busy: true, clearError: true));
    final result = await _coordinator.subscribe(ref);
    result.fold(
      onSuccess: (_) => emit(state.copyWith(busy: false, subscribed: true)),
      onFailure: (failure) {
        emit(state.copyWith(busy: false, lastError: failure.message));
      },
    );
  }

  Future<void> unsubscribeSelected() async {
    final ref = state.selectedCharacteristic;
    if (ref == null) {
      return;
    }
    emit(state.copyWith(busy: true, clearError: true));
    final result = await _coordinator.unsubscribe(ref);
    result.fold(
      onSuccess: (_) => emit(state.copyWith(busy: false, subscribed: false)),
      onFailure: (failure) {
        emit(state.copyWith(busy: false, lastError: failure.message));
      },
    );
  }

  Future<void> refreshRssi() async {
    final result = await _coordinator.readRssi();
    result.fold(
      onSuccess: (rssi) {
        emit(state.copyWith(currentRssi: rssi, lastActivityAt: _clock.now()));
      },
      onFailure: (failure) {
        emit(state.copyWith(lastError: failure.message));
      },
    );
  }

  Future<void> reconnect(String deviceId) async {
    emit(state.copyWith(busy: true, isReconnecting: true, clearError: true));
    final result = await _coordinator.reconnectToPairedDevice(deviceId);
    final paired = await _coordinator.loadPairedDevices();
    result.fold(
      onSuccess: (_) {
        emit(
          state.copyWith(
            busy: false,
            isReconnecting: false,
            pairedDevices: paired,
            selectedDeviceId: deviceId,
            services: _coordinator.discoveredServices,
            lastActivityAt: _clock.now(),
          ),
        );
      },
      onFailure: (failure) {
        emit(
          state.copyWith(
            busy: false,
            isReconnecting: false,
            lastError: failure.message,
            pairedDevices: paired,
          ),
        );
      },
    );
  }

  void cancelReconnect() {
    _coordinator.cancelReconnect();
    emit(state.copyWith(isReconnecting: false, busy: false));
  }

  Future<void> clearPairedDevices() async {
    await _coordinator.clearPairedDevices();
    emit(state.copyWith(pairedDevices: const <PairedDevice>[]));
  }

  @override
  Future<void> close() async {
    await _deviceSub?.cancel();
    await _connectionSub?.cancel();
    await _adapterSub?.cancel();
    await _telemetrySub?.cancel();
    await _rawSub?.cancel();
    await _errorSub?.cancel();
    return super.close();
  }
}
