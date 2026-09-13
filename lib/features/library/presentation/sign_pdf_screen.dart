import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/core/theme/tactile.dart';
import 'package:scan2/core/widgets/page_thumbnail.dart';
import 'package:scan2/core/widgets/paper.dart';
import 'package:scan2/core/widgets/pressable_scale.dart';
import 'package:scan2/features/home/domain/import_service.dart';
import 'package:scan2/features/library/data/document_store.dart';
import 'package:scan2/features/library/domain/document.dart';
import 'package:scan2/features/library/presentation/document_detail_screen.dart';
import 'package:scan2/features/pro/presentation/pro_gate.dart';
import 'package:scan2/features/shared/providers/db_provider.dart';

/// Sign a PDF: upload one from Files, or open a PDF already in the library.
///
/// Camera scans stay out of this list. Sign is a PDF tool, not a scan tool.
class SignPdfScreen extends ConsumerStatefulWidget {
  const SignPdfScreen({super.key});

  @override
  ConsumerState<SignPdfScreen> createState() => _SignPdfScreenState();
}

class _SignPdfScreenState extends ConsumerState<SignPdfScreen> {
  static const _importer = ImportService();
  bool _working = false;
  String _workingLabel = '';

  Future<void> _uploadPdf() async {
    if (_working) return;
    final repository = ref.read(documentRepositoryProvider);
    if (kIsWeb || repository is! DocumentStore) {
      _message('Importing is available on iOS and Android.');
      return;
    }
    if (!await ensureFreeScanSlot(context, ref)) return;
    if (!mounted) return;
    setState(() {
      _working = true;
      _workingLabel = 'Reading PDF…';
    });
    try {
      final imported = await _importer.fromPdfs(
        onProgress: (done, total) {
          if (!mounted || total < 2) return;
          setState(() => _workingLabel = 'Reading page $done of $total…');
        },
      );
      if (imported == null) return;
      final doc = await repository.createProcessedDocument(
        pages: imported.pages,
        title: imported.title,
        folderId: ref.read(openFolderIdProvider),
        importedFromPdf: true,
      );
      await recordNewScan(ref);
      bumpLibrary(ref);
      await AppHaptics.success();
      if (!mounted) return;
      context.push(
        '/library/document/${doc.id}',
        extra: DocumentScreenMode.signPdf,
      );
    } catch (e) {
      await AppHaptics.error();
      if (mounted) _message(_readable(e));
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _open(Document document) {
    context.push(
      '/library/document/${document.id}',
      extra: DocumentScreenMode.signPdf,
    );
  }

  String _readable(Object error) {
    final text = error is StateError ? error.message : error.toString();
    return text.length > 160 ? '${text.substring(0, 160)}…' : text;
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final all = ref.watch(documentsProvider).valueOrNull ?? const [];
    final pdfs = [
      for (final doc in all)
        if (doc.isPdfForSigning) doc,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Sign PDF')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
            children: [
              _UploadTile(onPressed: _working ? null : _uploadPdf),
              const SizedBox(height: 22),
              Text('Your PDFs', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              if (pdfs.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'PDFs you upload show up here. Scans stay in Documents.',
                    style: theme.textTheme.bodySmall,
                  ),
                )
              else
                for (var i = 0; i < pdfs.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _PdfTile(document: pdfs[i], onTap: () => _open(pdfs[i])),
                ],
            ],
          ),
          if (_working)
            Positioned.fill(
              child: ColoredBox(
                color: Brand.ink.withValues(alpha: 0.55),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      if (_workingLabel.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          _workingLabel,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PressableScale(
      onPressed: onPressed,
      haptic: AppHaptic.impactLight,
      scale: Tactile.pressScaleCard,
      borderRadius: BorderRadius.circular(Brand.radiusCard),
      minSize: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.light
              ? Colors.white
              : scheme.surface,
          borderRadius: BorderRadius.circular(Brand.radiusCard),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Brand.pdfRed.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.upload_file_rounded, color: Brand.pdfRed),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Upload a PDF', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Choose a file from Files, then sign it.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _PdfTile extends StatelessWidget {
  const _PdfTile({required this.document, required this.onTap});

  final Document document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return PressableScale(
      onPressed: onTap,
      haptic: AppHaptic.impactLight,
      scale: Tactile.pressScaleCard,
      borderRadius: BorderRadius.circular(Brand.radiusCard),
      minSize: 0,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.light
              ? Colors.white
              : scheme.surface,
          borderRadius: BorderRadius.circular(Brand.radiusCard),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: 68,
              child: PaperSheet(
                radius: 8,
                lift: 0.5,
                child: PageThumbnail(
                  path: document.pages.isEmpty
                      ? null
                      : document.pages.first.path,
                  cacheWidth: 156,
                  seed: document.id,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(document.title, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${document.pageCount} page'
                    '${document.pageCount == 1 ? '' : 's'}',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
