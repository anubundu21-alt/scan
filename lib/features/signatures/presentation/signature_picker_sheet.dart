import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/core/widgets/pressable_scale.dart';
import 'package:scan2/features/library/domain/document.dart';
import 'package:scan2/features/signatures/data/signature_store.dart';
import 'package:scan2/features/signatures/domain/saved_signature.dart';
import 'package:scan2/features/signatures/presentation/draw_signature_screen.dart';
import 'package:scan2/features/signatures/presentation/place_signature_screen.dart';

/// Pick a saved signature or draw a new one.
Future<SavedSignature?> showSignaturePicker(BuildContext context) {
  return showModalBottomSheet<SavedSignature>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => const _SignaturePickerSheet(),
  );
}

class _SignaturePickerSheet extends StatefulWidget {
  const _SignaturePickerSheet();

  @override
  State<_SignaturePickerSheet> createState() => _SignaturePickerSheetState();
}

class _SignaturePickerSheetState extends State<_SignaturePickerSheet> {
  final _store = SignatureStore();
  List<SavedSignature> _signatures = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    var list = const <SavedSignature>[];
    if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
      try {
        list = await _store.list();
      } catch (_) {
        list = const [];
      }
    }
    if (!mounted) return;
    setState(() {
      _signatures = list;
      _loading = false;
    });
  }

  Future<void> _drawNew() async {
    final saved = await Navigator.of(context).push<SavedSignature>(
      MaterialPageRoute(builder: (_) => DrawSignatureScreen(store: _store)),
    );
    if (saved != null && mounted) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                'Sign this page',
                style: theme.textTheme.headlineSmall,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.draw_rounded),
              title: const Text('Draw a new signature'),
              onTap: _drawNew,
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_signatures.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
                child: Text(
                  kIsWeb
                      ? 'Signatures are available on iOS and Android.'
                      : 'No saved signature yet.',
                  style: theme.textTheme.bodySmall,
                ),
              )
            else
              SizedBox(
                height: 168,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  itemCount: _signatures.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final signature = _signatures[index];
                    return PressableScale(
                      onPressed: () => Navigator.pop(context, signature),
                      borderRadius: BorderRadius.circular(Brand.radiusCard),
                      child: Container(
                        height: 72,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.light
                              ? Colors.white
                              : theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(Brand.radiusCard),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: kIsWeb
                                  ? const SizedBox.shrink()
                                  : Image.file(
                                      File(signature.path),
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.draw_outlined),
                                    ),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              onPressed: () async {
                                await _store.delete(signature.id);
                                await _reload();
                              },
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Opens the picker, then the placement screen for [page].
Future<void> startSigningPage(
  BuildContext context, {
  required Document document,
  required ScanPage page,
}) async {
  final signature = await showSignaturePicker(context);
  if (signature == null || !context.mounted) return;
  await context.push(
    '/sign/place',
    extra: PlaceSignatureArgs(
      documentId: document.id,
      pagePath: page.path,
      signature: signature,
    ),
  );
}
