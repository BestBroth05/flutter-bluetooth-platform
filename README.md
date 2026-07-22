# Flutter Bluetooth Platform

A personal portfolio project that demonstrates a reusable Flutter Bluetooth Low
Energy (BLE) architecture. The focus is clean module boundaries, testable
transport abstractions, packet reassembly, connection policies, and local
paired-device persistence.

This repository is greenfield portfolio code. It is not affiliated with any
commercial or medical product.

> **Important:** The demonstration GATT UUIDs and packet framing format used in
> this project are invented for portfolio demos only. They are unrelated to any
> commercial or medical Bluetooth device.

## Current status

**Phase 1 — Simulator mode**

The app runs entirely against a fake BLE transport. You can exercise discovery,
connection sessions, GATT discovery, telemetry streaming, command writes,
timeouts, retries, reconnection, and local pairing without hardware.

Real BLE hardware integration is **not** implemented in this phase.

## Main capabilities

- BLE scanning simulation with RSSI
- Connection and disconnection lifecycle
- Simulated GATT service and characteristic discovery
- Characteristic writes (demo commands)
- Notification / telemetry streaming
- Generic packet fragmentation and reassembly
- Connection timeouts
- Retry with exponential backoff
- Reconnection with cancellation
- Local paired-device persistence (`shared_preferences`)
- Typed BLE failures and `Result` handling
- Minimal simulator dashboard UI (`flutter_bloc` + GetIt)

## Architecture overview

The project follows a layered structure with replaceable infrastructure:

| Layer | Responsibility |
|-------|----------------|
| Presentation | Simulator dashboard Cubit/UI |
| Application | Session coordination (scan, connect, frame, persist) |
| Domain | Models, ports, policies, framing contracts |
| Infrastructure | Fake BLE transport, local storage |
| Demo protocol | Invented framing constants and framer |

### Dependency direction

```text
presentation → application → domain
infrastructure → domain
application → domain interfaces
demo_protocol → generic framing interfaces only
```

The domain layer does not import Flutter, `flutter_blue_plus`,
`shared_preferences`, or UI libraries. Transport, framing, and storage sit
behind interfaces so implementations can be swapped later.

## Generic demo packet format

Invented demonstration framing only:

```text
[ 'P', 'K', 'T' ][ uint16 big-endian payload length ][ payload bytes ]
```

| Field | Details |
|-------|---------|
| Magic | ASCII `PKT` (`0x50 0x4B 0x54`) |
| Length | Big-endian `uint16` |
| Max payload | 1024 bytes |
| Demo service UUID | `12345678-1234-5678-1234-56789abcdef0` |
| Demo command characteristic | `12345678-1234-5678-1234-56789abcdef1` |
| Demo telemetry characteristic | `12345678-1234-5678-1234-56789abcdef2` |

These values exist solely so reassembly, writes, and notifications can be
demonstrated in simulator mode.

## Simulator devices and scenarios

Default simulated sensors:

| Device ID | Name | Behavior |
|-----------|------|----------|
| `sim-sensor-alpha` | Demo Sensor Alpha | Reliable connect |
| `sim-sensor-beta` | Demo Sensor Beta | Reliable connect |
| `sim-sensor-flaky` | Demo Sensor Flaky | Simulated connection failure |

Supported demo scenarios:

- Device discovery / scanning states
- Connect and disconnect
- Service discovery simulation
- Telemetry streaming (including fragmented frames)
- Command writes with acknowledgement frames
- Connection failure
- Connection timeout
- Retry behavior
- Reconnection and cancel-reconnect
- Persisted paired-device information

## Project structure

```text
lib/
├── main.dart
├── app.dart
├── di/
├── core/
│   ├── error/
│   └── utils/
├── ble/
│   ├── domain/
│   │   ├── models/
│   │   ├── repositories/
│   │   ├── framing/
│   │   └── policies/
│   ├── application/
│   ├── infrastructure/
│   │   ├── fake/
│   │   └── persistence/
│   └── presentation/
├── features/
│   └── dashboard/
└── demo_protocol/
test/
├── framing/
├── policies/
├── transport/
├── persistence/
└── fakes/                  # reserved for shared test helpers
docs/
└── ARCHITECTURE.md
```

## Setup and run

Requirements:

- Flutter stable (project SDK: `^3.11.5`)
- Dart included with Flutter

```bash
git clone https://github.com/BestBroth05/flutter-bluetooth-platform.git
cd flutter-bluetooth-platform
flutter pub get
flutter run
```

The app launches in simulator mode and discovers demo sensors without a
physical Bluetooth peripheral.

## Test and analysis

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

## Current limitations

- No real-device BLE adapter yet
- No production-polished multi-screen UI
- No networking, authentication, or cloud sync
- Permissions and platform BLE settings flows are deferred to the real-adapter phase
- Feature folders beyond the dashboard shell are reserved for later extraction

## Roadmap: real BLE adapter

Planned next steps:

1. Add a `flutter_blue_plus` infrastructure adapter implementing `BleTransport`
2. Keep the fake transport for tests, CI, and demos
3. Add runtime permission handling for Android and iOS
4. Expand the dashboard into scanner / session / telemetry feature UIs
5. Preserve the same domain contracts so the application layer stays stable

## IP and privacy guardrails

- This is independently written portfolio code
- No client branding, proprietary UUIDs, opcodes, or device protocols
- No medical or assay domain terminology
- No secrets, API endpoints, Firebase configuration, or credentials
- Local persistence stores only generic paired-device fields (`id`, `name`,
  `lastConnectedAt`)

## License

This project is released under the [MIT License](LICENSE).

Copyright (c) 2026 Brayan Olivares

## Package identity

| Item | Value |
|------|-------|
| Repository | `flutter-bluetooth-platform` |
| Flutter package name | `bluetooth_platform` |
| Application identifier | `dev.brayanolivares.bluetooth_platform` |

For deeper module notes, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
