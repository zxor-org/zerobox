import 'package:dio/dio.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/features/accounts/services/bandbbs_auth_service.dart';

class BandBbsApiClient {
  BandBbsApiClient({required this.dio, required this.auth});

  final Dio dio;
  final BandBbsAuthNotifier auth;
  final Logger _log = getLogger('BandBbsApiClient');

  static const _baseUrl = 'https://www.bandbbs.cn';
  static const _developerApiBaseUrl = 'https://api.bandbbs.cn';

  Future<Map<String, dynamic>> getResource(String resourceId) async {
    final response = await _send<Object?>(
      () async => dio.get<Object?>(
        '$_baseUrl/api/resources/$resourceId',
        options: await _authOptions(),
      ),
    );
    return _objectMap(response.data);
  }

  Future<Map<String, dynamic>> getResources({
    required int page,
    int? prefixId,
    String? type,
    String? order,
    String? direction,
  }) async {
    final queryParameters = {
      'page': page,
      if (prefixId != null) 'prefix_id': prefixId,
      if (type?.isNotEmpty == true) 'type': type,
      if (order?.isNotEmpty == true) 'order': order,
      if (direction?.isNotEmpty == true) 'direction': direction,
    };
    final response = await _send<Object?>(
      () async => dio.get<Object?>(
        '$_baseUrl/api/resources/',
        queryParameters: queryParameters,
        options: await _authOptions(),
      ),
    );
    return _objectMap(response.data);
  }

  Future<Map<String, dynamic>> searchResources({
    required String keywords,
    required int page,
    String? order,
    List<int>? categoryIds,
  }) async {
    final queryParameters = {
      'keywords': keywords,
      'page': page,
      if (order?.isNotEmpty == true) 'search_order': order,
      if (categoryIds != null && categoryIds.isNotEmpty)
        'categories[]': categoryIds,
    };
    final response = await _send<Object?>(
      () async => dio.get<Object?>(
        '$_baseUrl/api/resource-search/',
        queryParameters: queryParameters,
        options: await _authOptions(),
      ),
    );
    return _objectMap(response.data);
  }

  Future<Map<String, dynamic>> getCategoryResources({
    required int categoryId,
    required int page,
  }) async {
    final response = await _send<Object?>(
      () async => dio.get<Object?>(
        '$_baseUrl/api/resource-categories/$categoryId/resources',
        queryParameters: {'page': page},
        options: await _authOptions(),
      ),
    );
    return _objectMap(response.data);
  }

  Future<Map<String, dynamic>> getFlattenedCategories() async {
    final response = await _send<Object?>(
      () async => dio.get<Object?>(
        '$_baseUrl/api/resource-categories/flattened',
        options: await _authOptions(),
      ),
    );
    return _objectMap(response.data);
  }

  Future<BandBbsResourceLicense> checkLicense(String resourceId) async {
    final response = await _send<Object?>(
      () async => dio.get<Object?>(
        '$_baseUrl/api/resource-check/$resourceId',
        options: await _authOptions(),
      ),
    );
    final data = _objectMap(response.data);
    return BandBbsResourceLicense(
      valid: data['valid'] == true,
      license: data['license']?.toString() ?? '',
      iv: data['iv']?.toString() ?? '',
    );
  }

  Future<Response<List<int>>> downloadFile(
    String url, {
    void Function(int received, int total)? onReceiveProgress,
    CancelToken? cancelToken,
  }) async {
    return _send<List<int>>(
      () async => dio.get<List<int>>(
        url,
        options: (await _authOptions()).copyWith(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
        cancelToken: cancelToken,
        onReceiveProgress: onReceiveProgress,
      ),
    );
  }

  Future<Response<Object?>> headFile(String url) async {
    return _send<Object?>(
      () async => dio.head<Object?>(url, options: await _authOptions()),
    );
  }

  Future<BandBbsDecryptInfo> getDecryptInfo({
    required String encryptedFileHash,
    required String verifyLicense,
    required String licenseIv,
  }) async {
    final requestBody = {
      'encrypted_file_hash': encryptedFileHash,
      'verify_license': verifyLicense,
      'license_iv': licenseIv,
    };
    final response = await _send<Object?>(
      () async => dio.post<Object?>(
        '$_developerApiBaseUrl/developerplatform/api/v1/public/files/decrypt',
        data: requestBody,
      ),
    );
    final root = _objectMap(response.data);
    if (root['success'] != true) {
      throw StateError(root['message']?.toString() ?? 'BandBBS decrypt failed');
    }
    final data = _objectMap(root['data']);
    return BandBbsDecryptInfo.fromJson(data);
  }

  Future<Options> _authOptions() async {
    final token = await auth.refreshIfNeeded();
    if (token == null) {
      throw StateError('BandBBS account is not signed in');
    }
    return Options(headers: {'Authorization': 'Bearer ${token.accessToken}'});
  }

  Map<String, dynamic> _objectMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    throw FormatException('BandBBS API returned ${value.runtimeType}');
  }

  Future<Response<T>> _send<T>(Future<Response<T>> Function() request) async {
    try {
      return await request();
    } on DioException catch (e, st) {
      _logDioException(e, st);
      rethrow;
    } catch (e, st) {
      _log.severe('BandBBS request failed before Dio response', e, st);
      rethrow;
    }
  }

  void _logDioException(DioException error, StackTrace stackTrace) {
    final request = error.requestOptions;
    _log.severe(
      'BandBBS ${request.method} ${request.uri} failed '
      'status=${error.response?.statusCode}',
      error,
      stackTrace,
    );
  }
}

class BandBbsResourceLicense {
  const BandBbsResourceLicense({
    required this.valid,
    required this.license,
    required this.iv,
  });

  final bool valid;
  final String license;
  final String iv;
}

class BandBbsDecryptInfo {
  const BandBbsDecryptInfo({
    required this.fileName,
    required this.encryptedFileHash,
    required this.decryptedFileHash,
    required this.decryptToken,
    required this.decryptIv,
    required this.authTag,
  });

  final String fileName;
  final String encryptedFileHash;
  final String decryptedFileHash;
  final String decryptToken;
  final String decryptIv;
  final String authTag;

  factory BandBbsDecryptInfo.fromJson(Map<String, dynamic> json) {
    final fileInfo = _objectMap(json['file_info']);
    final decryptedInfo = _objectMap(json['decrypted_info']);
    return BandBbsDecryptInfo(
      fileName: fileInfo['file_name']?.toString() ?? '',
      encryptedFileHash: fileInfo['encrypted_file_hash']?.toString() ?? '',
      decryptedFileHash: fileInfo['decrypted_file_hash']?.toString() ?? '',
      decryptToken: decryptedInfo['decrypt_token']?.toString() ?? '',
      decryptIv: decryptedInfo['decrypt_iv']?.toString() ?? '',
      authTag: decryptedInfo['auth_tag']?.toString() ?? '',
    );
  }

  static Map<String, dynamic> _objectMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return const {};
  }
}
