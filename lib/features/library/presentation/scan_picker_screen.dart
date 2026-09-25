import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/core/widgets/page_thumbnail.dart';
import 'package:scan2/core/widgets/paper.dart';
import 'package:scan2/features/library/domain/document.dart';
import 'package:scan2/features/library/presentation/document_detail_screen.dart';
import 'package:scan2/features/shared/providers/db_provider.dart';

/// Pick a document, then open it as Sign PDF.
///
/// Edit PDF no longer comes through here: that tool uploads a PDF from Files
/// and opens the editor directly.
class ScanPickerScreen extends ConsumerWidget {
  const ScanPickerScreen({super.key, required this.mode});

  final DocumentScreenMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final documents = ref.watch(documentsProvider).valueOrNull ?? const [];
    final theme = Theme.of(context);
    final isEdit = mode == DocumentScreenMode.editPdf;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit PDF' : 'Sign PDF')),
      body: documents.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Scan a document first, then come back here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 36),
              itemCount: documents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final doc = documents[index];
                return _PickTile(
                  document: doc,
                  onTap: () =>
                      context.push('/library/document/${doc.id}', extra: mode),
                );
              },
            ),
    );
  }
}

class _PickTile extends StatelessWidget {
  const _PickTile({required this.document, required this.onTap});

  final Document document;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: theme.brightness == Brightness.light
          ? Colors.white
          : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Brand.radiusCard),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Brand.radiusCard),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
      ),
    );
  }
}
