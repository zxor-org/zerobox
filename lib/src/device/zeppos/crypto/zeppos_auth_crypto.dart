import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

class ZeppOsAuthKeys {
  const ZeppOsAuthKeys({
    required this.privateKey,
    required this.publicKey,
    required this.sharedSecret,
    required this.sessionKey,
    required this.encryptedSequenceNumber,
  });

  final Uint8List privateKey;
  final Uint8List publicKey;
  final Uint8List sharedSecret;
  final Uint8List sessionKey;
  final int encryptedSequenceNumber;
}

class ZeppOsAuthKeyPair {
  const ZeppOsAuthKeyPair({required this.privateKey, required this.publicKey});

  final Uint8List privateKey;
  final Uint8List publicKey;
}

Uint8List parseZeppOsAuthKey(String authKey) {
  final trimmed = authKey.trim();
  final normalized = trimmed.toLowerCase();
  if (normalized.isEmpty) {
    return Uint8List.fromList('0123456789@ABCDE'.codeUnits);
  }
  final hex = normalized.startsWith('0x')
      ? normalized.substring(2)
      : normalized;
  if (hex.length == 32) {
    if (!RegExp(r'^[0-9a-f]{32}$').hasMatch(hex)) {
      throw const FormatException(
        'ZeppOS authkey must contain exactly 32 hexadecimal characters',
      );
    }
    final bytes = Uint8List(16);
    for (var i = 0; i < bytes.length; i += 1) {
      bytes[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }
  if (normalized.startsWith('0x')) {
    throw const FormatException(
      'ZeppOS authkey with 0x prefix must contain 32 hexadecimal characters',
    );
  }
  final raw = Uint8List.fromList(trimmed.codeUnits);
  final bytes = Uint8List(16);
  final copyLength = raw.length < bytes.length ? raw.length : bytes.length;
  if (copyLength > 0) {
    bytes.setRange(0, copyLength, raw);
  }
  return bytes;
}

ZeppOsAuthKeyPair createZeppOsAuthKeyPair() {
  final privateKey = _randomPrivateKey();
  return ZeppOsAuthKeyPair(
    privateKey: privateKey,
    publicKey: _generatePublicKey(privateKey),
  );
}

ZeppOsAuthKeys completeZeppOsAuth({
  required String authKey,
  required Uint8List privateKey,
  required Uint8List publicKey,
  required Uint8List remotePublicKey,
}) {
  if (remotePublicKey.length != 48) {
    throw ArgumentError('ZeppOS remote public key must be 48 bytes');
  }
  final secretKey = parseZeppOsAuthKey(authKey);
  final sharedSecret = _generateSharedSecret(privateKey, remotePublicKey);
  final sequence = _uint32Le(sharedSecret, 0);
  final sessionKey = Uint8List(16);
  for (var i = 0; i < sessionKey.length; i += 1) {
    sessionKey[i] = sharedSecret[i + 8] ^ secretKey[i];
  }
  return ZeppOsAuthKeys(
    privateKey: privateKey,
    publicKey: publicKey,
    sharedSecret: sharedSecret,
    sessionKey: sessionKey,
    encryptedSequenceNumber: sequence,
  );
}

Uint8List createZeppOsPublicKey(Uint8List privateKey) =>
    _generatePublicKey(privateKey);

Uint8List zeppOsAesEcbEncrypt(Uint8List key, Uint8List value) {
  if (key.length != 16) throw ArgumentError('AES key must be 16 bytes');
  if (value.length % 16 != 0) {
    throw ArgumentError('AES/ECB/NoPadding input must be 16-byte aligned');
  }
  final cipher = ECBBlockCipher(AESEngine())
    ..init(true, KeyParameter(Uint8List.fromList(key)));
  final output = Uint8List(value.length);
  for (var offset = 0; offset < value.length; offset += cipher.blockSize) {
    cipher.processBlock(value, offset, output, offset);
  }
  return output;
}

Uint8List _randomPrivateKey() {
  final random = Random.secure();
  while (true) {
    final key = Uint8List(24);
    for (var i = 0; i < key.length; i += 1) {
      key[i] = random.nextInt(256);
    }
    if (_bitLength(_littleEndianToBigInt(key)) >= _curveDegree ~/ 2) {
      return key;
    }
  }
}

Uint8List _generatePublicKey(Uint8List privateKey) {
  final point = _pointMultiply(_basePoint, _privateScalar(privateKey));
  if (point == null) {
    throw StateError('ZeppOS public key generation failed');
  }
  return _encodePoint(point);
}

Uint8List _generateSharedSecret(
  Uint8List privateKey,
  Uint8List remotePublicKey,
) {
  final remotePoint = _EcPoint(
    _gfReduce(_littleEndianToBigInt(remotePublicKey.sublist(0, 24))),
    _gfReduce(_littleEndianToBigInt(remotePublicKey.sublist(24, 48))),
  );
  if (!_isOnCurve(remotePoint)) {
    throw StateError('ZeppOS remote public key is not on B-163');
  }
  final shared = _pointMultiply(remotePoint, _privateScalar(privateKey));
  if (shared == null) {
    throw StateError('ZeppOS shared secret generation failed');
  }
  return _encodePoint(shared);
}

Uint8List _encodePoint(_EcPoint point) {
  final output = Uint8List(48);
  output.setRange(
    0,
    24,
    _bigIntToLittleEndian(point.x, 24),
  );
  output.setRange(
    24,
    48,
    _bigIntToLittleEndian(point.y, 24),
  );
  return output;
}

BigInt _privateScalar(Uint8List privateKey) {
  var scalar = _littleEndianToBigInt(privateKey);
  final bits = _bitLength(_baseOrder);
  final mask = (BigInt.one << (bits - 1)) - BigInt.one;
  scalar &= mask;
  return scalar;
}

class _EcPoint {
  const _EcPoint(this.x, this.y);

  final BigInt x;
  final BigInt y;
}

const _curveDegree = 163;
final _fieldPolynomial =
    (BigInt.one << 163) |
    (BigInt.one << 7) |
    (BigInt.one << 6) |
    (BigInt.one << 3) |
    BigInt.one;
final _curveB = _littleEndianToBigInt(
  Uint8List.fromList([
    0xfd, 0x05, 0x32, 0x4a, 0x74, 0x78, 0x2f, 0x51,
    0x10, 0xeb, 0x81, 0x14, 0xca, 0x53, 0xc9, 0xb8,
    0x07, 0x19, 0x60, 0x0a, 0x02, 0x00, 0x00, 0x00,
  ]),
);
final _baseOrder = _littleEndianToBigInt(
  Uint8List.fromList([
    0x33, 0x4c, 0x23, 0xa4, 0x12, 0x0c, 0xe7, 0x77,
    0xfe, 0x92, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00,
  ]),
);
final _basePoint = _EcPoint(
  _littleEndianToBigInt(
    Uint8List.fromList([
      0x36, 0x3e, 0x34, 0xe8, 0x37, 0x46, 0x99, 0xd4,
      0x68, 0x11, 0x99, 0xa0, 0x7e, 0xd5, 0xa2, 0x86,
      0x62, 0xa1, 0xeb, 0xf0, 0x03, 0x00, 0x00, 0x00,
    ]),
  ),
  _littleEndianToBigInt(
    Uint8List.fromList([
      0xf1, 0x24, 0x73, 0x79, 0x0c, 0x5c, 0x1c, 0xb1,
      0x45, 0xd5, 0xcd, 0xa2, 0x4f, 0x09, 0xa0, 0x71,
      0x6c, 0xbc, 0x1f, 0xd5, 0x00, 0x00, 0x00, 0x00,
    ]),
  ),
);

_EcPoint? _pointMultiply(_EcPoint point, BigInt scalar) {
  _EcPoint? result;
  _EcPoint? addend = point;
  var current = scalar;
  while (current > BigInt.zero) {
    if (current.isOdd) {
      result = _pointAdd(result, addend);
    }
    current >>= 1;
    if (current > BigInt.zero && addend != null) {
      addend = _pointDouble(addend);
    }
  }
  return result;
}

_EcPoint? _pointAdd(_EcPoint? p, _EcPoint? q) {
  if (p == null) return q;
  if (q == null) return p;
  if (p.x == q.x) {
    if (p.y == q.y) return _pointDouble(p);
    return null;
  }
  final lambda = _gfMul(_gfAdd(p.y, q.y), _gfInv(_gfAdd(p.x, q.x)));
  final x3 = _gfAdd(_gfAdd(_gfAdd(_gfSquare(lambda), lambda), p.x), q.x);
  final x3a = _gfAdd(x3, BigInt.one);
  final y3 = _gfAdd(_gfAdd(_gfMul(lambda, _gfAdd(p.x, x3a)), x3a), p.y);
  return _EcPoint(x3a, y3);
}

_EcPoint? _pointDouble(_EcPoint p) {
  if (p.x == BigInt.zero) return null;
  final lambda = _gfAdd(_gfMul(p.y, _gfInv(p.x)), p.x);
  final x3 = _gfAdd(_gfAdd(_gfSquare(lambda), lambda), BigInt.one);
  final y3 = _gfAdd(_gfSquare(p.x), _gfMul(_gfAdd(lambda, BigInt.one), x3));
  return _EcPoint(x3, y3);
}

bool _isOnCurve(_EcPoint p) {
  if (p.x == BigInt.zero && p.y == BigInt.zero) return false;
  final left = _gfAdd(_gfSquare(p.y), _gfMul(p.x, p.y));
  final right = _gfAdd(
    _gfAdd(_gfMul(_gfSquare(p.x), p.x), _gfSquare(p.x)),
    _curveB,
  );
  return left == right;
}

BigInt _gfAdd(BigInt a, BigInt b) => a ^ b;

BigInt _gfSquare(BigInt value) => _gfMul(value, value);

BigInt _gfMul(BigInt a, BigInt b) {
  var result = BigInt.zero;
  var left = a;
  var right = b;
  while (right > BigInt.zero) {
    if (right.isOdd) result ^= left;
    right >>= 1;
    left <<= 1;
  }
  return _gfReduce(result);
}

BigInt _gfInv(BigInt value) {
  if (value == BigInt.zero) {
    throw ArgumentError('Cannot invert zero in ZeppOS B-163 field');
  }
  var u = _gfReduce(value);
  var v = _fieldPolynomial;
  var g1 = BigInt.one;
  var g2 = BigInt.zero;
  while (u != BigInt.one) {
    var shift = _bitLength(u) - _bitLength(v);
    if (shift < 0) {
      final oldU = u;
      u = v;
      v = oldU;
      final oldG = g1;
      g1 = g2;
      g2 = oldG;
      shift = -shift;
    }
    u ^= v << shift;
    g1 ^= g2 << shift;
  }
  return _gfReduce(g1);
}

BigInt _gfReduce(BigInt value) {
  var result = value;
  while (_bitLength(result) > _curveDegree) {
    final shift = _bitLength(result) - _curveDegree - 1;
    result ^= _fieldPolynomial << shift;
  }
  return result;
}

BigInt _littleEndianToBigInt(Uint8List bytes) {
  var result = BigInt.zero;
  for (var i = bytes.length - 1; i >= 0; i -= 1) {
    result = (result << 8) | BigInt.from(bytes[i]);
  }
  return result;
}

int _bitLength(BigInt value) => value == BigInt.zero ? 0 : value.bitLength;

Uint8List _bigIntToLittleEndian(BigInt value, int length) {
  final output = Uint8List(length);
  var current = value;
  for (var i = 0; i < length; i += 1) {
    output[i] = (current & BigInt.from(0xff)).toInt();
    current >>= 8;
  }
  return output;
}

int _uint32Le(Uint8List bytes, int offset) =>
    bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24);
