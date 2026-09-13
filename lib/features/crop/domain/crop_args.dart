import 'package:flutter/foundation.dart';
import 'package:scan2/features/camera/domain/quad_detector.dart';
import 'package:scan2/features/crop/domain/image_processor.dart';

/// Route payload for the crop screen.
@immutable
class CropArgs {
  const CropArgs({
    required this.imagePath,
    this.initialQuad,
    this.adjustments = const ScanAdjustments(),
    this.edgesAlreadyApplied = false,
    this.documentId,
    this.pageIndex = 0,
    this.cropRemainingPages = false,
  });

  /// The page to edit. The screen re-derives from the page's stored original
  /// when one exists, so this may be either.
  final String imagePath;

  final Quad? initialQuad;
  final ScanAdjustments adjustments;

  /// True when the image was already edge-cropped (VisionKit / ML Kit), so
  /// the crop opens on the full frame instead of hunting for borders.
  final bool edgesAlreadyApplied;

  /// When set, closing or saving the editor returns to this document instead
  /// of popping — used after a fresh capture so Crop & rotate is first.
  final int? documentId;

  /// Page being edited when [documentId] is set.
  final int pageIndex;

  /// After save, open the next page of the same scan (fresh multi-page capture).
  final bool cropRemainingPages;
}
