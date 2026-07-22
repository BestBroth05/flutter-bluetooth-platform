# Architecture

Greenfield architecture for `flutter-bluetooth-platform`.

## Phases

| Phase | Status |
|-------|--------|
| Phase 1 | Simulator foundation, framing, policies, persistence |
| Phase 2 | Real BLE central adapter (`flutter_blue_plus` 2.3.10), permissions, GATT explorer, mode switching |

## Dependency rule

```text
presentation → application → domain
infrastructure → domain
application → domain interfaces
demo_protocol → generic framing interfaces only
```

Domain must not import Flutter, `flutter_blue_plus`, `permission_handler`,
`shared_preferences`, or plugin models.

## Module map

| Path | Responsibility |
|------|----------------|
| `lib/core` | Failures, `Result`, clock, byte codecs |
| `lib/ble/domain` | Models, ports, policies, framing contracts, permission port |
| `lib/ble/application` | Session coordinator, transport factory |
| `lib/ble/infrastructure/fake` | Simulator transport |
| `lib/ble/infrastructure/real` | FBP adapter + collaborators |
| `lib/ble/infrastructure/persistence` | Paired-device store |
| `lib/features/dashboard` | Phase 2 UI shell |
| `lib/demo_protocol` | Invented demo framing only |
| `lib/di` | GetIt composition root |

## Real infrastructure collaborators

```text
ble/infrastructure/real/
├── flutter_blue_plus_ble_transport.dart
├── ble_adapter_monitor.dart
├── ble_permission_gateway_impl.dart
├── ble_gatt_mapper.dart
├── ble_scan_filters.dart
├── ble_subscription_registry.dart
└── ble_platform_error_mapper.dart
```

## Transport modes

- `BleTransportMode.simulator` → `FakeBleTransport`
- `BleTransportMode.real` → `FlutterBluePlusBleTransport` (Android/iOS only)

`BleSessionCoordinator.replaceTransport` performs cleanup when switching modes.

## Domain interface extensions (Phase 2)

`BleTransport` gained generic capabilities required by real BLE:

- Adapter state stream
- Scan filters
- Characteristic read/write/subscribe
- RSSI read
- Notification events with characteristic refs
- `lastDisconnectWasIntentional`
- `supportsRealHardware`

Fake transport implements the same contract.

## IP guardrails

- No client branding or proprietary protocols
- No medical/assay terminology
- Invented demo UUIDs/framing only for optional simulator framing
- License evaluation recorded for `flutter_blue_plus`
