import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/error/ble_failure.dart';
import '../../domain/models/paired_device.dart';
import '../../domain/repositories/paired_device_store.dart';

/// [PairedDeviceStore] backed by [SharedPreferences] JSON serialization.
final class SharedPreferencesPairedDeviceStore implements PairedDeviceStore {
  SharedPreferencesPairedDeviceStore(
    this._preferences, {
    this.storageKey = defaultStorageKey,
  });

  static const String defaultStorageKey = 'paired_bluetooth_devices';

  final SharedPreferences _preferences;
  final String storageKey;

  @override
  Future<List<PairedDevice>> loadAll() async {
    try {
      final raw = _preferences.getString(storageKey);
      if (raw == null || raw.isEmpty) {
        return const <PairedDevice>[];
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        throw const PersistenceFailure('Paired device payload is not a list.');
      }

      return decoded
          .whereType<Map>()
          .map(
            (item) => PairedDevice.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .toList(growable: false);
    } on BleFailure {
      rethrow;
    } catch (error) {
      throw PersistenceFailure('Unable to load paired devices: $error');
    }
  }

  @override
  Future<void> save(PairedDevice device) async {
    try {
      final existing = await loadAll();
      final next = <PairedDevice>[
        for (final item in existing)
          if (item.id != device.id) item,
        device,
      ];
      await _writeAll(next);
    } on BleFailure {
      rethrow;
    } catch (error) {
      throw PersistenceFailure('Unable to save paired device: $error');
    }
  }

  @override
  Future<void> remove(String deviceId) async {
    try {
      final existing = await loadAll();
      final next = existing.where((item) => item.id != deviceId).toList();
      await _writeAll(next);
    } on BleFailure {
      rethrow;
    } catch (error) {
      throw PersistenceFailure('Unable to remove paired device: $error');
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _preferences.remove(storageKey);
    } catch (error) {
      throw PersistenceFailure('Unable to clear paired devices: $error');
    }
  }

  Future<void> _writeAll(List<PairedDevice> devices) async {
    final encoded = jsonEncode(
      devices.map((device) => device.toJson()).toList(growable: false),
    );
    final saved = await _preferences.setString(storageKey, encoded);
    if (!saved) {
      throw const PersistenceFailure('SharedPreferences rejected the write.');
    }
  }
}
