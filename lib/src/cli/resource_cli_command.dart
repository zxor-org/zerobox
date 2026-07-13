import 'package:zerobox/src/cli/cli_models.dart';
import 'package:zerobox/src/commands/command_protocol.dart';

const _sortRules = {'random', 'name', 'time'};
const _resourceTypes = {'quickapp', 'watchface', 'firmware', 'miniprogram'};
final _deviceFilterPattern = RegExp(r'\d');
const _legacyFilterOptions = {
  'type',
  'device',
  'devices',
  'free',
  'hide-paid',
  'hide-force-paid',
};

ZeroBoxCommand buildResourceQueryCommand(CliInvocation invocation) {
  final name = invocation.command.join('.');
  if (name != 'resource.list' && name != 'resource.search') {
    throw CliUsageException('Unsupported resource query command: $name');
  }
  final sort = invocation.options['sort'];
  if (sort != null && !_sortRules.contains(sort)) {
    throw CliUsageException(
      'Unsupported resource sort rule: $sort '
      '(expected random, name, or time)',
    );
  }
  final legacyOption = _legacyFilterOptions
      .where(invocation.options.containsKey)
      .firstOrNull;
  if (legacyOption != null) {
    throw CliUsageException(
      'Use --filter instead of --$legacyOption for resource filters',
    );
  }
  if (invocation.options.containsKey('filter') &&
      invocation.options['filter'] == null) {
    throw const CliUsageException('Missing value after --filter');
  }
  final chips = _filterChips(invocation.options['filter']);
  final types = chips.where(_resourceTypes.contains).toList(growable: false);
  if (types.length > 1) {
    throw CliUsageException(
      'Conflicting resource type filters: ${types.join(', ')}',
    );
  }
  final freeOnly = chips.contains('free');
  final devices = chips
      .where(
        (chip) =>
            !_resourceTypes.contains(chip) &&
            chip != 'free' &&
            chip != 'hide-paid' &&
            chip != 'hide-force-paid',
      )
      .toList(growable: false);
  final invalidChip = devices
      .where((chip) => !_deviceFilterPattern.hasMatch(chip))
      .firstOrNull;
  if (invalidChip != null) {
    throw CliUsageException('Unsupported resource filter chip: $invalidChip');
  }
  return ZeroBoxCommand(
    method: name,
    params: {
      if (invocation.options['source'] != null)
        'source': invocation.options['source'],
      if (types.isNotEmpty) 'type': types.single,
      if (sort != null) 'sort': sort,
      if (freeOnly || chips.contains('hide-paid')) 'hidePaid': true,
      if (freeOnly || chips.contains('hide-force-paid')) 'hideForcePaid': true,
      if (devices.isNotEmpty) 'devices': devices,
      if (invocation.options['page'] != null)
        'page': invocation.options['page'],
      if (invocation.options['page-size'] != null)
        'pageSize': invocation.options['page-size'],
      if (name == 'resource.search')
        'query': invocation.requiredArgument('search query'),
    },
  );
}

List<String> _filterChips(String? value) => [value]
    .whereType<String>()
    .expand((value) => value.split(','))
    .map((value) => value.trim())
    .where((value) => value.isNotEmpty)
    .toSet()
    .toList(growable: false);
