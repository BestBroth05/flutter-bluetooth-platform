import 'dart:async';

import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../../domain/models/characteristic_ref.dart';

/// Tracks active characteristic notification subscriptions for cleanup.
final class BleSubscriptionRegistry {
  final Map<String, StreamSubscription<List<int>>> _subscriptions =
      <String, StreamSubscription<List<int>>>{};

  String keyFor(CharacteristicRef ref) =>
      '${ref.serviceUuid.toLowerCase()}::${ref.characteristicUuid.toLowerCase()}';

  bool contains(CharacteristicRef ref) =>
      _subscriptions.containsKey(keyFor(ref));

  void add(
    CharacteristicRef ref,
    StreamSubscription<List<int>> subscription,
  ) {
    final key = keyFor(ref);
    unawaited(_subscriptions[key]?.cancel());
    _subscriptions[key] = subscription;
  }

  Future<void> remove(CharacteristicRef ref) async {
    final key = keyFor(ref);
    await _subscriptions.remove(key)?.cancel();
  }

  Future<void> clear() async {
    final pending = _subscriptions.values
        .map((subscription) => subscription.cancel())
        .toList(growable: false);
    _subscriptions.clear();
    await Future.wait(pending);
  }

  Future<void> bind(
    BluetoothDevice device,
    BluetoothCharacteristic characteristic,
    CharacteristicRef ref,
    void Function(List<int> value) onValue,
  ) async {
    await characteristic.setNotifyValue(true);
    final subscription = characteristic.onValueReceived.listen(onValue);
    device.cancelWhenDisconnected(subscription);
    add(ref, subscription);
  }
}
