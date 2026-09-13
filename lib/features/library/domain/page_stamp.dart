import 'package:flutter/foundation.dart';

/// A signature (and optional caption) placed on a finished page.
///
/// Stored on the page, not burnt into the JPEG, so Crop & enhance can still
/// re-derive from the original. Export and Photos composite the stamps on
/// the way out.
@immutable
class PageStamp {
  const PageStamp({
    required this.imagePath,
    required this.nx,
    required this.ny,
    required this.nw,
    required this.nh,
    this.caption,
  });

  /// PNG of the drawn signature, kept on disk.
  final String imagePath;

  /// Top-left and size as fractions of the page (0–1).
  final double nx;
  final double ny;
  final double nw;
  final double nh;

  /// Date and/or name drawn under the signature.
  final String? caption;

  PageStamp copyWith({
    String? imagePath,
    double? nx,
    double? ny,
    double? nw,
    double? nh,
    String? caption,
    bool clearCaption = false,
  }) {
    return PageStamp(
      imagePath: imagePath ?? this.imagePath,
      nx: nx ?? this.nx,
      ny: ny ?? this.ny,
      nw: nw ?? this.nw,
      nh: nh ?? this.nh,
      caption: clearCaption ? null : (caption ?? this.caption),
    );
  }

  /// 90° clockwise in normalized page space.
  PageStamp rotatedClockwise() {
    return PageStamp(
      imagePath: imagePath,
      nx: 1 - ny - nh,
      ny: nx,
      nw: nh,
      nh: nw,
      caption: caption,
    );
  }

  Map<String, dynamic> toJson(String Function(String path) relativize) {
    return {
      'image': relativize(imagePath),
      'nx': nx,
      'ny': ny,
      'nw': nw,
      'nh': nh,
      if (caption != null && caption!.trim().isNotEmpty) 'caption': caption,
    };
  }

  static PageStamp? fromJson(Object? raw, String Function(String rel) resolve) {
    if (raw is! Map) return null;
    final image = raw['image'];
    if (image is! String || image.isEmpty) return null;
    final nx = (raw['nx'] as num?)?.toDouble();
    final ny = (raw['ny'] as num?)?.toDouble();
    final nw = (raw['nw'] as num?)?.toDouble();
    final nh = (raw['nh'] as num?)?.toDouble();
    if (nx == null || ny == null || nw == null || nh == null) return null;
    final caption = raw['caption'] as String?;
    return PageStamp(
      imagePath: resolve(image),
      nx: nx.clamp(0, 1),
      ny: ny.clamp(0, 1),
      nw: nw.clamp(0.02, 1),
      nh: nh.clamp(0.02, 1),
      caption: caption?.trim().isEmpty ?? true ? null : caption!.trim(),
    );
  }
}
