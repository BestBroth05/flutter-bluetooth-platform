# BLE package and license evaluation (Phase 2)

Evaluation date: 2026-07-21  
Evaluated against current pub.dev / upstream documentation (not historical dependency pins).

## Selected package

| Field | Value |
|-------|-------|
| Package | `flutter_blue_plus` |
| Selected version | **2.3.10** (latest stable on pub.dev at evaluation time) |
| Publisher | jamcorder.com |
| Homepage | https://github.com/chipweinberger/flutter_blue_plus |
| License name | **FlutterBluePlus License** Version **1.5** |
| SPDX / OSI | Not an OSI-approved SPDX identifier (`license:unknown` on pub.dev) |
| Copyright | Copyright (c) 2026 Chip Weinberger |

## Suitability for this repository

| Use case | Suitable? | Notes |
|----------|-----------|-------|
| Public GitHub portfolio | **Yes** | Personal / hobby use is free under Section 2 |
| Personal and educational use | **Yes** | Explicitly free under Section 2 |
| Future commercial / for-profit use | **Conditional** | Requires purchase of a commercial license (Section 3) |

### License constraints (summary)

- **Free** for personal users, registered nonprofits, and accredited educational institutions (Section 2).
- **Commercial license required** for for-profit organizations and commercial use by individuals, including development, testing, and evaluation (Section 3).
- Redistributions of the software source must retain the copyright notice and the **entire** FlutterBluePlus License text.
- The software may attempt limited **build-time license telemetry** (package name, app name, app version, FlutterBluePlus version, date). No source code or end-user data.
- Some legacy portions remain under BSD-3; upstream advises reviewing `NOTICE.md` for contributor compliance.

Commercial license portal (upstream):  
https://jamcorder.myshopify.com/products/flutterblueplus-commercial-license

## Supported platforms (package)

Declared on pub.dev: **Android, iOS, Linux, macOS, web, Windows**.

### This portfolio Phase 2 scope

| Platform | Phase 2 claim |
|----------|---------------|
| Android | Primary real-BLE target |
| iOS | Secondary real-BLE target (physical device required for BLE validation) |
| Web / Desktop | Not claimed as functional real BLE in this phase; typed unsupported handling |

## Minimum platform requirements (from upstream docs)

| Platform | Requirement |
|----------|-------------|
| Android | `minSdkVersion` **21** |
| Android 12+ (API 31+) | `BLUETOOTH_SCAN` + `BLUETOOTH_CONNECT` |
| Android ≤ 11 | Legacy `BLUETOOTH` / `BLUETOOTH_ADMIN` (+ location only when required by OS/scan model) |
| iOS | `NSBluetoothAlwaysUsageDescription` in Info.plist |
| iOS Bluetooth power | User-controlled; apps cannot programmatically enable Bluetooth |

Upstream documents a **“No Location”** Android permission set using  
`BLUETOOTH_SCAN` with `android:usesPermissionFlags="neverForLocation"`. Phase 2 follows that model because this app does not derive physical location from scan results.

## Commercial licensing concern

If this portfolio code is later reused inside a **for-profit product**, a FlutterBluePlus commercial license must be purchased before that commercial use. Until then, personal/educational portfolio use remains within Section 2.

This evaluation does **not** silently switch packages. The selection remains `flutter_blue_plus` because:

1. It matches the Phase 2 technical plan (mature central-mode BLE API).
2. Personal/portfolio use is explicitly permitted.
3. Commercial constraints can be documented clearly for future readers.

## Comparable alternatives (if a fully OSI-approved dependency is preferred later)

Do not switch without an explicit decision. For reference only:

| Package | Latest (evaluation) | License | Notes |
|---------|---------------------|---------|-------|
| `universal_ble` | 2.1.0 | **BSD-3-Clause** | Cross-platform BLE; free for commercial use under BSD terms |
| `flutter_reactive_ble` | 5.5.0 | **BSD-3-Clause** | Reactive BLE API; Android/iOS oriented |

## Decision

**Proceed with `flutter_blue_plus` ^2.3.10** for Phase 2 real BLE infrastructure, with license constraints documented in README and architecture docs.
