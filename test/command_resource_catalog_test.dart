import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/data/community/community_source.dart';
import 'package:zerobox/src/features/resources/application/command_resource_catalog.dart';
import 'package:zerobox/src/features/resources/domain/community_resource.dart';
import 'package:zerobox/src/features/resources/domain/resource_catalog.dart';

void main() {
  test(
    'resource catalog crosses the host seam without source dependencies',
    () async {
      final host = _CatalogHost();
      final catalog = CommandResourceCatalog(
        host: host,
        sourceId: CommunitySourceId.bandbbs,
      );

      final page = await catalog.getPage(
        const CommunityResourceQuery(
          query: 'music',
          type: CommunityResourceType.quickApp,
          hidePaid: true,
          selectedDevices: {'o65m'},
        ),
      );

      expect(page.items.single.name, 'NeoMusic');
      expect(page.items.single.iconUrl, Uri.parse('https://example/icon.png'));
      expect(host.lastCommand?.method, 'resource.list');
      expect(host.lastCommand?.params['source'], 'bandbbs');
      expect(host.lastCommand?.params['query'], 'music');
      expect(host.lastCommand?.params['devices'], ['o65m']);
      expect(host.lastCommand?.params['hidePaid'], true);
    },
  );
}

class _CatalogHost implements ZeroBoxCommandBus {
  final _events = StreamController<CommandEvent>.broadcast();
  ZeroBoxCommand? lastCommand;

  @override
  Stream<CommandEvent> get events => _events.stream;

  @override
  Future<CommandResult> execute(ZeroBoxCommand command) async {
    lastCommand = command;
    return const CommandResult.success({
      'page': 0,
      'hasMore': false,
      'total': 1,
      'items': [
        {
          'ref': 'bandbbs:1',
          'name': 'NeoMusic',
          'type': 'quickApp',
          'paidType': 'free',
          'authors': [
            {'name': 'OrPudding'},
          ],
          'devices': ['o65m'],
          'iconUrl': 'https://example/icon.png',
        },
      ],
    });
  }

  @override
  Future<void> close() => _events.close();
}
