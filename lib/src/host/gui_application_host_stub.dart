import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/command_bus/local_command_bus.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/host/application_host.dart';

ZeroBoxCommandBus createGuiApplicationHost() {
  final container = ProviderContainer();
  return ApplicationHost(
    LocalCommandBus(container),
    onClose: container.dispose,
  );
}
