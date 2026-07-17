import 'package:zerobox/src/app/window/window_launch_spec.dart';

bool get supportsSecondaryWindows => false;
Future<bool> initializeWindowCoordinator(WindowLaunchSpec spec) async => true;
Future<void> notifySecondaryWindowReady() async {}
Future<bool> openDebugWindow() async => false;
Future<bool> closeDebugWindow() async => false;
Future<bool> openPluginWindow(String pluginId) async => false;
Future<void> shutdownSecondaryWindows() async {}
Future<void> reportSecondaryWindowBounds({
  required String role,
  required double width,
  required double height,
  required double x,
  required double y,
}) async {}
