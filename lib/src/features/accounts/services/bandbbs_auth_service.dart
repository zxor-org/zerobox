import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/services/build_info_service.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';

const _brokerBaseUrl = 'https://zb-api.zxor.org';
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
    final expiresAtRaw = json['expires_at']?.toString() ?? '';
    final expiresAt = DateTime.tryParse(expiresAtRaw);
    if (accessToken.isEmpty || expiresAt == null) {
      return null;
    }
    return BandBbsToken(
      accessToken: accessToken,
      refreshToken: json['refresh_token']?.toString() ?? '',
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
    required this.session,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.isBusy,
    required this.lastError,
  });

  /// BandBBS API token for bandbbs.cn requests.
  final BandBbsToken? token;
  /// ZeroBox session token for zb-api.zxor.org requests.
  final BandBbsToken? session;
  final String? userId;
  final String? username;
  final String? avatarUrl;
  final bool isBusy;
  final String? lastError;

  bool get isSignedIn => token != null;

  BandBbsAuthState copyWith({
    BandBbsToken? token,
    bool clearToken = false,
    BandBbsToken? session,
    bool clearSession = false,
    String? userId,
    bool clearUserId = false,
    String? username,
    bool clearUsername = false,
    String? avatarUrl,
    bool clearAvatarUrl = false,
    bool? isBusy,
    String? lastError,
    bool clearLastError = false,
  }) {
    return BandBbsAuthState(
      token: clearToken ? null : token ?? this.token,
      session: clearSession ? null : session ?? this.session,
      userId: clearUserId ? null : userId ?? this.userId,
      username: clearUsername ? null : username ?? this.username,
      avatarUrl: clearAvatarUrl ? null : avatarUrl ?? this.avatarUrl,
      isBusy: isBusy ?? this.isBusy,
      lastError: clearLastError ? null : lastError ?? this.lastError,
    );
  }

  static const empty = BandBbsAuthState(
    token: null,
    session: null,
    userId: null,
    username: null,
    avatarUrl: null,
    isBusy: false,
    lastError: null,
  );
}

