import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';

class HuamiTokenInfo {
  const HuamiTokenInfo({
    required this.appToken,
    required this.userId,
    required this.countryCode,
    required this.raw,
  });

  final String appToken;
  final String userId;
  final String countryCode;
  final Map<String, Object?> raw;

  bool get isValid => appToken.isNotEmpty && userId.isNotEmpty;

  Map<String, Object?> toJson() => {
    'app_token': appToken,
    'user_id': userId,
    'country_code': countryCode,
    'raw': raw,
  };

  static HuamiTokenInfo? fromJson(Map<String, Object?> json) {
    final appToken = json['app_token']?.toString() ?? '';
    final userId = json['user_id']?.toString() ?? '';
    if (appToken.isEmpty || userId.isEmpty) return null;
    return HuamiTokenInfo(
      appToken: appToken,
      userId: userId,
      countryCode:
          json['country_code']?.toString() ?? HuamiAuthNotifier.countryCode,
      raw: _objectMap(json['raw']),
    );
  }

  static HuamiTokenInfo fromLoginResponse(
    Map<String, Object?> tokenInfo, {
    required String countryCode,
  }) {
    return HuamiTokenInfo(
      appToken: tokenInfo['app_token']?.toString() ?? '',
      userId: tokenInfo['user_id']?.toString() ?? '',
      countryCode: countryCode,
      raw: tokenInfo,
    );
  }

  static Map<String, Object?> _objectMap(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) return value.cast<String, Object?>();
    return const {};
  }
}

class HuamiAuthState {
  const HuamiAuthState({
    required this.token,
    required this.username,
    required this.isBusy,
    required this.lastError,
  });

  final HuamiTokenInfo? token;
  final String? username;
  final bool isBusy;
  final String? lastError;

  bool get isSignedIn => token?.isValid == true;

  HuamiAuthState copyWith({
    HuamiTokenInfo? token,
    bool clearToken = false,
    String? username,
    bool clearUsername = false,
    bool? isBusy,
    String? lastError,
    bool clearLastError = false,
  }) {
    return HuamiAuthState(
      token: clearToken ? null : token ?? this.token,
      username: clearUsername ? null : username ?? this.username,
      isBusy: isBusy ?? this.isBusy,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
  }

  static const empty = HuamiAuthState(
    token: null,
    username: null,
    isBusy: false,
    lastError: null,
  );
}

class HuamiAuthNotifier extends Notifier<HuamiAuthState> {
  HuamiAuthNotifier({Dio? dio}) : _dio = dio ?? Dio();

  static const _keyToken = 'huami.account.token';
  static const _keyUsername = 'huami.account.username';

  static const countryCode = 'CN';
  static const appName = 'com.huami.zeppos.cli';
  static const zeppAppName = 'com.huami.midong';
  static const zeppVersion = '9.13.2-play_151705';
  static const zeppVersionIv = '151705_9.13.2-play';
  static const zeppUserAgent =
      'Zepp/9.13.2 (2203129G; Android 15; Density/2.75)';

  final Dio _dio;

