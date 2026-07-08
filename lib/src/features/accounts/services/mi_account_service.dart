import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/core/network/dio_provider.dart';
import 'package:zerobox/src/features/accounts/models/mi_account_models.dart';

class MiAccountService {
  MiAccountService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const _sdkVersion = 'accountsdk-18.8.15';
  static const _healthSid = 'miothealth';
  static const _serviceLoginUrl =
      'https://account.xiaomi.com/pass/serviceLogin?sid=$_healthSid&_json=true';
  static const _serviceLoginAuthUrl =
      'https://account.xiaomi.com/pass/serviceLoginAuth2';
  static const _deviceListUrl =
      'https://hlth.io.mi.com/app/v1/source/get_source_list';

  static const defaultUserAgent =
      'Mozilla/5.0 (Linux; Android 13; ZeroBox) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36';

  Future<MiAccountToken> login({
    required String username,
    required String password,
    String userAgent = defaultUserAgent,
  }) async {
    final deviceId = _randomDeviceId();
    final cookieJar = _CookieJar()
      ..set('sdkVersion', _sdkVersion)
      ..set('deviceId', deviceId);

    final step1 = await _dio.get<String>(
      _serviceLoginUrl,
      options: _requestOptions(userAgent, cookieJar),
    );
    cookieJar.mergeSetCookie(step1.headers);

    final step1Body = _decodeJsonBody(step1.data);
    final sign = step1Body['_sign']?.toString();
    if (sign == null || sign.isEmpty) {
      return _finishLogin(
        step1Body,
        userAgent: userAgent,
        deviceId: deviceId,
        cookieJar: cookieJar,
      );
    }

    final passwordHash = md5
        .convert(utf8.encode(password))
        .toString()
        .toUpperCase();
    final form = <String, String>{
      'sid': _healthSid,
      'hash': passwordHash,
      'callback': 'https://sts-hlth.io.mi.com/healthapp/sts',
      'qs': '%3Fsid%3Dmiothealth%26_json%3Dtrue',
      'user': username,
      '_sign': sign,
      '_json': 'true',
    };

    final step2 = await _dio.post<String>(
      _serviceLoginAuthUrl,
      data: form,
      options: _requestOptions(userAgent, cookieJar),
    );
    cookieJar.mergeSetCookie(step2.headers);

    final step2Body = _decodeJsonBody(step2.data);
    if ((step2Body['_sign']?.toString() ?? '').isNotEmpty) {
      throw StateError('Xiaomi account login returned another credential step');
    }
    return _finishLogin(
      step2Body,
      userAgent: userAgent,
      deviceId: deviceId,
      cookieJar: cookieJar,
    );
  }

