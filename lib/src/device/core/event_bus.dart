import 'dart:async';
import 'dart:typed_data';

import 'package:zerobox/src/core/models/bt_models.dart';

sealed class DeviceEvent {
  const DeviceEvent({required this.deviceId});

  final String deviceId;
}

final class TransportConnected extends DeviceEvent {
  const TransportConnected({required super.deviceId});
}

final class TransportDisconnected extends DeviceEvent {
  const TransportDisconnected({required super.deviceId});
}

final class DeviceAuthenticated extends DeviceEvent {
  const DeviceAuthenticated({required super.deviceId});
}

final class AuthFailed extends DeviceEvent {
  const AuthFailed({required super.deviceId, required this.error});

  final String error;
}

final class BatteryUpdated extends DeviceEvent {
  const BatteryUpdated({required super.deviceId, required this.battery});

  final BatteryStatus battery;
}

final class DeviceInfoUpdated extends DeviceEvent {
  const DeviceInfoUpdated({required super.deviceId, required this.info});

  final SystemInfo info;
}

final class AppListUpdated extends DeviceEvent {
  const AppListUpdated({required super.deviceId, required this.apps});

  final List<AppInfo> apps;
}

final class WatchfaceListUpdated extends DeviceEvent {
  const WatchfaceListUpdated({
    required super.deviceId,
    required this.watchfaces,
  });

  final List<WatchfaceInfo> watchfaces;
}

final class StorageInfoUpdated extends DeviceEvent {
  const StorageInfoUpdated({required super.deviceId, required this.info});

  final StorageInfo info;
}

final class InstallPrepared extends DeviceEvent {
  const InstallPrepared({required super.deviceId});
}

final class InstallProgress extends DeviceEvent {
  const InstallProgress({
    required super.deviceId,
    required this.progress,
    required this.totalParts,
    required this.currentPart,
  });

  final double progress;
  final int totalParts;
  final int currentPart;
}

final class InstallCompleted extends DeviceEvent {
  const InstallCompleted({required super.deviceId});
}

final class InstallFailed extends DeviceEvent {
  const InstallFailed({required super.deviceId, required this.error});

  final String error;
}

final class DeviceError extends DeviceEvent {
  const DeviceError({required super.deviceId, required this.error});

  final String error;
}

final class UnknownPacket extends DeviceEvent {
  const UnknownPacket({required super.deviceId});
}

final class InterconnectMessage extends DeviceEvent {
  const InterconnectMessage({
    required super.deviceId,
    required this.pkgName,
    required this.payload,
  });

  final String pkgName;
  final Uint8List payload;
}

final class ZeppOsEndpointMessageReceived extends DeviceEvent {
  const ZeppOsEndpointMessageReceived({
    required super.deviceId,
    required this.endpoint,
    required this.payload,
  });

  final int endpoint;
  final Uint8List payload;
}

final class XiaoAiSessionStarted extends DeviceEvent {
  const XiaoAiSessionStarted({
    required super.deviceId,
    required this.capabilities,
  });

  final Map<String, Object?> capabilities;
}

final class XiaoAiSessionEnded extends DeviceEvent {
  const XiaoAiSessionEnded({required super.deviceId});
}

final class XiaoAiOpusFrameReceived extends DeviceEvent {
  const XiaoAiOpusFrameReceived({
    required super.deviceId,
    required this.sequence,
    required this.frame,
  });

  final int sequence;
  final Uint8List frame;
}

class DeviceEventBus {
  DeviceEventBus();

  final _controller = StreamController<DeviceEvent>.broadcast();

  Stream<DeviceEvent> get stream => _controller.stream;

  void emit(DeviceEvent event) => _controller.add(event);

  void dispose() => _controller.close();
}
