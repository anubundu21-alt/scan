import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/pro/domain/scan_quota.dart';
import 'package:scan2/features/shared/providers/onboarding_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shortcuts for walking the paid flow end to end without waiting.
///
/// Compiled in only when the build was made with
/// `--dart-define=SCANELLA_TESTING=true`, so an App Store build has no way
/// to reach any of this. Nothing here grants Pro: buying still goes through
/// the real Apple sheet. What it does is skip the waiting, and pin this
/// iPhone as a new free user somewhere an uninstall cannot wipe.
class TestingTools {
  const TestingTools._();

  static const enabled = bool.fromEnvironment('SCANELLA_TESTING');

  static const _channel = MethodChannel('scanella/pro');

  /// What the device remembers about Pro, in the app's own storage.
  static const entitlementKey = 'scanella.pro.entitled';
  static const trialUsedKey = 'scanella.pro.trial_used';
  static const refreshSeenKey = 'scanella.quota.refresh_seen_ms';
  static const lowSeenKey = 'scanella.quota.low_seen_batch';

  /// Pins this iPhone as a new free user until [listenToStoreAgain].
  ///
  /// The pins live in the Keychain so a delete-and-reinstall still looks
  /// like a first install: Pro off, upgrade screen on, 1 month free shown.
  /// Asking the store is skipped while they are on, because that write
  /// would stamp Pro back and a reinstall would skip those screens again.
  static Future<void> forgetPro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(entitlementKey);
    await prefs.remove(trialUsedKey);
    await prefs.setBool(ProController.testingForceFreeKey, true);
    await prefs.setBool(ProController.testingOfferTrialKey, true);
    await prefs.setBool(OnboardingNotifier.prefsKey, false);
    try {
      await _channel.invokeMethod<void>('writePro', <String, Object?>{
        'entitled': false,
        'untilMs': null,
        'basisMs': null,
      });
      await _channel.invokeMethod<void>('clearTrialUsed');
      await _channel.invokeMethod<void>('writeTestingPins', <String, Object?>{
        'forceFree': true,
        'offerTrial': true,
      });
    } catch (_) {}
  }

  /// Drops the testing pins so the next restore uses the store's answer.
  static Future<void> listenToStoreAgain() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ProController.testingForceFreeKey);
    await prefs.remove(ProController.testingOfferTrialKey);
    try {
      await _channel.invokeMethod<void>('writeTestingPins', <String, Object?>{
        'forceFree': false,
        'offerTrial': false,
      });
    } catch (_) {}
  }

  /// Lets the one-off quota messages appear again.
  static Future<void> forgetNotices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(refreshSeenKey);
    await prefs.remove(lowSeenKey);
  }
}

class TestingToolsScreen extends ConsumerStatefulWidget {
  const TestingToolsScreen({super.key});

  @override
  ConsumerState<TestingToolsScreen> createState() => _TestingToolsScreenState();
}

class _TestingToolsScreenState extends ConsumerState<TestingToolsScreen> {
  String? _note;

  Future<void> _run(String note, Future<void> Function() action) async {
    await action();
    if (!mounted) return;
    setState(() => _note = note);
  }

  Future<void> _setUsed(int used) {
    return _run(
      'Free scans used set to $used.',
      () async {
        await ref.read(scanQuotaProvider.notifier).setUsedForTesting(used);
        await TestingTools.forgetNotices();
      },
    );
  }

  Future<void> _actAsNewFreeUser() {
    return _run(
      'This iPhone is a new free user. The upgrade screen is next.',
      () async {
        await TestingTools.forgetPro();
        await TestingTools.forgetNotices();
        await ref.read(scanQuotaProvider.notifier).resetForNewInstall();
        await ref.read(proProvider.notifier).restore();
        ref.read(onboardingCompletedProvider.notifier).reset();
        if (!mounted) return;
        context.go('/welcome');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final quota = ref.watch(scanQuotaProvider);
    final pro = ref.watch(proProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Testing tools')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Right now', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _Fact('Free scans used', '${quota.used} of ${quota.limit}'),
                  _Fact('Starter pack done', '${quota.starterDone}'),
                  _Fact('Pro', pro.isPro ? 'on' : 'off'),
                  _Fact('Free month taken', '${pro.trialUsed}'),
                  _Fact('Show 1 month free', '${pro.canStartTrial}'),
                  _Fact(
                    'Resets',
                    quota.resetsAt == null
                        ? 'not started'
                        : ScanQuota.formatResetShort(quota.resetsAt!),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Free scans', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _Action(
            label: 'Leave 2 scans',
            detail: 'Jumps to where the running-low screen appears',
            onTap: () => _setUsed(quota.limit - 2),
          ),
          _Action(
            label: 'Use them all',
            detail: 'Jumps to the paywall on the next scan',
            onTap: () => _setUsed(quota.limit),
          ),
          _Action(
            label: 'Give them back',
            detail: 'Back to a full allowance',
            onTap: () => _setUsed(0),
          ),
          const SizedBox(height: 16),
          Text('Pro', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          _Action(
            label: 'Act as a new free user',
            detail:
                'Turns Pro off, shows the 1 month free buttons, and opens '
                'the first-run screens. Survives delete and reinstall. '
                'Menu → Scanella Pro will say how many free scans are left, '
                'not that Pro is on.',
            onTap: _actAsNewFreeUser,
          ),
          _Action(
            label: 'Ask the store again',
            detail: 'Uses Apple’s answer. Pro comes back if the sandbox '
                'subscription is still running, and the free month hides.',
            onTap: () => _run(
              'Asked.',
              () async {
                await TestingTools.listenToStoreAgain();
                await ref.read(proProvider.notifier).restore();
              },
            ),
          ),
          _Action(
            label: 'Show the one-off messages again',
            detail: 'Lets the refill and running-low screens reappear',
            onTap: () => _run(
              'They can appear again.',
              TestingTools.forgetNotices,
            ),
          ),
          if (_note != null) ...[
            const SizedBox(height: 20),
            Text(
              _note!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Brand.accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'The 1 month free buttons are the first-time layout only. This '
            'Apple ID already used the trial, so a real purchase still bills '
            'the plan. Use a new sandbox Apple ID if you need Apple to grant '
            'the month for real.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.label,
    required this.detail,
    required this.onTap,
  });

  final String label;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(label),
        subtitle: Text(detail),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
