import 'package:flutter/material.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/core/widgets/page_thumbnail.dart';
import 'package:scan2/features/library/domain/document.dart';

/// Pick other scans to merge into a new combined PDF.
Future<List<int>?> showMergePickerSheet({
  required BuildContext context,
  required Document current,
  required List<Document> others,
}) {
  return showModalBottomSheet<List<int>>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => _MergePickerSheet(current: current, others: others),
  );
}

class _MergePickerSheet extends StatefulWidget {
  const _MergePickerSheet({required this.current, required this.others});

  final Document current;
  final List<Document> others;

  @override
  State<_MergePickerSheet> createState() => _MergePickerSheetState();
}

class _MergePickerSheetState extends State<_MergePickerSheet> {
  final _selected = <int>{};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: 16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                'Merge with another scan',
                style: theme.textTheme.headlineSmall,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                'Pages from “${widget.current.title}” stay first. '
                'A new scan is created; the originals stay in the library.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (widget.others.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                child: Text(
                  'There are no other scans to merge with.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 360),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: widget.others.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final doc = widget.others[index];
                    final checked = _selected.contains(doc.id);
                    return CheckboxListTile(
                      value: checked,
                      onChanged: (value) {
                        setState(() {
                          if (value == true) {
                            _selected.add(doc.id);
                          } else {
                            _selected.remove(doc.id);
                          }
                        });
                      },
                      secondary: SizedBox(
                        width: 36,
                        height: 48,
                        child: PageThumbnail(
                          path: doc.pages.isEmpty ? null : doc.pages.first.path,
                          cacheWidth: 108,
                          seed: doc.id,
                        ),
                      ),
                      title: Text(doc.title, maxLines: 1),
                      subtitle: Text(
                        '${doc.pageCount} page${doc.pageCount == 1 ? '' : 's'}',
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.pop(context, _selected.toList()),
              style: FilledButton.styleFrom(
                backgroundColor: Brand.accent,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(
                _selected.isEmpty
                    ? 'Pick at least one scan'
                    : 'Merge ${_selected.length + 1} scans',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
