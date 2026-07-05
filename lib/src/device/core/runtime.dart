import 'dart:async';

import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/device/core/device_kind.dart';
import 'package:zerobox/src/device/core/entity.dart';
import 'package:zerobox/src/device/core/event_bus.dart';
import 'package:zerobox/src/device/core/transport.dart';

class DeviceRuntime {
  DeviceRuntime() : _eventBus = DeviceEventBus();

  static final _log = getLogger('DeviceRuntime');
  final DeviceEventBus _eventBus;
  final _entities = <String, DeviceEntity>{};

  Stream<DeviceEvent> get eventStream => _eventBus.stream;

  DeviceEntity? entity(String id) => _entities[id];

  DeviceEntity spawnDevice({
    required String id,
    required String kind,
    required Transport transport,
    required DeviceEntityFactory factory,
  }) {
    unawaited(removeDevice(id));
    _log.info('[$id] spawning $kind device');

    final entity = factory.create(
      id: id,
      kind: kind,
      transport: transport,
      eventBus: _eventBus,
    );
    entity.startListening();
    _entities[id] = entity;
    return entity;
  }

  Future<void> removeDevice(String id) async {
    final entity = _entities.remove(id);
    if (entity != null) {
      _log.info('[$id] removing device');
      await entity.dispose();
    }
  }

  void clear() {
    final ids = _entities.keys.toList();
    for (final id in ids) {
      unawaited(removeDevice(id));
    }
  }

  void dispose() {
    _log.info('disposing runtime');
    clear();
    _eventBus.dispose();
  }
}

abstract class DeviceEntityFactory {
  DeviceEntity create({
    required String id,
    required String kind,
    required Transport transport,
    required DeviceEventBus eventBus,
  });
}

DeviceKind? parseDeviceKind(String value) => deviceKindFromString(value);

String deviceKindString(DeviceKind kind) => switch (kind) {
  DeviceKind.xiaomi => 'xiaomi',
  DeviceKind.zepp => 'zepp',
};
