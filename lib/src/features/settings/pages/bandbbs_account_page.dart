import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/utils/error_localization.dart';
import 'package:zerobox/src/app/widgets/dialog_helper.dart';
import 'package:zerobox/src/app/widgets/network_img_layer.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/core/providers/app_settings_providers.dart';
import 'package:zerobox/src/data/community/community_source.dart';
import 'package:zerobox/src/features/accounts/services/bandbbs_auth_service.dart';
import 'package:zerobox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:zerobox/src/features/resources/domain/community_resource.dart';
import 'package:zerobox/src/features/resources/services/download_queue_notifier.dart';

class BandBbsAccountPage extends ConsumerStatefulWidget {
  const BandBbsAccountPage({super.key});
  @override
  ConsumerState<BandBbsAccountPage> createState() => _BandBbsAccountPageState();
}

class _BandBbsAccountPageState extends ConsumerState<BandBbsAccountPage> {
  final _id = TextEditingController();
  CommunityResourceDetail? _resource;
  Object? _error;
  var _loading = false;
  @override
  void dispose() {
    _id.dispose();
    super.dispose();
  }

  Future<void> _query() async {
    final id = _id.text.trim();
    if (id.isEmpty || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
      _resource = null;
    });
    try {
      final resource = await ref
          .read(communityCatalogProviderForSource(CommunitySourceId.bandbbs))
          .getDetail(ResourceRef(source: CommunitySourceId.bandbbs, id: id));
      if (mounted) {
        setState(() {
          _resource = resource;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final account = ref.watch(bandBbsAuthProvider);
    return Scaffold(
      appBar: SysAppBar(title: Text(l10n.bandBbsAccountTitle)),
      body: SingleChildScrollView(
        child: PageContainer(
          padding: const EdgeInsets.all(StyleConstants.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: ListTile(
                  leading: account.avatarUrl != null
                      ? NetworkImgLayer(
                          src: account.avatarUrl!,
                          width: 40,
                          height: 40,
                          type: 'avatar',
                        )
                      : CircleAvatar(
                          child: Text(
                            (account.username ?? account.userId ?? 'B')
                                .characters
                                .first,
                          ),
                        ),
                  title: Text(
                    account.username ?? l10n.settingsAccountBBSAccount,
                  ),
                  subtitle: Text(
                    account.userId == null
                        ? l10n.settingsConnected
                        : '${l10n.settingsAccountBandBbsAccount} · ${account.userId}',
                  ),
                  trailing: TextButton(
                    onPressed: () async {
                      await ref.read(bandBbsAuthProvider.notifier).signOut();
                      if (!context.mounted) return;
                      ZeroBoxDialog.showToast(
                        message: l10n.bandBbsLoggedOut,
                        context: context,
                      );
                      context.pop();
                    },
                    child: Text(l10n.bandBbsLogout),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.bandBbsResourceQueryTitle,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _id,
                              keyboardType: TextInputType.number,
                              onSubmitted: (_) => _query(),
                              decoration: InputDecoration(
                                labelText: l10n.bandBbsResourceId,
                                hintText: l10n.bandBbsResourceIdHint,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: _loading ? null : _query,
                            icon: _loading
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.search),
                            label: Text(l10n.bandBbsQueryResource),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SettingsSection(
                title: Text(l10n.settingsGeneral),
                tiles: [
                  SettingsTile.switchTile(
                    onToggle: (value) async {
                      await ref
                          .read(appSettingsProvider.notifier)
                          .setBandBbsLoadPreviews(value ?? false);
                    },
                    initialValue: ref
                        .watch(appSettingsProvider)
                        .bandbbsLoadPreviews,
                    leading: const Icon(Icons.image_outlined),
                    title: Text(l10n.bandBbsLoadPreviews),
                    description: Text(l10n.bandBbsLoadPreviewsDesc),
                  ),
                  SettingsTile.switchTile(
                    onToggle: (value) async {
                      await ref
                          .read(appSettingsProvider.notifier)
                          .setBandBbsShowAllCategories(value ?? false);
                    },
                    initialValue: ref
                        .watch(appSettingsProvider)
                        .bandbbsShowAllCategories,
                    leading: const Icon(Icons.category_outlined),
                    title: Text(l10n.bandBbsShowAllCategories),
                    description: Text(l10n.bandBbsShowAllCategoriesDesc),
                  ),
                ],
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    localizedErrorMessage(l10n, _error!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (_resource != null) _Result(resource: _resource!),
            ],
          ),
        ),
      ),
    );
  }
}

class _Result extends ConsumerWidget {
  const _Result({required this.resource});
  final CommunityResourceDetail resource;
  @override
  Widget build(BuildContext context, WidgetRef ref) => Card(
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NetworkImgLayer(
                src: resource.iconUrl?.toString() ?? '',
                width: 56,
                height: 56,
                type: 'avatar',
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  resource.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (resource.publicUrl != null)
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => launchUrl(
                    resource.publicUrl!,
                    mode: LaunchMode.externalApplication,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          ...resource.files.map(
            (file) => ListTile(
              title: Text(file.fileName),
              subtitle: Text(file.version),
              trailing: FilledButton.icon(
                onPressed: resource.canDownload
                    ? () {
                        final target = file.supportedDevices.firstOrNull ?? '';
                        ref
                            .read(downloadQueueProvider.notifier)
                            .enqueue(
                              resource: resource,
                              file: file,
                              codename: target,
                            );
                      }
                    : null,
                icon: const Icon(Icons.download),
                label: const Icon(Icons.download),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
