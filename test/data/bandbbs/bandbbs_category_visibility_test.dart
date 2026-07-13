import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';
import 'package:zerobox/src/data/bandbbs/bandbbs_resource_provider.dart';
import 'package:zerobox/src/features/accounts/services/bandbbs_auth_service.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({
      'bandbbs.oauth.token': jsonEncode({
        'access_token': 'test-token',
        'refresh_token': 'test-refresh-token',
        'token_type': 'bearer',
        'expires_at': DateTime.utc(2099).toIso8601String(),
        'scope': '',
      }),
    });
    await SharedPrefsService.instance.init();
  });

  test('test category follows the standard default-hidden behavior', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final auth = container.read(bandBbsAuthProvider.notifier);

    final defaultTree = await BandBbsCatalog(
      dio: _categoryDio(),
      auth: auth,
    ).getCategoryTree();
    final fullTree = await BandBbsCatalog(
      dio: _categoryDio(),
      auth: auth,
      showAllCategories: true,
    ).getCategoryTree();

    expect(defaultTree.map((node) => node.title), ['红米手表5/6']);
    expect(fullTree.map((node) => node.title), ['测试区', '红米手表5/6']);
  });
}

Dio _categoryDio() {
  final dio = Dio();
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) => handler.resolve(
        Response<Object?>(
          requestOptions: options,
          statusCode: 200,
          data: {
            'categories_flat': [
              {
                'depth': 0,
                'category': {
                  'resource_category_id': 104,
                  'title': '测试区',
                  'resource_count': 1,
                  'parent_category_id': 0,
                },
              },
              {
                'depth': 0,
                'category': {
                  'resource_category_id': 101,
                  'title': '红米手表5/6',
                  'resource_count': 1,
                  'parent_category_id': 0,
                },
              },
            ],
          },
        ),
      ),
    ),
  );
  return dio;
}
