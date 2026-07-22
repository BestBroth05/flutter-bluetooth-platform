import 'dart:async';

import '../../core/error/ble_failure.dart';
import '../../core/error/result.dart';
import '../../core/utils/cancellation_token.dart';
import '../../core/utils/clock.dart';
import '../domain/framing/framed_packet.dart';
import '../domain/framing/packet_framer.dart';
import '../domain/models/ble_adapter_state.dart';
import '../domain/models/ble_command.dart';
import '../domain/models/ble_connection_state.dart';
import '../domain/models/ble_device.dart';
import '../domain/models/ble_notification_event.dart';
import '../domain/models/ble_scan_filter.dart';
import '../domain/models/ble_write_type.dart';
import '../domain/models/characteristic_ref.dart';
import '../domain/models/gatt_models.dart';
import '../domain/models/paired_device.dart';
import '../domain/models/telemetry_sample.dart';
import '../domain/policies/reconnection_policy.dart';
import '../domain/policies/retry_policy.dart';
import '../domain/policies/timeout_policy.dart';
import '../domain/repositories/ble_transport.dart';
import '../domain/repositories/paired_device_store.dart';

/// Application-layer coordinator for scan, session, framing, and persistence.
final class BleSessionCoordinator {
  BleSessionCoordinator({
    required BleTransport transport,
    required PairedDeviceStore pairedDeviceStore,
    required PacketFramer packetFramer,
    required TimeoutPolicy timeoutPolicy,
    required RetryPolicy retryPolicy,
    required ReconnectionPolicy reconnectionPolicy,
    required Clock clock,
  }) : _transport = transport,
       _pairedDeviceStore = pairedDeviceStore,
       _packetFramer = packetFramer,
       _timeoutPolicy = timeoutPolicy,
       _retryPolicy = retryPolicy,
       _reconnectionPolicy = reconnectionPolicy,
       _clock = clock;

  BleTransport _transport;
  final PairedDeviceStore _pairedDeviceStore;
  final PacketFramer _packetFramer;
  final TimeoutPolicy _timeoutPolicy;
  final RetryPolicy _retryPolicy;
  final ReconnectionPolicy _reconnectionPolicy;
  final Clock _clock;

  final StreamController<List<BleDevice>> _devicesController =
      StreamController<List<BleDevice>>.broadcast();
  final StreamController<TelemetrySample> _telemetryController =
      StreamController<TelemetrySample>.broadcast();
  final StreamController<BleNotificationEvent> _rawNotificationsController =
      StreamController<BleNotificationEvent>.broadcast();
  final StreamController<BleFailure> _errorsController =
      StreamController<BleFailure>.broadcast();

  final Map<String, BleDevice> _discovered = <String, BleDevice>{};
  StreamSubscription<BleDevice>? _scanSubscription;
  StreamSubscription<BleNotificationEvent>? _notificationSubscription;
  StreamSubscription<BleConnectionState>? _connectionSubscription;
  CancellationToken? _reconnectToken;

  List<GattService> _services = const <GattService>[];
  bool _isScanning = false;
  bool _demoFramingEnabled = false;
  bool _autoReconnectEnabled = true;
  bool _userRequestedDisconnect = false;

  BleTransport get transport => _transport;

  Stream<List<BleDevice>> get discoveredDevices => _devicesController.stream;

  Stream<BleConnectionState> get connectionState => _transport.connectionState;

  Stream<BleAdapterState> get adapterState => _transport.adapterState;

  Stream<TelemetrySample> get telemetry => _telemetryController.stream;

  Stream<BleNotificationEvent> get rawNotifications =>
      _rawNotificationsController.stream;

  Stream<BleFailure> get errors => _errorsController.stream;

  BleConnectionState get currentConnectionState =>
      _transport.currentConnectionState;

  BleAdapterState get currentAdapterState => _transport.currentAdapterState;

  String? get connectedDeviceId => _transport.connectedDeviceId;

  List<GattService> get discoveredServices => _services;

  bool get isScanning => _isScanning || _transport.isScanning;

  bool get demoFramingEnabled => _demoFramingEnabled;

  bool get supportsRealHardware => _transport.supportsRealHardware;

  set demoFramingEnabled(bool value) {
    _demoFramingEnabled = value;
    if (!value) {
      _packetFramer.reset();
    }
  }

  set autoReconnectEnabled(bool value) {
    _autoReconnectEnabled = value;
  }

