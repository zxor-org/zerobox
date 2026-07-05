import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/widgets/network_img_layer.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/status_chips.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/data/astrobox/astrobox_providers.dart';
import 'package:zerobox/src/data/astrobox/models/astrobox_models.dart';
import 'package:zerobox/src/device/core/xiaomi_wearable_catalog.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/features/resources/services/download_queue_notifier.dart';

class ResourceDetailPage extends ConsumerWidget {
  const ResourceDetailPage({super.key, required this.item});

  final AstroBoxIndexItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final manifestAsync = ref.watch(astroBoxManifestProvider(item));

    return Scaffold(
      appBar: SysAppBar(title: Text(item.name)),
      body: manifestAsync.when(
        data: (manifest) {
          if (manifest == null) {
            return Center(child: Text(l10n.notFound));
          }
          return _ResourceDetailContent(item: item, manifest: manifest);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('${l10n.error}: $err')),
      ),
    );
  }
}

class _ResourceDetailContent extends ConsumerWidget {
  const _ResourceDetailContent({required this.item, required this.manifest});

  final AstroBoxIndexItem item;
  final AstroBoxManifest manifest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final repo = ref.watch(astroBoxRepositoryProvider);
    final deviceState = ref.watch(deviceManagerProvider);
    final currentDevice = deviceState.currentDevice;
    final currentCodename = currentDevice?.codename;
    final isReady = deviceState.protocolState.name == 'ready';

    final iconUrl = repo.resolveImageUrl(item, manifest.item.icon);
    final coverUrl = repo.resolveImageUrl(item, manifest.item.cover);
    final previewUrls = manifest.item.preview
        .map((p) => repo.resolveImageUrl(item, p))
        .where((u) => u.isNotEmpty)
        .toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _DetailHero(
          coverUrl: coverUrl.isNotEmpty ? coverUrl : previewUrls.firstOrNull,
          child: PageContainer(
            padding: const EdgeInsets.fromLTRB(
              StyleConstants.pagePadding,
              20,
              StyleConstants.pagePadding,
              24,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 720;
                final titleBlock = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Hero(
                      tag: 'resource-icon-${item.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: NetworkImgLayer(
                          src: iconUrl,
                          width: wide ? 88 : 72,
                          height: wide ? 88 : 72,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _AuthorLinks(
                            authors: manifest.item.author,
                            fallback: item.repoOwner,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _ResourceTypeChip(type: item.type, l10n: l10n),
                              _PaidTypeChip(paidType: item.paidType),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                if (!wide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [titleBlock],
                  );
                }

                return titleBlock;
              },
            ),
          ),
        ),
        PageContainer(
          padding: const EdgeInsets.symmetric(
            horizontal: StyleConstants.pagePadding,
            vertical: StyleConstants.pagePadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (manifest.item.description.isNotEmpty) ...[
                Text(
                  manifest.item.description,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _ProductActions(
                item: item,
                manifest: manifest,
                currentCodename: currentCodename,
                isReady: isReady,
                links: manifest.links,
              ),
              const SizedBox(height: 22),
              if (previewUrls.isNotEmpty) ...[
                SectionHeader(title: l10n.preview),
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: previewUrls.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      return Card(
                        elevation: 0,
                        margin: EdgeInsets.zero,
                        clipBehavior: Clip.antiAlias,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            StyleConstants.cardRadius,
                          ),
                        ),
                        child: NetworkImgLayer(
                          src: previewUrls[index],
                          width: 320,
                          height: 220,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: StyleConstants.sectionSpacing),
              ],
              _DeviceRequirementNote(
                currentDeviceName: currentDevice?.name.toString(),
                currentCodename: currentCodename,
                downloads: manifest.downloads,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.child, this.coverUrl});

  final Widget child;
  final String? coverUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.22),
            ),
          ),
        ),
        if (coverUrl?.isNotEmpty == true)
          Positioned.fill(
            child: Opacity(
              opacity: Theme.of(context).brightness == Brightness.dark
                  ? 0.24
                  : 0.18,
              child: NetworkImgLayer(
                src: coverUrl,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  colorScheme.surface.withValues(alpha: 0.10),
                  colorScheme.surface,
                ],
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _AuthorLinks extends StatelessWidget {
  const _AuthorLinks({required this.authors, required this.fallback});

  final List<AstroBoxManifestAuthor> authors;
  final String fallback;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveAuthors = authors.where((a) => a.name.isNotEmpty).toList();
    final displayAuthors = effectiveAuthors.isEmpty
        ? [AstroBoxManifestAuthor(name: fallback)]
        : effectiveAuthors;

    return Wrap(
      spacing: 8,
      children: displayAuthors.map((author) {
        return Text(
          '@${author.name}',
          style: textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        );
      }).toList(),
    );
  }
}

class _ResourceTypeChip extends StatelessWidget {
  const _ResourceTypeChip({required this.type, required this.l10n});

  final AstroBoxResourceType type;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final label = switch (type) {
      AstroBoxResourceType.quickApp => l10n.quickApp,
      AstroBoxResourceType.watchface => l10n.watchface,
      AstroBoxResourceType.firmware => l10n.firmwareTool,
      AstroBoxResourceType.fontpack => l10n.fontPack,
      AstroBoxResourceType.iconpack => l10n.iconPack,
    };
    return StatusChip(label: label);
  }
}

