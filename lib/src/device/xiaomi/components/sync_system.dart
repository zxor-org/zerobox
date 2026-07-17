import 'dart:async';

import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/models/sync_models.dart';
import 'package:zerobox/src/device/xiaomi/system/xiaomi_system.dart';
import 'package:zerobox/src/protocols/generated/xiaomi/wear.pb.dart' as pb;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_common.pb.dart'
    as pb_common;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_system.pb.dart'
    as pb_system;

class XiaomiSyncSystem extends XiaomiPbSystem {
  static final _log = getLogger('XiaomiSyncSystem');

  Future<void> syncTime(TimeSyncProps props) async {
    _log.fine('[${entity.id}] syncing time: ${props.toJson()}');
    await component.sendPbPacket(_buildTimeSyncPacket(props));
  }

  Future<void> setLanguage(String locale) async {
    _log.fine('[${entity.id}] setting language: $locale');
    await component.sendPbPacket(_buildSetLanguagePacket(locale));
  }

  pb.WearPacket _buildSetLanguagePacket(String lang) {
    final payload = pb_system.Language(locale: lang);
    final pktPayload = pb_system.System(language: payload);

    return pb.WearPacket(
      type: pb.WearPacket_Type.SYSTEM,
      id: pb_system.System_SystemID.SET_LANGUAGE.value,
      system: pktPayload,
    );
  }

  pb.WearPacket _buildTimeSyncPacket(TimeSyncProps props) {
    final payload = pb_system.SystemTime(
      date: pb_common.Date(
        year: props.date.year,
        month: props.date.month,
        day: props.date.day,
      ),
      time: pb_common.Time(
        hour: props.time.hour,
        minuter: props.time.minute,
        second: props.time.second,
        millisecond: props.time.millisecond,
      ),
      timeZone: pb_common.Timezone(
        offset: props.timezone.offset,
        dstSaving: props.timezone.dstOffset,
        id: props.timezone.id,
        idSpec: '',
      ),
      is12Hours: props.is12HourFormat,
    );

    final pktPayload = pb_system.System(systemTime: payload);

    return pb.WearPacket(
      type: pb.WearPacket_Type.SYSTEM,
      id: pb_system.System_SystemID.SET_SYSTEM_TIME.value,
      system: pktPayload,
    );
  }

  @override
  void onWearPacket(pb.WearPacket packet) {}
}
