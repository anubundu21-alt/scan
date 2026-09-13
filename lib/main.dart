import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scan2/app_router.dart';
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/pro/data/iap_gateway.dart';
import 'package:scan2/features/settings/presentation/app_lock.dart';
import 'package:scan2/features/shared/providers/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // StoreKit can drop the purchase update if nobody is listening when the
  // Apple sheet finishes. Subscribe before any paywall opens.
  PluginIapGateway.ensureListening();
  // Scanning is a portrait, two-handed activity; letting the shell rotate
  // mid-capture only fights the user.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Warm the feedback generators before the first tap. iOS spins them up
  // lazily, so without this the very first press in a session answers late —
  // which is the one press a new customer judges the app on.
  unawaited(AppHaptics.prepare());
  runApp(const Scan2Root());
}

class Scan2Root extends StatelessWidget {
  const Scan2Root({super.key});

  @override
  Widget build(BuildContext context) {
    return const ProviderScope(child: Scan2App());
  }
}

/// Holds the brand splash for 2 seconds after Flutter's first frame so the
/// native launch screen is not a one-frame flash.
class LaunchHold extends StatefulWidget {
  const LaunchHold({super.key, required this.child});

  final Widget child;

  @override
  State<LaunchHold> createState() => _LaunchHoldState();
}

class _LaunchHoldState extends State<LaunchHold> {
  static const _hold = Duration(seconds: 2);
  Timer? _timer;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(_hold, () {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.child;
    return const ColoredBox(
      color: Brand.accent,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScanellaAppMark(size: 88),
            SizedBox(height: 18),
            ScanellaWordmark(onDark: true, fontSize: 34),
          ],
        ),
      ),
    );
  }
}

class Scan2App extends ConsumerWidget {
  const Scan2App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Scanella',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ref.watch(settingsProvider.select((s) => s.themeMode)),
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) => LaunchHold(
        child: AppLockGate(child: child ?? const SizedBox()),
      ),
    );
  }
}
