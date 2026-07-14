import 'dart:typed_data';

import 'package:zerobox/src/device/core/entity.dart';
import 'package:zerobox/src/device/core/event_bus.dart';
import 'package:zerobox/src/device/core/runtime.dart';
import 'package:zerobox/src/device/core/system.dart';
import 'package:zerobox/src/device/core/transport.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_auth_system.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_apps_system.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_battery_system.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_device_info_system.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_find_device_system.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_services_system.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_xiao_ai_system.dart';
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
    final appsSystem = ZeppOsAppsSystem();
    final batterySystem = ZeppOsBatterySystem();
    final deviceInfoSystem = ZeppOsDeviceInfoSystem();
    final servicesSystem = ZeppOsServicesSystem();
    final findDeviceSystem = ZeppOsFindDeviceSystem();
    final xiaoAiSystem = ZeppOsXiaoAiSystem();
    component.onPayload = (payload) {
      entity.emit(
        ZeppOsEndpointMessageReceived(
          deviceId: id,
          endpoint: payload.endpoint,
          payload: Uint8List.fromList(payload.payload),
        ),
      );
      if (payload.endpoint == ZeppOsDeviceComponent.endpointAuthentication) {
        authSystem.handlePayload(payload.payload);
      } else if (payload.endpoint == ZeppOsAppsSystem.endpoint) {
        appsSystem.handlePayload(payload.payload);
      } else if (payload.endpoint == ZeppOsBatterySystem.endpoint) {
        batterySystem.handlePayload(payload.payload);
      } else if (payload.endpoint == ZeppOsDeviceInfoSystem.endpoint) {
        deviceInfoSystem.handlePayload(payload.payload);
      } else if (payload.endpoint == ZeppOsServicesSystem.endpoint) {
        servicesSystem.handlePayload(payload.payload);
      } else if (payload.endpoint == ZeppOsXiaoAiSystem.xiaoAiEndpoint ||
          payload.endpoint == ZeppOsXiaoAiSystem.zeppFlowEndpoint) {
        xiaoAiSystem.handlePayload(payload.endpoint, payload.payload);
      }
    };
    entity.registerSystem(authSystem);
    entity.registerSystem(appsSystem);
    entity.registerSystem(batterySystem);
    entity.registerSystem(deviceInfoSystem);
    entity.registerSystem(servicesSystem);
    entity.registerSystem(findDeviceSystem);
    entity.registerSystem(xiaoAiSystem);

    return entity;
  }
}

class ZeppOsDispatcher extends Dispatcher {}
