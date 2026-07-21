# flutter-bluetooth-platform

Personal portfolio project demonstrating a reusable Flutter Bluetooth Low Energy
(BLE) architecture with a simulator-first workflow.

This repository is greenfield code written for portfolio use. It is not
affiliated with any commercial or medical product and does not implement any
proprietary device protocol.

## Package identity

| Item | Value |
|------|-------|
| Repository | `flutter-bluetooth-platform` |
| Flutter package name | `bluetooth_platform` |
| Application identifier | `dev.brayanolivares.bluetooth_platform` |

## What phase 1 includes

- Layered architecture: presentation → application → domain ← infrastructure
- Domain models for devices, sessions, GATT, telemetry, commands, and pairing
- Ports for BLE transport, packet framing, and paired-device storage
- Typed BLE failures and `Result` handling
- Fake BLE transport with simulated scan, connect, disconnect, services,
  notifications, command writes, failures, and timeouts
- Invented demo packet framer (`PKT` length-prefixed frames)
- Timeout, retry, and reconnection policies
- Local paired-device persistence via `shared_preferences`
- Minimal simulator application shell (`flutter_bloc` + GetIt)
- Unit tests for framing, policies, transport, and persistence

## What phase 1 intentionally excludes

- Real-device adapter using `flutter_blue_plus` (planned next)
- Production-polished UI
- Networking, authentication, Firebase, or remote APIs
- Any client branding, medical terminology, or proprietary UUIDs/commands

## Quick start

```bash
flutter pub get
flutter test
flutter run
```

The app launches in simulator mode and discovers demo sensors without hardware.

## Demo protocol

Invented demonstration framing only:

```text
[ P K T ][ uint16 BE payload length ][ payload ]
```

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for module boundaries, IP
guardrails, and extension points.

## Dependencies

| Package | Why |
|---------|-----|
| `flutter_bloc` | Predictable UI state for the simulator shell |
| `get_it` | Composition root / dependency injection |
| `shared_preferences` | Local paired-device persistence |
| `equatable` | Value equality for models and states |
| `mocktail` (dev) | Available for future interface mocking |

## License note

Portfolio demonstration code. Do not treat the demo UUIDs or framing constants
as a real product specification.
