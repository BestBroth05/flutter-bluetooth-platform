import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../domain/models/ble_device.dart';
import '../../domain/models/gatt_models.dart';
import '../../domain/models/signal_strength.dart';

/// Maps plugin GATT / scan models into domain models.
abstract final class BleGattMapper {
  static String normalizeUuid(Guid guid) => guid.toString().toLowerCase();

  static String displayName(
    BluetoothDevice device, {
    String? advertisementName,
  }) {
    final adv = advertisementName?.trim();
    if (adv != null && adv.isNotEmpty) {
      return adv;
    }
    final platformName = device.platformName.trim();
    if (platformName.isNotEmpty) {
      return platformName;
    }
    final advName = device.advName.trim();
    if (advName.isNotEmpty) {
      return advName;
    }
    return 'Unnamed device';
  }

  static BleDevice fromScanResult(ScanResult result) {
    return BleDevice(
      id: result.device.remoteId.str,
      name: displayName(
        result.device,
        advertisementName: result.advertisementData.advName,
      ),
      signalStrength: SignalStrength(result.rssi),
      isConnectable: result.advertisementData.connectable,
    );
  }

  static GattCharacteristicProperties mapProperties(
    CharacteristicProperties properties,
  ) {
    return GattCharacteristicProperties(
      canRead: properties.read,
      canWrite: properties.write,
      canWriteWithoutResponse: properties.writeWithoutResponse,
      canNotify: properties.notify,
      canIndicate: properties.indicate,
    );
  }

  static GattCharacteristic mapCharacteristic(
    BluetoothCharacteristic characteristic,
  ) {
    return GattCharacteristic(
      uuid: normalizeUuid(characteristic.uuid),
      properties: mapProperties(characteristic.properties),
      lastValue: List<int>.from(characteristic.lastValue),
    );
  }

  static GattService mapService(BluetoothService service) {
    return GattService(
      uuid: normalizeUuid(service.uuid),
      characteristics: service.characteristics
          .map(mapCharacteristic)
          .toList(growable: false),
    );
  }

  static List<GattService> mapServices(List<BluetoothService> services) {
    return services.map(mapService).toList(growable: false);
  }
}
