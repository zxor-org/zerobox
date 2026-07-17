import 'package:zerobox/src/device/core/entity.dart';
import 'package:zerobox/src/device/core/event_bus.dart';
import 'package:zerobox/src/device/core/runtime.dart';
import 'package:zerobox/src/device/core/transport.dart';
import 'package:zerobox/src/device/xiaomi/components/auth_system.dart';
import 'package:zerobox/src/device/xiaomi/components/info_system.dart';
import 'package:zerobox/src/device/xiaomi/components/install_system.dart';
import 'package:zerobox/src/device/xiaomi/components/mass_system.dart';
import 'package:zerobox/src/device/xiaomi/components/media_system.dart';
import 'package:zerobox/src/device/xiaomi/components/network_system.dart';
import 'package:zerobox/src/device/xiaomi/components/report_system.dart';
import 'package:zerobox/src/device/xiaomi/components/request_pool_system.dart';
import 'package:zerobox/src/device/xiaomi/components/resource_system.dart';
import 'package:zerobox/src/device/xiaomi/components/sync_system.dart';
import 'package:zerobox/src/device/xiaomi/components/thirdparty_app_system.dart';
import 'package:zerobox/src/device/xiaomi/components/watchface_system.dart';
import 'package:zerobox/src/device/xiaomi/components/xiaomi_device_component.dart';
import 'package:zerobox/src/device/xiaomi/system/xiaomi_dispatcher.dart';

class XiaomiDeviceFactory implements DeviceEntityFactory {
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

    final component = XiaomiDeviceComponent(transport: transport);
    component.onTransportFailure = (error, stackTrace) {
      entity.emit(DeviceError(deviceId: id, error: error.toString()));
      entity.emit(TransportDisconnected(deviceId: id));
    };
    entity.set(component);

    final dispatcher = XiaomiDispatcher(component);
    component.onL2Payload = dispatcher.onL2Payload;
    entity.setDispatcher(dispatcher);

    entity.registerSystem(XiaomiRequestPoolSystem());
    entity.registerSystem(XiaomiAuthSystem());

    entity.registerSystem(XiaomiMassSystem());
    entity.registerSystem(XiaomiMediaSystem());
    entity.registerSystem(XiaomiNetworkSystem());

    entity.registerSystem(XiaomiInstallSystem());
    entity.registerSystem(XiaomiInfoSystem());
    entity.registerSystem(XiaomiSyncSystem());
    entity.registerSystem(XiaomiResourceSystem());
    entity.registerSystem(XiaomiWatchfaceSystem());
    entity.registerSystem(XiaomiThirdpartyAppSystem());
    entity.registerSystem(XiaomiReportSystem());

    return entity;
  }
}
