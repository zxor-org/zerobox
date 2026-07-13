import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/device/zeppos/crypto/zeppos_auth_crypto.dart';

void main() {
  test('scalar one encodes the Gadgetbridge B-163 base point', () {
    final privateKey = Uint8List(24)..[0] = 1;
    final publicKey = createZeppOsPublicKey(privateKey);

    expect(
      publicKey,
      Uint8List.fromList(const [
        0x36, 0x3e, 0x34, 0xe8, 0x37, 0x46, 0x99, 0xd4,
        0x68, 0x11, 0x99, 0xa0, 0x7e, 0xd5, 0xa2, 0x86,
        0x62, 0xa1, 0xeb, 0xf0, 0x03, 0x00, 0x00, 0x00,
        0xf1, 0x24, 0x73, 0x79, 0x0c, 0x5c, 0x1c, 0xb1,
        0x45, 0xd5, 0xcd, 0xa2, 0x4f, 0x09, 0xa0, 0x71,
        0x6c, 0xbc, 0x1f, 0xd5, 0x00, 0x00, 0x00, 0x00,
      ]),
    );
  });

  test('authkey accepts canonical ZeppOS hex forms', () {
    const key = '00112233445566778899aabbccddeeff';
    expect(parseZeppOsAuthKey(key), parseZeppOsAuthKey('0x$key'));
  });

  test('authkey rejects malformed prefixed and 32-character values', () {
    expect(
      () => parseZeppOsAuthKey('0x1234'),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => parseZeppOsAuthKey(List.filled(32, 'z').join()),
      throwsA(isA<FormatException>()),
    );
  });
}
