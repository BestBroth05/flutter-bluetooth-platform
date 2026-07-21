import '../models/paired_device.dart';

/// Port for persisting paired Bluetooth device records locally.
abstract class PairedDeviceStore {
  Future<List<PairedDevice>> loadAll();

  Future<void> save(PairedDevice device);

  Future<void> remove(String deviceId);

  Future<void> clear();
}
