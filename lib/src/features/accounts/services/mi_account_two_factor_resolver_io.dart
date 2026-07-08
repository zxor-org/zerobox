import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'mi_account_two_factor_resolver_base.dart';

MiAccountTwoFactorResolver createPlatformMiAccountTwoFactorResolver() {
  if (Platform.isAndroid ||
      Platform.isLinux ||
      Platform.isMacOS ||
      Platform.isWindows) {
    return const NativeMiAccountTwoFactorResolver();
  }
  return const UnsupportedIoMiAccountTwoFactorResolver();
}

class NativeMiAccountTwoFactorResolver implements MiAccountTwoFactorResolver {
  const NativeMiAccountTwoFactorResolver();

  static const _method = MethodChannel('zerobox/mi_account_2fa');

  @override
  Future<String> resolve(BuildContext context, Uri notificationUrl) async {
    final cookieHeader = await _method.invokeMethod<String>('resolve', {
      'url': notificationUrl.toString(),
    });
    if (cookieHeader == null || cookieHeader.trim().isEmpty) {
      throw StateError('Xiaomi 2FA did not return account cookies');
    }
    return cookieHeader;
  }
}

class UnsupportedIoMiAccountTwoFactorResolver
    implements MiAccountTwoFactorResolver {
  const UnsupportedIoMiAccountTwoFactorResolver();

  @override
  Future<String> resolve(BuildContext context, Uri notificationUrl) {
    throw UnsupportedError('This platform does not support Xiaomi 2FA WebView');
  }
}
