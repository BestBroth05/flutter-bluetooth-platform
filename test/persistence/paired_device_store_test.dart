import 'package:bluetooth_platform/ble/domain/models/paired_device.dart';
import 'package:bluetooth_platform/ble/infrastructure/persistence/shared_preferences_paired_device_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SharedPreferencesPairedDeviceStore', () {
    test('serializes and deserializes paired devices', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      final store = SharedPreferencesPairedDeviceStore(preferences);

      final device = PairedDevice(
        id: 'sim-sensor-alpha',
        name: 'Demo Sensor Alpha',
        lastConnectedAt: DateTime.utc(2026, 7, 21, 18, 0),
      );

      await store.save(device);
      final loaded = await store.loadAll();

      expect(loaded, hasLength(1));
      expect(loaded.single.id, device.id);
      expect(loaded.single.name, device.name);
      expect(loaded.single.lastConnectedAt, device.lastConnectedAt);
    });

    test('updates an existing paired device by id', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      final store = SharedPreferencesPairedDeviceStore(preferences);

      await store.save(const PairedDevice(id: 'sensor-1', name: 'Old Name'));
      await store.save(
        PairedDevice(
          id: 'sensor-1',
          name: 'New Name',
          lastConnectedAt: DateTime.utc(2026, 7, 21),
        ),
      );

      final loaded = await store.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.single.name, 'New Name');
    });

    test('PairedDevice JSON round-trip keeps generic fields', () {
      final original = PairedDevice(
        id: 'sensor-9',
        name: 'Portfolio Sensor',
        lastConnectedAt: DateTime.utc(2026, 1, 2, 3, 4, 5),
      );

      final restored = PairedDevice.fromJson(original.toJson());

      expect(restored, original);
    });
  });
}
