import 'package:flutter/material.dart';
import 'package:scan2/core/theme/brand.dart';

const kScanNameSuggestions = ['Invoice', 'Receipt', 'ID', 'Contract', 'Notes'];

/// Asks for a file or scan name. Skip / empty keeps the current title.
Future<String?> promptScanName(
  BuildContext context, {
  String? initial,
  String title = 'Name this PDF',
}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (context) => _ScanNameDialog(title: title, initial: initial),
  );
  final trimmed = name?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

class _ScanNameDialog extends StatefulWidget {
  const _ScanNameDialog({required this.title, this.initial});

  final String title;
  final String? initial;

  @override
  State<_ScanNameDialog> createState() => _ScanNameDialogState();
}

class _ScanNameDialogState extends State<_ScanNameDialog> {
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

  void _use(String value) {
    _controller.text = value;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Invoice, ID, Receipt…',
            ),
            onSubmitted: (value) => Navigator.pop(context, value),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final label in kScanNameSuggestions)
                ActionChip(
                  label: Text(label),
                  onPressed: () => _use(label),
                  backgroundColor: Brand.accentWash,
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
