import 'dart:async';

import '../../../core/error/ble_failure.dart';
import '../../../core/utils/clock.dart';
import '../../../demo_protocol/demo_packet_codec.dart';
import '../../../demo_protocol/demo_protocol_constants.dart';
import '../../domain/models/ble_adapter_state.dart';
import '../../domain/models/ble_command.dart';
import '../../domain/models/ble_connection_state.dart';
import '../../domain/models/ble_device.dart';
import '../../domain/models/ble_notification_event.dart';
import '../../domain/models/ble_scan_filter.dart';
import '../../domain/models/ble_write_type.dart';
import '../../domain/models/characteristic_ref.dart';
import '../../domain/models/gatt_models.dart';
import '../../domain/models/signal_strength.dart';
import '../../domain/repositories/ble_transport.dart';
import 'fake_ble_peripheral.dart';

/// In-memory BLE transport for tests, CI, and portfolio demonstrations.
final class FakeBleTransport implements BleTransport {
  FakeBleTransport({
    List<FakeBlePeripheral>? peripherals,
    this.clock = const SystemClock(),
    this.scanEmitInterval = const Duration(milliseconds: 40),
    this.telemetryInterval = const Duration(milliseconds: 250),
    this.enableAutoTelemetry = true,
    BleAdapterState initialAdapterState = BleAdapterState.on,
  }) : _adapterState = initialAdapterState,
       _peripherals =
           peripherals ??
           <FakeBlePeripheral>[
             FakeBlePeripheral(
               id: 'sim-sensor-alpha',
               name: 'Demo Sensor Alpha',
               signalStrength: const SignalStrength(-55),
             ),
             FakeBlePeripheral(
               id: 'sim-sensor-beta',
               name: 'Demo Sensor Beta',
               signalStrength: const SignalStrength(-72),
             ),
             FakeBlePeripheral(
               id: 'sim-sensor-flaky',
               name: 'Demo Sensor Flaky',
               signalStrength: const SignalStrength(-80),
               shouldFailConnection: true,
             ),
           ];

  static const CharacteristicRef demoTelemetryRef = CharacteristicRef(
    serviceUuid: DemoProtocolConstants.demoServiceUuid,
    characteristicUuid: DemoProtocolConstants.demoTelemetryCharacteristicUuid,
  );

  static const CharacteristicRef demoCommandRef = CharacteristicRef(
    serviceUuid: DemoProtocolConstants.demoServiceUuid,
    characteristicUuid: DemoProtocolConstants.demoCommandCharacteristicUuid,
  );

  final Clock clock;
  final Duration scanEmitInterval;
  final Duration telemetryInterval;
  final bool enableAutoTelemetry;
  final List<FakeBlePeripheral> _peripherals;

  final StreamController<BleDevice> _scanController =
      StreamController<BleDevice>.broadcast();
  final StreamController<BleConnectionState> _connectionController =
      StreamController<BleConnectionState>.broadcast();
  final StreamController<BleAdapterState> _adapterController =
      StreamController<BleAdapterState>.broadcast();
  final StreamController<BleNotificationEvent> _notificationController =
      StreamController<BleNotificationEvent>.broadcast();

  BleConnectionState _connectionState = BleConnectionState.disconnected;
  BleAdapterState _adapterState;
  String? _connectedDeviceId;
  bool _isScanning = false;
  bool _notificationsEnabled = false;
  bool _forceNextConnectionTimeout = false;
  bool _telemetryLoopActive = false;
  bool _intentionalDisconnect = false;
  int _telemetryCounter = 0;
  final Set<CharacteristicRef> _subscriptions = <CharacteristicRef>{};

  List<FakeBlePeripheral> get peripherals =>
      List<FakeBlePeripheral>.unmodifiable(_peripherals);

  @override
  bool get lastDisconnectWasIntentional => _intentionalDisconnect;

  @override
  Stream<BleDevice> get scanResults => _scanController.stream;

  @override
  Stream<BleConnectionState> get connectionState =>
      _connectionController.stream;

  @override
  Stream<BleAdapterState> get adapterState => _adapterController.stream;

  @override
  Stream<BleNotificationEvent> get notifications =>
      _notificationController.stream;

  @override
  BleConnectionState get currentConnectionState => _connectionState;

  @override
  BleAdapterState get currentAdapterState => _adapterState;

  @override
  String? get connectedDeviceId => _connectedDeviceId;

  @override
  bool get isScanning => _isScanning;

  @override
  bool get supportsRealHardware => false;

  void setAdapterState(BleAdapterState state) {
    _adapterState = state;
    if (!_adapterController.isClosed) {
      _adapterController.add(state);
    }
  }

  void failNextConnectionWithTimeout() {
    _forceNextConnectionTimeout = true;
  }

  void setConnectionShouldFail(String deviceId, bool shouldFail) {
    _peripheralById(deviceId).shouldFailConnection = shouldFail;
  }

