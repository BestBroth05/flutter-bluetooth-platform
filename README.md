# Flutter Bluetooth Platform

A personal portfolio project that demonstrates a reusable Flutter Bluetooth Low
Energy (BLE) architecture with **simulator mode** and **real BLE central mode**.

This repository is greenfield portfolio code. It is not affiliated with any
commercial or medical product.

> **Important:** The demonstration GATT UUIDs and packet framing format used in
> simulator demos are invented for portfolio use only. They are unrelated to any
> commercial or medical Bluetooth device.

## Current status

**Phase 2 — Real BLE central support + simulator**

- Simulator mode remains the default for tests and demos.
- Real BLE mode uses `flutter_blue_plus` on Android and iOS.
- Real mode is unavailable (typed unsupported state) on web/desktop in this phase.

## Selected BLE package

| Field | Value |
|-------|-------|
| Package | `flutter_blue_plus` |
| Version | **2.3.10** |
| License | FlutterBluePlus License v1.5 |
| Personal / educational use | Free (Section 2 / `License.nonprofit`) |
| Commercial / for-profit use | Requires paid commercial license |

Full evaluation: [docs/BLE_PACKAGE_LICENSE_EVALUATION.md](docs/BLE_PACKAGE_LICENSE_EVALUATION.md)

Comparable OSI-licensed alternatives (not used in this phase): `universal_ble`,
`flutter_reactive_ble` (both BSD-3-Clause).

## Main capabilities

- Transport mode selection: Simulator / Real BLE
- Bluetooth adapter state monitoring
- Runtime permission handling
- BLE scanning with timeout, cancellation, dedupe, RSSI, optional filters
- Connect / disconnect with timeout
- GATT service and characteristic discovery
- Characteristic read / write (with and without response when supported)
- Notification / indication subscriptions
- Raw notification log (hex + printable text when valid)
- Optional demo `PKT` framing (explicit opt-in for real devices)
- Retry and reconnection policies
- Local paired-device persistence
- Typed `BleFailure` mapping

## Architecture overview

```text
presentation → application → domain
infrastructure → domain
application → domain interfaces
```

Domain code does not import Flutter plugins. Plugin types stay in
`lib/ble/infrastructure/real/`.

### Dependency direction

| Layer | Responsibility |
|-------|----------------|
| Presentation | Dashboard Cubit/UI |
| Application | Session coordinator, transport factory |
| Domain | Models, ports, policies, framing contracts |
| Infrastructure | Fake transport, FBP transport, permissions, persistence |

## Simulator versus real mode

| Mode | Transport | Default in tests | Hardware |
|------|-----------|------------------|----------|
| Simulator | `FakeBleTransport` | Yes | None |
| Real BLE | `FlutterBluePlusBleTransport` | No | Physical Android/iOS device |

Switching modes stops scans, disconnects active sessions when needed, and
disposes prior streams.

## Real scan workflow

1. Request Bluetooth permissions.
2. Confirm adapter is on.
3. Start scan (optional name / min-RSSI / service filters).
4. Select a device and connect.
5. Discover GATT services/characteristics.
6. Read, write, or subscribe based on characteristic properties.

Notes:

- Demo UUIDs are **not** applied as default scan filters in real mode.
- Some phones may hide unnamed devices or expose randomized identifiers.

## Connection lifecycle

```text
disconnected → connecting → connected → (discover services) → ready
ready → disconnecting → disconnected
```

Also handled: permission failure, adapter off, timeout, discovery failure,
unexpected disconnect, user disconnect, reconnect in progress / cancelled.

Intentional user disconnect does **not** auto-reconnect. Unexpected disconnect
may trigger reconnection through the existing policy abstraction.

## GATT explorer

Connected devices expose an expandable GATT tree with property flags. Unsupported
operations are blocked in the UI and return typed failures.

## Raw notifications versus optional framed packets

1. Raw characteristic bytes are always shown when subscribed.
2. Demo `PKT` framing is optional and must be explicitly enabled.
3. Malformed framed data must not crash the raw notification stream.

Invented demo framing:

```text
[ 'P', 'K', 'T' ][ uint16 BE length ][ payload ]
```

## Android permission model

Uses the upstream “No Location” model for modern Android:

- API 31+: `BLUETOOTH_SCAN` (`neverForLocation`) + `BLUETOOTH_CONNECT`
- API ≤ 30: legacy Bluetooth permissions + location (`maxSdkVersion` limited)
- `minSdk` ≥ 21

This app does not derive physical location from BLE scans.

## iOS privacy configuration

- `NSBluetoothAlwaysUsageDescription` explains generic sensor discovery/connect use.
- Background Bluetooth modes are **not** enabled in this phase.
- Apps cannot programmatically turn Bluetooth on; the user controls Bluetooth power.

## Setup and run

```bash
git clone https://github.com/BestBroth05/flutter-bluetooth-platform.git
cd flutter-bluetooth-platform
flutter pub get
flutter run
```

## Test and analysis

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
```

Optional iOS compile check (not BLE validation):

```bash
flutter build ios --simulator
```

## Manual testing limitations

Automated tests never depend on physical Bluetooth hardware.

Real BLE behavior requires a physical Android and/or iOS device and an authorized
nearby peripheral or development board. The iOS Simulator cannot reliably validate
BLE scanning.

If no authorized physical peripheral is available, treat real hardware behavior as
**unverified**.

### Responsible testing

- Do not send arbitrary writes to unknown nearby devices.
- Do not repeatedly connect to devices you do not own or have permission to test.
- Prefer your own development boards or explicitly authorized peripherals.

## Troubleshooting

| Symptom | Likely cause |
|---------|--------------|
| Permission missing | Runtime permission denied/permanently denied |
| Adapter off | Bluetooth disabled in system settings |
| Real mode unsupported | Running on web/desktop |
| No devices found | Device not advertising, OS filtering, or permissions |
| Unauthorized adapter state (iOS) | Bluetooth permission not granted |
| Write/notify disabled | Characteristic properties do not allow the operation |

## Current limitations

- Real BLE claimed only for Android/iOS
- No background BLE modes
- No polished multi-screen navigation beyond the Phase 2 dashboard
- No cloud sync
- Commercial reuse of `flutter_blue_plus` requires a paid license

## License

This project is released under the [MIT License](LICENSE).

Copyright (c) 2026 Brayan Olivares

`flutter_blue_plus` remains under the FlutterBluePlus License (see evaluation doc).

## Package identity

| Item | Value |
|------|-------|
| Repository | `flutter-bluetooth-platform` |
| Flutter package name | `bluetooth_platform` |
| Application identifier | `dev.brayanolivares.bluetooth_platform` |

See also [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
