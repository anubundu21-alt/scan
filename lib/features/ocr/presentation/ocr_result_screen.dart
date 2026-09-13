import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/core/widgets/pressable_scale.dart';

/// What the recogniser read, as text you can do something with.
class OcrResultScreen extends StatelessWidget {
  const OcrResultScreen({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final empty = text.trim().isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Extracted text'),
        actions: [
          if (!empty)
            TactileIconButton(
              icon: Icons.copy_rounded,
              tooltip: 'Copy all',
              color: scheme.onSurface,
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                await AppHaptics.success();
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(content: Text('Copied to the clipboard')),
                    );
                }
              },
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: empty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.text_fields_rounded,
                      size: 40,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No text found on that page',
                      style: theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Recognition works best on a flat, well-lit page with '
                      'printed text.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.light
                      ? Colors.white
                      : scheme.surface,
                  borderRadius: BorderRadius.circular(Brand.radiusCard),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                // Selectable, because the commonest thing anyone wants is one
                // line out of the middle — an account number, a date — not
                // the whole page.
                child: SelectableText(
                  text,
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.55),
                ),
              ),
            ),
    );
  }
}
