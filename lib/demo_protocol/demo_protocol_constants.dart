/// Demonstration-only framing constants invented for this portfolio project.
///
/// These values are unrelated to any commercial or medical Bluetooth device.
/// They exist solely so packet reassembly can be exercised in simulator mode.
abstract final class DemoProtocolConstants {
  /// ASCII magic "PKT".
  static const List<int> magic = <int>[0x50, 0x4B, 0x54];

  /// Bytes occupied by the magic marker.
  static const int magicLength = 3;

  /// Bytes occupied by the big-endian payload length field.
  static const int lengthFieldSize = 2;

  /// Total header size: magic + length.
  static const int headerLength = magicLength + lengthFieldSize;

  /// Reject frames that claim an absurd payload size.
  static const int maxPayloadLength = 1024;

  /// Invented demo GATT service UUID (not from a commercial product).
  static const String demoServiceUuid = '12345678-1234-5678-1234-56789abcdef0';

  /// Invented demo write characteristic UUID.
  static const String demoCommandCharacteristicUuid =
      '12345678-1234-5678-1234-56789abcdef1';

  /// Invented demo notify characteristic UUID.
  static const String demoTelemetryCharacteristicUuid =
      '12345678-1234-5678-1234-56789abcdef2';
}
