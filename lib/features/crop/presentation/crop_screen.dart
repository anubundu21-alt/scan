import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:scan2/core/imaging/raster_image.dart';
import 'package:scan2/core/theme/app_theme.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/camera/domain/quad_detector.dart';
import 'package:scan2/features/crop/domain/crop_args.dart';
import 'package:scan2/features/crop/domain/image_processor.dart';
import 'package:scan2/features/crop/domain/page_processor.dart';
import 'package:scan2/features/crop/domain/scan_preview.dart';
import 'package:scan2/features/crop/presentation/widgets/draggable_quad.dart';
import 'package:scan2/features/library/domain/document.dart';
import 'package:scan2/features/library/domain/document_repository.dart';
import 'package:scan2/features/shared/providers/db_provider.dart';

enum _Stage { crop, enhance }

class CropScreen extends ConsumerStatefulWidget {
  const CropScreen({
    super.key,
    this.imagePath,
    this.initialQuad,
    this.initialAdjustments = const ScanAdjustments(),
    this.edgesAlreadyApplied = false,
    this.documentId,
    this.pageIndex = 0,
    this.cropRemainingPages = false,
  });

  factory CropScreen.fromArgs(CropArgs args) => CropScreen(
    imagePath: args.imagePath,
    initialQuad: args.initialQuad,
    initialAdjustments: args.adjustments,
    edgesAlreadyApplied: args.edgesAlreadyApplied,
    documentId: args.documentId,
    pageIndex: args.pageIndex,
    cropRemainingPages: args.cropRemainingPages,
  );

  final String? imagePath;
  final Quad? initialQuad;
  final ScanAdjustments initialAdjustments;
  final bool edgesAlreadyApplied;
  final int? documentId;
  final int pageIndex;
  final bool cropRemainingPages;

