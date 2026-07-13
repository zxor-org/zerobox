import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/host/application_host_provider.dart';

class HostAccount {
  const HostAccount({
    required this.provider,
    this.signedIn = false,
    this.username,
    this.userId,
    this.avatarUrl,
    this.syncedDevices = 0,
    this.isBusy = false,
  });

  final String provider;
  final bool signedIn;
  final String? username;
  final String? userId;
  final String? avatarUrl;
  final int syncedDevices;
  final bool isBusy;
  bool get isSignedIn => signedIn;

  factory HostAccount.fromJson(Map<String, Object?> json) => HostAccount(
    provider: json['provider']?.toString() ?? '',
    signedIn: json['signedIn'] == true,
    username: json['username']?.toString(),
    userId: json['userId']?.toString(),
    avatarUrl: json['avatarUrl']?.toString(),
    syncedDevices:
        (json['syncedDevices'] as num?)?.toInt() ??
        (json['importedDevices'] as num?)?.toInt() ??
        0,
  );
}

class HostAccountsState {
  const HostAccountsState({
    this.accounts = const {},
    this.busyProvider,
    this.error,
  });

  final Map<String, HostAccount> accounts;
  final String? busyProvider;
  final String? error;

  HostAccount get xiaomi => _account('xiaomi');
  HostAccount get amazfit => _account('amazfit');
  HostAccount get bandbbs => _account('bandbbs');

  HostAccount _account(String provider) {
    final account = accounts[provider] ?? HostAccount(provider: provider);
    return HostAccount(
      provider: account.provider,
      signedIn: account.signedIn,
      username: account.username,
      userId: account.userId,
      avatarUrl: account.avatarUrl,
      syncedDevices: account.syncedDevices,
      isBusy: busyProvider == provider,
    );
  }

  HostAccountsState copyWith({
    Map<String, HostAccount>? accounts,
    String? busyProvider,
    bool clearBusy = false,
    String? error,
    bool clearError = false,
  }) => HostAccountsState(
    accounts: accounts ?? this.accounts,
    busyProvider: clearBusy ? null : busyProvider ?? this.busyProvider,
    error: clearError ? null : error ?? this.error,
  );
}

class HostAccountsNotifier extends Notifier<HostAccountsState> {
  StreamSubscription<CommandEvent>? _subscription;

  @override
  HostAccountsState build() {
    _subscription = ref.watch(applicationHostProvider).events.listen((event) {
      if (event.event == 'account.state' || event.event == 'host.connected') {
        unawaited(refresh());
      }
    });
    ref.onDispose(() => unawaited(_subscription?.cancel()));
    scheduleMicrotask(refresh);
    return const HostAccountsState();
  }

  Future<void> refresh() async {
    final value = await _execute(const ZeroBoxCommand(method: 'account.list'));
    final accounts = {
      for (final row in (value as List).whereType<Map>())
        row['provider'].toString(): HostAccount.fromJson(
          row.cast<String, Object?>(),
        ),
    };
    state = state.copyWith(accounts: accounts, clearError: true);
  }

  Future<HostAccount> loginAmazfit({
    required String username,
    required String password,
  }) => _mutate(
    'amazfit',
    ZeroBoxCommand(
      method: 'account.login',
      params: {
        'provider': 'amazfit',
        'username': username,
        'password': password,
      },
    ),
  );

  Future<HostAccount> loginXiaomi({
    required String username,
    required String password,
  }) => _mutate(
    'xiaomi',
    ZeroBoxCommand(
      method: 'account.login',
      params: {
        'provider': 'xiaomi',
        'username': username,
        'password': password,
      },
    ),
  );

  Future<HostAccount> completeXiaomiTwoFactor({
    required HostTwoFactorRequired challenge,
    required String cookieHeader,
  }) => _mutate(
    'xiaomi',
    ZeroBoxCommand(
      method: 'account.xiaomi.complete',
      params: {
        'url': challenge.url,
        'deviceId': challenge.deviceId,
        'cookieHeader': cookieHeader,
      },
    ),
  );

  Future<void> startBandBbsLogin() async {
    await _mutate(
      'bandbbs',
      const ZeroBoxCommand(
        method: 'account.login',
        params: {'provider': 'bandbbs'},
      ),
    );
  }

  Future<bool> handleBandBbsCallback(Uri uri) async {
    if (uri.scheme != 'zerobox' ||
        uri.host != 'oauth' ||
        uri.path != '/bandbbs') {
      return false;
    }
    await _mutate(
      'bandbbs',
      ZeroBoxCommand(
        method: 'account.bandbbs.callback',
        params: {'uri': uri.toString()},
      ),
    );
    return true;
  }

  Future<void> logout(String provider) async {
    await _mutate(
      provider,
      ZeroBoxCommand(method: 'account.logout', params: {'provider': provider}),
    );
  }

  Future<Map<String, Object?>> rememberedCredentials(String provider) async {
    final value = await _execute(
      ZeroBoxCommand(
        method: 'account.credentials.get',
        params: {'provider': provider},
      ),
    );
    return (value as Map).cast<String, Object?>();
  }

  Future<void> saveCredentials({
    required String provider,
    required bool remember,
    required String username,
    required String password,
    String? userId,
  }) async {
    await _execute(
      ZeroBoxCommand(
        method: 'account.credentials.set',
        params: {
          'provider': provider,
          'remember': remember,
          'username': username,
          'password': password,
          if (userId != null) 'userId': userId,
        },
      ),
    );
  }

  Future<HostAccount> _mutate(String provider, ZeroBoxCommand command) async {
    state = state.copyWith(busyProvider: provider, clearError: true);
    try {
      final value = await _execute(command);
      final account = HostAccount.fromJson(
        (value as Map).cast<String, Object?>(),
      );
      state = state.copyWith(
        accounts: {...state.accounts, account.provider: account},
        clearBusy: true,
      );
      return account;
    } catch (error) {
      state = state.copyWith(clearBusy: true, error: error.toString());
      rethrow;
    }
  }

  Future<Object?> _execute(ZeroBoxCommand command) async {
    final result = await ref.read(applicationHostProvider).execute(command);
    if (!result.ok) {
      if (result.error?.code == 'two_factor_required') {
        final details = (result.error?.details as Map).cast<String, Object?>();
        throw HostTwoFactorRequired(
          url: details['url']!.toString(),
          deviceId: details['deviceId']!.toString(),
        );
      }
      throw StateError('${result.error!.code}: ${result.error!.message}');
    }
    return result.value;
  }
}

class HostTwoFactorRequired implements Exception {
  const HostTwoFactorRequired({required this.url, required this.deviceId});
  final String url;
  final String deviceId;
}

final hostAccountsProvider =
    NotifierProvider<HostAccountsNotifier, HostAccountsState>(
      HostAccountsNotifier.new,
    );