  @override
  HuamiAuthState build() {
    final prefs = SharedPrefsService.instance;
    final raw = prefs.getString(_keyToken);
    HuamiTokenInfo? token;
    if (raw != null) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, Object?>) {
          token = HuamiTokenInfo.fromJson(decoded);
        } else if (decoded is Map) {
          token = HuamiTokenInfo.fromJson(decoded.cast<String, Object?>());
        }
      } catch (_) {
        token = null;
      }
    }
    return HuamiAuthState.empty.copyWith(
      token: token,
      username: prefs.getString(_keyUsername),
    );
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    state = state.copyWith(isBusy: true, clearLastError: true);
    try {
      final access = await _requestAccessToken(
        username: username,
        password: password,
      );
      final token = await _requestAppToken(access);
      await validateToken(token);
      await _saveToken(token, username: username);
      state = state.copyWith(
        token: token,
        username: username,
        isBusy: false,
        clearLastError: true,
      );
    } catch (e) {
      state = state.copyWith(isBusy: false, lastError: e.toString());
      rethrow;
    }
  }

  Future<void> validateToken(HuamiTokenInfo token) async {
    final response = await _dio.get<Object?>(
      'https://api.amazfit.com/apps/$zeppAppName/fileTypes/AGPS/files',
      options: Options(headers: storeHeaders(token)),
    );
    if ((response.statusCode ?? 0) < 200 || (response.statusCode ?? 0) >= 300) {
      throw StateError('Huami token validation failed');
    }
  }

  Map<String, String> storeHeaders(
    HuamiTokenInfo token, {
    String appname = zeppAppName,
  }) {
    return {
      'apptoken': token.appToken,
      'appplatform': 'android_phone',
      'Country': countryCode,
      'appname': appname,
      'cv': zeppVersionIv,
      'hm-privacy-diagnostics': 'false',
      'user-agent': zeppUserAgent,
    };
  }

  Map<String, Object?> storeQuery(
    HuamiTokenInfo token, {
    int apiLevel = 500,
    int perPage = 15,
  }) {
    return {
      'userid': token.userId,
      'user_country': countryCode,
      'api_level': apiLevel,
      'per_page': perPage,
    };
  }

  Future<void> signOut() async {
    final prefs = SharedPrefsService.instance;
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUsername);
    state = HuamiAuthState.empty;
  }

  Future<Map<String, Object?>> _requestAccessToken({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post<Object?>(
      'https://api-user.huami.com/registrations/${Uri.encodeComponent(username)}/tokens',
      data: {
        'client_id': 'HuaMi',
        'country_code': countryCode,
        'json_response': 'true',
        'name': username,
        'password': password,
        'redirect_uri':
            'https://s3-us-west-2.amazonaws.com/hm-registration/successsignin.html',
        'state': 'REDIRECTION',
        'token': 'access',
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        headers: {'app_name': appName},
      ),
    );
    final data = _objectMap(response.data);
    if ((data['access']?.toString() ?? '').isEmpty) {
      throw StateError('Huami login did not return an access token');
    }
    return data;
  }

  Future<HuamiTokenInfo> _requestAppToken(
    Map<String, Object?> access,
  ) async {
    final accessCode = access['access']?.toString() ?? '';
    final response = await _dio.post<Object?>(
      'https://account.huami.com/v2/client/login',
      data: {
        'allow_registration': 'false',
        'app_name': appName,
        'app_version': '4.3.0',
        'code': accessCode,
        'country_code': access['country_code']?.toString() ?? countryCode,
        'device_id': '02:00:00:00:00:00',
        'device_model': 'web',
        'dn':
            'account.huami.com,api-user.huami.com,auth.huami.com,api-mifit.huami.com,api-open.huami.com',
        'grant_type': 'access_token',
        'third_name': 'huami',
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );
    final root = _objectMap(response.data);
    final tokenInfo = _objectMap(root['token_info']);
    final token = HuamiTokenInfo.fromLoginResponse(
      tokenInfo,
      countryCode: access['country_code']?.toString() ?? countryCode,
    );
    if (!token.isValid) {
      throw StateError('Huami login did not return store credentials');
    }
    return token;
  }

  Future<void> _saveToken(
    HuamiTokenInfo token, {
    required String username,
  }) async {
    final prefs = SharedPrefsService.instance;
    await prefs.setString(_keyToken, jsonEncode(token.toJson()));
    await prefs.setString(_keyUsername, username);
  }

  Map<String, Object?> _objectMap(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) return value.cast<String, Object?>();
    return const {};
  }
}

final huamiAuthProvider =
    NotifierProvider<HuamiAuthNotifier, HuamiAuthState>(() {
      return HuamiAuthNotifier();
    });

final huamiStoreHeadersProvider = Provider<Map<String, String>?>((ref) {
  final auth = ref.watch(huamiAuthProvider);
  final token = auth.token;
  if (token == null || !token.isValid) return null;
  return ref.read(huamiAuthProvider.notifier).storeHeaders(token);
});
