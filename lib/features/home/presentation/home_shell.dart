import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/core/theme/tactile.dart';
import 'package:scan2/core/widgets/pressable_scale.dart';
import 'package:scan2/features/home/presentation/app_drawer.dart';
import 'package:scan2/features/library/domain/smart_folder.dart';
import 'package:scan2/features/library/presentation/documents_view.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/pro/domain/scan_quota.dart';
import 'package:scan2/features/pro/presentation/free_scans_used_screen.dart';
import 'package:scan2/features/pro/presentation/pro_gate.dart';
import 'package:scan2/features/pro/presentation/pro_paywall.dart';
import 'package:scan2/features/settings/presentation/app_lock.dart';
import 'package:scan2/features/settings/presentation/settings_screen.dart';
import 'package:scan2/features/shared/providers/db_provider.dart';

/// The app shell: documents, a docked scan button, and a side menu.
///
/// Capture stays under the thumb. Settings is also a bar item so the
/// notch is balanced; About stays in the drawer.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// 0 = Documents, 1 = Settings. Settings is a tab, not a pushed page.
  int _tab = 0;

  /// One notice at a time. The quota can change while one is open, and two
  /// full-screen messages stacked on each other is how an app feels broken.
  bool _noticeOpen = false;

  @override
  void initState() {
    super.initState();
    _checkQuotaNotices();
  }

  /// Home is where the user lands after every scan, so it is where the app
  /// gets to say the allowance refilled or is running low.
  void _checkQuotaNotices() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _noticeOpen) return;
      _noticeOpen = true;
      try {
        await showQuotaNotices(context, ref);
      } finally {
        _noticeOpen = false;
      }
    });
  }

  void _openMenu() => _scaffoldKey.currentState?.openDrawer();

  void _closeDrawer() => _scaffoldKey.currentState?.closeDrawer();

  void _openSettings() {
    _closeDrawer();
    setState(() => _tab = 1);
  }

  void _openAbout() {
    _closeDrawer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showScanellaAbout(context);
    });
  }

  void _contactUs() {
    _closeDrawer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      copySupportEmail(context);
    });
  }

  Future<void> _startScan({bool idCard = false}) async {
    if (!await ensureFreeScanSlot(context, ref)) return;
    if (!mounted) return;
    if (idCard) {
      context.go('/camera', extra: true);
    } else {
      context.go('/camera');
    }
  }

  void _openPro() {
    _closeDrawer();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!ref.read(proProvider).isPro) {
        await ref.read(scanQuotaProvider.notifier).ensureLoaded();
        if (!mounted) return;
        if (!ref.read(scanQuotaProvider).canCreate) {
          // Out of scans already: the used-up screen carries the offer, so
          // showing the paywall on top of it would be the same ask twice.
          await showFreeScansUsed(context, ref);
          return;
        }
      }
      await showProPaywall(context);
    });
  }

  void _openFeatures() {
    _closeDrawer();
    context.push('/features');
  }

  void _openAllDocuments() {
    setState(() => _tab = 0);
    ref.read(smartFolderProvider.notifier).state = null;
    ref.read(openFolderIdProvider.notifier).state = null;
    _closeDrawer();
  }

  Future<void> _openSmartFolder(SmartFolder folder) async {
    _closeDrawer();
    setState(() => _tab = 0);
    // Favorites, Private and IDs are all on the free plan. Pro is only
    // unlimited scans.
    if (folder == SmartFolder.private) {
      final allowed = await ref
          .read(appLockProvider.notifier)
          .authenticateForPrivate();
      if (!allowed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Unlock the phone to open private documents.'),
            ),
          );
        return;
      }
    }
    ref.read(openFolderIdProvider.notifier).state = null;
    ref.read(smartFolderProvider.notifier).state = folder;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isPro = ref.watch(proProvider).isPro;
    final quota = ref.watch(scanQuotaProvider);

    ref.listen<ScanQuota>(scanQuotaProvider, (before, after) {
      if (before?.used == after.used &&
          before?.refreshedAt == after.refreshedAt) {
        return;
      }
      _checkQuotaNotices();
    });

    return Scaffold(
      key: _scaffoldKey,
      extendBody: true,
      backgroundColor: theme.brightness == Brightness.light
          ? Brand.canvas
          : scheme.surface,
      drawer: AppDrawer(
        onSettings: _openSettings,
        onAbout: _openAbout,
        onTrash: () {
          _closeDrawer();
          context.push('/trash');
        },
        onHelp: () {
          _closeDrawer();
          context.push('/help');
        },
        onContact: _contactUs,
        onPro: _openPro,
        onFeatures: _openFeatures,
        onAllDocuments: _openAllDocuments,
        onSmartFolder: _openSmartFolder,
        selectedSmartFolder: ref.watch(smartFolderProvider),
        proSubtitle: isPro ? 'Scanella Pro is on' : quota.freePlanLabel,
      ),
      body: _tab == 0
          ? DocumentsView(
              onOpenMenu: _openMenu,
              onScan: () => _startScan(),
              onAllTools: () => context.push('/tools'),
            )
          : Builder(
              // The bar floats over the body (extendBody), so keep the last
              // settings row above it.
              builder: (context) => Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom,
                ),
                child: MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: const SettingsScreen(),
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      // Hidden while typing so it never sits on top of the search field.
      floatingActionButton: MediaQuery.viewInsetsOf(context).bottom > 0
          ? null
          : _ScanButton(onPressed: () => _startScan()),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(
                alpha: theme.brightness == Brightness.light ? 0.06 : 0.28,
              ),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomAppBar(
          padding: EdgeInsets.zero,
          color: theme.brightness == Brightness.light
              ? Colors.white
              : scheme.surfaceContainerHigh,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          shadowColor: Colors.transparent,
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.folder_rounded,
                  label: 'Documents',
                  selected: _tab == 0,
                  onTap: () => setState(() => _tab = 0),
                ),
              ),
              SizedBox(
                width: 84,
                child: _ScanMeLabel(onPressed: () => _startScan()),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.tune_outlined,
                  label: 'Settings',
                  selected: _tab == 1,
                  onTap: () => setState(() => _tab = 1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The scan target: a rounded square docked in the bar.
///
/// It carries a white collar so the notch reads as deliberate on any
/// background, a gradient rather than a flat fill, and a press that actually
/// depresses — the single most-tapped control in the app is worth the frame.
class _ScanButton extends StatelessWidget {
  const _ScanButton({required this.onPressed});

  final VoidCallback onPressed;

  static const _size = 68.0;
  static const _pad = 4.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final barColor = theme.brightness == Brightness.light
        ? Colors.white
        : scheme.surfaceContainerHigh;
    const innerRadius = Brand.radiusFab;
    const outerRadius = Brand.radiusFab + _pad;

    return PressableScale(
      tooltip: 'Scan me',
      onPressed: onPressed,
      haptic: AppHaptic.impactMedium,
      // Heavier travel than a flat tile: this one is raised, so it should
      // read as being pushed down into the bar.
      scale: Tactile.pressScaleFab,
      overlay: false,
      child: Container(
        width: _size,
        height: _size,
        padding: const EdgeInsets.all(_pad),
        decoration: BoxDecoration(
          color: barColor,
          borderRadius: BorderRadius.circular(outerRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(innerRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(scheme.primary, Colors.white, 0.10) ??
                    scheme.primary,
                scheme.primary,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.20),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.document_scanner_rounded,
              size: 28,
              color: scheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanMeLabel extends StatelessWidget {
  const _ScanMeLabel({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: PressableScale(
          onPressed: onPressed,
          haptic: AppHaptic.impactMedium,
          overlay: false,
          minSize: 0,
          child: Text(
            'Scan me',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;

    final item = Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: color),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (onTap == null) return item;

    return PressableScale(
      onPressed: onTap,
      haptic: AppHaptic.selection,
      scale: Tactile.pressScaleIcon,
      overlay: false,
      child: item,
    );
  }
}
