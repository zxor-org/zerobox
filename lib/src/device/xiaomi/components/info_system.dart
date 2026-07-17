import 'dart:async';

import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/models/bt_models.dart' as models;
import 'package:zerobox/src/device/core/event_bus.dart';
import 'package:zerobox/src/device/xiaomi/system/xiaomi_system.dart';
import 'package:zerobox/src/protocols/generated/xiaomi/wear.pb.dart' as pb;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_lpa.pb.dart'
    as pb_lpa;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_system.pb.dart'
    as pb_system;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_watch_face.pb.dart'
    as pb_watchface;
import 'package:zerobox/src/protocols/xiaomi/commands/xiaomi_request_pool.dart';

class XiaomiInfoSystem extends XiaomiPbSystem {
  static final _log = getLogger('XiaomiInfoSystem');

  Future<models.BatteryStatus> fetchBatteryInfo() async {
    final response = await component.requestPool
        .request<pb_system.DeviceStatus>(
          packet: buildSystemPacket(
            pb_system.System_SystemID.GET_DEVICE_STATUS,
          ),
          typeMatcher: (p) =>
              p.whichPayload() == pb.WearPacket_Payload.system &&
              p.id == pb_system.System_SystemID.GET_DEVICE_STATUS.value,
          responseMapper: (p) => p.system.deviceStatus,
        );
    final status = _batteryStatus(response.battery);
    _emitBattery(status);
    return status;
  }

  models.BatteryStatus _batteryStatus(pb_system.DeviceStatus_Battery battery) {
    return models.BatteryStatus(
      capacity: battery.capacity,
      chargeStatus: _mapChargeStatus(battery.chargeStatus),
      chargeInfo: battery.hasChargeInfo()
          ? models.ChargeInfo(
              state: battery.chargeInfo.state.toInt(),
              timestamp: battery.chargeInfo.hasTimestamp()
                  ? battery.chargeInfo.timestamp.toInt()
                  : null,
            )
          : null,
    );
  }

  void _emitBattery(models.BatteryStatus status) {
    entity.emit(BatteryUpdated(deviceId: entity.id, battery: status));
  }

  Future<models.SystemInfo> fetchDeviceInfo() async {
    _log.fine('[${entity.id}] fetching device info');
    final response = await component.requestPool.request<pb_system.DeviceInfo>(
      packet: buildSystemPacket(pb_system.System_SystemID.GET_DEVICE_INFO),
      typeMatcher: (p) =>
          p.whichPayload() == pb.WearPacket_Payload.system &&
          p.id == pb_system.System_SystemID.GET_DEVICE_INFO.value,
      responseMapper: (p) => p.system.deviceInfo,
    );
    final info = models.SystemInfo(
      serialNumber: response.serialNumber,
      firmwareVersion: response.firmwareVersion,
      imei: response.imei,
      model: response.model,
    );
    _log.fine(
      '[${entity.id}] device info: model=${info.model}, fw=${info.firmwareVersion}, serial=${info.serialNumber}, imei=${info.imei}',
    );
    entity.emit(DeviceInfoUpdated(deviceId: entity.id, info: info));
    return info;
  }

  Future<String?> fetchEuiccImei() async {
    _log.fine('[${entity.id}] fetching eUICC info');
    final response = await component.requestPool.request<pb_lpa.EuiccInfo>(
      packet: pb.WearPacket(
        type: pb.WearPacket_Type.LPA,
        id: pb_lpa.Lpa_LpaID.GET_EUICC_INFO.value,
        lpa: pb_lpa.Lpa(),
      ),
      typeMatcher: (p) =>
          p.whichPayload() == pb.WearPacket_Payload.lpa &&
          p.id == pb_lpa.Lpa_LpaID.GET_EUICC_INFO.value &&
          p.lpa.hasEuiccInfo(),
      responseMapper: (p) => p.lpa.euiccInfo,
      timeout: const Duration(seconds: 3),
    );
    final imei = response.hasImei() ? response.imei.trim() : '';
    final eidLength = response.hasEid() ? response.eid.length : 0;
    _log.fine(
      '[${entity.id}] eUICC info: imei_present=${imei.isNotEmpty}, eid_bytes=$eidLength',
    );
    return imei.isEmpty ? null : imei;
  }

