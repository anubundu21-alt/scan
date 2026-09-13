import 'package:flutter/material.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/core/theme/tactile.dart';
import 'package:scan2/core/widgets/pressable_scale.dart';
import 'package:scan2/features/library/domain/smart_folder.dart';

/// Side menu: Scanella Pro, Complete features, library folders, then App.
class AppDrawer extends StatelessWidget {
  const AppDrawer({
    super.key,
    required this.onSettings,
    required this.onAbout,
    required this.onTrash,
    required this.onHelp,
    required this.onPro,
    required this.onFeatures,
    required this.onAllDocuments,
    required this.onSmartFolder,
    required this.proSubtitle,
    this.selectedSmartFolder,
  });

  final VoidCallback onSettings;
  final VoidCallback onAbout;
  final VoidCallback onTrash;
  final VoidCallback onHelp;
  final VoidCallback onPro;
  final VoidCallback onFeatures;
  final VoidCallback onAllDocuments;
  final ValueChanged<SmartFolder> onSmartFolder;
  final String proSubtitle;
  final SmartFolder? selectedSmartFolder;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return Drawer(
      width: (width * 0.82).clamp(280.0, 320.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _DrawerHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 36),
              children: [
                _DrawerTile(
                  icon: Icons.workspace_premium_rounded,
                  tint: Brand.amber,
                  title: 'Scanella Pro',
                  subtitle: proSubtitle,
                  selected: false,
                  onTap: onPro,
                ),
                const SizedBox(height: 6),
                _DrawerTile(
                  icon: Icons.checklist_rounded,
                  tint: Brand.accent,
                  title: 'Complete features',
                  subtitle: 'Free, Pro, and prices',
                  selected: false,
                  onTap: onFeatures,
                ),
                const _DrawerSection('Library'),
                _DrawerTile(
                  icon: Icons.folder_rounded,
                  tint: Brand.docBlue,
                  title: 'All documents',
                  subtitle: 'Home list',
                  selected: selectedSmartFolder == null,
                  onTap: onAllDocuments,
                ),
                for (final folder in SmartFolder.inDrawer) ...[
                  const SizedBox(height: 6),
                  _DrawerTile(
                    icon: folder.icon,
                    tint: Brand.accent,
                    title: folder.label,
                    subtitle: folder.drawerSubtitle,
                    selected: selectedSmartFolder == folder,
                    onTap: () => onSmartFolder(folder),
                  ),
                ],
                const _DrawerSection('App'),
                _DrawerTile(
                  icon: Icons.delete_outline_rounded,
                  tint: Brand.amber,
                  title: 'Trash',
                  subtitle: 'Recover scans for 30 days',
                  onTap: onTrash,
                ),
                const SizedBox(height: 6),
                _DrawerTile(
                  icon: Icons.tune_rounded,
                  tint: Brand.accent,
                  title: 'Settings',
                  subtitle: 'Camera, lock, appearance',
                  onTap: onSettings,
                ),
                const SizedBox(height: 6),
                _DrawerTile(
                  icon: Icons.help_outline_rounded,
                  tint: Brand.accent,
                  title: 'Help',
                  subtitle: 'Camera, PDFs, lock',
                  onTap: onHelp,
                ),
                const SizedBox(height: 6),
                _DrawerTile(
                  icon: Icons.info_rounded,
                  tint: Brand.docBlue,
                  title: 'About',
                  subtitle: 'Version details',
                  onTap: onAbout,
                ),
                const SizedBox(height: 18),
                Text(
                  'Offline document scanner',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerSection extends StatelessWidget {
  const _DrawerSection(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 18, 10, 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _DrawerHeader extends StatelessWidget {
  const _DrawerHeader();

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.dark,
      child: Material(
        color: Brand.ink,
        child: SafeArea(
          bottom: false,
          child: Builder(
            builder: (context) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
                child: Row(
                  children: [
                    const ScanellaAppMark(size: 48),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ScanellaWordmark(fontSize: 22, onDark: true),
                          const SizedBox(height: 4),
                          Text(
                            'Scans stay on this device',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: Brand.greyOnDark),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  const _DrawerTile({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.selected = false,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PressableScale(
      onPressed: onTap,
      haptic: AppHaptic.selection,
      scale: Tactile.pressScaleCard,
      borderRadius: BorderRadius.circular(16),
      minSize: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 19, color: tint),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(subtitle, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
