import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/core/widgets/pressable_scale.dart';
import 'package:scan2/features/library/domain/page_stamp.dart';
import 'package:scan2/features/shared/providers/db_provider.dart';
import 'package:scan2/features/signatures/domain/saved_signature.dart';

class PlaceSignatureArgs {
  const PlaceSignatureArgs({
    required this.documentId,
    required this.pagePath,
    required this.signature,
  });

  final int documentId;
  final String pagePath;
  final SavedSignature signature;
}

/// Drag a saved signature onto a page, optionally with a name and date.
class PlaceSignatureScreen extends ConsumerStatefulWidget {
  const PlaceSignatureScreen({super.key, required this.args});

  final PlaceSignatureArgs args;

  @override
  ConsumerState<PlaceSignatureScreen> createState() =>
      _PlaceSignatureScreenState();
}

class _PlaceSignatureScreenState extends ConsumerState<PlaceSignatureScreen> {
  // Default: lower-right, about a third of the page wide.
  double _nx = 0.58;
  double _ny = 0.78;
  double _nw = 0.36;
  double _nh = 0.14;
  bool _addDate = true;
  bool _saving = false;
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String? get _caption {
    final parts = <String>[
      if (_name.text.trim().isNotEmpty) _name.text.trim(),
      if (_addDate) DateFormat.yMMMd().format(DateTime.now()),
    ];
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  Future<void> _apply() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final stamp = PageStamp(
        imagePath: widget.args.signature.path,
        nx: _nx.clamp(0, 1 - _nw),
        ny: _ny.clamp(0, 1 - _nh),
        nw: _nw,
        nh: _nh,
        caption: _caption,
      );
      final document = await ref
          .read(documentRepositoryProvider)
          .getDocument(widget.args.documentId);
      final page = document?.pageAt(widget.args.pagePath);
      final existing = page?.stamps ?? const <PageStamp>[];
      await ref.read(documentRepositoryProvider).setPageStamps(
        documentId: widget.args.documentId,
        pagePath: widget.args.pagePath,
        stamps: [...existing, stamp],
      );
      bumpLibrary(ref);
      if (!mounted) return;
      AppHaptics.success();
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final document =
        ref.watch(documentProvider(widget.args.documentId)).valueOrNull;
    final page = document?.pageAt(widget.args.pagePath);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Place signature')),
      body: page == null
          ? const Center(child: Text('That page is gone.'))
          : Column(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                    child: _PageStage(
                      pagePath: page.path,
                      nx: _nx,
                      ny: _ny,
                      nw: _nw,
                      nh: _nh,
                      signaturePath: widget.args.signature.path,
                      caption: _caption,
                      onMove: (nx, ny) => setState(() {
                        _nx = nx;
                        _ny = ny;
                      }),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Row(
                    children: [
                      Text('Size', style: theme.textTheme.labelMedium),
                      Expanded(
                        child: Slider(
                          value: _nw,
                          min: 0.16,
                          max: 0.7,
                          onChanged: (value) {
                            setState(() {
                              _nw = value;
                              _nh = (value * 0.4).clamp(0.08, 0.4);
                              _nx = _nx.clamp(0, 1 - _nw);
                              _ny = _ny.clamp(0, 1 - _nh);
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                  title: const Text('Add today’s date'),
                  value: _addDate,
                  onChanged: (value) => setState(() => _addDate = value),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Name (optional)',
                      hintText: 'Printed under the signature',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: TactileButton(
            label: _saving ? 'Placing…' : 'Place signature',
            icon: Icons.check_rounded,
            onPressed: page == null || _saving ? null : _apply,
            haptic: AppHaptic.impactMedium,
          ),
        ),
      ),
    );
  }
}

class _PageStage extends StatefulWidget {
  const _PageStage({
    required this.pagePath,
    required this.nx,
    required this.ny,
    required this.nw,
    required this.nh,
    required this.signaturePath,
    required this.onMove,
    this.caption,
  });

  final String pagePath;
  final double nx;
  final double ny;
  final double nw;
  final double nh;
  final String signaturePath;
  final String? caption;
  final void Function(double nx, double ny) onMove;

  @override
  State<_PageStage> createState() => _PageStageState();
}

class _PageStageState extends State<_PageStage> {
  double _aspect = 3 / 4;

  @override
  void initState() {
    super.initState();
    _loadAspect();
  }

  Future<void> _loadAspect() async {
    if (kIsWeb) return;
    try {
      final bytes = await File(widget.pagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final aspect = frame.image.width / frame.image.height;
      frame.image.dispose();
      if (!mounted || aspect <= 0) return;
      setState(() => _aspect = aspect);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final nx = widget.nx;
    final ny = widget.ny;
    final nw = widget.nw;
    final nh = widget.nh;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: AspectRatio(
            // Match the real page, not a 3:4 crop. Cover + 3:4 put the ink
            // in a different place than the JPEG export uses.
            aspectRatio: _aspect,
            child: LayoutBuilder(
              builder: (context, pageBox) {
                final w = pageBox.maxWidth;
                final h = pageBox.maxHeight;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: kIsWeb || !File(widget.pagePath).existsSync()
                            ? const ColoredBox(color: Color(0xFFF3F4F8))
                            : Image.file(
                                File(widget.pagePath),
                                fit: BoxFit.fill,
                              ),
                      ),
                      Positioned(
                        left: nx * w,
                        top: ny * h,
                        width: nw * w,
                        height: nh * h,
                        child: GestureDetector(
                          onPanUpdate: (details) {
                            widget.onMove(
                              (nx + details.delta.dx / w).clamp(0.0, 1 - nw),
                              (ny + details.delta.dy / h).clamp(0.0, 1 - nh),
                            );
                          },
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Brand.accent,
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                Expanded(
                                  child: kIsWeb
                                      ? const Icon(Icons.draw_outlined)
                                      : Image.file(
                                          File(widget.signaturePath),
                                          fit: BoxFit.contain,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(Icons.draw_outlined),
                                        ),
                                ),
                                if (widget.caption != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 2),
                                    child: Text(
                                      widget.caption!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF111111),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
