import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/utils/layout.dart';

class CreatorEditorShell extends StatefulWidget {
  const CreatorEditorShell({super.key});

  @override
  State<CreatorEditorShell> createState() => _CreatorEditorShellState();
}

class _CreatorEditorShellState extends State<CreatorEditorShell> {
  int _currentStep = 0;

  final List<IconData> _icons = [
    Icons.info_outline,
    Icons.folder_zip_outlined,
    Icons.watch_outlined,
    Icons.link_outlined,
    Icons.publish_outlined,
    Icons.preview_outlined,
    Icons.fact_check_outlined,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final titles = [
      l10n.basicInfo,
      l10n.packageFiles,
      l10n.deviceSelection,
      l10n.deviceFileMapping,
      l10n.publishTargets,
      l10n.publishPreview,
      l10n.reviewStatus,
    ];

    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text('${l10n.newResource} · ${titles[_currentStep]}'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [TextButton(onPressed: () {}, child: Text(l10n.drafts))],
      ),
      body: Row(
        children: [
          if (useWideLayout(MediaQuery.sizeOf(context).width))
            NavigationRail(
              selectedIndex: _currentStep,
              onDestinationSelected: (index) =>
                  setState(() => _currentStep = index),
              labelType: NavigationRailLabelType.all,
              destinations: List.generate(titles.length, (index) {
                return NavigationRailDestination(
                  icon: Icon(_icons[index]),
                  selectedIcon: Icon(_icons[index]),
                  label: Text(titles[index]),
                );
              }),
            ),
          Expanded(
            child: Stepper(
              type: StepperType.vertical,
              currentStep: _currentStep,
              onStepTapped: (index) => setState(() => _currentStep = index),
              onStepContinue: () {
                if (_currentStep < titles.length - 1) {
                  setState(() => _currentStep++);
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() => _currentStep--);
                }
              },
              steps: [
                _buildStep(
                  title: l10n.basicInfo,
                  content: const _BasicInfoForm(),
                ),
                _buildStep(
                  title: l10n.packageFiles,
                  content: const _PackageFilesForm(),
                ),
                _buildStep(
                  title: l10n.deviceSelection,
                  content: const _DeviceSelectionForm(),
                ),
                _buildStep(
                  title: l10n.deviceFileMapping,
                  content: const _DeviceMappingForm(),
                ),
                _buildStep(
                  title: l10n.publishTargets,
                  content: const _PublishTargetsForm(),
                ),
                _buildStep(
                  title: l10n.publishPreview,
                  content: const _PublishPreviewForm(),
                ),
                _buildStep(
                  title: l10n.reviewStatus,
                  content: const _ReviewStatusForm(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Step _buildStep({required String title, required Widget content}) {
    return Step(
      title: Text(title),
      content: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: content,
      ),
    );
  }
}

class _BasicInfoForm extends StatelessWidget {
  const _BasicInfoForm();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(decoration: InputDecoration(labelText: 'Resource name')),
        const SizedBox(height: 12),
        TextField(decoration: InputDecoration(labelText: 'Author name')),
        const SizedBox(height: 12),
        DropdownButtonFormField(
          decoration: InputDecoration(labelText: 'Resource type'),
          items: const [
            DropdownMenuItem(value: 'watchface', child: Text('Watchface')),
            DropdownMenuItem(value: 'quickapp', child: Text('Quick App')),
            DropdownMenuItem(value: 'firmware', child: Text('Firmware')),
          ],
          onChanged: (_) {},
        ),
        const SizedBox(height: 12),
        TextField(decoration: InputDecoration(labelText: 'Version')),
        const SizedBox(height: 12),
        TextField(
          decoration: InputDecoration(labelText: 'Description'),
          maxLines: 3,
        ),
        const SizedBox(height: 12),
        TextField(decoration: InputDecoration(labelText: 'Tags')),
      ],
    );
  }
}

class _PackageFilesForm extends StatelessWidget {
  const _PackageFilesForm();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('Add .rpk / .face'),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.insert_drive_file),
            title: const Text('minimal-dark-1.2.face'),
            subtitle: const Text('1.2 MB · SHA256: a1b2...c3d4'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {},
            ),
          ),
        ),
      ],
    );
  }
}

