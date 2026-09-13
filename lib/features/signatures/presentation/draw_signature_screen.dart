import 'package:flutter/material.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/core/widgets/pressable_scale.dart';
import 'package:scan2/features/signatures/data/signature_store.dart';
import 'package:scan2/features/signatures/presentation/signature_pad.dart';

/// Draw a signature in ink, then keep it on the device for reuse.
class DrawSignatureScreen extends StatefulWidget {
  const DrawSignatureScreen({super.key, this.store});

  final SignatureStore? store;

  @override
  State<DrawSignatureScreen> createState() => _DrawSignatureScreenState();
}

class _DrawSignatureScreenState extends State<DrawSignatureScreen> {
  final _padKey = GlobalKey<SignaturePadState>();
  bool _hasInk = false;
  bool _saving = false;

  void _clear() {
    _padKey.currentState?.clear();
    setState(() => _hasInk = false);
    AppHaptics.selection();
  }

  Future<void> _save() async {
    if (!_hasInk || _saving) return;
    setState(() => _saving = true);
    try {
      final png = await _padKey.currentState?.capturePng();
      if (png == null || png.isEmpty) {
        throw StateError('Could not save that signature.');
      }
      final store = widget.store ?? SignatureStore();
      final saved = await store.savePng(png);
      if (!mounted) return;
      AppHaptics.success();
      Navigator.pop(context, saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Draw signature'),
        actions: [
          TextButton(
            onPressed: _hasInk ? _clear : null,
            child: const Text('Clear'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Text(
              'Sign with your finger. Scanella keeps this on the device '
              'and reuses it the next time.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Brand.radiusCard),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(Brand.radiusCard),
                  child: SignaturePad(
                    key: _padKey,
                    onInkChanged: (hasInk) {
                      if (hasInk != _hasInk) setState(() => _hasInk = hasInk);
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: TactileButton(
            label: _saving ? 'Saving…' : 'Save signature',
            icon: Icons.check_rounded,
            onPressed: _hasInk && !_saving ? _save : null,
            haptic: AppHaptic.impactMedium,
          ),
        ),
      ),
    );
  }
}
