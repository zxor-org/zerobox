import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/features/accounts/application/host_accounts.dart';
import 'package:zerobox/src/host/application_host_provider.dart';

void main() {
  test('account state and mutations use the host interface', () async {
    final host = _AccountHost();
    final container = ProviderContainer(
      overrides: [applicationHostProvider.overrideWithValue(host)],
    );
    addTearDown(container.dispose);

    await container.read(hostAccountsProvider.notifier).refresh();
    await container
        .read(hostAccountsProvider.notifier)
        .loginAmazfit(username: 'user@example.com', password: 'secret');
    await container
        .read(hostAccountsProvider.notifier)
        .saveCredentials(
          provider: 'amazfit',
          remember: true,
          username: 'user@example.com',
          password: 'secret',
        );
    final credentials = await container
        .read(hostAccountsProvider.notifier)
        .rememberedCredentials('amazfit');

    final state = container.read(hostAccountsProvider);
    expect(state.amazfit.signedIn, true);
    expect(state.amazfit.username, 'user@example.com');
    expect(credentials['password'], 'secret');
    expect(
      host.methods.where((method) => method == 'account.list'),
      isNotEmpty,
    );
    expect(
      host.methods,
      containsAll([
        'account.login',
        'account.credentials.set',
        'account.credentials.get',
      ]),
    );
  });
}

class _AccountHost implements ZeroBoxCommandBus {
  final _events = StreamController<CommandEvent>.broadcast();
  final methods = <String>[];

  @override
  Stream<CommandEvent> get events => _events.stream;

  @override
  Future<CommandResult> execute(ZeroBoxCommand command) async {
    methods.add(command.method);
    if (command.method == 'account.list') {
      return const CommandResult.success([
        {'provider': 'xiaomi', 'signedIn': false},
        {'provider': 'amazfit', 'signedIn': false},
        {'provider': 'bandbbs', 'signedIn': false},
      ]);
    }
    if (command.method == 'account.credentials.get') {
      return const CommandResult.success({
        'provider': 'amazfit',
        'remember': true,
        'username': 'user@example.com',
        'password': 'secret',
      });
    }
    if (command.method == 'account.credentials.set') {
      return CommandResult.success(command.params);
    }
    return CommandResult.success({
      'provider': 'amazfit',
      'signedIn': true,
      'username': command.params['username'],
    });
  }

  @override
  Future<void> close() => _events.close();
}
