import 'package:flutter/material.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/library/domain/folder.dart';

/// Asks for a folder name. Returns null if cancelled or blank.
Future<String?> promptFolderName(
  BuildContext context, {
  String title = 'New folder',
  String confirmLabel = 'Create',
  String? initial,
}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (context) => _FolderNameDialog(
      title: title,
      confirmLabel: confirmLabel,
      initial: initial,
    ),
  );
  final trimmed = name?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

class _FolderNameDialog extends StatefulWidget {
  const _FolderNameDialog({
    required this.title,
    required this.confirmLabel,
    this.initial,
  });

  final String title;
  final String confirmLabel;
  final String? initial;

  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        maxLength: 40,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'Receipts, Taxes…',
        ),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Where selected scans should live after the move sheet.
class FolderDestination {
  const FolderDestination._(this.folderId);
  const FolderDestination.home() : this._(null);
  const FolderDestination.folder(int id) : this._(id);

  final int? folderId;
}

/// Picks a folder, or the unfiled home list, for the selected scans.
Future<FolderDestination?> showMoveToFolderSheet({
  required BuildContext context,
  required List<Folder> folders,
  required Future<Folder> Function(String name) createFolder,
}) {
  return showModalBottomSheet<FolderDestination>(
    context: context,
    showDragHandle: true,
    builder: (context) =>
        _MoveSheet(folders: folders, createFolder: createFolder),
  );
}

class _MoveSheet extends StatelessWidget {
  const _MoveSheet({required this.folders, required this.createFolder});

  final List<Folder> folders;
  final Future<Folder> Function(String name) createFolder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('Move to folder', style: theme.textTheme.titleLarge),
            ),
            ListTile(
              leading: Icon(
                Icons.home_outlined,
                color: theme.colorScheme.primary,
              ),
              title: const Text('Documents'),
              subtitle: const Text('Not in a folder'),
              onTap: () =>
                  Navigator.pop(context, const FolderDestination.home()),
            ),
            if (folders.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: folders.length,
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    return ListTile(
                      leading: Icon(Icons.folder_rounded, color: Brand.accent),
                      title: Text(folder.name),
                      onTap: () => Navigator.pop(
                        context,
                        FolderDestination.folder(folder.id),
                      ),
                    );
                  },
                ),
              ),
            ListTile(
              leading: Icon(
                Icons.create_new_folder_outlined,
                color: theme.colorScheme.primary,
              ),
              title: const Text('New folder'),
              onTap: () async {
                final name = await promptFolderName(context);
                if (name == null || !context.mounted) return;
                final folder = await createFolder(name);
                if (!context.mounted) return;
                Navigator.pop(context, FolderDestination.folder(folder.id));
              },
            ),
          ],
        ),
      ),
    );
  }
}
