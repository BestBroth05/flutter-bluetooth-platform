import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../../core/error/ble_failure.dart';
import '../../../core/utils/clock.dart';
import '../../domain/models/ble_adapter_state.dart';
import '../../domain/models/ble_command.dart';
import '../../domain/models/ble_connection_state.dart';
import '../../domain/models/ble_device.dart';
import '../../domain/models/ble_notification_event.dart';
import '../../domain/models/ble_scan_filter.dart';
import '../../domain/models/ble_write_type.dart';
import '../../domain/models/characteristic_ref.dart';
import '../../domain/models/gatt_models.dart';
import '../../domain/repositories/ble_transport.dart';
import 'ble_adapter_monitor.dart';
import 'ble_gatt_mapper.dart';
import 'ble_platform_error_mapper.dart';
import 'ble_scan_filters.dart';
import 'ble_subscription_registry.dart';

/// Real BLE central-mode transport backed by flutter_blue_plus.
final class FlutterBluePlusBleTransport implements BleTransport {
  FlutterBluePlusBleTransport({this.clock = const SystemClock()}) {
    if (supportsRealHardware) {
      _adapterSubscription = BleAdapterMonitor.watch().listen((state) {
        _adapterState = state;
        if (!_adapterController.isClosed) {
          _adapterController.add(state);
        }
      });
    } else {
      _adapterState = BleAdapterState.unsupported;
    }
  }

  final Clock clock;

  final StreamController<BleDevice> _scanController =
      StreamController<BleDevice>.broadcast();
  final StreamController<BleConnectionState> _connectionController =
      StreamController<BleConnectionState>.broadcast();
  final StreamController<BleAdapterState> _adapterController =
      StreamController<BleAdapterState>.broadcast();
  final StreamController<BleNotificationEvent> _notificationController =
      StreamController<BleNotificationEvent>.broadcast();

  final BleSubscriptionRegistry _subscriptions = BleSubscriptionRegistry();
  final Map<String, BleDevice> _discovered = <String, BleDevice>{};

  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _deviceConnectionSubscription;
  StreamSubscription<BleAdapterState>? _adapterSubscription;
  BluetoothDevice? _device;
  Timer? _scanTimeoutTimer;

  BleConnectionState _connectionState = BleConnectionState.disconnected;
  BleAdapterState _adapterState = BleAdapterState.unknown;
  bool _isScanning = false;
  bool _connectInFlight = false;
  bool _intentionalDisconnect = false;

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
  String? get connectedDeviceId => _device?.remoteId.str;

  @override
  bool get isScanning => _isScanning;