  Future<void> initialize() async {
    await _connectionSubscription?.cancel();
    _connectionSubscription = _transport.connectionState.listen((state) {
      if (state == BleConnectionState.disconnected) {
        _services = const <GattService>[];
        _packetFramer.reset();
        final intentional =
            _userRequestedDisconnect || _transport.lastDisconnectWasIntentional;
        final deviceId = _lastConnectedId;
        final shouldReconnect =
            !intentional &&
            _autoReconnectEnabled &&
            _sessionWasReady &&
            deviceId != null &&
            (_reconnectToken == null || _reconnectToken!.isCancelled);
        _sessionWasReady = false;
        _userRequestedDisconnect = false;
        if (shouldReconnect) {
          unawaited(reconnectToPairedDevice(deviceId));
        }
      }
    });
  }

  String? _lastConnectedId;
  bool _sessionWasReady = false;

  /// Replaces the active transport after disposing the previous one.
  Future<void> replaceTransport(BleTransport next) async {
    _reconnectToken?.cancel();
    await stopScan();
    if (_transport.currentConnectionState != BleConnectionState.disconnected) {
      _userRequestedDisconnect = true;
      await _transport.disconnect().catchError((_) {});
    }
    await _scanSubscription?.cancel();
    await _notificationSubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _transport.dispose();
    _transport = next;
    _services = const <GattService>[];
    _discovered.clear();
    _devicesController.add(const <BleDevice>[]);
    _packetFramer.reset();
    await initialize();
  }

  Future<Result<List<BleDevice>>> startScan({
    BleScanFilter filter = const BleScanFilter(),
  }) async {
    try {
      _discovered.clear();
      _devicesController.add(const <BleDevice>[]);
      _isScanning = true;

      await _scanSubscription?.cancel();
      _scanSubscription = _transport.scanResults.listen((device) {
        _discovered[device.id] = device;
        _devicesController.add(_discovered.values.toList(growable: false));
      });

      await _transport.startScan(
        timeout: _timeoutPolicy.scanTimeout,
        filter: filter,
      );
      _isScanning = false;
      return Success(_discovered.values.toList(growable: false));
    } on BleFailure catch (failure) {
      _isScanning = false;
      _errorsController.add(failure);
      return Failure(failure);
    } catch (error) {
      _isScanning = false;
      final failure = UnexpectedBleFailure(error.toString());
      _errorsController.add(failure);
      return Failure(failure);
    }
  }

  Future<void> stopScan() async {
    _isScanning = false;
    await _transport.stopScan();
  }

  Future<Result<List<GattService>>> connect(
    BleDevice device, {
    bool persistPairing = true,
  }) async {
    try {
      await stopScan();
      _userRequestedDisconnect = false;
      await _retryPolicy.execute(() async {
        await _transport.connect(
          device.id,
          timeout: _timeoutPolicy.connectionTimeout,
        );
      });

      _lastConnectedId = device.id;
      _sessionWasReady = true;
      _services = await _transport.discoverServices();
      await _attachNotificationPipeline();

      await _enableSimulatorTelemetryIfSupported();

      if (persistPairing) {
        await _pairedDeviceStore.save(
          PairedDevice(
            id: device.id,
            name: device.name,
            lastConnectedAt: _clock.now(),
          ),
        );
      }

      return Success(_services);
    } on BleFailure catch (failure) {
      _errorsController.add(failure);
      return Failure(failure);
    } catch (error) {
      final failure = UnexpectedBleFailure(error.toString());
      _errorsController.add(failure);
      return Failure(failure);
    }
  }

  Future<Result<void>> disconnect() async {
    try {
      _reconnectToken?.cancel();
      _userRequestedDisconnect = true;
      _autoReconnectEnabled = false;
      await _disableSimulatorTelemetryIfSupported();
      await _notificationSubscription?.cancel();
      _notificationSubscription = null;
      await _transport.disconnect();
      _packetFramer.reset();
      _autoReconnectEnabled = true;
      return const Success(null);
    } on BleFailure catch (failure) {
      _autoReconnectEnabled = true;
      _errorsController.add(failure);
      return Failure(failure);
    } catch (error) {
      _autoReconnectEnabled = true;
      final failure = UnexpectedBleFailure(error.toString());
      _errorsController.add(failure);
      return Failure(failure);
    }
  }

  Future<Result<void>> writeCommand(List<int> bytes) async {
    try {
      await _transport.writeCommand(BleCommand(bytes));
      return const Success(null);
    } on BleFailure catch (failure) {
      _errorsController.add(failure);
      return Failure(failure);
    } catch (error) {
      final failure = WriteFailure(error.toString());
      _errorsController.add(failure);
      return Failure(failure);
    }
  }

  Future<Result<List<int>>> readCharacteristic(CharacteristicRef ref) async {
    try {
      final value = await _transport.readCharacteristic(ref);
      return Success(value);
    } on BleFailure catch (failure) {
      _errorsController.add(failure);
      return Failure(failure);
    } catch (error) {
      final failure = ReadFailure(error.toString());
      _errorsController.add(failure);
      return Failure(failure);
    }
  }

