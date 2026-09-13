import 'package:flutter/material.dart';
import 'package:scan2/core/theme/brand.dart';

/// Title and copy for a converter that is on All tools but not built yet.
class ComingSoonTool {
  const ComingSoonTool({required this.title, required this.detail});

  final String title;
  final String detail;
}

/// Honest empty screen so a card in the grid is never a fake converter.
class ComingSoonToolScreen extends StatelessWidget {
  const ComingSoonToolScreen({super.key, required this.tool});

  final ComingSoonTool tool;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tool.title)),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 36),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Brand.accentWash,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.hourglass_empty_rounded,
                color: Brand.accent,
              ),
            ),
            const SizedBox(height: 22),
            Text(tool.title, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 10),
            Text(tool.detail, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
