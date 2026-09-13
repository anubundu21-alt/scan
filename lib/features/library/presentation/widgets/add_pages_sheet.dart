import 'package:flutter/material.dart';
import 'package:scan2/core/theme/brand.dart';

enum AddPagesSource { photos, files }

/// How to append pages to the open scan without opening the camera.
Future<AddPagesSource?> showAddPagesSheet(BuildContext context) {
  return showModalBottomSheet<AddPagesSource>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final theme = Theme.of(context);
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Text('Add pages', style: theme.textTheme.headlineSmall),
              ),
              Text(
                'Photos or files become extra pages on this scan.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Brand.imageGreen.withValues(alpha: 0.16),
                  foregroundColor: Brand.imageGreen,
                  child: const Icon(Icons.photo_library_outlined),
                ),
                title: const Text('From photos'),
                subtitle: const Text('Pages already in the library'),
                onTap: () => Navigator.pop(context, AddPagesSource.photos),
              ),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Brand.pdfRed.withValues(alpha: 0.16),
                  foregroundColor: Brand.pdfRed,
                  child: const Icon(Icons.folder_open_rounded),
                ),
                title: const Text('From files'),
                subtitle: const Text('PDF or images from Files'),
                onTap: () => Navigator.pop(context, AddPagesSource.files),
              ),
            ],
          ),
        ),
      );
    },
  );
}
