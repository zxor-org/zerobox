import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/app_constants.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/core/logging/file_log_sink.dart';
import 'package:zerobox/src/core/services/build_info_service.dart';

class AboutSoftwarePage extends StatelessWidget {
  const AboutSoftwarePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: SysAppBar(title: Text(l10n.settingsAboutSoftware)),
      body: SingleChildScrollView(
        child: PageContainer(
          maxWidth: 1000,
          padding: const EdgeInsets.symmetric(
            horizontal: StyleConstants.pagePadding,
            vertical: 24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AboutHeader(
                title: 'ZeroBox',
                subtitle: l10n.settingsAboutSoftwareTagline,
                repositoryLabel: l10n.settingsAboutSoftwareRepository,
                licenseLabel: l10n.openSourceLicenses,
                onOpenRepository: () => _openUrl(AppConstants.githubRepoUrl),
                onOpenLicense: () =>
                    _openUrl('${AppConstants.githubRepoUrl}/blob/main/LICENSE'),
              ),
              const SizedBox(height: 12),
              _Section(
                icon: Icons.people_alt_outlined,
                title: l10n.settingsAboutSoftwareTeam,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final useTwoColumns = constraints.maxWidth >= 720;
                    final columns = useTwoColumns ? 2 : 1;
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: AppConstants.teamMembers.length,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 72,
                      ),
                      itemBuilder: (context, index) {
                        final member = AppConstants.teamMembers[index];
                        return _TeamMemberTile(
                          name: member.name,
                          role: _roleLabel(l10n, member.role),
                          avatarAsset: member.avatarAsset,
                          onTap: () => _openUrl(member.githubUrl),
                        );
                      },
                    );
                  },
                ),
              ),
              _Section(
                icon: Icons.article_outlined,
                title: l10n.changelog,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsAboutSoftwareReleaseName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.settingsAboutSoftwareReleaseBody,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              _Section(
                icon: Icons.terminal_outlined,
                title: l10n.settingsAboutSoftwareBuildInfo,
                child: FutureBuilder<String>(
                  future: BuildInfoService.resolveCommitHash(),
                  builder: (context, snapshot) {
                    final commit = snapshot.data ?? 'local';
                    return SelectableText(
                      'APP_VERSION: ${BuildInfoService.appVersion}\n'
                      'GIT_COMMIT_HASH: $commit',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    );
                  },
                ),
              ),
              _Section(
                icon: Icons.folder_outlined,
                title: l10n.settingsAboutLogs,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.settingsAboutLogsDescription,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (dialogContext) =>
                              _LogDisclosureDialog(l10n: l10n),
                        );
                        if (confirmed != true || !context.mounted) return;
                        final opened = await openLogDirectory();
                        if (!opened && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.settingsAboutLogsOpenFailed),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.folder_open_outlined),
                      label: Text(l10n.settingsAboutLogsOpen),
                    ),
                  ],
                ),
              ),
              Text(
                l10n.settingsAboutSoftwareCopyright,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _roleLabel(AppLocalizations l10n, TeamRole role) {
    return switch (role) {
      TeamRole.mainDeveloperDesigner => l10n.settingsTeamRoleMain,
      TeamRole.zeppOSImplementation => l10n.settingsTeamRoleZeppOS,
    };
  }
}

class _LogDisclosureDialog extends StatefulWidget {
  const _LogDisclosureDialog({required this.l10n});

  final AppLocalizations l10n;

  @override
  State<_LogDisclosureDialog> createState() => _LogDisclosureDialogState();
}

class _LogDisclosureDialogState extends State<_LogDisclosureDialog> {
  static const _countdownSeconds = 5;
  Timer? _timer;
  var _remainingSeconds = _countdownSeconds;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        setState(() => _remainingSeconds = 0);
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final confirmLabel = _remainingSeconds > 0
        ? '${widget.l10n.understood}(${_remainingSeconds}s)'
        : widget.l10n.understood;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: Text(widget.l10n.settingsAboutLogsWarningTitle),
        content: Text(widget.l10n.settingsAboutLogsWarningMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(widget.l10n.cancel),
          ),
          TextButton(
            onPressed: _remainingSeconds == 0
                ? () => Navigator.pop(context, true)
                : null,
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }
}

class _AboutHeader extends StatelessWidget {
  const _AboutHeader({
    required this.title,
    required this.subtitle,
    required this.repositoryLabel,
    required this.licenseLabel,
    required this.onOpenRepository,
    required this.onOpenLicense,
  });

  final String title;
  final String subtitle;
  final String repositoryLabel;
  final String licenseLabel;
  final VoidCallback onOpenRepository;
  final VoidCallback onOpenLicense;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final useHorizontalHeader = constraints.maxWidth >= 720;
        final logo = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: SvgPicture.asset(
                    'assets/images/app_icon.svg',
                    width: 60,
                    height: 60,
                    colorMapper: _AppIconColorMapper(colorScheme),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: useHorizontalHeader
              ? WrapAlignment.end
              : WrapAlignment.start,
          children: [
            FilledButton.tonalIcon(
              onPressed: onOpenRepository,
              icon: const Icon(Icons.code_outlined),
              label: Text(repositoryLabel),
            ),
            OutlinedButton.icon(
              onPressed: onOpenLicense,
              icon: const Icon(Icons.description_outlined),
              label: Text(licenseLabel),
            ),
          ],
        );

        return Padding(
          padding: EdgeInsets.only(
            top: useHorizontalHeader ? 24 : 8,
            bottom: useHorizontalHeader ? 36 : 20,
          ),
          child: Flex(
            direction: useHorizontalHeader ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: useHorizontalHeader
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (useHorizontalHeader) Expanded(child: logo) else logo,
              if (useHorizontalHeader)
                const SizedBox(width: 24)
              else
                const SizedBox(height: 18),
              Align(
                alignment: useHorizontalHeader
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: actions,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _AppIconColorMapper extends ColorMapper {
  const _AppIconColorMapper(this.colorScheme);

  final ColorScheme colorScheme;

  @override
  Color substitute(
    String? id,
    String elementName,
    String attributeName,
    Color color,
  ) {
    return switch (color) {
      const Color(0xFF211A1B) => colorScheme.surface,
      const Color(0xFF744550) => colorScheme.primaryContainer,
      const Color(0xFFF4B6C3) => colorScheme.primary,
      const Color(0xFFFFD8EF) => colorScheme.onPrimaryContainer,
      _ => color,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is _AppIconColorMapper && other.colorScheme == colorScheme;
  }

  @override
  int get hashCode => colorScheme.hashCode;
}

class _TeamMemberTile extends StatelessWidget {
  const _TeamMemberTile({
    required this.name,
    required this.role,
    required this.avatarAsset,
    required this.onTap,
  });

  final String name;
  final String role;
  final String avatarAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                avatarAsset,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    role,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            SvgPicture.asset(
              'assets/images/brands/github.svg',
              width: 20,
              height: 20,
              colorFilter: ColorFilter.mode(
                Theme.of(context).colorScheme.onSurfaceVariant,
                BlendMode.srcIn,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
