import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/settings/domain/pin_hash.dart';
import 'package:scan2/features/shared/providers/onboarding_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPinHash = 'scanella_lock_pin_hash';
const _kEnabled = 'scanella_lock_enabled';
const _kUseBio = 'scanella_lock_use_bio';

/// What the phone calls its unlock sensor: Face ID on iPhone, fingerprint
/// elsewhere.
String get biometricLabel =>
    defaultTargetPlatform == TargetPlatform.iOS ? 'Face ID' : 'Fingerprint';

class AppLockState {
  const AppLockState({
    required this.enabled,
    required this.useBiometrics,
    required this.locked,
    required this.hasPin,
  });

  final bool enabled;
  final bool useBiometrics;
  final bool locked;
  final bool hasPin;

  AppLockState copyWith({
    bool? enabled,
    bool? useBiometrics,
    bool? locked,
    bool? hasPin,
  }) {
    return AppLockState(
      enabled: enabled ?? this.enabled,
      useBiometrics: useBiometrics ?? this.useBiometrics,
      locked: locked ?? this.locked,
      hasPin: hasPin ?? this.hasPin,
    );
  }
}

class AppLockController extends StateNotifier<AppLockState>
    with WidgetsBindingObserver {
  AppLockController()
    : super(
        const AppLockState(
          enabled: false,
          useBiometrics: true,
          locked: false,
          hasPin: false,
        ),
      ) {
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  LocalAuthentication? _auth;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.paused ||
        lifecycle == AppLifecycleState.hidden) {
      if (state.enabled && state.hasPin) {
        state = state.copyWith(locked: true);
      }
    }
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hash = prefs.getString(_kPinHash);
      final enabled = prefs.getBool(_kEnabled) ?? false;
      final useBio = prefs.getBool(_kUseBio) ?? true;
      state = AppLockState(
        enabled: enabled && hash != null,
        useBiometrics: useBio,
        locked: enabled && hash != null,
        hasPin: hash != null,
      );
    } catch (e) {
      debugPrint('App lock prefs unavailable: $e');
    }
  }

  Future<bool> unlockWithPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_kPinHash);
      if (stored == null) return false;
      if (hashPin(pin) != stored) return false;
      state = state.copyWith(locked: false);
      return true;
    } catch (e) {
      debugPrint('Unlock failed: $e');
      return false;
    }
  }

  LocalAuthentication? _biometrics() {
    if (kIsWeb) return null;
    try {
      return _auth ??= LocalAuthentication();
    } catch (_) {
      return null;
    }
  }

  Future<bool> tryBiometrics() async {
    if (!state.useBiometrics) return false;
    final auth = _biometrics();
    if (auth == null) return false;
    try {
      final can =
          await auth.canCheckBiometrics || await auth.isDeviceSupported();
      if (!can) return false;
      final ok = await auth.authenticate(
        localizedReason: 'Unlock Scanella',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
      if (ok) state = state.copyWith(locked: false);
      return ok;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Face ID / device lock for the Private smart folder.
  Future<bool> authenticateForPrivate() async {
    final auth = _biometrics();
    if (auth != null) {
      try {
        final can =
            await auth.canCheckBiometrics || await auth.isDeviceSupported();
        if (can) {
          return await auth.authenticate(
            localizedReason: 'Open private documents',
            options: const AuthenticationOptions(
              biometricOnly: false,
              stickyAuth: true,
            ),
          );
        }
      } on PlatformException {
        return false;
      } catch (_) {
        return false;
      }
    }
    if (state.enabled && state.locked) return false;
    return true;
  }

  Future<bool> biometricsAvailable() async {
    final auth = _biometrics();
    if (auth == null) return false;
    try {
      return await auth.canCheckBiometrics || await auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPinHash, hashPin(pin));
    await prefs.setBool(_kEnabled, true);
    state = state.copyWith(enabled: true, hasPin: true, locked: false);
  }

  Future<void> disable() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPinHash);
    await prefs.setBool(_kEnabled, false);
    state = state.copyWith(enabled: false, hasPin: false, locked: false);
  }

  Future<void> setUseBiometrics(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kUseBio, value);
    state = state.copyWith(useBiometrics: value);
  }
}

final appLockProvider = StateNotifierProvider<AppLockController, AppLockState>((
  ref,
) {
  return AppLockController();
});

class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate> {
  final _pin = TextEditingController();
  String? _error;
  var _askedBio = false;

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  Future<void> _bio() async {
    await ref.read(appLockProvider.notifier).tryBiometrics();
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(appLockProvider.notifier)
        .unlockWithPin(_pin.text.trim());
    if (!ok) {
      setState(() => _error = 'Wrong PIN');
      return;
    }
    _pin.clear();
    setState(() => _error = null);
  }

  @override
  Widget build(BuildContext context) {
    final seenIntro = ref.watch(onboardingCompletedProvider);
    final lock = ref.watch(appLockProvider);
    final showLock = seenIntro && lock.locked;

    if (!showLock) {
      _askedBio = false;
      return widget.child;
    }

    if (!_askedBio && lock.useBiometrics) {
      _askedBio = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _bio());
    }

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: Material(
            color: Brand.ink,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_outline,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Scanella is locked',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your PIN to open scans.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _pin,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      autofocus: true,
                      style: const TextStyle(
                        color: Colors.white,
                        letterSpacing: 8,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'PIN',
                        hintStyle: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                        errorText: _error,
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.1),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _submit,
                      child: const Text('Unlock'),
                    ),
                    if (lock.useBiometrics) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _bio,
                        child: Text('Use $biometricLabel'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Future<String?> promptNewPin(BuildContext context) async {
  final first = TextEditingController();
  final second = TextEditingController();
  try {
    return await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Set a PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '4 to 8 digits. You will need this if Face ID is off.',
              ),
              const SizedBox(height: 12),
              TextField(
                controller: first,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  counterText: '',
                ),
              ),
              TextField(
                controller: second,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: const InputDecoration(
                  labelText: 'Confirm PIN',
                  counterText: '',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final pin = first.text.trim();
                if (pin.length < 4 ||
                    pin.length > 8 ||
                    !RegExp(r'^\d+$').hasMatch(pin)) {
                  return;
                }
                if (pin != second.text.trim()) return;
                Navigator.pop(ctx, pin);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  } finally {
    first.dispose();
    second.dispose();
  }
}
