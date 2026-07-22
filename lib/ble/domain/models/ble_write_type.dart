/// Generic write semantics for a GATT characteristic.
enum BleWriteType {
  /// Write with response (acknowledged).
  withResponse,

  /// Write without response when the characteristic supports it.
  withoutResponse,
}