  /// Simulates an unexpected link drop (may trigger reconnection policies).
  Future<void> simulateUnexpectedDisconnect() async {
    if (_connectionState == BleConnectionState.disconnected) {
      return;
    }
    _intentionalDisconnect = false;
    await _stopTelemetryLoop();
    _connectedDeviceId = null;
    _notificationsEnabled = false;
    _subscriptions.clear();
    _setConnectionState(BleConnectionState.disconnected);
  }

  @override
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 10),
    BleScanFilter filter = const BleScanFilter(),
  }) async {
    if (_adapterState == BleAdapterState.off) {
      throw const AdapterOffFailure();
    }
    if (_adapterState == BleAdapterState.unsupported) {
      throw const BluetoothUnavailableFailure();
    }
    if (_isScanning) {
      return;
    }
    _isScanning = true;

    try {
      for (final peripheral in _peripherals) {
        if (!_isScanning) {
          return;
        }
        await clock.delay(scanEmitInterval);
        if (!_isScanning || _scanController.isClosed) {
          return;
        }
        final device = peripheral.toBleDevice();
        if (_matchesFilter(device, filter)) {
          _scanController.add(device);
        }
      }

      final remaining = timeout - (scanEmitInterval * _peripherals.length);
      if (remaining > Duration.zero && _isScanning) {
        await clock.delay(
          remaining < const Duration(milliseconds: 100)
              ? remaining
              : const Duration(milliseconds: 100),
        );
      }
    } finally {
      await stopScan();
    }
  }

  @override
  Future<void> stopScan() async {
    _isScanning = false;
  }

  @override
  Future<void> connect(
    String deviceId, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    if (_connectionState == BleConnectionState.connecting) {
      throw const ConnectionFailure(
        'A connection attempt is already in progress.',
      );
    }
    if (_connectionState == BleConnectionState.connected &&
        _connectedDeviceId == deviceId) {
      return;
    }

    await stopScan();
    final peripheral = _peripheralById(deviceId);
    _intentionalDisconnect = false;
    _setConnectionState(BleConnectionState.connecting);

    if (_forceNextConnectionTimeout) {
      _forceNextConnectionTimeout = false;
      await clock.delay(timeout);
      _setConnectionState(BleConnectionState.disconnected);
      throw const ConnectionTimeoutFailure();
    }

    final delay = peripheral.connectionDelay;
    if (delay > timeout) {
      await clock.delay(timeout);
      _setConnectionState(BleConnectionState.disconnected);
      throw const ConnectionTimeoutFailure();
    }

    await clock.delay(delay);

    if (peripheral.shouldFailConnection) {
      _setConnectionState(BleConnectionState.disconnected);
      throw const ConnectionFailure(
        'Simulated connection failure for demo sensor.',
      );
    }

    _connectedDeviceId = deviceId;
    _setConnectionState(BleConnectionState.connected);
  }

  @override
  Future<void> disconnect() async {
    if (_connectionState == BleConnectionState.disconnected) {
      return;
    }
    _intentionalDisconnect = true;
    _setConnectionState(BleConnectionState.disconnecting);
    await _stopTelemetryLoop();
    await clock.delay(const Duration(milliseconds: 20));
    _connectedDeviceId = null;
    _notificationsEnabled = false;
    _subscriptions.clear();
    _setConnectionState(BleConnectionState.disconnected);
  }

  @override
  Future<List<GattService>> discoverServices() async {
    final deviceId = _connectedDeviceId;
    if (deviceId == null || _connectionState != BleConnectionState.connected) {
      throw const ServiceDiscoveryFailure(
        'Cannot discover services while disconnected.',
      );
    }
    await clock.delay(const Duration(milliseconds: 20));
    return _peripheralById(deviceId).services;
  }

  @override
  Future<List<int>> readCharacteristic(CharacteristicRef characteristic) async {
    _ensureConnected();
    final match = _findCharacteristic(characteristic);
    if (!match.properties.canRead && characteristic != demoTelemetryRef) {
      // Allow battery-like reads on notify char in simulator for demo values.
      if (!match.properties.canNotify) {
        throw const UnsupportedOperationFailure();
      }
    }
    await clock.delay(const Duration(milliseconds: 10));
    if (characteristic.characteristicUuid.toLowerCase().contains('abcdef2')) {
      return <int>[_telemetryCounter & 0xFF];
    }
    return List<int>.from(match.lastValue);
  }

  @override
  Future<void> writeCharacteristic(
    CharacteristicRef characteristic,
    List<int> bytes, {
    BleWriteType writeType = BleWriteType.withResponse,
  }) async {
    _ensureConnected();
    final match = _findCharacteristic(characteristic);
    final allowed =
        match.properties.canWrite ||
        (writeType == BleWriteType.withoutResponse &&
            match.properties.canWriteWithoutResponse);
    if (!allowed && characteristic != demoCommandRef) {
      throw const UnsupportedOperationFailure();
    }
    await writeCommand(BleCommand(bytes));
  }

  @override
  Future<void> writeCommand(BleCommand command) async {
    _ensureConnected();
    await clock.delay(const Duration(milliseconds: 15));

    if (_notificationsEnabled || _subscriptions.contains(demoTelemetryRef)) {
      final ackPayload = <int>[0x01, ...command.bytes.take(8)];
      final frame = DemoPacketCodec.encode(ackPayload);
      _emitPossiblyFragmented(frame);
    }
  }

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {
    if (enabled) {
      await subscribe(demoTelemetryRef);
    } else {
      await unsubscribe(demoTelemetryRef);
    }
  }

  @override
  Future<void> subscribe(CharacteristicRef characteristic) async {
    _ensureConnected();
    final match = _findCharacteristic(characteristic);
    if (!match.properties.canSubscribe && characteristic != demoTelemetryRef) {
      throw const UnsupportedOperationFailure();
    }
    _subscriptions.add(characteristic);
    if (characteristic == demoTelemetryRef) {
      _notificationsEnabled = true;
      if (enableAutoTelemetry) {
        unawaited(_runTelemetryLoop());
      }
    }
  }

  @override
  Future<void> unsubscribe(CharacteristicRef characteristic) async {
    _subscriptions.remove(characteristic);
    if (characteristic == demoTelemetryRef) {
      _notificationsEnabled = false;
      await _stopTelemetryLoop();
    }
  }

  @override
  Future<int> readRssi() async {
    _ensureConnected();
    final id = _connectedDeviceId!;
    return _peripheralById(id).signalStrength.rssiDbm;
  }

  void emitTelemetryPayload(List<int> payload, {bool fragment = false}) {
    final frame = DemoPacketCodec.encode(payload);
    _emitPossiblyFragmented(frame, forceFragment: fragment);
  }

  Future<void> _runTelemetryLoop() async {
    if (_telemetryLoopActive) {
      return;
    }
    _telemetryLoopActive = true;
    while (_telemetryLoopActive &&
        _notificationsEnabled &&
        _connectionState == BleConnectionState.connected &&
        !_notificationController.isClosed) {
      _telemetryCounter += 1;
      final payload = <int>[
        0x54,
        _telemetryCounter & 0xFF,
        (_connectedDeviceId?.hashCode ?? 0) & 0xFF,
      ];
      final frame = DemoPacketCodec.encode(payload);
      _emitPossiblyFragmented(frame, forceFragment: _telemetryCounter.isOdd);
      await clock.delay(telemetryInterval);
    }
    _telemetryLoopActive = false;
  }

  Future<void> _stopTelemetryLoop() async {
    _telemetryLoopActive = false;
  }

  void _emitPossiblyFragmented(List<int> frame, {bool forceFragment = false}) {
    void emit(List<int> chunk) {
      _notificationController.add(
        BleNotificationEvent(
          characteristic: demoTelemetryRef,
          bytes: List<int>.from(chunk),
          receivedAt: clock.now(),
        ),
      );
    }

    if (!forceFragment || frame.length < 4) {
      emit(frame);
      return;
    }
    final splitAt = frame.length ~/ 2;
    emit(frame.sublist(0, splitAt));
    emit(frame.sublist(splitAt));
  }

  bool _matchesFilter(BleDevice device, BleScanFilter filter) {
    if (filter.minRssiDbm != null &&
        device.signalStrength.rssiDbm < filter.minRssiDbm!) {
      return false;
    }
    final nameFilter = filter.nameContains?.trim();
    if (nameFilter != null && nameFilter.isNotEmpty) {
      if (!device.name.toLowerCase().contains(nameFilter.toLowerCase())) {
        return false;
      }
    }
    // Simulator peripherals advertise the demo service when a service filter is set.
    if (filter.serviceUuids.isNotEmpty) {
      final wanted = filter.serviceUuids.map((u) => u.toLowerCase()).toSet();
      if (!wanted.contains(
        DemoProtocolConstants.demoServiceUuid.toLowerCase(),
      )) {
        return false;
      }
    }
    return true;
  }

  GattCharacteristic _findCharacteristic(CharacteristicRef ref) {
    final services = _peripheralById(_connectedDeviceId!).services;
    for (final service in services) {
      if (service.uuid.toLowerCase() != ref.serviceUuid.toLowerCase()) {
        continue;
      }
      for (final characteristic in service.characteristics) {
        if (characteristic.uuid.toLowerCase() ==
            ref.characteristicUuid.toLowerCase()) {
          return characteristic;
        }
      }
    }
    throw const CharacteristicNotFoundFailure();
  }

  void _ensureConnected() {
    if (_connectionState != BleConnectionState.connected ||
        _connectedDeviceId == null) {
      throw const WriteFailure('Cannot operate while disconnected.');
    }
  }

  FakeBlePeripheral _peripheralById(String deviceId) {
    return _peripherals.firstWhere(
      (peripheral) => peripheral.id == deviceId,
      orElse: () => throw DeviceNotFoundFailure(
        'Simulated device "$deviceId" was not found.',
      ),
    );
  }

  void _setConnectionState(BleConnectionState state) {
    _connectionState = state;
    if (!_connectionController.isClosed) {
      _connectionController.add(state);
    }
  }

  @override
  Future<void> dispose() async {
    await stopScan();
    await _stopTelemetryLoop();
    _subscriptions.clear();
    await _scanController.close();
    await _connectionController.close();
    await _adapterController.close();
    await _notificationController.close();
  }
}
