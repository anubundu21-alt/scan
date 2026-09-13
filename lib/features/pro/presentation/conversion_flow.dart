import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:scan2/core/haptics/app_haptics.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/core/theme/tactile.dart';
import 'package:scan2/core/widgets/pressable_scale.dart';
import 'package:scan2/features/library/presentation/widgets/export_sheet.dart';
import 'package:scan2/features/pro/domain/file_conversion.dart';
import 'package:share_plus/share_plus.dart';

/// Shared behaviour for the converter screens: run a job, keep the screen
/// honest about which step it is on, then hand the finished file to Share.
mixin ConversionRunner<T extends StatefulWidget> on State<T> {
  ConversionStatus? _status;

  /// The step being worked on, or null when nothing is running.
  ConversionStatus? get status => _status;

  bool get isBusy => _status != null;

  Future<void> runConversion(
    Future<ConvertedFile> Function(ConversionProgress onProgress) convert, {
    required String doneMessage,

    /// For tools where the interesting part is what came back — how much
    /// smaller a PDF got, how many files a split made.
    String Function(ConvertedFile result)? describe,
  }) async {
    if (isBusy) return;
    final origin = shareOriginFor(context);
    setState(() {
      _status = const ConversionStatus(
        stage: ConversionStage.starting,
        message: 'Getting ready…',
        fraction: 0,
      );
    });
    try {
      final result = await convert((status) {
        if (!mounted) return;
        setState(() => _status = status);
      });
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, result.filename));
      await file.writeAsBytes(result.bytes, flush: true);
      await AppHaptics.success();
      if (!mounted) return;
      await Share.shareXFiles([
        XFile(file.path, mimeType: result.mimeType, name: result.filename),
      ], sharePositionOrigin: origin);
      if (mounted) {
        showConversionMessage(describe?.call(result) ?? doneMessage);
      }
    } catch (e) {
      await AppHaptics.error();
      if (mounted) showConversionMessage(_readable(e));
    } finally {
      if (mounted) setState(() => _status = null);
    }
  }

  void showConversionMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  String _readable(Object error) {
    if (error is PlatformException &&
        (error.message ?? '').contains('sharePositionOrigin')) {
      return 'Could not open the share sheet. Try again.';
    }
    return readableConversionError(error);
  }
}

/// Covers the screen while a file is uploading, converting or coming back.
///
/// Upload and download know how far along they are, so the ring fills. The
/// conversion itself happens on the service with nothing to report, so the
/// ring spins instead of inventing a number.
class ConversionOverlay extends StatelessWidget {
  const ConversionOverlay({super.key, required this.status});

  final ConversionStatus? status;

  @override
  Widget build(BuildContext context) {
    final current = status;
    if (current == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final fraction = current.fraction;
    return Positioned.fill(
      child: ColoredBox(
        color: Brand.ink.withValues(alpha: 0.55),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  value: fraction,
                  strokeWidth: 4,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                current.message,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                ),
              ),
              if (fraction != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${(fraction * 100).round()}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown when the app was built without a converter host, so the tool says so
/// before someone picks a file rather than after they have waited for one.
class ConversionUnavailableNotice extends StatelessWidget {
  const ConversionUnavailableNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(Brand.radiusCard),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Converting is not switched on in this build of the app. It '
              'will be back in the next update.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// The "pick a file" card at the top of a converter screen.
class ConversionUploadTile extends StatelessWidget {
  const ConversionUploadTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PressableScale(
      onPressed: onPressed,
      haptic: AppHaptic.impactLight,
      scale: Tactile.pressScaleCard,
      borderRadius: BorderRadius.circular(Brand.radiusCard),
      minSize: 0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Brand.accent,
          borderRadius: BorderRadius.circular(Brand.radiusCard),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(Brand.radiusFab),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.86),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white),
          ],
        ),
      ),
    );
  }
}

/// Sizes the way a person would say them, so 1.4 MB rather than 1468006.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes bytes';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb < 10 ? 1 : 0)} KB';
  final mb = kb / 1024;
  return '${mb.toStringAsFixed(mb < 10 ? 1 : 0)} MB';
}
