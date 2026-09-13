import 'package:flutter/material.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/legal/legal_copy.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.document});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = LegalCopy.title(document);
    final sections = LegalCopy.sections(document);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final section = sections[index];
          return Material(
            color: theme.brightness == Brightness.light
                ? Colors.white
                : theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Brand.radiusCard),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(section.heading, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(section.body, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
