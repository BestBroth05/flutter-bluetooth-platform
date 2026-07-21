# Architecture

This document describes the greenfield architecture of
`flutter-bluetooth-platform`, a personal portfolio project for reusable
Flutter Bluetooth Low Energy (BLE) patterns.

## Goals

- Demonstrate modular BLE architecture with clear dependency boundaries.
- Keep transport, framing, persistence, and UI replaceable behind interfaces.
- Ship a simulator-first mode that works in tests, CI, and demos without
  hardware.
- Avoid any client branding, proprietary protocols, or medical domain language.

## Dependency rule

```text
presentation → application → domain
infrastructure → domain
application → domain interfaces
demo_protocol → generic framing interfaces only
```

The domain layer must not import Flutter, `flutter_blue_plus`,
`shared_preferences`, or UI packages.

## Module map

| Path | Responsibility |
|------|----------------|
| `lib/core/error` | Typed BLE failures and `Result` |
| `lib/core/utils` | Clock and cancellation helpers |
| `lib/ble/domain` | Models, ports, policies, framing contracts |
| `lib/ble/application` | Session coordination use-case layer |
| `lib/ble/infrastructure` | Fake transport and local persistence |
| `lib/ble/presentation` | Reserved for BLE-specific presentation helpers |
| `lib/features/*` | Feature UI (scanner, session, telemetry, dashboard) |
| `lib/demo_protocol` | Invented demonstration framing only |
| `lib/di` | GetIt composition root |

## Demo protocol (invented)

Wire format used only for portfolio demonstrations:

```text
[ 'P', 'K', 'T' ][ uint16 big-endian length ][ payload bytes ]
```

- Magic ASCII: `PKT` (`0x50 0x4B 0x54`)
- Maximum payload length: `1024`
- Demo GATT UUIDs are invented placeholders under
  `12345678-1234-5678-1234-56789abcdef*`

This framing is unrelated to any commercial or medical device protocol.

## Runtime composition

Phase 1 registers:

- `FakeBleTransport` as `BleTransport`
- `DemoPacketFramer` as `PacketFramer`
- `SharedPreferencesPairedDeviceStore` as `PairedDeviceStore`
- `BleSessionCoordinator` as the application façade
- `flutter_bloc` Cubits for the simulator shell

A future phase can register a `flutter_blue_plus` adapter without changing
domain or feature contracts.

## Policies

- **TimeoutPolicy**: scan, connection, and command budgets
- **RetryPolicy**: bounded attempts with exponential backoff
- **ReconnectionPolicy**: retry loop with cancellation support

## Persistence

Paired device records are stored locally as JSON in `shared_preferences`:

- `id`
- `name`
- `lastConnectedAt`

No remote API, authentication, or cloud sync is used in this phase.

## Testing strategy

- Unit tests for framing edge cases
- Unit tests for retry/backoff and reconnection cancellation
- Fake transport behavioral tests
- Persistence serialization tests
- A lightweight widget smoke test for the simulator shell

Reusable fakes live under `test/` and `lib/ble/infrastructure/fake/`.

## Intellectual property guardrails

This repository is independently written portfolio code. It must not contain:

- Client or product branding
- Proprietary BLE UUIDs, opcodes, framing constants, or algorithms
- Medical or assay terminology
- Secrets, API endpoints, Firebase configuration, or credentials
- Copied source, assets, comments, or Git history from other products
