import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/camera/domain/native_document_scanner.dart';
import 'package:scan2/features/camera/domain/quad_detector.dart';
import 'package:scan2/features/crop/domain/crop_args.dart';
import 'package:scan2/features/pro/presentation/pro_gate.dart';
import 'package:scan2/features/shared/providers/db_provider.dart';

/// The default scanning screen: hands straight over to the platform's own
/// document scanner — VisionKit on iOS, ML Kit Document Scanner on Android.
///
/// Those are trained models maintained by Apple and Google, and they beat the
/// in-app geometric detector on exactly the awkward frames that matter: a
/// small card on a patterned surface, a page in poor light, a document held at
/// an angle. Scan2's own value is everything after the capture — enhancement,
/// multi-page documents, re-editable pages, export — so the capture step uses
/// whatever detects best on the device.
///
/// Pages come back already perspective-corrected. After the system scanner's
/// tick, the next screen is Crop & rotate — not the document list.
class NativeScanScreen extends ConsumerStatefulWidget {
  const NativeScanScreen({super.key, this.idCard = false});

  final bool idCard;

  @override
  ConsumerState<NativeScanScreen> createState() => _NativeScanScreenState();
}

class _NativeScanScreenState extends ConsumerState<NativeScanScreen> {
  static const _scanner = NativeDocumentScanner();

  String _status = 'Opening scanner…';
  String? _error;
  bool _launched = false;
  bool _needsSettings = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    if (_launched) return;
    _launched = true;

    if (kIsWeb) {
      setState(() => _error = 'Scanning needs a device camera.');
      return;
    }

    if (!await ensureFreeScanSlot(context, ref)) {
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/library');
      }
      return;
    }

    try {
      final pages = await _scanner.scan(maxPages: widget.idCard ? 2 : 24);

      // Cancelled from inside the system scanner.
      if (pages == null || pages.isEmpty) {
        if (!mounted) return;
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/library');
        }
        return;
      }

      if (!mounted) return;
      setState(() => _status = 'Opening editor…');

      final repository = ref.read(documentRepositoryProvider);
      final doc = await repository.createDocumentFromScans(
        pages,
        edgesAlreadyApplied: true,
        folderId: ref.read(openFolderIdProvider),
        isIdCard: widget.idCard,
        title: widget.idCard ? 'ID' : null,
      );
      await recordNewScan(ref);
      bumpLibrary(ref);
      HapticFeedback.mediumImpact();

      if (!mounted) return;
      final first = doc.pages.first;
      context.go(
        '/crop',
        extra: CropArgs(
          imagePath: first.editSource,
          initialQuad: const Quad.fullFrame(),
          edgesAlreadyApplied: true,
          documentId: doc.id,
          cropRemainingPages: true,
        ),
      );
    } catch (e) {
      debugPrint('Scan failed: $e');
      if (mounted) {
        setState(() {
          _error = _describeScanError(e);
          _needsSettings = _isPermissionError(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;

    // Every scan passes through this screen twice — once handing off to the
    // system scanner, once coming back to open Crop & rotate.
    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: const Color(0xFF070D19),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: error == null
                  ? _Working(status: _status)
                  : _Failed(
                      message: error,
                      needsSettings: _needsSettings,
                      onRetry: () {
                        setState(() {
                          _error = null;
                          _needsSettings = false;
                          _launched = false;
                          _status = 'Opening scanner…';
                        });
                        _run();
                      },
                      onOpenSettings: () => openAppSettings(),
                      onBack: () => context.go('/library'),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

String _describeScanError(Object error) {
  if (error is CameraPermissionNeeded) return error.toString();
  final text = error.toString();
  if (_isPermissionError(error)) {
    return 'Scanella needs camera access to scan documents. '
        'Enable Camera in Settings, then try again.';
  }
  if (text.contains('ERROR_ALREADY_REQUESTING_PERMISSIONS') ||
      text.contains('already running')) {
    return 'The camera permission prompt is still open. '
        'Close it, then try again.';
  }
  if (error is PlatformException && (error.message?.isNotEmpty ?? false)) {
    return error.message!;
  }
  return text.length > 180 ? '${text.substring(0, 180)}…' : text;
}

bool _isPermissionError(Object error) {
  if (error is CameraPermissionNeeded) return true;
  final text = error.toString().toLowerCase();
  return text.contains('permission not granted') ||
      text.contains('camera permission') ||
      text.contains('permanentlydenied') ||
      (error is PlatformException &&
          error.code.toLowerCase().contains('permission'));
}

class _Working extends StatelessWidget {
  const _Working({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ScanellaAppMark(size: 72),
        const SizedBox(height: 30),
        const SizedBox(
          width: 132,
          child: LinearProgressIndicator(
            minHeight: 3,
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          status,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_rounded,
              size: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              'Nothing leaves your device',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({
    required this.message,
    required this.onRetry,
    required this.onBack,
    required this.onOpenSettings,
    this.needsSettings = false,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;
  final VoidCallback onOpenSettings;
  final bool needsSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 68,
          height: 68,
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.error_outline_rounded,
            size: 32,
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'That scan did not finish',
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ),
        if (needsSettings) ...[
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: onOpenSettings,
              child: const Text('Open Settings'),
            ),
          ),
        ],
        const SizedBox(height: 6),
        TextButton(onPressed: onBack, child: const Text('Back to library')),
      ],
    );
  }
}
