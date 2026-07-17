import 'dart:async';

import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/device/xiaomi/system/xiaomi_system.dart';
import 'package:zerobox/src/protocols/generated/xiaomi/wear.pb.dart' as pb;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_thirdparty_app.pb.dart'
    as pb_thirdparty;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_watch_face.pb.dart'
    as pb_watchface;

class XiaomiResourceSystem extends XiaomiPbSystem {
  static final _log = getLogger('XiaomiResourceSystem');

  final _watchfaceWaiters = <Completer<List<pb_watchface.WatchFaceItem>>>[];
  final _quickAppWaiters = <Completer<List<pb_thirdparty.AppItem>>>[];

  Future<List<pb_watchface.WatchFaceItem>> fetchInstalledWatchfaces() async {
    _log.fine('[${entity.id}] fetching installed watchfaces');
    final completer = Completer<List<pb_watchface.WatchFaceItem>>();
    _watchfaceWaiters.add(completer);
    await component.sendPbPacket(_buildWatchfaceGetInstalled());
    return completer.future.timeout(const Duration(seconds: 10));
  }

  Future<List<pb_thirdparty.AppItem>> fetchInstalledQuickApps() async {
    _log.fine('[${entity.id}] fetching installed quick apps');
    final completer = Completer<List<pb_thirdparty.AppItem>>();
    _quickAppWaiters.add(completer);
    await component.sendPbPacket(_buildThirdpartyAppGetInstalled());
    return completer.future.timeout(const Duration(seconds: 10));
  }

  @override
  void onWearPacket(pb.WearPacket packet) {
    if (packet.whichPayload() == pb.WearPacket_Payload.watchFace &&
        packet.id ==
            pb_watchface.WatchFace_WatchFaceID.GET_INSTALLED_LIST.value) {
      final list = packet.watchFace.watchFaceList.list;
      _fulfillAll(_watchfaceWaiters, list);
      return;
    }

    if (packet.whichPayload() == pb.WearPacket_Payload.thirdpartyApp &&
        packet.id ==
            pb_thirdparty
                .ThirdpartyApp_ThirdpartyAppID
                .GET_INSTALLED_LIST
                .value) {
      final list = packet.thirdpartyApp.appItemList.list;
      _fulfillAll(_quickAppWaiters, list);
      return;
    }
  }

  void _fulfillAll<T>(List<Completer<T>> waiters, T value) {
    for (final completer in waiters) {
      if (!completer.isCompleted) {
        completer.complete(value);
      }
    }
    waiters.clear();
  }
}

pb.WearPacket _buildWatchfaceGetInstalled() {
  return pb.WearPacket(
    type: pb.WearPacket_Type.WATCH_FACE,
    id: pb_watchface.WatchFace_WatchFaceID.GET_INSTALLED_LIST.value,
    watchFace: pb_watchface.WatchFace(),
  );
}

pb.WearPacket _buildThirdpartyAppGetInstalled() {
  return pb.WearPacket(
    type: pb.WearPacket_Type.THIRDPARTY_APP,
    id: pb_thirdparty.ThirdpartyApp_ThirdpartyAppID.GET_INSTALLED_LIST.value,
    thirdpartyApp: pb_thirdparty.ThirdpartyApp(),
  );
}
