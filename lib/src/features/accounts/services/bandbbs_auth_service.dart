import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/services/build_info_service.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';

const _brokerBaseUrl = 'https://auth.zxor.org';
const _clientAppId = 'zerobox';
const _callbackUri = 'zerobox://oauth/bandbbs';

class BandBbsToken {
  const BandBbsToken({
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.expiresAt,
    required this.scope,
  });

  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final DateTime expiresAt;
  final String scope;

  bool get isExpired => DateTime.now().toUtc().isAfter(
    expiresAt.subtract(const Duration(minutes: 2)),
  );

  Map<String, Object?> toJson() => {
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'token_type': tokenType,
    'expires_at': expiresAt.toIso8601String(),
    'scope': scope,
  };

  static BandBbsToken fromTokenResponse(Map<String, Object?> json) {
    final expiresIn = _asInt(json['expires_in']);
    return BandBbsToken(
      accessToken: json['access_token']?.toString() ?? '',
      refreshToken: json['refresh_token']?.toString() ?? '',
      tokenType: json['token_type']?.toString() ?? 'bearer',
      expiresAt: DateTime.now().toUtc().add(Duration(seconds: expiresIn)),
      scope: json['scope']?.toString() ?? '',
    );
  }

  static BandBbsToken? fromJson(Map<String, Object?> json) {
    final accessToken = json['access_token']?.toString() ?? '';
    final refreshToken = json['refresh_token']?.toString() ?? '';
    final expiresAtRaw = json['expires_at']?.toString() ?? '';
    final expiresAt = DateTime.tryParse(expiresAtRaw);
    if (accessToken.isEmpty || refreshToken.isEmpty || expiresAt == null) {
      return null;
    }
    return BandBbsToken(
      accessToken: accessToken,
      refreshToken: refreshToken,
      tokenType: json['token_type']?.toString() ?? 'bearer',
      expiresAt: expiresAt.toUtc(),
      scope: json['scope']?.toString() ?? '',
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class BandBbsAuthState {
  const BandBbsAuthState({
    required this.token,
    required this.userId,
    required this.isBusy,
    required this.lastError,
  });

  final BandBbsToken? token;
  final String? userId;
  final bool isBusy;
  final String? lastError;

  bool get isSignedIn => token != null;

  BandBbsAuthState copyWith({
    BandBbsToken? token,
    bool clearToken = false,
    String? userId,
    bool clearUserId = false,
    bool? isBusy,
    String? lastError,
    bool clearLastError = false,
  }) {
    return BandBbsAuthState(
      token: clearToken ? null : token ?? this.token,
      userId: clearUserId ? null : userId ?? this.userId,
      isBusy: isBusy ?? this.isBusy,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
  }

  static const empty = BandBbsAuthState(
    token: null,
    userId: null,
    isBusy: false,
    lastError: null,
  );
}

class BandBbsAuthNotifier extends Notifier<BandBbsAuthState> {
  static const _keyToken = 'bandbbs.oauth.token';
  static const _keyUserId = 'bandbbs.oauth.user_id';

  final Logger _log = getLogger('BandBbsAuthService');

  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: _brokerBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  @override
  BandBbsAuthState build() {
    final prefs = SharedPrefsService.instance;
    final tokenRaw = prefs.getString(_keyToken);
    BandBbsToken? token;
    if (tokenRaw != null) {
      try {
        final decoded = jsonDecode(tokenRaw);
        if (decoded is Map<String, Object?>) {
          token = BandBbsToken.fromJson(decoded);
        } else if (decoded is Map) {
          token = BandBbsToken.fromJson(decoded.cast<String, Object?>());
        }
      } catch (_) {
        token = null;
      }
    }
    return BandBbsAuthState.empty.copyWith(
      token: token,
      userId: prefs.getString(_keyUserId),
    );
  }

  Future<void> startLogin() async {
    state = state.copyWith(isBusy: true, clearLastError: true);
    try {
      final uri = Uri.parse('$_brokerBaseUrl/oauth2/bandbbs/start').replace(
        queryParameters: {
          'app_id': _clientAppId,
          'app_version': BuildInfoService.appVersion,
          'app_build': await BuildInfoService.resolveCommitHash(),
          'platform': _platformName(),
          'return_uri': _callbackUri,
        },
      );
      _log.info(
        'BandBBS OAuth start request\n'
        'method=GET\n'
        'url=$uri\n'
        'headers=null\n'
        'query=${_formatBody(uri.queryParameters)}\n'
        'body=null',
      );
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError('failed to open BandBBS OAuth page');
      }
      state = state.copyWith(isBusy: false);
    } catch (e) {
      state = state.copyWith(isBusy: false, lastError: e.toString());
      rethrow;
    }
  }

  Future<bool> handleCallback(Uri uri) async {
    if (uri.scheme != 'zerobox' ||
        uri.host != 'oauth' ||
        uri.path != '/bandbbs') {
      return false;
    }
    final ticket = uri.queryParameters['ticket']?.trim() ?? '';
    if (ticket.isEmpty) {
      final error = uri.queryParameters['error']?.trim();
      state = state.copyWith(
        isBusy: false,
        lastError: error?.isNotEmpty == true ? error : 'missing ticket',
      );
      return true;
    }
    await exchangeTicket(ticket);
    return true;
  }

  Future<void> exchangeTicket(String ticket) async {
    state = state.copyWith(isBusy: true, clearLastError: true);
    try {
      final response = await _send<Object?>(
        () async => _dio.post<Object?>(
          '/api/oauth/bandbbs/exchange',
          data: {'ticket': ticket},
          options: Options(headers: await _clientHeaders()),
        ),
      );
      final token = BandBbsToken.fromTokenResponse(_objectMap(response.data));
      await _saveToken(token);
      state = state.copyWith(token: token, isBusy: false, clearLastError: true);
      await _fetchTokenInfo(token);
    } catch (e) {
      state = state.copyWith(isBusy: false, lastError: e.toString());
      rethrow;
    }
  }

  Future<BandBbsToken?> refreshIfNeeded() async {
    final token = state.token;
    if (token == null) return null;
    if (!token.isExpired) return token;
    return refresh();
  }

  Future<BandBbsToken> refresh() async {
    final oldToken = state.token;
    if (oldToken == null) {
      throw StateError('BandBBS account is not signed in');
    }
    final response = await _send<Object?>(
      () async => _dio.post<Object?>(
        '/api/oauth/bandbbs/refresh',
        data: {'refresh_token': oldToken.refreshToken},
        options: Options(headers: await _clientHeaders()),
      ),
    );
    final token = BandBbsToken.fromTokenResponse(_objectMap(response.data));
    await _saveToken(token);
    state = state.copyWith(token: token, clearLastError: true);
    await _fetchTokenInfo(token);
    return token;
  }

  Future<void> signOut() async {
    final prefs = SharedPrefsService.instance;
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUserId);
    state = BandBbsAuthState.empty;
  }

  Future<Map<String, String>> _clientHeaders() async {
    return {
      'X-ZeroBox-App-Id': _clientAppId,
      'X-ZeroBox-Version': BuildInfoService.appVersion,
      'X-ZeroBox-Build': await BuildInfoService.resolveCommitHash(),
      'X-ZeroBox-Platform': _platformName(),
    };
  }

  Future<void> _saveToken(BandBbsToken token) async {
    await SharedPrefsService.instance.setString(
      _keyToken,
      jsonEncode(token.toJson()),
    );
  }

  Future<void> _fetchTokenInfo(BandBbsToken token) async {
    try {
      final response = await _send<Object?>(
        () async => Dio().get<Object?>(
          'https://www.bandbbs.cn/api/oauth2/token',
          queryParameters: {'token': token.accessToken},
        ),
      );
      final userId = _objectMap(response.data)['user_id']?.toString();
      if (userId == null || userId.isEmpty) return;
      await SharedPrefsService.instance.setString(_keyUserId, userId);
      state = state.copyWith(userId: userId);
    } catch (_) {
      // User info is only for display. Token exchange success is enough here.
    }
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  Map<String, Object?> _objectMap(Object? data) {
    if (data is Map<String, Object?>) return data;
    if (data is Map) return data.cast<String, Object?>();
    return const {};
  }

  Future<Response<T>> _send<T>(Future<Response<T>> Function() request) async {
    try {
      final response = await request();
      _logResponse(response);
      return response;
    } on DioException catch (e, st) {
      _logDioException(e, st);
      rethrow;
    } catch (e, st) {
      _log.severe('BandBBS OAuth request failed before Dio response', e, st);
      rethrow;
    }
  }

  void _logResponse(Response<Object?> response) {
    final request = response.requestOptions;
    _log.info(
      'BandBBS OAuth request\n'
      'method=${request.method}\n'
      'url=${request.uri}\n'
      'headers=${_formatBody(request.headers)}\n'
      'query=${_formatBody(request.queryParameters)}\n'
      'body=${_formatBody(request.data)}\n'
      'BandBBS OAuth response\n'
      'status=${response.statusCode}\n'
      'headers=${_formatBody(response.headers.map)}\n'
      'body=${_formatBody(response.data)}',
    );
  }

  void _logDioException(DioException error, StackTrace stackTrace) {
    final request = error.requestOptions;
    final response = error.response;
    _log.severe(
      'BandBBS OAuth request failed\n'
      'method=${request.method}\n'
      'url=${request.uri}\n'
      'headers=${_formatBody(request.headers)}\n'
      'query=${_formatBody(request.queryParameters)}\n'
      'body=${_formatBody(request.data)}\n'
      'response_status=${response?.statusCode}\n'
      'response_headers=${_formatBody(response?.headers.map)}\n'
      'response_body=${_formatBody(response?.data)}',
      error,
      stackTrace,
    );
  }

  String _formatBody(Object? value) {
    if (value == null) return 'null';
    if (value is List<int>) return '<bytes length=${value.length}>';
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }
}

final bandBbsAuthProvider =
    NotifierProvider<BandBbsAuthNotifier, BandBbsAuthState>(
      BandBbsAuthNotifier.new,
    );
