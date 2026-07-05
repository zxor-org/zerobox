import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/app_constants.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';

class AboutSoftwarePage extends StatelessWidget {
  const AboutSoftwarePage({super.key});

  static const _appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0+1',
  );
  static const _buildCommit = String.fromEnvironment(
    'GIT_COMMIT_HASH',
    defaultValue: 'local',
  );

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
                    final columns = constraints.maxWidth >= 720 ? 2 : 1;
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
                          role: member.role,
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
                child: SelectableText(
                  'APP_VERSION: $_appVersion\n'
                  'GIT_COMMIT_HASH: $_buildCommit',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
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
        final wide = constraints.maxWidth >= 720;
        final logo = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/images/app_icon.png',
                width: 64,
                height: 64,
                fit: BoxFit.cover,
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
          alignment: wide ? WrapAlignment.end : WrapAlignment.start,
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
          padding: EdgeInsets.only(top: wide ? 24 : 8, bottom: wide ? 36 : 20),
          child: Flex(
            direction: wide ? Axis.horizontal : Axis.vertical,
            crossAxisAlignment: wide
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (wide) Expanded(child: logo) else logo,
              if (wide)
                const SizedBox(width: 24)
              else
                const SizedBox(height: 18),
              Align(
                alignment: wide ? Alignment.centerRight : Alignment.centerLeft,
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