  Future<models.StorageInfo> fetchStorageInfo() async {
    _log.fine('[${entity.id}] fetching storage info');
    final response = await component.requestPool.request<pb_system.StorageInfo>(
      packet: buildSystemPacket(pb_system.System_SystemID.GET_STORAGE_INFO),
      typeMatcher: (p) =>
          p.whichPayload() == pb.WearPacket_Payload.system &&
          p.id == pb_system.System_SystemID.GET_STORAGE_INFO.value,
      responseMapper: (p) => p.system.storageInfo,
    );
    final info = models.StorageInfo(
      used: response.used.toInt(),
      total: response.total.toInt(),
    );
    _log.fine(
      '[${entity.id}] storage info: used=${info.used}, total=${info.total}',
    );
    entity.emit(StorageInfoUpdated(deviceId: entity.id, info: info));
    return info;
  }

  Future<List<models.AppInfo>> fetchInstalledApps() async {
    _log.fine('[${entity.id}] fetching installed apps');
    final response = await component.requestPool.request<pb_system.App_List>(
      packet: buildSystemPacket(pb_system.System_SystemID.GET_ORDERED_APP_LIST),
      typeMatcher: (p) =>
          p.whichPayload() == pb.WearPacket_Payload.system &&
          p.id == pb_system.System_SystemID.GET_ORDERED_APP_LIST.value,
      responseMapper: (p) => p.system.appList,
    );
    final apps = response.list
        .map((app) => models.AppInfo(packageName: app.id, appName: app.name))
        .toList();
    _log.fine('[${entity.id}] installed apps: ${apps.length}');
    entity.emit(AppListUpdated(deviceId: entity.id, apps: apps));
    return apps;
  }

  Future<List<models.WatchfaceInfo>> fetchInstalledWatchfaces() async {
    _log.fine('[${entity.id}] fetching installed watchfaces');
    final response = await component.requestPool
        .request<pb_watchface.WatchFaceItem_List>(
          packet: pb.WearPacket(
            type: pb.WearPacket_Type.WATCH_FACE,
            id: pb_watchface.WatchFace_WatchFaceID.GET_INSTALLED_LIST.value,
            watchFace: pb_watchface.WatchFace(),
          ),
          typeMatcher: (p) =>
              p.whichPayload() == pb.WearPacket_Payload.watchFace &&
              p.id ==
                  pb_watchface.WatchFace_WatchFaceID.GET_INSTALLED_LIST.value &&
              p.watchFace.hasWatchFaceList(),
          responseMapper: (p) => p.watchFace.watchFaceList,
        );
    final watchfaces = response.list
        .map(
          (item) => models.WatchfaceInfo(
            id: item.id,
            name: item.name,
            isCurrent: item.isCurrent,
            canRemove: item.canRemove,
            versionCode: item.versionCode.toInt(),
            canEdit: item.canEdit,
            backgroundColor: item.backgroundColor,
            backgroundImage: item.backgroundImage,
            style: item.style,
            backgroundImageList: item.backgroundImageList.toList(),
          ),
        )
        .toList();
    _log.fine('[${entity.id}] installed watchfaces: ${watchfaces.length}');
    entity.emit(
      WatchfaceListUpdated(deviceId: entity.id, watchfaces: watchfaces),
    );
    return watchfaces;
  }

  models.ChargeStatus _mapChargeStatus(
    pb_system.DeviceStatus_Battery_ChargeStatus status,
  ) {
    return switch (status) {
      pb_system.DeviceStatus_Battery_ChargeStatus.CHARGING =>
        models.ChargeStatus.charging,
      pb_system.DeviceStatus_Battery_ChargeStatus.NOT_CHARGING =>
        models.ChargeStatus.notCharging,
      pb_system.DeviceStatus_Battery_ChargeStatus.FULL =>
        models.ChargeStatus.full,
      _ => models.ChargeStatus.unknown,
    };
  }

  @override
  void onWearPacket(pb.WearPacket packet) {
    if (packet.whichPayload() != pb.WearPacket_Payload.system ||
        packet.system.whichPayload() !=
            pb_system.System_Payload.batteryStatus) {
      return;
    }
    _emitBattery(_batteryStatus(packet.system.batteryStatus));
  }
}
