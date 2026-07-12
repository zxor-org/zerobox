import 'package:zerobox/src/device/core/entity.dart';
import 'package:zerobox/src/device/core/event_bus.dart';
import 'package:zerobox/src/device/core/runtime.dart';
import 'package:zerobox/src/device/core/system.dart';
import 'package:zerobox/src/device/core/transport.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_auth_system.dart';
import 'package:zerobox/src/device/zeppos/zeppos_device_component.dart';

class ZeppOsDeviceFactory implements DeviceEntityFactory {
  @override
  DeviceEntity create({
    required String id,
    required String kind,
    required Transport transport,
    required DeviceEventBus eventBus,
  }) {
    final entity = DeviceEntity(
      id: id,
      kind: kind,
      transport: transport,
      eventBus: eventBus,
    );

    final component = ZeppOsDeviceComponent(transport: transport);
    component.onTransportFailure = (error, stackTrace) {
      entity.emit(DeviceError(deviceId: id, error: error.toString()));
      entity.emit(TransportDisconnected(deviceId: id));
    };
    entity.set(component);
    entity.setDispatcher(ZeppOsDispatcher());

    final authSystem = ZeppOsAuthSystem();
    component.onPayload = (payload) {
      if (payload.endpoint == ZeppOsDeviceComponent.endpointAuthentication) {
        authSystem.handlePayload(payload.payload);
      }
    };
    entity.registerSystem(authSystem);

    return entity;
  }
}

class ZeppOsDispatcher extends Dispatcher {}