  Future<Result<void>> writeCharacteristic(
    CharacteristicRef ref,
    List<int> bytes, {
    BleWriteType writeType = BleWriteType.withResponse,
  }) async {
    try {
      await _transport.writeCharacteristic(ref, bytes, writeType: writeType);
      return const Success(null);
    } on BleFailure catch (failure) {
      _errorsController.add(failure);
      return Failure(failure);
    } catch (error) {
      final failure = WriteFailure(error.toString());
      _errorsController.add(failure);
      return Failure(failure);
    }
  }

  Future<Result<void>> subscribe(CharacteristicRef ref) async {
    try {
      await _attachNotificationPipeline();
      await _transport.subscribe(ref);
      return const Success(null);
    } on BleFailure catch (failure) {
      _errorsController.add(failure);
      return Failure(failure);
    } catch (error) {
      final failure = NotificationFailure(error.toString());
      _errorsController.add(failure);
      return Failure(failure);
    }
  }

  Future<Result<void>> unsubscribe(CharacteristicRef ref) async {
    try {
      await _transport.unsubscribe(ref);
      return const Success(null);
    } on BleFailure catch (failure) {
      _errorsController.add(failure);
      return Failure(failure);
    } catch (error) {
      final failure = NotificationFailure(error.toString());
      _errorsController.add(failure);
      return Failure(failure);
    }
  }

  Future<Result<int>> readRssi() async {
    try {
      return Success(await _transport.readRssi());
    } on BleFailure catch (failure) {
      _errorsController.add(failure);
      return Failure(failure);
    } catch (error) {
      final failure = UnexpectedBleFailure(error.toString());
      _errorsController.add(failure);
      return Failure(failure);
    }
  }

  Future<Result<void>> reconnectToPairedDevice(String deviceId) async {
    _reconnectToken?.cancel();
    final token = CancellationToken();
    _reconnectToken = token;
    _userRequestedDisconnect = false;

    try {
      await _reconnectionPolicy.reconnect(
        cancellationToken: token,
        connect: () async {
          await _transport.connect(
            deviceId,
            timeout: _timeoutPolicy.connectionTimeout,
          );
        },
      );

      if (token.isCancelled) {
        return const Failure(CancelledFailure());
      }

      final paired = await _pairedDeviceStore.loadAll();
      final match = paired.where((item) => item.id == deviceId).firstOrNull;
      final deviceName = match?.name ?? 'Paired Sensor';

      _lastConnectedId = deviceId;
      _sessionWasReady = true;
      _services = await _transport.discoverServices();
      await _attachNotificationPipeline();
      await _enableSimulatorTelemetryIfSupported();
      await _pairedDeviceStore.save(
        PairedDevice(
          id: deviceId,
          name: deviceName,
          lastConnectedAt: _clock.now(),
        ),
      );

      return const Success(null);
    } on CancelledException {
      return const Failure(CancelledFailure());
    } on BleFailure catch (failure) {
      _errorsController.add(failure);
      return Failure(failure);
    } catch (error) {
      final failure = UnexpectedBleFailure(error.toString());
      _errorsController.add(failure);
      return Failure(failure);
    }
  }

  void cancelReconnect() {
    _reconnectToken?.cancel();
    _userRequestedDisconnect = true;
  }

  Future<List<PairedDevice>> loadPairedDevices() {
    return _pairedDeviceStore.loadAll();
  }

  Future<void> clearPairedDevices() {
    return _pairedDeviceStore.clear();
  }

  Future<void> _enableSimulatorTelemetryIfSupported() async {
    try {
      await _transport.setNotificationsEnabled(true);
    } on UnsupportedOperationFailure {
      // Real transports require explicit characteristic subscribe.
    } catch (_) {}
  }

  Future<void> _disableSimulatorTelemetryIfSupported() async {
    try {
      await _transport.setNotificationsEnabled(false);
    } catch (_) {}
  }

  Future<void> _attachNotificationPipeline() async {
    await _notificationSubscription?.cancel();
    _packetFramer.reset();
    _notificationSubscription = _transport.notifications.listen((event) {
      if (!_rawNotificationsController.isClosed) {
        _rawNotificationsController.add(event);
      }
      if (!_demoFramingEnabled) {
        return;
      }
      try {
        final frames = _packetFramer.push(event.bytes);
        for (final FramedPacket frame in frames) {
          _telemetryController.add(
            TelemetrySample(payload: frame.payload, receivedAt: _clock.now()),
          );
        }
      } catch (_) {
        // Malformed framed data must not break the raw notification stream.
        _packetFramer.reset();
      }
    });
  }

  Future<void> dispose() async {
    _reconnectToken?.cancel();
    await _scanSubscription?.cancel();
    await _notificationSubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _devicesController.close();
    await _telemetryController.close();
    await _rawNotificationsController.close();
    await _errorsController.close();
    await _transport.dispose();
  }
}
