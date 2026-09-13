import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/core/widgets/page_thumbnail.dart';
import 'package:scan2/features/library/domain/document.dart';
import 'package:scan2/features/shared/providers/db_provider.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(trashProvider);
    final items = async.valueOrNull ?? const <Document>[];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trash'),
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => _empty(context, ref),
              child: const Text('Empty'),
            ),
        ],
      ),
      body: items.isEmpty
          ? Center(
              child: Text(
                'Trash is empty.\nDeleted scans stay here for 30 days.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final doc = items[index];
                final deleted = doc.deletedAt;
                final when = deleted == null
                    ? ''
                    : DateFormat.MMMd().format(deleted);
                return Material(
                  color: theme.brightness == Brightness.light
                      ? Colors.white
                      : theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(Brand.radiusCard),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 48,
                        height: 64,
                        child: PageThumbnail(
                          path: doc.pages.isEmpty ? null : doc.pages.first.path,
                          seed: doc.id,
                        ),
                      ),
                    ),
                    title: Text(doc.title),
                    subtitle: Text(
                      deleted == null
                          ? '${doc.pageCount} pages'
                          : '${doc.pageCount} pages · Deleted $when',
                    ),
                    trailing: Wrap(
                      children: [
                        IconButton(
                          tooltip: 'Restore',
                          icon: const Icon(Icons.restore_rounded),
                          onPressed: () async {
                            await ref
                                .read(documentRepositoryProvider)
                                .restoreFromTrash(doc.id);
                            bumpLibrary(ref);
                            AppHaptics.success();
                          },
                        ),
                        IconButton(
                          tooltip: 'Delete forever',
                          icon: Icon(
                            Icons.delete_forever_rounded,
                            color: theme.colorScheme.error,
                          ),
                          onPressed: () async {
                            await ref
                                .read(documentRepositoryProvider)
                                .deleteDocument(doc.id);
                            bumpLibrary(ref);
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _empty(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty Trash?'),
        content: const Text('This deletes those scans for good.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Empty'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(documentRepositoryProvider).emptyTrash();
    bumpLibrary(ref);
    AppHaptics.success();
  }
}
