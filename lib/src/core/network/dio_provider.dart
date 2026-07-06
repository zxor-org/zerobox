import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/core/network/github_cdn_interceptor.dart';
import 'package:zerobox/src/core/providers/app_settings_providers.dart';

final appDioProvider = Provider<Dio>((ref) {
  final dio = Dio();
  dio.interceptors.add(
    GithubCdnInterceptor(cdn: () => ref.read(appSettingsProvider).cdn),
  );
  return dio;
});