  @override
  bool get supportsRealHardware =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  @override
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 10),
    BleScanFilter filter = const BleScanFilter(),
  }) async {
    _ensureSupported();
    await _ensureAdapterReady();

    if (_isScanning) {
      return;
    }

    _discovered.clear();
    _isScanning = true;

    try {
      await _scanSubscription?.cancel();
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (final result in results) {
          final device = BleGattMapper.fromScanResult(result);
          if (!BleScanFilters.matches(device, filter)) {
            continue;
          }
          // Optional advertised-service filter applied against advertisement data.
          if (filter.serviceUuids.isNotEmpty) {
            final advertised = result.advertisementData.serviceUuids
                .map((guid) => guid.toString().toLowerCase())
                .toSet();
            final wanted = filter.serviceUuids
                .map((uuid) => uuid.toLowerCase())
                .toSet();
            if (advertised.intersection(wanted).isEmpty) {
              continue;
            }
          }
          final next = BleScanFilters.upsert(_discovered, device);
          _discovered
            ..clear()
            ..addAll(next);
          if (!_scanController.isClosed) {
            _scanController.add(device);
          }
        }
      });

      final withServices = filter.serviceUuids
          .map(Guid.new)
          .toList(growable: false);

      await FlutterBluePlus.startScan(
        timeout: timeout,
        withServices: withServices,
        continuousUpdates: true,
      );

      _scanTimeoutTimer?.cancel();
      _scanTimeoutTimer = Timer(timeout, () {
        unawaited(stopScan());
      });
    } catch (error) {
      _isScanning = false;
      throw BlePlatformErrorMapper.map(error, fallbackMessage: 'Scan failed.');
    }
  }

  @override
  Future<void> stopScan() async {
    _scanTimeoutTimer?.cancel();
    _scanTimeoutTimer = null;
    _isScanning = false;
    await _scanSubscription?.cancel();
    _scanSubscription = null;
    if (supportsRealHardware) {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {
        // Ignore stop errors during teardown.
      }
    }
  }

  @override
  Future<void> connect(
    String deviceId, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    _ensureSupported();
    await _ensureAdapterReady();

    if (_connectInFlight) {
      throw const ConnectionFailure(
        'A connection attempt is already in progress.',
      );
    }
    if (_connectionState == BleConnectionState.connected &&
        connectedDeviceId == deviceId) {
      return;
    }

    _connectInFlight = true;
    _intentionalDisconnect = false;

    try {
      await stopScan();
      await _detachDevice(preserveIntentionalFlag: true);

      final device = BluetoothDevice.fromId(deviceId);
      _device = device;
      _setConnectionState(BleConnectionState.connecting);

      _deviceConnectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          if (_connectionState == BleConnectionState.disconnecting ||
              _intentionalDisconnect) {
            _setConnectionState(BleConnectionState.disconnected);
          } else if (_connectionState == BleConnectionState.connected) {
            unawaited(_handleUnexpectedDisconnect());
          }
        } else if (state == BluetoothConnectionState.connected) {
          if (_connectionState == BleConnectionState.connecting) {
            _setConnectionState(BleConnectionState.connected);
          }
        }
      });

      await device.connect(
        timeout: timeout,
        // Personal/educational portfolio use under FlutterBluePlus License §2.
        license: License.nonprofit,
        autoConnect: false,
      );
      _setConnectionState(BleConnectionState.connected);
    } on TimeoutException {
      await _detachDevice(preserveIntentionalFlag: true);
      _setConnectionState(BleConnectionState.disconnected);
      throw const ConnectionTimeoutFailure();
    } catch (error) {
      await _detachDevice(preserveIntentionalFlag: true);
      _setConnectionState(BleConnectionState.disconnected);
      final mapped = BlePlatformErrorMapper.map(error);
      if (mapped is ConnectionTimeoutFailure) {
        throw mapped;
      }
      throw mapped;
    } finally {
      _connectInFlight = false;
    }
  }

  @override
  Future<void> disconnect() async {
    _intentionalDisconnect = true;
    if (_device == null &&
        _connectionState == BleConnectionState.disconnected) {
      return;
    }
    _setConnectionState(BleConnectionState.disconnecting);
    try {
      await _subscriptions.clear();
      await _device?.disconnect();
    } catch (error) {
      throw BlePlatformErrorMapper.map(error);
    } finally {
      await _detachDevice(preserveIntentionalFlag: true);
      _setConnectionState(BleConnectionState.disconnected);
    }
  }

  @override
  Future<List<GattService>> discoverServices() async {
    final device = _requireDevice();
    try {
      final services = await device.discoverServices();
      return BleGattMapper.mapServices(services);
    } catch (error) {
      throw BlePlatformErrorMapper.map(
        error,
        fallbackMessage: 'GATT service discovery failed.',
      );
    }
  }

  @override
  Future<List<int>> readCharacteristic(CharacteristicRef characteristic) async {
    try {
      final target = await _findCharacteristic(characteristic);
      if (!target.properties.read) {
        throw const UnsupportedOperationFailure(
          'Characteristic does not support read.',
        );
      }
      final value = await target.read();
      return List<int>.from(value);
    } on BleFailure {
      rethrow;
    } catch (error) {
      throw BlePlatformErrorMapper.map(error, fallbackMessage: 'Read failed.');
    }
  }

  @override
  Future<void> writeCharacteristic(
    CharacteristicRef characteristic,
    List<int> bytes, {
    BleWriteType writeType = BleWriteType.withResponse,
  }) async {
    try {
      final target = await _findCharacteristic(characteristic);
      final withoutResponse = writeType == BleWriteType.withoutResponse;
      if (withoutResponse && !target.properties.writeWithoutResponse) {
        throw const UnsupportedOperationFailure(
          'Characteristic does not support write without response.',
        );
      }
      if (!withoutResponse &&
          !target.properties.write &&
          !target.properties.writeWithoutResponse) {
        throw const UnsupportedOperationFailure(
          'Characteristic does not support write.',
        );
      }
      await target.write(bytes, withoutResponse: withoutResponse);
    } on BleFailure {
      rethrow;
    } catch (error) {
      throw BlePlatformErrorMapper.map(error, fallbackMessage: 'Write failed.');
    }
  }

  @override
  Future<void> writeCommand(BleCommand command) async {
    throw const UnsupportedOperationFailure(
      'writeCommand is simulator-only. Use writeCharacteristic in real mode.',
    );
  }

  @override
  Future<void> setNotificationsEnabled(bool enabled) async {
    throw const UnsupportedOperationFailure(
      'setNotificationsEnabled is simulator-only. Use subscribe/unsubscribe.',
    );
  }

  @override
  Future<void> subscribe(CharacteristicRef characteristic) async {
    try {
      final target = await _findCharacteristic(characteristic);
      final canSubscribe =
          target.properties.notify || target.properties.indicate;
      if (!canSubscribe) {
        throw const UnsupportedOperationFailure(
          'Characteristic does not support notify or indicate.',
        );
      }
      final device = _requireDevice();
      await _subscriptions.bind(device, target, characteristic, (value) {
        if (_notificationController.isClosed) {
          return;
        }
        _notificationController.add(
          BleNotificationEvent(
            characteristic: characteristic,
            bytes: List<int>.from(value),
            receivedAt: clock.now(),
          ),
        );
      });
    } on BleFailure {
      rethrow;
    } catch (error) {
      throw BlePlatformErrorMapper.map(
        error,
        fallbackMessage: 'Failed to subscribe to notifications.',
      );
    }
  }

  @override
  Future<void> unsubscribe(CharacteristicRef characteristic) async {
    try {
      if (_subscriptions.contains(characteristic)) {
        final target = await _findCharacteristic(characteristic);
        await target.setNotifyValue(false);
      }
      await _subscriptions.remove(characteristic);
    } catch (error) {
      throw BlePlatformErrorMapper.map(
        error,
        fallbackMessage: 'Failed to unsubscribe from notifications.',
      );
    }
  }

  @override
  Future<int> readRssi() async {
    final device = _requireDevice();
    try {
      return await device.readRssi();
    } catch (error) {
      throw BlePlatformErrorMapper.map(error);
    }
  }

  Future<void> _handleUnexpectedDisconnect() async {
    await _subscriptions.clear();
    _device = null;
    await _deviceConnectionSubscription?.cancel();
    _deviceConnectionSubscription = null;
    _setConnectionState(BleConnectionState.disconnected);
  }

  Future<void> _detachDevice({required bool preserveIntentionalFlag}) async {
    await _subscriptions.clear();
    await _deviceConnectionSubscription?.cancel();
    _deviceConnectionSubscription = null;
    _device = null;
    if (!preserveIntentionalFlag) {
      _intentionalDisconnect = false;
    }
  }

  Future<BluetoothCharacteristic> _findCharacteristic(
    CharacteristicRef ref,
  ) async {
    final device = _requireDevice();
    final services = await device.discoverServices();
    for (final service in services) {
      if (BleGattMapper.normalizeUuid(service.uuid) !=
          ref.serviceUuid.toLowerCase()) {
        continue;
      }
      for (final characteristic in service.characteristics) {
        if (BleGattMapper.normalizeUuid(characteristic.uuid) ==
            ref.characteristicUuid.toLowerCase()) {
          return characteristic;
        }
      }
    }
    throw const CharacteristicNotFoundFailure();
  }

  BluetoothDevice _requireDevice() {
    final device = _device;
    if (device == null || _connectionState != BleConnectionState.connected) {
      throw const ConnectionFailure('No connected Bluetooth device.');
    }
    return device;
  }

  void _ensureSupported() {
    if (!supportsRealHardware) {
      throw const UnsupportedPlatformFailure();
    }
  }

  Future<void> _ensureAdapterReady() async {
    final state = await BleAdapterMonitor.current();
    _adapterState = state;
    if (!_adapterController.isClosed) {
      _adapterController.add(state);
    }
    if (state == BleAdapterState.unsupported) {
      throw const BluetoothUnavailableFailure();
    }
    if (state == BleAdapterState.unauthorized) {
      throw const PermissionDeniedFailure();
    }
    if (state == BleAdapterState.off || state == BleAdapterState.turningOff) {
      throw const AdapterOffFailure();
    }
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
    await _subscriptions.clear();
    await _adapterSubscription?.cancel();
    await _deviceConnectionSubscription?.cancel();
    await _scanSubscription?.cancel();
    await _scanController.close();
    await _connectionController.close();
    await _adapterController.close();
    await _notificationController.close();
  }
}