  Future<List<MiCloudDevice>> fetchBoundDevices({
    required MiAccountToken token,
    String userAgent = defaultUserAgent,
  }) async {
    final body = await _miServiceCallEncrypted(
      token: token,
      url: _deviceListUrl,
      paramsPlain: const {'data': '{"page_size":50,"status":1}'},
      userAgent: userAgent,
    );

    final payload = jsonDecode(body) as Map<String, dynamic>;
    final code = _parseCode(payload);
    if (code != 0 && code != 200) {
      throw StateError(
        'Xiaomi device list failed: code=$code, message=${payload['message'] ?? payload['msg'] ?? ''}',
      );
    }
    final result =
        (payload['result'] as Map?)?.cast<String, dynamic>() ??
        const <String, dynamic>{};
    final list = (result['list'] as List?) ?? const [];
    return list
        .whereType<Map>()
        .map((item) => MiCloudDevice.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  Future<MiAccountToken> completeTwoFactorLogin({
    required MiAccountTwoFactorRequired challenge,
    required String cookieHeader,
    String userAgent = defaultUserAgent,
  }) async {
    final deviceId =
        _extractCookieValue(cookieHeader, 'deviceId') ?? challenge.deviceId;
    final cookieJar = _CookieJar()
      ..set('sdkVersion', _sdkVersion)
      ..set('deviceId', deviceId)
      ..mergeCookieHeader(cookieHeader);

    Map<String, dynamic>? lastCredentialStepBody;
    for (var attempt = 0; attempt < 3; attempt += 1) {
      if (attempt > 0) {
        await Future<void>.delayed(Duration(milliseconds: 700 * attempt));
      }

      final step1 = await _dio.get<String>(
        _serviceLoginUrl,
        options: _requestOptions(userAgent, cookieJar),
      );
      cookieJar.mergeSetCookie(step1.headers);

      final body = _fillAuthResponseFromHeaders(
        _decodeJsonBody(step1.data),
        step1.headers,
      );
      if ((body['_sign']?.toString() ?? '').isNotEmpty) {
        lastCredentialStepBody = body;
        continue;
      }

      final notificationUrl = body['notificationUrl']?.toString();
      if (notificationUrl != null && notificationUrl.trim().isNotEmpty) {
        throw MiAccountTwoFactorRequired(
          url: notificationUrl,
          deviceId: deviceId,
        );
      }

      return _finishLogin(
        body,
        userAgent: userAgent,
        deviceId: deviceId,
        cookieJar: cookieJar,
      );
    }
    throw StateError(
      'Verified Xiaomi 2FA session still requires account credentials'
      '${lastCredentialStepBody == null ? '' : ' after retry'}',
    );
  }

  Future<MiAccountToken> _finishLogin(
    Map<String, dynamic> authResp, {
    required String userAgent,
    required String deviceId,
    required _CookieJar cookieJar,
  }) async {
    final code = _parseCode(authResp);
    final ssecurity = authResp['ssecurity']?.toString() ?? '';
    final notificationUrl = authResp['notificationUrl']?.toString();
    if (notificationUrl != null && notificationUrl.trim().isNotEmpty) {
      throw MiAccountTwoFactorRequired(
        url: notificationUrl,
        deviceId: deviceId,
      );
    }
    if (code != 0 || ssecurity.isEmpty) {
      if (code == 70016) {
        throw StateError('Xiaomi account username or password is incorrect');
      }
      throw StateError(
        'Xiaomi account login failed: code=$code, description=${authResp['description'] ?? authResp['desc'] ?? ''}',
      );
    }

    final location = authResp['location']?.toString() ?? '';
    if (location.isEmpty) {
      throw StateError('Xiaomi account login response is missing STS location');
    }

    final step3 = await _dio.get<String>(
      location,
      options: _requestOptions(userAgent, cookieJar),
    );
    cookieJar.mergeSetCookie(step3.headers);
    final serviceToken =
        cookieJar.value('serviceToken') ??
        _extractHeaderCookie(step3.headers, 'serviceToken');
    if (serviceToken == null || serviceToken.isEmpty) {
      throw StateError('Xiaomi account login did not return serviceToken');
    }

    return MiAccountToken(
      userId: authResp['userId']?.toString() ?? '',
      deviceId: deviceId,
      ssecurity: ssecurity,
      serviceToken: serviceToken,
      cUserId:
          cookieJar.value('cUserId') ?? authResp['cUserId']?.toString() ?? '',
      passToken:
          cookieJar.value('passToken') ??
          authResp['passToken']?.toString() ??
          '',
      psecurity: authResp['psecurity']?.toString() ?? '',
    );
  }

  Future<String> _miServiceCallEncrypted({
    required MiAccountToken token,
    required String url,
    required Map<String, String> paramsPlain,
    required String userAgent,
  }) async {
    final nonce = _generateNonce(DateTime.now().millisecondsSinceEpoch);
    final signedNonce = _calcSignedNonce(token.ssecurity, nonce);

    final signedParams = Map<String, String>.from(paramsPlain);
    signedParams['rc4_hash__'] = _generateEncSignature(
      path: Uri.parse(url).path,
      method: 'POST',
      signedNonce: signedNonce,
      params: paramsPlain,
    );

    final encryptedParams = _rc4EncryptParams(signedNonce, signedParams);
    encryptedParams['signature'] = _generateEncSignature(
      path: Uri.parse(url).path,
      method: 'POST',
      signedNonce: signedNonce,
      params: encryptedParams,
    );
    encryptedParams['_nonce'] = nonce;

    final cookieParts = <String>[
      'sdkVersion=$_sdkVersion',
      'locale=en_us',
      if (token.deviceId.isNotEmpty) 'deviceId=${token.deviceId}',
      if (token.userId.isNotEmpty) 'userId=${token.userId}',
      if (token.cUserId.isNotEmpty) 'cUserId=${token.cUserId}',
      'serviceToken=${token.serviceToken}',
    ];

    final response = await _dio.post<String>(
      url,
      data: encryptedParams,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.plain,
        headers: {
          'User-Agent': userAgent,
          'region_tag': 'cn',
          'HandleParams': 'true',
          'Cookie': cookieParts.join('; '),
        },
      ),
    );

    final raw = (response.data ?? '').trim();
    if (raw.isEmpty) return raw;
    final encoded = raw.startsWith('"') && raw.endsWith('"')
        ? raw.substring(1, raw.length - 1)
        : raw;
    final encrypted = base64.decode(encoded);
    final decrypted = _rc4Crypt(base64.decode(signedNonce), encrypted);
    return utf8.decode(decrypted);
  }

  Options _requestOptions(String userAgent, _CookieJar cookieJar) {
    return Options(
      contentType: Headers.formUrlEncodedContentType,
      responseType: ResponseType.plain,
      headers: {'User-Agent': userAgent, 'Cookie': cookieJar.header},
    );
  }

  Map<String, dynamic> _decodeJsonBody(String? body) {
    const prefix = '&&&START&&&';
    final text = (body ?? '').trim();
    final stripped = text.startsWith(prefix)
        ? text.substring(prefix.length)
        : text;
    return jsonDecode(stripped) as Map<String, dynamic>;
  }

  Map<String, dynamic> _fillAuthResponseFromHeaders(
    Map<String, dynamic> body,
    Headers headers,
  ) {
    final filled = Map<String, dynamic>.from(body);
    for (final key in ['passToken', 'cUserId', 'userId']) {
      filled.putIfAbsent(key, () => _extractHeaderCookie(headers, key));
    }

    final extensionPragma =
        _headerValue(headers, 'extension-pragma') ??
        _headerValue(headers, 'Extension-Pragma');
    if (extensionPragma != null && extensionPragma.isNotEmpty) {
      try {
        final extension = jsonDecode(extensionPragma) as Map<String, dynamic>;
        for (final key in ['ssecurity', 'psecurity', 'nonce']) {
          final value = extension[key];
          if ((filled[key]?.toString() ?? '').isEmpty && value != null) {
            filled[key] = value;
          }
        }
      } catch (_) {
        // Xiaomi sometimes omits this header; malformed values should not hide
        // the primary account response.
      }
    }
    return filled;
  }

  String? _headerValue(Headers headers, String name) {
    final values = headers.map[name] ?? headers.map[name.toLowerCase()];
    return values?.firstOrNull?.trim();
  }

  int _parseCode(Map<String, dynamic> value) {
    final raw = value['code'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? -1;
  }

  String _generateNonce(int millis) {
    final random = Random.secure();
    final bytes = BytesBuilder();
    bytes.add(List<int>.generate(8, (_) => random.nextInt(256)));
    final minutes = millis ~/ 60000;
    bytes.add([
      (minutes >> 24) & 0xff,
      (minutes >> 16) & 0xff,
      (minutes >> 8) & 0xff,
      minutes & 0xff,
    ]);
    return base64.encode(bytes.toBytes());
  }

  String _calcSignedNonce(String ssecurity, String nonce) {
    final bytes = BytesBuilder()
      ..add(base64.decode(ssecurity))
      ..add(base64.decode(nonce));
    return base64.encode(sha256.convert(bytes.toBytes()).bytes);
  }

  String _generateEncSignature({
    required String path,
    required String method,
    required String signedNonce,
    required Map<String, String> params,
  }) {
    final keys = params.keys.toList()..sort();
    final pieces = <String>[
      method.toUpperCase(),
      path,
      for (final key in keys) '$key=${params[key]}',
      signedNonce,
    ];
    return base64.encode(sha1.convert(utf8.encode(pieces.join('&'))).bytes);
  }

  Map<String, String> _rc4EncryptParams(
    String signedNonce,
    Map<String, String> paramsPlain,
  ) {
    final key = base64.decode(signedNonce);
    final keys = paramsPlain.keys.toList()..sort();
    final cipher = _Rc4(key)..drop(1024);
    return {
      for (final keyName in keys)
        keyName: base64.encode(
          cipher.crypt(utf8.encode(paramsPlain[keyName]!)),
        ),
    };
  }

  Uint8List _rc4Crypt(List<int> key, List<int> data) {
    final cipher = _Rc4(key)..drop(1024);
    return cipher.crypt(data);
  }

  String _randomDeviceId() {
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    final random = Random.secure();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  String? _extractHeaderCookie(Headers headers, String name) {
    final setCookie = headers.map['set-cookie'] ?? const <String>[];
    for (final cookie in setCookie) {
      final value = _parseCookiePair(cookie, name);
      if (value != null) return value;
    }
    return null;
  }

  String? _extractCookieValue(String cookieHeader, String name) {
    for (final rawPair in cookieHeader.split(';')) {
      final pair = rawPair.trim();
      final index = pair.indexOf('=');
      if (index <= 0) continue;
      if (pair.substring(0, index).trim() == name) {
        return pair.substring(index + 1).trim();
      }
    }
    return null;
  }
}

class _CookieJar {
  final _values = <String, String>{};

  String get header =>
      _values.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');

  String? value(String key) => _values[key];

  void set(String key, String value) {
    if (key.isNotEmpty && value.isNotEmpty) {
      _values[key] = value;
    }
  }

  void mergeSetCookie(Headers headers) {
    final setCookie = headers.map['set-cookie'] ?? const <String>[];
    for (final cookie in setCookie) {
      final pair = cookie.split(';').first.trim();
      final index = pair.indexOf('=');
      if (index <= 0) continue;
      set(pair.substring(0, index).trim(), pair.substring(index + 1).trim());
    }
  }

  void mergeCookieHeader(String cookieHeader) {
    for (final rawPair in cookieHeader.split(';')) {
      final pair = rawPair.trim();
      final index = pair.indexOf('=');
      if (index <= 0) continue;
      set(pair.substring(0, index).trim(), pair.substring(index + 1).trim());
    }
  }
}

String? _parseCookiePair(String cookie, String name) {
  final pair = cookie.split(';').first.trim();
  final index = pair.indexOf('=');
  if (index <= 0) return null;
  final cookieName = pair.substring(0, index).trim();
  if (cookieName != name && !cookieName.endsWith('_$name')) return null;
  return pair.substring(index + 1).trim();
}

class _Rc4 {
  _Rc4(List<int> key) {
    for (var n = 0; n < 256; n++) {
      _s[n] = n;
    }
    var j = 0;
    for (var n = 0; n < 256; n++) {
      j = (j + _s[n] + key[n % key.length]) & 0xff;
      final tmp = _s[n];
      _s[n] = _s[j];
      _s[j] = tmp;
    }
  }

  final _s = Uint8List(256);
  var _i = 0;
  var _j = 0;

  void drop(int count) {
    for (var n = 0; n < count; n++) {
      _next();
    }
  }

  Uint8List crypt(List<int> data) {
    final out = Uint8List(data.length);
    for (var n = 0; n < data.length; n++) {
      out[n] = data[n] ^ _next();
    }
    return out;
  }

  int _next() {
    _i = (_i + 1) & 0xff;
    _j = (_j + _s[_i]) & 0xff;
    final tmp = _s[_i];
    _s[_i] = _s[_j];
    _s[_j] = tmp;
    return _s[(_s[_i] + _s[_j]) & 0xff];
  }
}

final miAccountServiceProvider = Provider<MiAccountService>((ref) {
  return MiAccountService(dio: ref.read(appDioProvider));
});