class _PaidTypeChip extends StatelessWidget {
  const _PaidTypeChip({required this.paidType});

  final AstroBoxPaidType paidType;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final (label, color) = switch (paidType) {
      AstroBoxPaidType.free => (l10n.free, Colors.green),
      AstroBoxPaidType.paid => (l10n.paid, colorScheme.tertiary),
      AstroBoxPaidType.forcePaid => (l10n.forcePaid, colorScheme.error),
    };
    return StatusChip(label: label, color: color);
  }
}

class _ProductActions extends StatelessWidget {
  const _ProductActions({
    required this.item,
    required this.manifest,
    required this.currentCodename,
    required this.isReady,
    required this.links,
  });

  final AstroBoxIndexItem item;
  final AstroBoxManifest manifest;
  final String? currentCodename;
  final bool isReady;
  final List<AstroBoxManifestLink> links;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = constraints.maxWidth < 520;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: mobile ? double.infinity : null,
              child: _DownloadButton(
                item: item,
                manifest: manifest,
                currentCodename: currentCodename,
                isReady: isReady,
                expand: mobile,
              ),
            ),
            if (links.isNotEmpty) _ShareLinks(links: links),
          ],
        );
      },
    );
  }
}

class _DownloadButton extends ConsumerWidget {
  const _DownloadButton({
    required this.item,
    required this.manifest,
    required this.currentCodename,
    required this.isReady,
    required this.expand,
  });

  final AstroBoxIndexItem item;
  final AstroBoxManifest manifest;
  final String? currentCodename;
  final bool isReady;
  final bool expand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final downloads = manifest.downloads.entries.toList();
    if (downloads.isEmpty) return const SizedBox.shrink();

    final showDefault =
        currentCodename != null &&
        manifest.downloads.containsKey(currentCodename);
    final currentEntry = showDefault
        ? manifest.downloads.entries.firstWhere(
            (entry) => entry.key == currentCodename,
          )
        : null;
    final inQueue = ref.watch(
      downloadQueueProvider.select(
        (tasks) => tasks.any(
          (task) =>
              task.item.id == item.id &&
              task.status != ResourceTaskStatus.completed,
        ),
      ),
    );
    final canInstall = isReady && !inQueue;
    final colorScheme = Theme.of(context).colorScheme;

