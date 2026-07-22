/// Pure Dart helpers for hex and text command encoding/decoding.
abstract final class ByteCodecs {
  /// Parses space-separated or contiguous hex (e.g. `01 02 FF` or `0102FF`).
  static List<int> parseHex(String input) {
    final cleaned = input.replaceAll(RegExp(r'[\s:_-]'), '').toLowerCase();
    if (cleaned.isEmpty) {
      throw const FormatException('Hex input is empty.');
    }
    if (cleaned.length.isOdd) {
      throw const FormatException(
        'Hex input must contain an even number of digits.',
      );
    }
    if (!RegExp(r'^[0-9a-f]+$').hasMatch(cleaned)) {
      throw const FormatException('Hex input contains non-hex characters.');
    }

    final bytes = <int>[];
    for (var i = 0; i < cleaned.length; i += 2) {
      bytes.add(int.parse(cleaned.substring(i, i + 2), radix: 16));
    }
    return bytes;
  }

  static String toHex(List<int> bytes, {String separator = ' '}) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join(separator);
  }

  static List<int> encodeUtf8(String text) => text.codeUnits;

  /// Returns printable UTF-8/ASCII text when every byte is a printable code unit.
  static String? tryDecodePrintable(List<int> bytes) {
    if (bytes.isEmpty) {
      return '';
    }
    for (final byte in bytes) {
      if (byte < 0x20 || byte > 0x7E) {
        return null;
      }
    }
    return String.fromCharCodes(bytes);
  }
}
