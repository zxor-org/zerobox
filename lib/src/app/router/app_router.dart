import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zerobox/src/app/layout/app_scaffold.dart';
import 'package:zerobox/src/app/widgets/dialog_helper.dart';
import 'package:zerobox/src/data/astrobox/models/astrobox_models.dart';
import 'package:zerobox/src/features/devices/pages/apps/device_apps_page.dart';
import 'package:zerobox/src/features/devices/pages/devices_page.dart';
import 'package:zerobox/src/features/devices/pages/info/device_info_page.dart';
import 'package:zerobox/src/features/devices/pages/install/install_local_page.dart';
import 'package:zerobox/src/features/devices/pages/switch/device_switch_page.dart';
import 'package:zerobox/src/features/devices/pages/watchfaces/device_watchfaces_page.dart';
import 'package:zerobox/src/features/devices/providers/pending_shared_device_provider.dart';
import 'package:zerobox/src/features/devices/services/device_share_link.dart';
import 'package:zerobox/src/features/home/pages/home_page.dart';
import 'package:zerobox/src/features/resources/pages/creator/creator_dashboard_page.dart';
import 'package:zerobox/src/features/resources/pages/creator/creator_editor_shell.dart';
import 'package:zerobox/src/features/resources/pages/resource_detail_page.dart';
import 'package:zerobox/src/features/resources/pages/resources_page.dart';
import 'package:zerobox/src/features/settings/pages/acknowledgements_page.dart';
import 'package:zerobox/src/features/settings/pages/about_software_page.dart';
import 'package:zerobox/src/features/settings/pages/settings_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    observers: [ZeroBoxDialog.observer],
    redirect: (context, state) {
      final uri = state.uri;
      final isDeviceShareLink =
          (uri.scheme == 'zerobox' && uri.host == 'open') ||
          ((uri.scheme == 'https' || uri.scheme == 'http') &&
              uri.host == 'zerobox.zxor.org' &&
              uri.path == '/open');
      if (!isDeviceShareLink) return null;

      final device = DeviceShareLink.parse(uri.toString());
      if (device != null) {
        ref.read(pendingSharedDeviceProvider.notifier).set(device);
        return '/devices/switch';
      }
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/resources',
                builder: (context, state) => const ResourcesPage(),
                routes: [
                  GoRoute(
                    path: 'detail/:id',
                    builder: (context, state) {
                      final item = state.extra as AstroBoxIndexItem?;
                      if (item != null) {
                        return ResourceDetailPage(item: item);
                      }
                      return ResourceDetailPage(
                        item: AstroBoxIndexItem(
                          id: state.pathParameters['id']!,
                          name: 'Unknown',
                          type: AstroBoxResourceType.quickApp,
                          repoOwner: '',
                          repoName: '',
                          repoCommitHash: '',
                          icon: '',
                          cover: '',
                          paidType: AstroBoxPaidType.free,
                        ),
                      );
                    },
                  ),
                  GoRoute(
                    path: 'creator',
                    builder: (context, state) => const CreatorDashboardPage(),
                    routes: [
                      GoRoute(
                        path: 'new',
                        builder: (context, state) => const CreatorEditorShell(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/devices',
                builder: (context, state) => const DevicesPage(),
                routes: [
                  GoRoute(
                    path: 'switch',
                    builder: (context, state) => const DeviceSwitchPage(),
                  ),
                  GoRoute(
                    path: 'info',
                    builder: (context, state) => const DeviceInfoPage(),
                  ),
                  GoRoute(
                    path: 'install/:type',
                    builder: (context, state) {
                      final typeName = state.pathParameters['type']!;
                      final type = InstallType.values.firstWhere(
                        (e) => e.name == typeName,
                        orElse: () => InstallType.app,
                      );
                      return InstallLocalPage(type: type);
                    },
                  ),
                  GoRoute(
                    path: 'apps',
                    builder: (context, state) => const DeviceAppsPage(),
                  ),
                  GoRoute(
                    path: 'watchfaces',
                    builder: (context, state) => const DeviceWatchfacesPage(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsPage(),
                routes: [
                  GoRoute(
                    path: 'about',
                    builder: (context, state) => const AboutSoftwarePage(),
                  ),
                  GoRoute(
                    path: 'team',
                    redirect: (context, state) => '/settings/about',
                  ),
                  GoRoute(
                    path: 'acknowledgements',
                    builder: (context, state) => const AcknowledgementsPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