class BandBbsAuthNotifier extends Notifier<BandBbsAuthState> {
  static const _keyToken = 'bandbbs.oauth.token';
  static const _keySession = 'bandbbs.oauth.session';
  static const _keyUserId = 'bandbbs.oauth.user_id';
  static const _keyUsername = 'bandbbs.oauth.username';
  static const _keyAvatarUrl = 'bandbbs.oauth.avatar_url';

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
    BandBbsToken? token = _loadToken(prefs, _keyToken);
    BandBbsToken? session = _loadToken(prefs, _keySession);
    final initial = BandBbsAuthState.empty.copyWith(
      token: token,
      session: session,
      userId: prefs.getString(_keyUserId),
      username: prefs.getString(_keyUsername),
      avatarUrl: prefs.getString(_keyAvatarUrl),
    );
    final restoredToken = token;
    if (restoredToken != null && initial.username == null) {
      Future.microtask(() => _fetchTokenInfo(restoredToken));
    }
    return initial;
  }

  BandBbsToken? _loadToken(SharedPrefsService prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, Object?>) return BandBbsToken.fromJson(decoded);
      if (decoded is Map) return BandBbsToken.fromJson(decoded.cast<String, Object?>());
    } catch (_) {}
    return null;
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
        'BandBBS OAuth start method=GET endpoint=${_endpoint(uri)} '
        'platform=${_platformName()} appVersion=${BuildInfoService.appVersion}',
      );
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    if (uri.scheme != 'zerobox' || uri.host != 'oauth' || uri.path != '/bandbbs') {
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
      final root = _objectMap(response.data);
      // Top-level = ZeroBox session tokens.
      final session = BandBbsToken.fromTokenResponse(root);
      await SharedPrefsService.instance.setString(_keySession, jsonEncode(session.toJson()));
      // Nested bandbbs = actual BandBBS API token.
      final bandbbs = _objectMap(root['bandbbs']);
      final token = bandbbs.isNotEmpty
          ? BandBbsToken.fromTokenResponse(bandbbs)
          : session;
      await _saveToken(token);
      state = state.copyWith(token: token, session: session, isBusy: false, clearLastError: true);
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
    final oldSession = state.session;
    if (oldSession == null) {
      throw StateError('BandBBS account is not signed in');
    }
    // Step 1: refresh ZeroBox session.
    final sessionResp = await _send<Object?>(
      () async => _dio.post<Object?>(
        '/api/oauth/bandbbs/refresh',
        data: {'refresh_token': oldSession.refreshToken},
        options: Options(headers: await _clientHeaders()),
      ),
    );
    final newSession = BandBbsToken.fromTokenResponse(_objectMap(sessionResp.data));
    await SharedPrefsService.instance.setString(_keySession, jsonEncode(newSession.toJson()));
    state = state.copyWith(session: newSession, clearLastError: true);

    // Step 2: refresh BandBBS API token using the new session.
    final tokenResp = await _send<Object?>(
      () async => _dio.post<Object?>(
        '/api/oauth/bandbbs/token/refresh',
        options: Options(
          headers: {
            ...await _clientHeaders(),
            'Authorization': 'Bearer ${newSession.accessToken}',
          },
        ),
      ),
    );
    final newToken = BandBbsToken.fromTokenResponse(_objectMap(tokenResp.data));
    await _saveToken(newToken);
    state = state.copyWith(token: newToken, clearLastError: true);
    await _fetchTokenInfo(newToken);
    return newToken;
  }

  Future<void> signOut() async {
    final prefs = SharedPrefsService.instance;
    await prefs.remove(_keyToken);
    await prefs.remove(_keySession);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUsername);
    await prefs.remove(_keyAvatarUrl);
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
    await SharedPrefsService.instance.setString(_keyToken, jsonEncode(token.toJson()));
  }

  Future<void> _fetchTokenInfo(BandBbsToken token) async {
    final prefs = SharedPrefsService.instance;
    try {
      final response = await _send<Object?>(
        () async => Dio().get<Object?>(
          'https://www.bandbbs.cn/api/oauth2/token',
          queryParameters: {'token': token.accessToken},
        ),
      );
      final userId = _objectMap(response.data)['user_id']?.toString();
      if (userId != null && userId.isNotEmpty) {
        await prefs.setString(_keyUserId, userId);
        state = state.copyWith(userId: userId);
      }
    } catch (_) {}
    try {
      final response = await _send<Object?>(
        () async => Dio().get<Object?>(
          'https://www.bandbbs.cn/api/me',
          options: Options(
            headers: {'Authorization': 'Bearer ${token.accessToken}'},
          ),
        ),
      );
      final me = _objectMap(_objectMap(response.data)['me']);
      final username = me['username']?.toString() ?? '';
      final avatarUrl = _objectMap(me['avatar_urls'])['m']?.toString() ?? '';
      if (username.isNotEmpty) await prefs.setString(_keyUsername, username);
      if (avatarUrl.isNotEmpty) await prefs.setString(_keyAvatarUrl, avatarUrl);
      state = state.copyWith(
        username: username.isNotEmpty ? username : null,
        avatarUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
      );
    } catch (_) {}
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
    final summary = _responseSummary(request.uri.path, response.data);
    _log.info(
      'BandBBS OAuth request method=${request.method} '
      'endpoint=${_endpoint(request.uri)} status=${response.statusCode}'
      '${summary.isEmpty ? '' : ' $summary'}',
    );
  }

  void _logDioException(DioException error, StackTrace stackTrace) {
    final request = error.requestOptions;
    final response = error.response;
    _log.severe(
      'BandBBS OAuth request failed method=${request.method} '
      'endpoint=${_endpoint(request.uri)} status=${response?.statusCode} '
      'errorType=${error.type.name}',
      null,
      stackTrace,
    );
  }

  String _responseSummary(String path, Object? data) {
    final root = _objectMap(data);
    if (path == '/api/oauth2/token') {
      return _fields({
        'userId': root['user_id'],
        'expiresIn': root['expires_in'],
        'scopeCount': root['scope'] is Map ? (root['scope'] as Map).length : null,
      });
    }
    if (path == '/api/me') {
      final me = _objectMap(root['me']);
      return _fields({'userId': me['user_id'], 'username': me['username']});
    }
    if (path == '/api/oauth/bandbbs/exchange' ||
        path == '/api/oauth/bandbbs/refresh' ||
        path == '/api/oauth/bandbbs/token/refresh') {
      return _fields({
        'tokenType': root['token_type'],
        'expiresIn': root['expires_in'],
        'accessTokenReceived': root['access_token']?.toString().isNotEmpty == true,
        'refreshTokenReceived': root['refresh_token']?.toString().isNotEmpty == true,
      });
    }
    return '';
  }

  String _endpoint(Uri uri) => '${uri.scheme}://${uri.host}${uri.path}';

  String _fields(Map<String, Object?> values) => values.entries
      .where((entry) => entry.value != null)
      .map((entry) => '${entry.key}=${entry.value}')
      .join(' ');
}

final bandBbsAuthProvider =
    NotifierProvider<BandBbsAuthNotifier, BandBbsAuthState>(
      BandBbsAuthNotifier.new,
    );
