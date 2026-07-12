import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';

class AcknowledgementItem {
  const AcknowledgementItem({
    required this.name,
    required this.description,
    this.url,
  });

  final String name;
  final String description;
  final String? url;
}

class AcknowledgementsPage extends StatelessWidget {
  const AcknowledgementsPage({super.key});

  List<AcknowledgementItem> _items(AppLocalizations l10n) {
    return [
      AcknowledgementItem(
        name: 'Kazumi',
        description: l10n.acknowledgementsKazumi,
        url: 'https://github.com/Predidit/Kazumi',
      ),
      AcknowledgementItem(
        name: 'AstroBox-Public',
        description: l10n.acknowledgementsAstroBoxPublic,
        url: 'https://github.com/AstralSightStudios/AstroBox-Public',
      ),
      AcknowledgementItem(
        name: 'AstroBox-NG-Module-Core',
        description: l10n.acknowledgementsAstroBoxNgCore,
        url: 'https://github.com/AstralSightStudios/AstroBox-NG-Module-Core',
      ),
      AcknowledgementItem(
        name: 'AstroBox-NG-Module-Bluetooth',
        description: l10n.acknowledgementsAstroBoxNgBluetooth,
        url:
            'https://github.com/AstralSightStudios/AstroBox-NG-Module-Bluetooth',
      ),
      AcknowledgementItem(
        name: 'AstroBox-NG-Module-Account',
        description: l10n.acknowledgementsAstroBoxNgAccount,
        url: 'https://github.com/AstralSightStudios/AstroBox-NG-Module-Account',
      ),
      AcknowledgementItem(
        name: 'AstroBox-NG-Module-Provider',
        description: l10n.acknowledgementsAstroBoxNgProvider,
        url:
            'https://github.com/AstralSightStudios/AstroBox-NG-Module-Provider',
      ),
      AcknowledgementItem(
        name: 'AstroBox-NG-Module-AppWasm',
        description: l10n.acknowledgementsAstroBoxNgAppWasm,
        url: 'https://github.com/AstralSightStudios/AstroBox-NG-Module-AppWasm',
      ),
      AcknowledgementItem(
        name: 'Gadgetbridge',
        description: l10n.acknowledgementsGadgetbridge,
        url: 'https://codeberg.org/Freeyourgadget/Gadgetbridge',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = _items(l10n);

    return Scaffold(
      appBar: SysAppBar(title: Text(l10n.acknowledgements)),
      body: PageContainer(
        padding: EdgeInsets.zero,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(
            horizontal: StyleConstants.pagePadding,
            vertical: StyleConstants.pagePadding,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: item.url == null
                    ? null
                    : () => _launchUrl(context, item.url!),
                borderRadius: BorderRadius.circular(StyleConstants.cardRadius),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              item.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (item.url != null)
                            const Icon(
                              Icons.open_in_new,
                              size: 16,
                              color: Colors.grey,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