class _DeviceSelectionForm extends StatelessWidget {
  const _DeviceSelectionForm();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton(
          segments: const [
            ButtonSegment(value: 'all', label: Text('All')),
            ButtonSegment(value: 'vela', label: Text('VelaOS')),
            ButtonSegment(value: 'zepp', label: Text('ZeppOS')),
          ],
          selected: const {'all'},
          onSelectionChanged: (_) {},
        ),
        const SizedBox(height: 16),
        CheckboxListTile(
          value: true,
          onChanged: (_) {},
          title: const Text('Amazfit GTR 4'),
          subtitle: const Text('ZeppOS · Xiaomi'),
        ),
        CheckboxListTile(
          value: false,
          onChanged: (_) {},
          title: const Text('Redmi Watch 4'),
          subtitle: const Text('VelaOS · Xiaomi'),
        ),
      ],
    );
  }
}

class _DeviceMappingForm extends StatelessWidget {
  const _DeviceMappingForm();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: ListTile(
            title: const Text('Amazfit GTR 4'),
            subtitle: const Text('minimal-dark-1.2.face · v1.2.0'),
            trailing: IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {},
            ),
          ),
        ),
      ],
    );
  }
}

class _PublishTargetsForm extends StatelessWidget {
  const _PublishTargetsForm();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CheckboxListTile(
          value: true,
          onChanged: (_) {},
          title: const Text('ZeroBox Platform'),
        ),
        CheckboxListTile(
          value: false,
          onChanged: (_) {},
          title: const Text('BandBBS'),
        ),
        CheckboxListTile(
          value: true,
          onChanged: (_) {},
          title: const Text('AstroBox GitHub'),
        ),
        CheckboxListTile(
          value: false,
          onChanged: (_) {},
          title: const Text('Personal GitHub Token'),
        ),
        CheckboxListTile(
          value: false,
          onChanged: (_) {},
          title: const Text('zerobox-community Proxy'),
        ),
      ],
    );
  }
}

class _PublishPreviewForm extends StatelessWidget {
  const _PublishPreviewForm();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Repositories to create / update'),
        const Text('AstroBox devices: Amazfit GTR 4'),
        const Text('Files to upload: 1'),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Manifest preview',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text('{\n  "name": "Minimal Dark",\n  "version": "1.2.0"\n}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.send),
          label: const Text('Confirm Submit'),
        ),
      ],
    );
  }
}

class _ReviewStatusForm extends StatelessWidget {
  const _ReviewStatusForm();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _StatusTimelineTile(
          title: 'Submitted',
          subtitle: 'Waiting for auto check',
          isActive: true,
          isDone: true,
        ),
        const _StatusTimelineTile(
          title: 'Auto checking',
          subtitle: 'In progress',
          isActive: true,
          isDone: false,
        ),
        const _StatusTimelineTile(
          title: 'Pending review',
          subtitle: 'Queue position 3',
          isActive: false,
          isDone: false,
        ),
        const _StatusTimelineTile(
          title: 'Published',
          subtitle: 'Not yet',
          isActive: false,
          isDone: false,
        ),
      ],
    );
  }
}

class _StatusTimelineTile extends StatelessWidget {
  const _StatusTimelineTile({
    required this.title,
    required this.subtitle,
    required this.isActive,
    required this.isDone,
  });

  final String title;
  final String subtitle;
  final bool isActive;
  final bool isDone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = isDone
        ? Colors.green
        : isActive
        ? colorScheme.primary
        : colorScheme.outline;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            isDone ? Icons.check_circle : Icons.circle_outlined,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
