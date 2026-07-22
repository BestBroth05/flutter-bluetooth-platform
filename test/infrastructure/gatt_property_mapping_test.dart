import 'package:bluetooth_platform/ble/domain/models/gatt_models.dart';
import 'package:bluetooth_platform/ble/infrastructure/real/ble_gatt_mapper.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps characteristic properties into domain flags', () {
    final mapped = BleGattMapper.mapProperties(
      CharacteristicProperties(
        read: true,
        write: true,
        writeWithoutResponse: true,
        notify: true,
        indicate: false,
      ),
    );

    expect(
      mapped,
      const GattCharacteristicProperties(
        canRead: true,
        canWrite: true,
        canWriteWithoutResponse: true,
        canNotify: true,
        canIndicate: false,
      ),
    );
    expect(mapped.canSubscribe, isTrue);
  });
}
