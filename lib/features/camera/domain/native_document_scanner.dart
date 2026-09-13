import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Native document scanner — VisionKit on iOS, ML Kit Document Scanner on Android.
///
/// This is the production-quality edge detection path (platform CV), not the
/// live preview heuristic. Returns cropped page image paths, or null if cancelled.
class NativeDocumentScanner {
  const NativeDocumentScanner();

  Future<List<String>?> scan({int maxPages = 24}) async {
    if (kIsWeb) return null;

    // Do not call Permission.camera.request() here. CunningDocumentScanner
    // already does, and a second overlapping request throws
    // ERROR_ALREADY_REQUESTING_PERMISSIONS — the first-open crash.
    final status = await Permission.camera.status;
    if (status.isPermanentlyDenied) {
      throw const CameraPermissionNeeded();
    }

    try {
      return await CunningDocumentScanner.getPictures(
        noOfPages: maxPages,
        isGalleryImportAllowed: true,
      );
    } on PlatformException catch (error) {
      if (error.code == 'ERROR_ALREADY_REQUESTING_PERMISSIONS') {
        await Future<void>.delayed(const Duration(milliseconds: 700));
        return CunningDocumentScanner.getPictures(
          noOfPages: maxPages,
          isGalleryImportAllowed: true,
        );
      }
      rethrow;
    }
  }
}

/// Camera access was refused with "Don't allow" / Don't ask again.
class CameraPermissionNeeded implements Exception {
  const CameraPermissionNeeded();

  @override
  String toString() =>
      'Scanella needs camera access to scan documents. '
      'Enable Camera in Settings, then try again.';
}
