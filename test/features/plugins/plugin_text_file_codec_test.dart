import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/features/plugins/application/plugin_text_file_codec.dart';

void main() {
  test(
    'Legacy text slices use UTF-16 offsets instead of UTF-8 byte offsets',
    () {
      final bytes = Uint8List.fromList(utf8.encode('A猫📚B'));

      expect(PluginTextFileCodec.length(bytes), 5);
      expect(PluginTextFileCodec.slice(bytes, offset: 1, length: 1), '猫');
      expect(PluginTextFileCodec.slice(bytes, offset: 2, length: 2), '📚');
      expect(PluginTextFileCodec.slice(bytes, offset: 4, length: 1), 'B');
    },
  );

  test('Legacy text decoding tolerates malformed input', () {
    final bytes = Uint8List.fromList([0x41, 0xe7, 0x8c]);

    expect(PluginTextFileCodec.decode(bytes), 'A�');
  });
}
