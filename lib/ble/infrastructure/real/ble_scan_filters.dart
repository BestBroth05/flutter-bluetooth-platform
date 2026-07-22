import '../../domain/models/ble_device.dart';
import '../../domain/models/ble_scan_filter.dart';

/// Pure scan-filter helpers used by real and test code.
abstract final class BleScanFilters {
  static bool matches(BleDevice device, BleScanFilter filter) {
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

    return true;
  }

  /// Deduplicate by device id, keeping the newest RSSI/name.
  static Map<String, BleDevice> upsert(
    Map<String, BleDevice> current,
    BleDevice device,
  ) {
    final next = Map<String, BleDevice>.from(current);
    next[device.id] = device;
    return next;
  }
}
