import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/permissions/ble_permission_gateway.dart';
import '../../domain/permissions/ble_permission_status.dart';

/// permission_handler-backed Bluetooth permission gateway.
final class PermissionHandlerBlePermissionGateway
    implements BlePermissionGateway {
  const PermissionHandlerBlePermissionGateway();

  @override
  Future<BlePermissionStatus> status() async {
    if (kIsWeb) {
      return BlePermissionStatus.unavailable;
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return _map(await Permission.bluetooth.status);
    }
    if (Platform.isAndroid) {
      return _aggregateAndroid(await _androidStatuses());
    }
    return BlePermissionStatus.unavailable;
  }

  @override
  Future<BlePermissionStatus> request() async {
    if (kIsWeb) {
      return BlePermissionStatus.unavailable;
    }
    if (Platform.isIOS || Platform.isMacOS) {
      return _map(await Permission.bluetooth.request());
    }
    if (Platform.isAndroid) {
      final results = await _androidPermissions().request();
      return _aggregateAndroid(results);
    }
    return BlePermissionStatus.unavailable;
  }

  @override
  Future<bool> get isPermanentlyDenied async {
    final current = await status();
    return current == BlePermissionStatus.permanentlyDenied;
  }

  List<Permission> _androidPermissions() {
    // Android 12+ uses dedicated BLE permissions. Legacy Android still needs
    // location for BLE scans even when the app does not derive physical location.
    return <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ];
  }

  Future<Map<Permission, PermissionStatus>> _androidStatuses() async {
    final permissions = _androidPermissions();
    final entries = await Future.wait(
      permissions.map((permission) async {
        return MapEntry(permission, await permission.status);
      }),
    );
    return Map<Permission, PermissionStatus>.fromEntries(entries);
  }

  BlePermissionStatus _aggregateAndroid(
    Map<Permission, PermissionStatus> statuses,
  ) {
    // On API 31+, location may be denied while BLE scan/connect are granted.
    // Prefer BLE-specific statuses when present.
    final bleStatuses = <PermissionStatus>[
      if (statuses.containsKey(Permission.bluetoothScan))
        statuses[Permission.bluetoothScan]!,
      if (statuses.containsKey(Permission.bluetoothConnect))
        statuses[Permission.bluetoothConnect]!,
    ];

    if (bleStatuses.isNotEmpty) {
      if (bleStatuses.every((status) => status.isGranted)) {
        return BlePermissionStatus.granted;
      }
      if (bleStatuses.any((status) => status.isPermanentlyDenied)) {
        return BlePermissionStatus.permanentlyDenied;
      }
      if (bleStatuses.any((status) => status.isRestricted)) {
        return BlePermissionStatus.restricted;
      }
      return BlePermissionStatus.denied;
    }

    final location = statuses[Permission.locationWhenInUse];
    if (location == null) {
      return BlePermissionStatus.unavailable;
    }
    return _map(location);
  }

  BlePermissionStatus _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited) {
      return BlePermissionStatus.granted;
    }
    if (status.isPermanentlyDenied) {
      return BlePermissionStatus.permanentlyDenied;
    }
    if (status.isRestricted) {
      return BlePermissionStatus.restricted;
    }
    if (status.isDenied) {
      return BlePermissionStatus.denied;
    }
    return BlePermissionStatus.unavailable;
  }
}
