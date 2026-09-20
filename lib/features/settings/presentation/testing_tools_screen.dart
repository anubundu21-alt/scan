import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/pro/domain/pro_store.dart';
import 'package:scan2/features/pro/domain/scan_quota.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shortcuts for walking the paid flow end to end without waiting.
///
/// Compiled in only when the build was made with
/// `--dart-define=SCANELLA_TESTING=true`, so an App Store build has no way
/// to reach any of this. Nothing here grants Pro: the store decides that,
/// and a tester still pays through the real Apple sheet. What it does is
/// skip the waiting — burning an allowance instead of making ten documents,
/// and forgetting what the device remembers so a reinstall can be tried
/// without actually deleting the app.
class TestingTools {
  const TestingTools._();

  static const enabled = bool.fromEnvironment('SCANELLA_TESTING');

  static const _channel = MethodChannel('scanella/pro');

  /// What the device remembers about Pro, in the app's own storage.
  static const _entitlementKey = 'scanella.pro.entitled';
  static const _trialUsedKey = 'scanella.pro.trial_used';
  static const _refreshSeenKey = 'scanella.quota.refresh_seen_ms';
  static const _lowSeenKey = 'scanella.quota.low_seen_batch';

  /// Wipes everything an uninstall would wipe, and the Keychain copies it
  /// would not. The store is asked again afterwards, so a device with a
  /// live subscription comes straight back as Pro — which is the point:
  /// it is how the reinstall path gets tested without a reinstall.
  static Future<void> forgetPro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_entitlementKey);
    await prefs.remove(_trialUsedKey);
    try {
      await _channel.invokeMethod<void>('writePro', <String, Object?>{
        'entitled': false,
        'untilMs': null,
        'basisMs': null,
      });
      await _channel.invokeMethod<void>('clearTrialUsed');
    } catch (_) {}
  }

  /// Lets the one-off quota messages appear again.
  static Future<void> forgetNotices() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_refreshSeenKey);
    await prefs.remove(_lowSeenKey);
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
            label: 'Forget Pro on this device',
            detail:
                'Clears what the app and the Keychain remember, then asks '
                'the store again. A live subscription comes straight back — '
                'that is the reinstall path, without the reinstall.',
            onTap: () => _run(
              'Forgotten. The store was asked again.',
              () async {
                await TestingTools.forgetPro();
                await ref.read(proProvider.notifier).restore();
              },
            ),
          ),
          _Action(
            label: 'Ask the store again',
            detail: 'Re-checks the subscription without clearing anything',
            onTap: () => _run(
              'Asked.',
              () => ref.read(proProvider.notifier).restore(),
            ),
          ),
          _Action(
            label: 'Show the one-off messages again',
            detail: 'Lets the refill and running-low screens reappear',
            onTap: () => _run('They can appear again.',
                TestingTools.forgetNotices),
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
            'Nothing here grants Pro. Buying still goes through Apple, and '
            'Apple still decides who is owed a free month. In TestFlight the '
            'purchase is a sandbox one: no real money changes hands, and a '
            'one-month plan runs out in about five minutes.',
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
