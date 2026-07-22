/// Selects which [BleTransport] implementation the app uses.
enum BleTransportMode {
  /// In-memory fake peripherals for tests, CI, and demos.
  simulator,

  /// Real Bluetooth Low Energy central mode on a supported mobile device.
  real,
}
