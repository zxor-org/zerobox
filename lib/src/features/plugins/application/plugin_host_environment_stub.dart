import 'dart:ui';

String pluginHostPlatform() => 'web';

String pluginHostArchitecture() => 'unknown';

String pluginHostVersion() => 'unknown';

String pluginHostHostname() => 'unknown';

String pluginHostLocale() => PlatformDispatcher.instance.locale.toString();