  @override
  ConsumerState<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends ConsumerState<CropScreen> {
  final _processor = const PageProcessor();

  _Stage _stage = _Stage.crop;
  PreviewSource? _source;
  ui.Image? _cropPreview;
  ui.Image? _enhancePreview;

  late Quad _quad;
  late ScanAdjustments _adjustments;

  bool _loading = true;
  bool _rendering = false;
  bool _rotating = false;
  bool _saving = false;
  String? _loadError;

  Timer? _debounce;

  /// Guards against a slow render overwriting the result of a newer one.
  int _renderToken = 0;

  late String? _imagePath;
  late int _pageIndex;
  late bool _cropRemaining;
  int _pageCount = 1;
  bool _keepQuad = false;

  @override
  void initState() {
    super.initState();
    _imagePath = widget.imagePath;
    _pageIndex = widget.pageIndex;
    _cropRemaining = widget.cropRemainingPages;
    _quad =
        widget.initialQuad ??
        (widget.edgesAlreadyApplied
            ? const Quad.fullFrame()
            : const Quad.centered());
    _adjustments = widget.initialAdjustments;
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _cropPreview?.dispose();
    _enhancePreview?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final path = _imagePath;
    if (path == null || kIsWeb) {
      setState(() => _loading = false);
      return;
    }

    try {
      final bytes = await File(path).readAsBytes();
      final source = await loadPreviewSource(bytes);
      if (!mounted) return;
      if (source == null) {
        setState(() {
          _loading = false;
          _loadError = 'That image could not be opened.';
        });
        return;
      }

      // Detect edges up front when the caller did not supply them, so the
      // crop opens on the page rather than on an arbitrary default frame.
      // Native / system-scanner pages are already cropped — do not detect
      // again. The detector treats printed text as a page edge and the tick
      // then saves only that inner half.
      var quad = _quad;
      if (!_keepQuad &&
          widget.initialQuad == null &&
          !widget.edgesAlreadyApplied) {
        quad = resolveScanQuad(
          source.raster.rotatedTurns(_adjustments.rotationTurns),
          edgesAlreadyApplied: false,
          initial: const Quad.centered(),
        );
      }
      _keepQuad = false;

      final preview = await rasterToImage(
        source.raster.rotatedTurns(_adjustments.rotationTurns),
      );
      if (!mounted) {
        preview.dispose();
        return;
      }

      setState(() {
        _source = source;
        _quad = quad;
        _cropPreview = preview;
        _loading = false;
      });
      final documentId = widget.documentId;
      if (documentId != null) {
        final doc = await ref
            .read(documentRepositoryProvider)
            .getDocument(documentId);
        if (mounted && doc != null) {
          setState(() => _pageCount = doc.pageCount);
        }
      }
    } catch (e) {
      debugPrint('Crop source failed to load: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'That image could not be opened.';
        });
      }
    }
  }

  // -------------------------------------------------------------------------
  // Preview rendering
  // -------------------------------------------------------------------------

  void _scheduleEnhancePreview({bool immediate = false}) {
    _debounce?.cancel();
    if (immediate) {
      unawaited(_renderEnhancePreview());
      return;
    }
    // Dragging a slider emits a value per frame; rendering each one would
    // queue work faster than it completes.
    _debounce = Timer(
      const Duration(milliseconds: 140),
      () => unawaited(_renderEnhancePreview()),
    );
  }

  Future<void> _renderEnhancePreview() async {
    final source = _source;
    if (source == null) return;

    final token = ++_renderToken;
    if (mounted) setState(() => _rendering = true);

    try {
      final raster = await renderPreview(
        PreviewRequest(source: source, adjustments: _adjustments, quad: _quad),
      );
      final image = await rasterToImage(raster);
      if (!mounted || token != _renderToken) {
        image.dispose();
        return;
      }
      setState(() {
        _enhancePreview?.dispose();
        _enhancePreview = image;
        _rendering = false;
      });
    } catch (e) {
      debugPrint('Preview render failed: $e');
      if (mounted && token == _renderToken) {
        setState(() => _rendering = false);
      }
    }
  }

  // -------------------------------------------------------------------------
  // Actions
  // -------------------------------------------------------------------------

  void _goToEnhance() {
    setState(() => _stage = _Stage.enhance);
    _scheduleEnhancePreview(immediate: true);
  }

  void _backToCrop() => setState(() => _stage = _Stage.crop);

  void _autoDetect() {
    final source = _source;
    if (source == null) return;
    final detected = detectQuadInRaster(
      source.raster.rotatedTurns(_adjustments.rotationTurns),
    );
    if (detected == null) {
      _showMessage('No document edges found — adjust the corners by hand.');
      return;
    }
    setState(() => _quad = detected);
  }

  void _selectAll() => setState(() => _quad = const Quad.fullFrame());

  Future<void> _rotateClockwise() async {
    final source = _source;
    if (source == null || _rotating) return;

    setState(() {
      _rotating = true;
      _quad = _quad.rotatedClockwise();
      _adjustments = _adjustments.copyWith(
        rotationTurns: (_adjustments.rotationTurns + 1) % 4,
      );
      _enhancePreview?.dispose();
      _enhancePreview = null;
    });

    final preview = await rasterToImage(
      source.raster.rotatedTurns(_adjustments.rotationTurns),
    );
    if (!mounted) {
      preview.dispose();
      return;
    }
    setState(() {
      _cropPreview?.dispose();
      _cropPreview = preview;
      _rotating = false;
    });
  }

  void _onFilter(ScanFilter filter) {
    setState(() => _adjustments = _adjustments.copyWith(filter: filter));
    _scheduleEnhancePreview(immediate: true);
  }

  void _onBrightness(double value) {
    setState(() => _adjustments = _adjustments.copyWith(brightness: value));
    _scheduleEnhancePreview();
  }

  void _onContrast(double value) {
    setState(() => _adjustments = _adjustments.copyWith(contrast: value));
    _scheduleEnhancePreview();
  }

  void _resetTone() {
    setState(
      () => _adjustments = _adjustments.copyWith(brightness: 0, contrast: 0),
    );
    _scheduleEnhancePreview(immediate: true);
  }

  Future<void> _save() async {
    final path = _imagePath;
    if (_saving || path == null || kIsWeb) {
      if (mounted) _leaveEditor();
      return;
    }

    setState(() => _saving = true);
    try {
      final repository = ref.read(documentRepositoryProvider);
      final owner = await _findOwner(repository, path);
      final page = owner?.pageAt(_targetPagePath(path, owner));
      if (owner != null) _pageCount = owner.pageCount;

      // Always re-derive from the untouched capture; re-processing an already
      // enhanced JPEG compounds the losses of every previous pass.
      final sourcePath = page?.editSource ?? path;
      final sourceBytes = await File(sourcePath).readAsBytes();

      final rendered = await _processor.render(
        sourceBytes: sourceBytes,
        quad: _quad,
        adjustments: _adjustments,
      );

      if (owner != null && page != null) {
        await repository.replacePageBytes(
          documentId: owner.id,
          pagePath: page.path,
          bytes: rendered,
          quad: _quad,
          adjustments: _adjustments,
        );
        bumpLibrary(ref);
      } else {
        await File(path).writeAsBytes(rendered, flush: true);
      }

      if (!mounted) return;
      if (_cropRemaining && owner != null) {
        final latest = await repository.getDocument(owner.id);
        final next = _pageIndex + 1;
        if (latest != null && next < latest.pageCount) {
          await _openPage(latest, next);
          return;
        }
      }
      _showMessage('Page saved');
      _leaveEditor();
    } catch (e) {
      debugPrint('Save failed: $e');
      if (mounted) {
        setState(() => _saving = false);
        _showMessage('Could not save this page.');
      }
    }
  }

  Future<void> _openPage(Document document, int index) async {
    final page = document.pages[index];
    _debounce?.cancel();
    _cropPreview?.dispose();
    _enhancePreview?.dispose();
    setState(() {
      _imagePath = page.editSource;
      _pageIndex = index;
      _pageCount = document.pageCount;
      _keepQuad = true;
      _stage = _Stage.crop;
      _saving = false;
      _rotating = false;
      _loading = true;
      _loadError = null;
      _source = null;
      _cropPreview = null;
      _enhancePreview = null;
      _quad =
          page.quad ??
          (widget.edgesAlreadyApplied
              ? const Quad.fullFrame()
              : const Quad.centered());
      _adjustments = page.adjustments;
    });
    await _load();
  }

  Future<Document?> _findOwner(
    DocumentRepository repository,
    String path,
  ) async {
    final direct = await repository.findDocumentByPagePath(path);
    if (direct != null) return direct;

    // The caller may have handed us the original rather than the page.
    for (final doc in await repository.getAllDocuments()) {
      for (final page in doc.pages) {
        if (page.originalPath == path) return doc;
      }
    }
    return null;
  }

  String _targetPagePath(String path, Document? owner) {
    if (owner == null) return path;
    for (final page in owner.pages) {
      if (page.path == path || page.originalPath == path) return page.path;
    }
    return path;
  }

  void _leaveEditor() {
    final id = widget.documentId;
    if (id != null) {
      context.go('/library/document/$id');
    } else {
      context.pop();
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // The editor is dark whatever the rest of the app is set to — a page is
    // judged against the surface around it, and a white chrome throws the
    // whiteness of the paper you are trying to correct. Using the app's own
    // dark theme rather than raw black keeps it the same product: the same
    // navy, the same blue on the buttons, the same type.
    return Theme(
      data: AppTheme.dark,
      child: Scaffold(
        backgroundColor: _editorBackground,
        appBar: AppBar(
          backgroundColor: _editorBackground,
          foregroundColor: Brand.paperOnDark,
          title: Text(_editorTitle),
          leading: IconButton(
            icon: Icon(
              _stage == _Stage.crop
                  ? Icons.close_rounded
                  : Icons.arrow_back_rounded,
            ),
            color: Brand.paperOnDark,
            onPressed: _stage == _Stage.crop ? _leaveEditor : _backToCrop,
          ),
          actions: [
            if (_stage == _Stage.crop) ...[
              IconButton(
                tooltip: 'Detect edges',
                icon: const Icon(Icons.auto_fix_high_rounded),
                color: Brand.paperOnDark,
                onPressed: _source == null ? null : _autoDetect,
              ),
              IconButton(
                tooltip: 'Select whole image',
                icon: const Icon(Icons.select_all_rounded),
                color: Brand.paperOnDark,
                onPressed: _source == null ? null : _selectAll,
              ),
              const SizedBox(width: 4),
            ],
          ],
        ),
        body: Column(
          children: [
            Expanded(child: _buildStage()),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  /// Near-black, but the app's navy near-black rather than #000.
  static const _editorBackground = Color(0xFF070D19);

  String get _editorTitle {
    final stage = _stage == _Stage.crop ? 'Crop & rotate' : 'Enhance';
    if (_pageCount < 2) return stage;
    return '$stage · ${_pageIndex + 1} of $_pageCount';
  }

  bool get _hasNextPage => _cropRemaining && _pageIndex + 1 < _pageCount;

  Widget _buildStage() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Brand.accentLight),
      );
    }

    final error = _loadError;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Brand.greyOnDark),
          ),
        ),
      );
    }

    if (_source == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Editing is available on device.',
            style: TextStyle(color: Brand.greyOnDark),
          ),
        ),
      );
    }

    return _stage == _Stage.crop ? _buildCropStage() : _buildEnhanceStage();
  }

  Widget _buildCropStage() {
    final preview = _cropPreview;
    if (preview == null) {
      return const Center(
        child: CircularProgressIndicator(color: Brand.accentLight),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = EdgeInsets.all(16);
        final available = Size(
          constraints.maxWidth - padding.horizontal,
          constraints.maxHeight - padding.vertical,
        );
        final imageRect = containedImageRect(
          available,
          Size(preview.width.toDouble(), preview.height.toDouble()),
        );

        return Padding(
          padding: padding,
          child: Stack(
            children: [
              Positioned.fromRect(
                rect: imageRect,
                child: RawImage(image: preview, fit: BoxFit.fill),
              ),
              // Handles are positioned against the image rectangle, which is
              // what makes the crop land where the user drew it.
              Positioned.fill(
                child: DraggableQuad(
                  quad: _quad,
                  imageRect: imageRect,
                  onChanged: (quad) => setState(() => _quad = quad),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEnhanceStage() {
    final preview = _enhancePreview;
    return Stack(
      children: [
        Center(
          child: preview == null
              ? const CircularProgressIndicator(color: Brand.accentLight)
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: RawImage(image: preview, fit: BoxFit.contain),
                ),
        ),
        if (_rendering && preview != null)
          const Positioned(
            top: 16,
            right: 16,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Brand.accentLight,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildControls() {
    if (_source == null && !kIsWeb) return const SizedBox.shrink();

    return Material(
      color: Brand.inkSurface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: _stage == _Stage.crop
              ? _buildCropControls()
              : _buildEnhanceControls(),
        ),
      ),
    );
  }

  Widget _buildCropControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Drag the corners to crop. Rotate if the page is sideways.',
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _source == null || _rotating
                    ? null
                    : _rotateClockwise,
                icon: _rotating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.rotate_90_degrees_cw_rounded, size: 20),
                label: const Text('Rotate'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _source == null ? null : _goToEnhance,
                icon: const Icon(Icons.arrow_forward_rounded, size: 19),
                label: const Text('Next'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEnhanceControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            // Without the trailing inset the last chip sits flush against the
            // screen edge and reads as cut off rather than scrollable.
            padding: const EdgeInsets.only(right: 16),
            itemCount: ScanFilter.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final filter = ScanFilter.values[index];
              final selected = filter == _adjustments.filter;
              return ChoiceChip(
                label: Text(ImageProcessor.labelFor(filter)),
                selected: selected,
                onSelected: (_) => _onFilter(filter),
                showCheckmark: false,
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        _ToneSlider(
          icon: Icons.brightness_6_rounded,
          label: 'Brightness',
          value: _adjustments.brightness,
          onChanged: _onBrightness,
        ),
        _ToneSlider(
          icon: Icons.contrast_rounded,
          label: 'Contrast',
          value: _adjustments.contrast,
          onChanged: _onContrast,
        ),
        Row(
          children: [
            TextButton(
              onPressed: _adjustments.isNeutralTone ? null : _resetTone,
              child: const Text('Reset'),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded, size: 20),
              label: Text(
                _saving ? 'Saving…' : (_hasNextPage ? 'Save & next' : 'Save'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ToneSlider extends StatelessWidget {
  const _ToneSlider({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Tooltip(
          message: label,
          child: Icon(
            icon,
            size: 19,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: -1,
            max: 1,
            divisions: 40,
            label: value == 0 ? label : value.toStringAsFixed(2),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
