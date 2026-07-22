/// Generic Bluetooth adapter readiness, independent of any plugin enum.
enum BleAdapterState {
  unknown,
  unsupported,
  unauthorized,
  off,
  turningOn,
  on,
  turningOff,
}
