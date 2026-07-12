import 'package:dio/dio.dart';
import 'package:zerobox/src/features/accounts/services/huami_auth_service.dart';

class HuamiAppStoreApiClient {
  HuamiAppStoreApiClient({required Dio dio, required HuamiAuthNotifier auth})
    : _dio = dio,
      _auth = auth;

  final Dio _dio;
  final HuamiAuthNotifier _auth;

  static const _baseUrl = 'https://api.amazfit.com';
  static const _devicesUrl =
      'https://raw.githubusercontent.com/melianmiko/ZeppOS-DevicesList/refs/heads/main/zepp_devices.json';
  static const _entryType = 'lightapp';

  Future<List<HuamiStoreDevice>> getDevices() async {
    final response = await _dio.get<Object?>(_devicesUrl);
    final rows = response.data is List ? response.data as List : const [];
    return rows
        .whereType<Map>()
        .expand((row) => HuamiStoreDevice.fromJson(row.cast<String, Object?>()))
        .toList();
  }

  Future<List<Map<String, Object?>>> getPopularApps({
    required int deviceSource,
    required int page,
    required int perPage,
  }) async {
    final token = _requireToken();
    final response = await _dio.get<Object?>(
      '$_baseUrl/market/devices/$deviceSource/$_entryType/apps',
      queryParameters: {
        'page': page,
        ..._auth.storeQuery(token, perPage: perPage),
      },
      options: Options(headers: _auth.storeHeaders(token)),
    );
    final root = _objectMap(response.data);
    final data = root['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((entry) => entry.cast<String, Object?>())
        .toList();
  }

  Future<Map<String, Object?>> getAppDetail({
    required int deviceSource,
    required String appId,
  }) async {
    final token = _requireToken();
    final response = await _dio.get<Object?>(
      '$_baseUrl/market/devices/$deviceSource/$_entryType/apps/$appId',
      queryParameters: _auth.storeQuery(token)..remove('per_page'),
      options: Options(headers: _auth.storeHeaders(token)),
    );
    return _objectMap(response.data);
  }

  Future<Response<List<int>>> downloadFile(
    String url, {
    void Function(int received, int total)? onReceiveProgress,
  }) async {
    final token = _requireToken();
    return _dio.get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
        headers: _auth.storeHeaders(token),
      ),
      onReceiveProgress: onReceiveProgress,
    );
  }

  HuamiTokenInfo _requireToken() {
    final token = _auth.state.token;
    if (token == null || !token.isValid) {
      throw StateError('Huami account is not signed in');
    }
    return token;
  }

  Map<String, Object?> _objectMap(Object? value) {
    if (value is Map<String, Object?>) return value;
    if (value is Map) return value.cast<String, Object?>();
    return const {};
  }
}

class HuamiStoreDevice {
  const HuamiStoreDevice({
    required this.id,
    required this.name,
    required this.deviceSource,
    required this.osVersion,
    required this.appName,
  });

  final String id;
  final String name;
  final int deviceSource;
  final String osVersion;
  final String appName;

  bool get supportsLightApps => osVersion != 'legacy' && osVersion != 'mifit';

  static List<HuamiStoreDevice> fromJson(Map<String, Object?> json) {
    final sources = json['deviceSource'] is List
        ? json['deviceSource'] as List
        : const [];
    final name =
        json['shortDeviceName']?.toString() ??
        json['deviceName']?.toString() ??
        '';
    final osVersion = json['osVersion']?.toString() ?? '';
    final appName = json['application']?.toString() ?? HuamiAuthNotifier.zeppAppName;
    return [
      for (final source in sources)
        if (source is int || int.tryParse(source.toString()) != null)
          HuamiStoreDevice(
            id: json['id']?.toString() ?? '',
            name: name,
            deviceSource: source is int ? source : int.parse(source.toString()),
            osVersion: osVersion,
            appName: appName,
          ),
    ];
  }
}
