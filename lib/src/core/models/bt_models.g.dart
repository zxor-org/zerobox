// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bt_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BTDeviceInfo _$BTDeviceInfoFromJson(Map<String, dynamic> json) =>
    _BTDeviceInfo(
      name: json['name'] as String,
      addr: json['addr'] as String,
      connectType: json['connectType'] as String,
    );

Map<String, dynamic> _$BTDeviceInfoToJson(_BTDeviceInfo instance) =>
    <String, dynamic>{
      'name': instance.name,
      'addr': instance.addr,
      'connectType': instance.connectType,
    };

_MiWearState _$MiWearStateFromJson(Map<String, dynamic> json) => _MiWearState(
  name: json['name'] as String,
  addr: json['addr'] as String,
  connectType: json['connectType'] as String,
  authkey: json['authkey'] as String?,
  codename: json['codename'] as String?,
  disconnected: json['disconnected'] as bool? ?? false,
);

Map<String, dynamic> _$MiWearStateToJson(_MiWearState instance) =>
    <String, dynamic>{
      'name': instance.name,
      'addr': instance.addr,
      'connectType': instance.connectType,
      'authkey': instance.authkey,
      'codename': instance.codename,
      'disconnected': instance.disconnected,
    };

_ChargeInfo _$ChargeInfoFromJson(Map<String, dynamic> json) => _ChargeInfo(
  state: (json['state'] as num?)?.toInt() ?? 0,
  timestamp: (json['timestamp'] as num?)?.toInt(),
);

Map<String, dynamic> _$ChargeInfoToJson(_ChargeInfo instance) =>
    <String, dynamic>{'state': instance.state, 'timestamp': instance.timestamp};

_BatteryStatus _$BatteryStatusFromJson(Map<String, dynamic> json) =>
    _BatteryStatus(
      capacity: (json['capacity'] as num).toInt(),
      chargeStatus:
          $enumDecodeNullable(_$ChargeStatusEnumMap, json['chargeStatus']) ??
          ChargeStatus.unknown,
      chargeInfo: json['chargeInfo'] == null
          ? null
          : ChargeInfo.fromJson(json['chargeInfo'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BatteryStatusToJson(_BatteryStatus instance) =>
    <String, dynamic>{
      'capacity': instance.capacity,
      'chargeStatus': _$ChargeStatusEnumMap[instance.chargeStatus]!,
      'chargeInfo': instance.chargeInfo,
    };

const _$ChargeStatusEnumMap = {
  ChargeStatus.unknown: 'unknown',
  ChargeStatus.charging: 'charging',
  ChargeStatus.notCharging: 'notCharging',
  ChargeStatus.full: 'full',
};

_AppInfo _$AppInfoFromJson(Map<String, dynamic> json) => _AppInfo(
  packageName: json['packageName'] as String,
  fingerprint:
      (json['fingerprint'] as List<dynamic>?)
          ?.map((e) => (e as num).toInt())
          .toList() ??
      const <int>[],
  versionCode: (json['versionCode'] as num?)?.toInt() ?? 0,
  canRemove: json['canRemove'] as bool? ?? false,
  appName: json['appName'] as String,
);

Map<String, dynamic> _$AppInfoToJson(_AppInfo instance) => <String, dynamic>{
  'packageName': instance.packageName,
  'fingerprint': instance.fingerprint,
  'versionCode': instance.versionCode,
  'canRemove': instance.canRemove,
  'appName': instance.appName,
};

_StorageInfo _$StorageInfoFromJson(Map<String, dynamic> json) => _StorageInfo(
  used: (json['used'] as num).toInt(),
  total: (json['total'] as num).toInt(),
);

Map<String, dynamic> _$StorageInfoToJson(_StorageInfo instance) =>
    <String, dynamic>{'used': instance.used, 'total': instance.total};

_SystemInfo _$SystemInfoFromJson(Map<String, dynamic> json) => _SystemInfo(
  serialNumber: json['serialNumber'] as String,
  firmwareVersion: json['firmwareVersion'] as String,
  imei: json['imei'] as String,
  model: json['model'] as String,
  storageInfo: json['storageInfo'] == null
      ? null
      : StorageInfo.fromJson(json['storageInfo'] as Map<String, dynamic>),
);

Map<String, dynamic> _$SystemInfoToJson(_SystemInfo instance) =>
    <String, dynamic>{
      'serialNumber': instance.serialNumber,
      'firmwareVersion': instance.firmwareVersion,
      'imei': instance.imei,
      'model': instance.model,
      'storageInfo': instance.storageInfo,
    };

_WatchfaceInfo _$WatchfaceInfoFromJson(Map<String, dynamic> json) =>
    _WatchfaceInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      isCurrent: json['isCurrent'] as bool? ?? false,
      canRemove: json['canRemove'] as bool? ?? false,
      versionCode: (json['versionCode'] as num?)?.toInt() ?? 0,
      canEdit: json['canEdit'] as bool? ?? false,
      backgroundColor: json['backgroundColor'] as String? ?? '',
      backgroundImage: json['backgroundImage'] as String? ?? '',
      style: json['style'] as String? ?? '',
      backgroundImageList:
          (json['backgroundImageList'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$WatchfaceInfoToJson(_WatchfaceInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'isCurrent': instance.isCurrent,
      'canRemove': instance.canRemove,
      'versionCode': instance.versionCode,
      'canEdit': instance.canEdit,
      'backgroundColor': instance.backgroundColor,
      'backgroundImage': instance.backgroundImage,
      'style': instance.style,
      'backgroundImageList': instance.backgroundImageList,
    };
