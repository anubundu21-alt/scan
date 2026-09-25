import 'package:flutter/material.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/core/theme/tactile.dart';
import 'package:scan2/core/widgets/pressable_scale.dart';

/// The three ways onto a document from home, plus the row that opens every
/// other tool. PDF converters live on All tools, not here.
class HomeShortcuts extends StatelessWidget {
  const HomeShortcuts({
    super.key,
    required this.onFromPhotos,
    required this.onImportFile,
    required this.onScanFromCamera,
    required this.onAllTools,
  });

  final VoidCallback onFromPhotos;
  final VoidCallback onImportFile;
  final VoidCallback onScanFromCamera;
  final VoidCallback onAllTools;

  static const photosWash = Color(0xFFD9EAFF);
  static const photosInk = Color(0xFF3478E5);
  static const fileWash = Color(0xFFE7DEFF);
  static const fileInk = Color(0xFF6C5CE7);
  static const cameraWash = Color(0xFFFFE0CC);
  static const cameraInk = Color(0xFFFF6B2C);
  static const toolsWash = Color(0xFFE5F7F0);
  static const toolsInk = Color(0xFF19A974);
  static const _label = Color(0xFF101D41);
  static const _muted = Color(0xFF68748A);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ShortcutCard(
                    label: 'Scan from photos',
                    wash: photosWash,
                    ink: photosInk,
                    icon: Icons.photo_library_rounded,
                    onPressed: onFromPhotos,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ShortcutCard(
                    label: 'Import from file',
                    wash: fileWash,
                    ink: fileInk,
                    icon: Icons.cloud_upload_rounded,
                    onPressed: onImportFile,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ShortcutCard(
                    label: 'Scan from camera',
                    wash: cameraWash,
                    ink: cameraInk,
                    icon: Icons.photo_camera_rounded,
                    emphasized: true,
                    onPressed: onScanFromCamera,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _AllToolsRow(onPressed: onAllTools),
        ],
      ),
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
    required this.label,
    required this.wash,
    required this.ink,
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
  });

  final String label;
  final Color wash;
  final Color ink;
  final IconData icon;
  final VoidCallback onPressed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return PressableScale(
      onPressed: onPressed,
      haptic: AppHaptic.impactLight,
      scale: Tactile.pressScaleCard,
      borderRadius: BorderRadius.circular(Brand.radiusCard),
      minSize: 0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        decoration: BoxDecoration(
          color: isLight ? wash : wash.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(Brand.radiusCard),
          border: Border.all(
            width: 1,
            color: emphasized
                ? ink.withValues(alpha: 0.28)
                : Colors.transparent,
          ),
          boxShadow: isLight
              ? [
                  BoxShadow(
                    color: (emphasized ? ink : Brand.ink).withValues(
                      alpha: emphasized ? 0.16 : 0.05,
                    ),
                    blurRadius: emphasized ? 14 : 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [],
        ),
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(color: ink, shape: BoxShape.circle),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                height: 1.2,
                color: isLight
                    ? HomeShortcuts._label
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllToolsRow extends StatelessWidget {
  const _AllToolsRow({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    return PressableScale(
      onPressed: onPressed,
      haptic: AppHaptic.impactLight,
      scale: Tactile.pressScaleCard,
      borderRadius: BorderRadius.circular(Brand.radiusCard),
      minSize: 0,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: isLight
              ? HomeShortcuts.toolsWash
              : HomeShortcuts.toolsWash.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(Brand.radiusCard),
          border: Border.all(color: Brand.outline),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: HomeShortcuts.toolsInk,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.apps_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All tools',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isLight ? HomeShortcuts._label : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PDF, text, sign, convert and more',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isLight
                          ? HomeShortcuts._muted
                          : scheme.onSurfaceVariant,
                    ),
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
