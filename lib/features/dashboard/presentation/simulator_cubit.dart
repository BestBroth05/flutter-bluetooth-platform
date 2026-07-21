import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../ble/application/ble_session_coordinator.dart';
import '../../../ble/domain/models/ble_connection_state.dart';
import '../../../ble/domain/models/ble_device.dart';
import '../../../ble/domain/models/gatt_models.dart';
import '../../../ble/domain/models/paired_device.dart';
import '../../../ble/domain/models/telemetry_sample.dart';
import '../../../core/error/ble_failure.dart';

part 'simulator_state.dart';

/// Minimal Cubit that drives the simulator dashboard shell.
final class SimulatorCubit extends Cubit<SimulatorState> {
  SimulatorCubit(this._coordinator) : super(const SimulatorState()) {
    _deviceSub = _coordinator.discoveredDevices.listen((devices) {
      emit(state.copyWith(devices: devices));
    });
    _connectionSub = _coordinator.connectionState.listen((connectionState) {
      emit(state.copyWith(connectionState: connectionState));
    });
    _telemetrySub = _coordinator.telemetry.listen((sample) {
      final next = <TelemetrySample>[sample, ...state.telemetry];
      emit(state.copyWith(telemetry: next.take(20).toList(growable: false)));
    });
    _errorSub = _coordinator.errors.listen((failure) {
      emit(state.copyWith(lastError: failure.message));
    });
  }

  final BleSessionCoordinator _coordinator;

  StreamSubscription<List<BleDevice>>? _deviceSub;
  StreamSubscription<BleConnectionState>? _connectionSub;
  StreamSubscription<TelemetrySample>? _telemetrySub;
  StreamSubscription<BleFailure>? _errorSub;

  Future<void> bootstrap() async {
    await _coordinator.initialize();
    final paired = await _coordinator.loadPairedDevices();
    emit(state.copyWith(pairedDevices: paired, clearError: true));
  }

  Future<void> startScan() async {
    emit(state.copyWith(isScanning: true, clearError: true));
    final result = await _coordinator.startScan();
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
            telemetry: const <TelemetrySample>[],
            clearSelectedDevice: true,
          ),
        );
      },
      onFailure: (failure) {
        emit(state.copyWith(busy: false, lastError: failure.message));
      },
    );
  }

  Future<void> sendDemoCommand() async {
    emit(state.copyWith(busy: true, clearError: true));
    final result = await _coordinator.writeCommand(const <int>[0xC0, 0x01]);
    result.fold(
      onSuccess: (_) => emit(state.copyWith(busy: false)),
      onFailure: (failure) {
        emit(state.copyWith(busy: false, lastError: failure.message));
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
    await _telemetrySub?.cancel();
    await _errorSub?.cancel();
    return super.close();
  }
}
