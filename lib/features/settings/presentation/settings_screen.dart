import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:scan2/core/branding.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/tactile.dart';
import 'package:scan2/core/widgets/pressable_scale.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/crop/domain/image_processor.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/pro/presentation/pro_paywall.dart';
import 'package:scan2/features/settings/presentation/app_lock.dart';
import 'package:scan2/features/shared/providers/settings_provider.dart';

/// Shared About screen used by Settings and the side menu.
///
/// Version and the on-device line only — not Flutter's package licence list.
Future<void> showScanellaAbout(BuildContext context) async {
  var version = '';
  try {
    final info = await PackageInfo.fromPlatform().timeout(
      const Duration(milliseconds: 300),
    );
    final name = info.version.trim();
    final build = info.buildNumber.trim();
    if (name.isNotEmpty && build.isNotEmpty) {
      version = '$name ($build)';
    } else if (name.isNotEmpty) {
      version = name;
    }
  } catch (_) {}
  if (!context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ScanellaAboutScreen(version: version),
    ),
  );
}

/// Put the support address on the clipboard and say so.
///
/// Copying rather than opening a mail app: there is no url_launcher here, and
/// a phone without a mail account set up would swallow the tap silently.
Future<void> copySupportEmail(BuildContext context) async {
  await Clipboard.setData(const ClipboardData(text: AppIdentity.supportEmail));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('${AppIdentity.supportEmail} copied'),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// Name, mark, version, and the on-device promise. No licence catalogue.
class ScanellaAboutScreen extends StatelessWidget {
  const ScanellaAboutScreen({super.key, required this.version});

  final String version;

  static const legalese = 'Scans stay on your device. Nothing is uploaded.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.35,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
          child: Column(
            children: [
              const ScanellaWordmark(fontSize: 28),
              const SizedBox(height: 20),
              const ScanellaAppMark(size: 72),
              if (version.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(version, style: muted),
              ],
              const SizedBox(height: 14),
              Text(legalese, textAlign: TextAlign.center, style: muted),
              const SizedBox(height: 14),
              Text(
                AppIdentity.supportEmail,
                textAlign: TextAlign.center,
                style: muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final lock = ref.watch(appLockProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
          children: [
            const _SectionLabel('Scanella Pro'),
            _Group(
              children: [
                _InfoRow(
                  icon: Icons.workspace_premium_rounded,
                  tint: Brand.accent,
                  title: settingsProTitle(ref),
                  subtitle: settingsProSubtitle(ref),
                  onTap: () => showProPaywall(context),
                ),
              ],
            ),

            const _SectionLabel('Default enhancement'),
            _Group(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
                  child: Text(
                    'Applied to new scans. Change it per page any time.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final filter in ScanFilter.values)
                        ChoiceChip(
                          label: Text(ImageProcessor.labelFor(filter)),
                          selected: settings.defaultFilter == filter,
                          onSelected: (_) {
                            AppHaptics.selection();
                            notifier.setDefaultFilter(filter);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const _SectionLabel('Appearance'),
            _Group(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          label: Text('System'),
                          icon: Icon(Icons.phone_iphone_rounded, size: 16),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode_rounded, size: 16),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode_rounded, size: 16),
                        ),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (selection) {
                        AppHaptics.selection();
                        notifier.setThemeMode(selection.first);
                      },
                    ),
                  ),
                ),
              ],
            ),

            const _SectionLabel('Privacy'),
            _Group(
              children: [
                _SwitchRow(
                  icon: Icons.lock_rounded,
                  tint: Brand.accent,
                  title: 'App lock',
                  subtitle: 'PIN, and Face ID when the phone offers it',
                  value: lock.enabled,
                  onChanged: (value) async {
                    final controller = ref.read(appLockProvider.notifier);
                    if (value) {
                      final pin = await promptNewPin(context);
                      if (pin != null) await controller.setPin(pin);
                    } else {
                      await controller.disable();
                    }
                  },
                ),
                _SwitchRow(
                  icon: Icons.face_retouching_natural_rounded,
                  tint: Brand.docBlue,
                  title: 'Face ID / fingerprint',
                  subtitle: 'Used when App lock is on',
                  value: lock.useBiometrics,
                  onChanged: lock.enabled
                      ? (value) => ref
                            .read(appLockProvider.notifier)
                            .setUseBiometrics(value)
                      : null,
                  last: true,
                ),
              ],
            ),

            const _SectionLabel('About'),
            _Group(
              children: [
                const _InfoRow(
                  icon: Icons.lock_rounded,
                  tint: Brand.accent,
                  title: 'Everything stays on your device',
                  subtitle: 'No accounts, no uploads.',
                ),
                const Divider(indent: 68, endIndent: 16),
                _InfoRow(
                  icon: Icons.gavel_rounded,
                  tint: Brand.ink,
                  title: 'Terms of Use',
                  subtitle: 'How you may use Scanella',
                  onTap: () => context.push('/legal/terms'),
                ),
                const Divider(indent: 68, endIndent: 16),
                _InfoRow(
                  icon: Icons.policy_rounded,
                  tint: Brand.docBlue,
                  title: 'Privacy Policy',
                  subtitle: 'What stays on this device',
                  onTap: () => context.push('/legal/privacy'),
                ),
                const Divider(indent: 68, endIndent: 16),
                _InfoRow(
                  icon: Icons.mail_rounded,
                  tint: Brand.accent,
                  title: 'Contact us',
                  subtitle: AppIdentity.supportEmail,
                  onTap: () => copySupportEmail(context),
                ),
                const Divider(indent: 68, endIndent: 16),
                _InfoRow(
                  icon: Icons.info_rounded,
                  tint: Brand.docBlue,
                  title: 'About Scanella',
                  subtitle: 'Version',
                  onTap: () => showScanellaAbout(context),
                ),
              ],
            ),

            const SizedBox(height: 28),
            Center(
              child: Opacity(
                opacity: 0.55,
                child: Column(
                  children: [
                    const ScanellaWordmark(fontSize: 17),
                    const SizedBox(height: 4),
                    Text(
                      'Offline document scanner',
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String settingsProTitle(WidgetRef ref) {
  return ref.watch(proProvider).isPro ? 'Scanella Pro is on' : 'Upgrade to Pro';
}

String settingsProSubtitle(WidgetRef ref) {
  final offer = ref.watch(proProvider).offer;
  if (ref.watch(proProvider).isPro) {
    return 'Advanced OCR, organisation, private files and export';
  }
  if (offer == null) {
    return 'Prices in your currency';
  }
  return '${offer.monthlyLabel} / month · ${offer.yearlyLabel} / year';
}

/// A quiet section label. Loud coloured headings make a settings list look
/// like a form; these should recede and let the groups do the structuring.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 26, 4, 10),
      child: Text(
        label.toUpperCase(),
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.9,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Rows grouped into one rounded surface, the shape people expect settings to
/// take on a phone.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Material rather than a DecoratedBox: rows paint their ink splashes on
    // the nearest Material ancestor, and a plain coloured box in between
    // swallows the tap feedback entirely.
    return Material(
      color: theme.brightness == Brightness.light
          ? Colors.white
          : theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Brand.radiusCard),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(children: children),
    );
  }
}

/// The rounded, tinted icon tile every settings row leads with.
///
/// A bare glyph in the accent colour makes every row look equally important;
/// a tinted tile gives the list a spine to scan down and lets each row own a
/// colour.
class _RowIcon extends StatelessWidget {
  const _RowIcon({required this.icon, required this.tint, this.enabled = true});

  final IconData icon;
  final Color tint;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? tint : Theme.of(context).disabledColor;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, size: 19, color: color),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.last = false,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onChanged != null;
    final text = subtitle;
    final change = onChanged;

    return Column(
      children: [
        SwitchListTile(
          value: value,
          onChanged: change == null
              ? null
              : (next) {
                  AppHaptics.selection();
                  change(next);
                },
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
          secondary: _RowIcon(icon: icon, tint: tint, enabled: enabled),
          title: Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: enabled ? null : theme.disabledColor,
            ),
          ),
          subtitle: text == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(text, style: theme.textTheme.labelSmall),
                ),
        ),
        if (!last) const Divider(indent: 68, endIndent: 16),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PressableScale(
      onPressed: onTap,
      enabled: onTap != null,
      haptic: AppHaptic.selection,
      scale: Tactile.pressScaleCard,
      overlay: onTap != null,
      minSize: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Row(
          children: [
            _RowIcon(icon: icon, tint: tint),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 3),
                  Text(subtitle, style: theme.textTheme.labelSmall),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: theme.colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }
}
