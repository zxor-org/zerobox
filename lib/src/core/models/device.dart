import 'package:zerobox/src/core/models/bt_models.dart';
import 'package:zerobox/src/device/core/device_profile.dart';

enum DevicePlatform { velaOS, zeppOS }

enum ConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
  ready,
  error,
}

class Device {
  const Device({
    required this.id,
    required this.name,
    required this.platform,
    required this.modelId,
    required this.status,
    this.battery,
    this.firmwareVersion,
    this.address,
    this.authkey,
    this.connectType,
    this.codename,
  });

  final String id;
  final String name;
  final DevicePlatform platform;
  final String modelId;
  final ConnectionStatus status;
  final int? battery;
  final String? firmwareVersion;
  final String? address;
  final String? authkey;
  final String? connectType;
  final String? codename;

  bool get isConnected =>
      status == ConnectionStatus.connected || status == ConnectionStatus.ready;

  MiWearState toMiWearState() => MiWearState(
    name: name,
    addr: address ?? id,
    connectType: connectType ?? 'ble',
    authkey: authkey,
    codename: codename,
    disconnected: !isConnected,
  );
}

String devicePlatformLabel(DevicePlatform platform) {
  return switch (platform) {
    DevicePlatform.velaOS => 'VelaOS',
    DevicePlatform.zeppOS => 'ZeppOS',
  };
}

String connectionStatusLabel(ConnectionStatus status) {
  return switch (status) {
    ConnectionStatus.disconnected => 'Disconnected',
    ConnectionStatus.scanning => 'Scanning',
    ConnectionStatus.connecting => 'Connecting',
    ConnectionStatus.connected => 'Connected',
    ConnectionStatus.ready => 'Ready',
    ConnectionStatus.error => 'Error',
  };
}

String _matchIllustrationAsset(String name, {String? codename}) {
  return DeviceRegistry.resolveIdentity(
    name: name,
    codename: codename,
  ).illustrationAsset;
}

extension DeviceIllustration on Device {
  String? illustrationAsset() {
    return _matchIllustrationAsset(name, codename: codename);
  }
}

extension MiWearStateIllustration on MiWearState {
  String illustrationAsset() {
    return _matchIllustrationAsset(name, codename: codename);
  }
}

extension BTDeviceInfoIllustration on BTDeviceInfo {
  String illustrationAsset() {
    return _matchIllustrationAsset(name);
  }
}
