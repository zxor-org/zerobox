import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/utils/error_localization.dart';
import 'package:zerobox/src/app/widgets/horizontal_scroller.dart';
import 'package:zerobox/src/app/widgets/network_img_layer.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/data/community/community_source.dart';
import 'package:zerobox/src/device/core/xiaomi_wearable_catalog.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:zerobox/src/features/resources/domain/community_resource.dart';
import 'package:zerobox/src/features/resources/services/download_queue_notifier.dart';
import 'package:zerobox/src/features/resources/services/install_queue_notifier.dart';
import 'package:zerobox/src/features/resources/widgets/community_html_content.dart';

class ResourceDetailPage extends ConsumerWidget {
  const ResourceDetailPage({super.key, required this.resource});
  final CommunityResource resource;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final detail = ref.watch(communityResourceDetailProvider(resource.ref));
    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(resource.name)),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text(localizedErrorMessage(l10n, error))),
        data: (value) => _DetailContent(detail: value),
      ),
    );
  }
}

class _DetailContent extends ConsumerWidget {
  const _DetailContent({required this.detail});
  final CommunityResourceDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final deviceState = ref.watch(deviceManagerProvider);
    final current = deviceState.currentDevice;
    final currentCodename = normalizeXiaomiWearableCodename(current?.codename);
    final image = detail.coverUrl ?? detail.iconUrl;
    final isBandBbs = detail.ref.source == CommunitySourceId.bandbbs;
    final previews = isBandBbs
        ? detail.previewImages
              .where(
                (image) => !detail.content.value.contains(image.url.toString()),
              )
              .toList()
        : detail.previewImages;
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _Hero(
          image: image,
          child: PageContainer(
            padding: const EdgeInsets.fromLTRB(
              StyleConstants.pagePadding,
              20,
              StyleConstants.pagePadding,
              24,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: NetworkImgLayer(
                    src: detail.iconUrl?.toString() ?? '',
                    width: 76,
                    height: 76,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.name,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _Authors(detail: detail),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          _Chip(
                            label: _typeLabel(
                              AppLocalizations.of(context)!,
                              detail.type,
                              source: detail.ref.source,
                            ),
                            color: theme.colorScheme.primary,
                          ),
                          _Chip(
                            label: _paidLabel(
                              AppLocalizations.of(context)!,
                              detail.paidType,
                            ),
                            color: detail.paidType == CommunityPaidType.free
                                ? Colors.green
                                : theme.colorScheme.tertiary,
                          ),
                          if (detail.ref.source == CommunitySourceId.bandbbs)
                            ...detail.tags
                                .take(1)
                                .map(
                                  (tag) => _Chip(
                                    label: tag,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        PageContainer(
          padding: const EdgeInsets.all(StyleConstants.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (detail.summary.isNotEmpty &&
                  detail.summary != detail.content.value) ...[
                Text(
                  detail.summary,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _Actions(detail: detail, currentCodename: currentCodename),
              if (previews.isNotEmpty && !isBandBbs) ...[
                const SizedBox(height: 24),
                _PreviewGallery(previews: previews),
              ],
              if (detail.content.value.trim().isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  AppLocalizations.of(context)!.description,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                switch (detail.content.format) {
                  ResourceContentFormat.html => CommunityHtmlContent(
                    html: detail.content.value,
                    baseUri: detail.content.baseUri,
                  ),
                  ResourceContentFormat.plainText => SelectableText(
                    detail.content.value,
                    style: theme.textTheme.bodyLarge,
                  ),
                },
              ],
              if (previews.isNotEmpty && isBandBbs) ...[
                const SizedBox(height: 24),
                _PreviewGallery(previews: previews),
              ],
              if (currentCodename.isNotEmpty) ...[
                const SizedBox(height: 24),
                _Compatibility(
                  detail: detail,
                  codename: currentCodename,
                  deviceName: xiaomiDisplayNameForIdentity(
                    name: current?.name.toString() ?? currentCodename,
                    codename: currentCodename,
                  ),
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}

class _Authors extends StatelessWidget {
  const _Authors({required this.detail});

  final CommunityResourceDetail detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (detail.authors.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: detail.authors
          .map(
            (author) => InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _openAuthor(context, detail, author),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '@${author.name}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    if (detail.ref.source == CommunitySourceId.huamiAppStore)
                      Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  void _openAuthor(
    BuildContext context,
    CommunityResourceDetail detail,
    CommunityResourceAuthor author,
  ) {
    if (detail.ref.source == CommunitySourceId.huamiAppStore) {
      final name = author.name.trim();
      if (name.isEmpty) return;
      context.push(
        '/resources/huami-publisher?name=${Uri.encodeQueryComponent(name)}',
      );
      return;
    }
    final url = author.url;
    if (url != null) {
      launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}

class _PreviewGallery extends StatelessWidget {
  const _PreviewGallery({required this.previews});
  final List<CommunityResourceImage> previews;

  static const _height = 240.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.preview,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        HorizontalScroller(
          height: _height,
          spacing: 12,
          children: [
            for (final image in previews)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _sized(image)
                    ? NetworkImgLayer(
                        src: image.url.toString(),
                        width: _height * _aspectOf(image),
                        height: _height,
                        fit: BoxFit.contain,
                      )
                    : NetworkImgAutoWidth(
                        src: image.url.toString(),
                        height: _height,
                      ),
              ),
          ],
        ),
      ],
    );
  }

  bool _sized(CommunityResourceImage image) =>
      image.width != null && image.height != null && image.height! > 0;

  double _aspectOf(CommunityResourceImage image) {
    final width = image.width;
    final height = image.height;
    if (width == null || height == null || height <= 0) return 3 / 2;
    return width / height;
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.detail, required this.currentCodename});
  final CommunityResourceDetail detail;
  final String currentCodename;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final files = detail.files;
    if (files.isEmpty && detail.links.isEmpty) return const SizedBox.shrink();
    final preferred = files
        .where((file) => _matchesDevice(file, currentCodename))
        .firstOrNull;
    final inDownloadQueue = ref.watch(
      downloadQueueProvider.select(
        (tasks) => tasks.any(
          (task) =>
              task.resource.ref == detail.ref &&
              task.status != ResourceTaskStatus.completed,
        ),
      ),
    );
    final inInstallQueue = ref.watch(
      installQueueProvider.select(
        (state) => state.tasks.any(
          (task) =>
              task.resource?.ref == detail.ref &&
              task.status != ResourceTaskStatus.completed,
        ),
      ),
    );
    final inQueue = inDownloadQueue || inInstallQueue;
    final canInstall = detail.canDownload && !inQueue;
    void enqueue(CommunityResourceFile file) {
      final target = currentCodename.isNotEmpty
          ? currentCodename
          : file.supportedDevices.firstOrNull ?? '';
      ref
          .read(downloadQueueProvider.notifier)
          .enqueue(resource: detail, file: file, codename: target);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.downloadStarted)));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final expand = constraints.maxWidth < 520;
        final color = Theme.of(context).colorScheme;
        final label = inQueue ? l10n.productInQueue : l10n.install;
        final foreground = canInstall
            ? color.onPrimaryContainer
            : color.onSurface.withValues(alpha: .38);
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (files.isNotEmpty)
              SizedBox(
                width: expand ? double.infinity : 190,
                child: MenuAnchor(
                  alignmentOffset: const Offset(0, 4),
                  menuChildren: files
                      .map(
                        (file) => MenuItemButton(
                          onPressed: canInstall ? () => enqueue(file) : null,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 280),
                            child: Text(
                              _installMenuLabel(detail, file),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  builder: (_, controller, _) => ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Material(
                      color: canInstall
                          ? color.primaryContainer
                          : color.onSurface.withValues(alpha: .08),
                      child: SizedBox(
                        height: 48,
                        child: preferred == null
                            ? InkWell(
                                onTap: canInstall
                                    ? () => _toggleMenu(controller)
                                    : null,
                                child: _InstallButtonContent(
                                  label: label,
                                  color: foreground,
                                  trailing: const Icon(Icons.arrow_drop_down),
                                ),
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: canInstall
                                          ? () => enqueue(preferred)
                                          : null,
                                      child: _InstallButtonContent(
                                        label: label,
                                        color: foreground,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 28,
                                    child: VerticalDivider(
                                      width: 1,
                                      color: foreground.withValues(alpha: .20),
                                    ),
                                  ),
                                  _InstallMenuHandle(
                                    enabled: canInstall && files.length > 1,
                                    color: foreground,
                                    onTap: () => _toggleMenu(controller),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            for (final link in detail.links)
              TextButton.icon(
                onPressed: () =>
                    launchUrl(link.url, mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.open_in_new),
                label: Text(link.title),
              ),
          ],
        );
      },
    );
  }

  void _toggleMenu(MenuController controller) {
    if (controller.isOpen) {
      controller.close();
    } else {
      controller.open();
    }
  }
}

bool _matchesDevice(CommunityResourceFile file, String codename) {
  if (file.supportedDevices.isEmpty) return true;
  return file.supportedDevices
      .map(normalizeXiaomiWearableCodename)
      .contains(codename);
}

String _installMenuLabel(
  CommunityResourceDetail detail,
  CommunityResourceFile file,
) {
  if (detail.ref.source == CommunitySourceId.bandbbs) {
    return file.fileName;
  }

  final explicitName = file.displayName?.trim();
  if (explicitName != null && explicitName.isNotEmpty) {
    return explicitName;
  }

  final deviceIds = file.supportedDevices.isNotEmpty
      ? file.supportedDevices
      : detail.supportedDevices;
  if (deviceIds.isEmpty) {
    return file.label;
  }

  final label = deviceIds
      .map(normalizeXiaomiWearableCodename)
      .where((codename) => codename.isNotEmpty)
      .map(
        (codename) =>
            xiaomiDisplayNameForIdentity(name: codename, codename: codename),
      )
      .join(' / ');
  return label.isEmpty ? file.label : label;
}

class _InstallButtonContent extends StatelessWidget {
  const _InstallButtonContent({
    required this.label,
    required this.color,
    this.trailing,
  });

  final String label;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.download_for_offline, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            IconTheme(
              data: IconThemeData(color: color),
              child: trailing!,
            ),
          ],
        ],
      ),
    ),
  );
}

class _InstallMenuHandle extends StatelessWidget {
  const _InstallMenuHandle({
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: double.infinity,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Icon(Icons.arrow_drop_down, color: color),
      ),
    );
  }
}

class _Compatibility extends StatelessWidget {
  const _Compatibility({
    required this.detail,
    required this.codename,
    required this.deviceName,
  });
  final CommunityResourceDetail detail;
  final String codename;
  final String deviceName;
  @override
  Widget build(BuildContext context) {
    final compatible = detail.files.any(
      (file) => _matchesDevice(file, codename),
    );
    final versions = detail.files
        .expand((file) => file.supportedDevices)
        .map(normalizeXiaomiWearableCodename)
        .where((value) => value.isNotEmpty)
        .toSet();
    final color = Theme.of(context).colorScheme;
    final statusColor = compatible ? Colors.green : color.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.productDeviceRequirements,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              compatible ? Icons.check_circle : Icons.cancel,
              size: 20,
              color: statusColor,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                compatible
                    ? '${AppLocalizations.of(context)!.compatible} $deviceName'
                    : '${AppLocalizations.of(context)!.incompatible} $deviceName ${AppLocalizations.of(context)!.incompatibleSuffix}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (versions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.productOtherVersions,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: color.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: versions.map((version) {
              final selected = version == codename;
              return Chip(
                label: Text(
                  xiaomiDisplayNameForIdentity(
                    name: version,
                    codename: version,
                  ),
                ),
                backgroundColor: selected
                    ? color.primaryContainer
                    : color.surfaceContainerHighest,
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.child, this.image});
  final Widget child;
  final Uri? image;
  @override
  Widget build(BuildContext context) => Stack(
    children: [
      if (image != null)
        Positioned.fill(
          child: Opacity(
            opacity: .16,
            child: NetworkImgLayer(
              src: image.toString(),
              width: double.infinity,
              height: double.infinity,
            ),
          ),
        ),
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withValues(alpha: .22),
          ),
        ),
      ),
      child,
    ],
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: color.withValues(alpha: .12),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontWeight: FontWeight.w600),
    ),
  );
}

String _typeLabel(
  AppLocalizations l10n,
  CommunityResourceType type, {
  CommunitySourceId? source,
}) => switch (type) {
  CommunityResourceType.quickApp =>
    source == CommunitySourceId.huamiAppStore
        ? l10n.miniprogram
        : l10n.quickApp,
  CommunityResourceType.watchface => l10n.watchface,
  CommunityResourceType.firmware => l10n.firmwareTool,
  CommunityResourceType.fontpack => l10n.fontPack,
  CommunityResourceType.iconpack => l10n.iconPack,
};
String _paidLabel(AppLocalizations l10n, CommunityPaidType type) =>
    switch (type) {
      CommunityPaidType.free => l10n.free,
      CommunityPaidType.paid => l10n.paid,
      CommunityPaidType.forcePaid => l10n.forcePaid,
    };
