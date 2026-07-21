import 'dart:async';

import '../../../core/error/ble_failure.dart';
import '../../../core/utils/clock.dart';
import '../../../demo_protocol/demo_packet_codec.dart';
import '../../domain/models/ble_command.dart';
import '../../domain/models/ble_connection_state.dart';
import '../../domain/models/ble_device.dart';
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
  }) : _peripherals =
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

  final Clock clock;
  final Duration scanEmitInterval;
  final Duration telemetryInterval;

  /// When false, tests drive notifications via [emitTelemetryPayload].
  final bool enableAutoTelemetry;
  final List<FakeBlePeripheral> _peripherals;

  final StreamController<BleDevice> _scanController =
      StreamController<BleDevice>.broadcast();
  final StreamController<BleConnectionState> _connectionController =
      StreamController<BleConnectionState>.broadcast();
  final StreamController<List<int>> _notificationController =
      StreamController<List<int>>.broadcast();

  BleConnectionState _connectionState = BleConnectionState.disconnected;
  String? _connectedDeviceId;
  bool _isScanning = false;
  bool _notificationsEnabled = false;
  bool _forceNextConnectionTimeout = false;
  bool _telemetryLoopActive = false;
  int _telemetryCounter = 0;

  List<FakeBlePeripheral> get peripherals =>
      List<FakeBlePeripheral>.unmodifiable(_peripherals);

  @override
  Stream<BleDevice> get scanResults => _scanController.stream;

  @override
  Stream<BleConnectionState> get connectionState =>
      _connectionController.stream;

  @override
  Stream<List<int>> get notifications => _notificationController.stream;

  @override
  BleConnectionState get currentConnectionState => _connectionState;

  @override
  String? get connectedDeviceId => _connectedDeviceId;

  /// Test/demo hook: the next [connect] call times out.
  void failNextConnectionWithTimeout() {
    _forceNextConnectionTimeout = true;
  }

  void setConnectionShouldFail(String deviceId, bool shouldFail) {
    _peripheralById(deviceId).shouldFailConnection = shouldFail;
  }

  @override
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 10),
  }) async {
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
        _scanController.add(peripheral.toBleDevice());
      }

      // Keep the scan "active" briefly so callers can observe scanning state.
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
    if (_connectionState == BleConnectionState.connected &&
        _connectedDeviceId == deviceId) {
      return;
    }

    final peripheral = _peripheralById(deviceId);
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
    _setConnectionState(BleConnectionState.disconnecting);
    await _stopTelemetryLoop();
    await clock.delay(const Duration(milliseconds: 20));
    _connectedDeviceId = null;
    _notificationsEnabled = false;
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
  Future<void> writeCommand(BleCommand command) async {
    if (_connectionState != BleConnectionState.connected) {
      throw const WriteFailure('Cannot write while disconnected.');
    }
    await clock.delay(const Duration(milliseconds: 15));

    if (_notificationsEnabled) {
      final ackPayload = <int>[0x01, ...command.bytes.take(8)];
      final frame = DemoPacketCodec.encode(ackPayload);
      _emitPossiblyFragmented(frame);
    }
  }

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {
    if (_connectionState != BleConnectionState.connected) {
      throw const NotificationFailure(
        'Cannot change notifications while disconnected.',
      );
    }
    _notificationsEnabled = enabled;
    if (enabled && enableAutoTelemetry) {
      unawaited(_runTelemetryLoop());
    } else {
      await _stopTelemetryLoop();
    }
  }

  /// Emits a framed telemetry packet, optionally split across chunks.
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
        0x54, // 'T' telemetry marker for the demo payload
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
    if (!forceFragment || frame.length < 4) {
      _notificationController.add(List<int>.from(frame));
      return;
    }
    final splitAt = frame.length ~/ 2;
    _notificationController.add(frame.sublist(0, splitAt));
    _notificationController.add(frame.sublist(splitAt));
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
    await _scanController.close();
    await _connectionController.close();
    await _notificationController.close();
  }
}