    void enqueue(MapEntry<String, AstroBoxManifestDownload> entry) {
      ref
          .read(downloadQueueProvider.notifier)
          .enqueue(
            item: item,
            manifest: manifest,
            download: entry.value,
            codename: entry.key,
          );
    }

    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      menuChildren: downloads.map((entry) {
        return MenuItemButton(
          onPressed: canInstall ? () => enqueue(entry) : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
            child: Text(
              _downloadDeviceName(entry.key, entry.value),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }).toList(),
      builder: (context, controller, child) {
        final width = expand ? double.infinity : 190.0;
        final buttonText = inQueue ? l10n.productInQueue : l10n.install;
        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Material(
            color: canInstall
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            child: SizedBox(
              width: width,
              height: 48,
              child: Row(
                children: [
                  if (showDefault && currentEntry != null) ...[
                    Expanded(
                      child: InkWell(
                        onTap: canInstall ? () => enqueue(currentEntry) : null,
                        child: _DownloadButtonContent(
                          label: buttonText,
                          color: colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 28,
                      child: VerticalDivider(
                        width: 1,
                        color: colorScheme.onPrimaryContainer.withValues(
                          alpha: 0.20,
                        ),
                      ),
                    ),
                    _MenuHandle(
                      enabled: canInstall && downloads.length > 1,
                      onTap: () => _toggleMenu(controller),
                    ),
                  ] else
                    Expanded(
                      child: InkWell(
                        onTap: canInstall
                            ? () => _toggleMenu(controller)
                            : null,
                        child: _DownloadButtonContent(
                          label: buttonText,
                          color: colorScheme.onPrimaryContainer,
                          trailing: const Icon(Icons.arrow_drop_down),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
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

class _DownloadButtonContent extends StatelessWidget {
  const _DownloadButtonContent({
    required this.label,
    required this.color,
    this.trailing,
  });

  final String label;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
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
}

class _MenuHandle extends StatelessWidget {
  const _MenuHandle({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 48,
      height: double.infinity,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Icon(
          Icons.arrow_drop_down,
          color: enabled
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurface.withValues(alpha: 0.38),
        ),
      ),
    );
  }
}

String _downloadDeviceName(
  String codename, [
  AstroBoxManifestDownload? download,
]) {
  final explicitName = download?.displayName?.trim();
  if (explicitName != null && explicitName.isNotEmpty) return explicitName;

  final identity = xiaomiWearableIdentityForCodename(codename);
  return identity?.displayName ?? codename;
}

class _DeviceRequirementNote extends StatelessWidget {
  const _DeviceRequirementNote({
    required this.currentDeviceName,
    required this.currentCodename,
    required this.downloads,
  });

  final String? currentDeviceName;
  final String? currentCodename;
  final Map<String, AstroBoxManifestDownload> downloads;

  @override
  Widget build(BuildContext context) {
    if (currentDeviceName == null || currentCodename == null) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final compatible = downloads.containsKey(currentCodename);
    final color = compatible ? Colors.green : colorScheme.error;
    final icon = compatible ? Icons.check_circle : Icons.cancel;
    final text = compatible
        ? '${l10n.compatible} $currentDeviceName'
        : '${l10n.incompatible} $currentDeviceName ${l10n.incompatibleSuffix}';

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title: l10n.productDeviceRequirements),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.productOtherVersions,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: downloads.entries.map((entry) {
              final selected = entry.key == currentCodename;
              return Chip(
                label: Text(_downloadDeviceName(entry.key, entry.value)),
                backgroundColor: selected
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                side: BorderSide.none,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _ShareLinks extends StatelessWidget {
  const _ShareLinks({required this.links});

  final List<AstroBoxManifestLink> links;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: links.map((link) {
        return ActionChip(
          avatar: link.icon?.isNotEmpty == true
              ? Icon(_linkIcon(link.icon!), color: colorScheme.primary)
              : null,
          label: Text(link.title),
          onPressed: () => _open(link.url),
        );
      }).toList(),
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  IconData _linkIcon(String icon) {
    return switch (icon.toLowerCase()) {
      'github' || 'github-logo' => Icons.code,
      'link' => Icons.link,
      _ => Icons.open_in_new,
    };
  }
}
