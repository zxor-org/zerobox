import 'dart:typed_data';

import 'package:zerobox/src/device/core/event_bus.dart';
import 'package:zerobox/src/device/xiaomi/system/xiaomi_system.dart';
import 'package:zerobox/src/protocols/generated/xiaomi/wear.pb.dart' as pb;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_thirdparty_app.pb.dart'
    as pb_thirdparty;

class ThirdpartyAppInfo {
  ThirdpartyAppInfo({required this.packageName, required this.fingerprint});

  final String packageName;
  final Uint8List fingerprint;
}

class XiaomiThirdpartyAppSystem extends XiaomiPbSystem {
  Future<void> sendPhoneMessage(
    ThirdpartyAppInfo app,
    Uint8List payload,
  ) async {
    await component.sendPbPacket(_buildThirdpartyAppMsgContent(app, payload));
  }

  Future<void> launchApp(ThirdpartyAppInfo app, String page) async {
    await component.sendPbPacket(_buildThirdpartyAppLaunch(app, page));
  }

  Future<void> uninstallApp(ThirdpartyAppInfo app) async {
    await component.sendPbPacket(_buildThirdpartyAppUninstall(app));
  }

  Future<void> syncStatus(
    ThirdpartyAppInfo app,
    pb_thirdparty.PhoneAppStatus_Status status,
  ) async {
    await component.sendPbPacket(
      _buildThirdpartyAppSyncStatus(_toBasicInfo(app), status),
    );
  }

  void _handleBasicInfo(pb_thirdparty.BasicInfo basicInfo) {
    component.sendPbPacket(
      _buildThirdpartyAppSyncStatus(
        basicInfo,
        pb_thirdparty.PhoneAppStatus_Status.CONNECTED,
      ),
    );
  }

  void _handleMessageContent(pb_thirdparty.MessageContent message) {
    final pkgName = message.basicInfo.packageName;
    entity.emit(
      InterconnectMessage(
        deviceId: entity.id,
        pkgName: pkgName,
        payload: Uint8List.fromList(message.content),
      ),
    );
  }

  @override
  void onWearPacket(pb.WearPacket packet) {
    if (packet.whichPayload() != pb.WearPacket_Payload.thirdpartyApp) return;
    final app = packet.thirdpartyApp;

    switch (app.whichPayload()) {
      case pb_thirdparty.ThirdpartyApp_Payload.basicInfo:
        _handleBasicInfo(app.basicInfo);
      case pb_thirdparty.ThirdpartyApp_Payload.messageContent:
        _handleMessageContent(app.messageContent);
      default:
        break;
    }
  }
}

pb.WearPacket _buildThirdpartyAppSyncStatus(
  pb_thirdparty.BasicInfo basicInfo,
  pb_thirdparty.PhoneAppStatus_Status status,
) {
  final phoneStatus = pb_thirdparty.PhoneAppStatus(
    basicInfo: basicInfo,
    status: status,
  );

  return pb.WearPacket(
    type: pb.WearPacket_Type.THIRDPARTY_APP,
    id: pb_thirdparty.ThirdpartyApp_ThirdpartyAppID.SYNC_PHONE_APP_STATUS.value,
    thirdpartyApp: pb_thirdparty.ThirdpartyApp(appStatus: phoneStatus),
  );
}

pb.WearPacket _buildThirdpartyAppMsgContent(
  ThirdpartyAppInfo app,
  Uint8List data,
) {
  return pb.WearPacket(
    type: pb.WearPacket_Type.THIRDPARTY_APP,
    id: pb_thirdparty.ThirdpartyApp_ThirdpartyAppID.SEND_PHONE_MESSAGE.value,
    thirdpartyApp: pb_thirdparty.ThirdpartyApp(
      messageContent: pb_thirdparty.MessageContent(
        basicInfo: _toBasicInfo(app),
        content: data,
      ),
    ),
  );
}

pb.WearPacket _buildThirdpartyAppLaunch(ThirdpartyAppInfo app, String page) {
  return pb.WearPacket(
    type: pb.WearPacket_Type.THIRDPARTY_APP,
    id: pb_thirdparty.ThirdpartyApp_ThirdpartyAppID.LAUNCH_APP.value,
    thirdpartyApp: pb_thirdparty.ThirdpartyApp(
      launchInfo: pb_thirdparty.LaunchInfo(
        basicInfo: _toBasicInfo(app),
        uri: page,
      ),
    ),
  );
}

pb.WearPacket _buildThirdpartyAppUninstall(ThirdpartyAppInfo app) {
  return pb.WearPacket(
    type: pb.WearPacket_Type.THIRDPARTY_APP,
    id: pb_thirdparty.ThirdpartyApp_ThirdpartyAppID.REMOVE_APP.value,
    thirdpartyApp: pb_thirdparty.ThirdpartyApp(basicInfo: _toBasicInfo(app)),
  );
}

pb_thirdparty.BasicInfo _toBasicInfo(ThirdpartyAppInfo app) {
  return pb_thirdparty.BasicInfo(
    packageName: app.packageName,
    fingerprint: app.fingerprint,
  );
}
