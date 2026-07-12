import 'package:freezed_annotation/freezed_annotation.dart';

part 'bt_models.freezed.dart';
part 'bt_models.g.dart';

enum ChargeStatus { unknown, charging, notCharging, full }

@freezed
abstract class BTDeviceInfo with _$BTDeviceInfo {
  const factory BTDeviceInfo({
    required String name,
    required String addr,
    required String connectType,
  }) = _BTDeviceInfo;

  factory BTDeviceInfo.fromJson(Map<String, dynamic> json) =>
      _$BTDeviceInfoFromJson(json);
}

@freezed
abstract class MiWearState with _$MiWearState {
  const factory MiWearState({
    required String name,
    required String addr,
    required String connectType,
    String? authkey,
    String? codename,
    @Default(false) bool disconnected,
  }) = _MiWearState;

  factory MiWearState.fromJson(Map<String, dynamic> json) =>
      _$MiWearStateFromJson(json);
}

@freezed
abstract class ChargeInfo with _$ChargeInfo {
  const factory ChargeInfo({@Default(0) int state, int? timestamp}) =
      _ChargeInfo;

  factory ChargeInfo.fromJson(Map<String, dynamic> json) =>
      _$ChargeInfoFromJson(json);
}

@freezed
abstract class BatteryStatus with _$BatteryStatus {
  const factory BatteryStatus({
    required int capacity,
    @Default(ChargeStatus.unknown) ChargeStatus chargeStatus,
    ChargeInfo? chargeInfo,
  }) = _BatteryStatus;

  factory BatteryStatus.fromJson(Map<String, dynamic> json) =>
      _$BatteryStatusFromJson(json);
}

@freezed
abstract class AppInfo with _$AppInfo {
  const factory AppInfo({
    required String packageName,
    @Default(<int>[]) List<int> fingerprint,
    @Default(0) int versionCode,
    @Default(false) bool canRemove,
    required String appName,
  }) = _AppInfo;

  factory AppInfo.fromJson(Map<String, dynamic> json) =>
      _$AppInfoFromJson(json);
}

@freezed
abstract class StorageInfo with _$StorageInfo {
  const factory StorageInfo({required int used, required int total}) =
      _StorageInfo;

  factory StorageInfo.fromJson(Map<String, dynamic> json) =>
      _$StorageInfoFromJson(json);
}

@freezed
abstract class SystemInfo with _$SystemInfo {
  const factory SystemInfo({
    required String serialNumber,
    required String firmwareVersion,
    required String imei,
    required String model,
    StorageInfo? storageInfo,
  }) = _SystemInfo;

  factory SystemInfo.fromJson(Map<String, dynamic> json) =>
      _$SystemInfoFromJson(json);
}

@freezed
abstract class WatchfaceInfo with _$WatchfaceInfo {
  const factory WatchfaceInfo({
    required String id,
    required String name,
    @Default(false) bool isCurrent,
    @Default(false) bool canRemove,
    @Default(0) int versionCode,
    @Default(false) bool canEdit,
    @Default('') String backgroundColor,
    @Default('') String backgroundImage,
    @Default('') String style,
    @Default(<String>[]) List<String> backgroundImageList,
  }) = _WatchfaceInfo;

  factory WatchfaceInfo.fromJson(Map<String, dynamic> json) =>
      _$WatchfaceInfoFromJson(json);
}
