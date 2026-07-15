import 'dart:convert';
import 'dart:typed_data';

abstract final class PluginTextFileCodec {
  static String decode(Uint8List bytes) =>
      utf8.decode(bytes, allowMalformed: true);

  static int length(Uint8List bytes) => decode(bytes).length;

  static String slice(Uint8List bytes, {int offset = 0, int? length}) {
    final text = decode(bytes);
    if (offset < 0 || offset > text.length) {
      throw RangeError('Invalid text offset: $offset');
    }
    final end = length == null
        ? text.length
        : (offset + length).clamp(offset, text.length);
    return text.substring(offset, end);
  }
}
