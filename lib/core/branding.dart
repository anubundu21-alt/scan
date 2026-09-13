/// User-facing identity. Keep this separate from the Dart package name
/// (`scan2`) so renaming the store app does not rewrite scanner imports.
class AppIdentity {
  const AppIdentity._();

  static const name = 'Scanella';

  /// Same as iOS `com.scanella.mobile`.
  static const applicationId = 'com.scanella.mobile';

  /// Photos album written by "Save to Photos".
  static const photosAlbum = name;

  /// Hosted Terms / Privacy (Vercel). Project name `canela` → this host.
  static const legalSite = 'https://canela.vercel.app';
  static const termsUrl = '$legalSite/terms';
  static const privacyUrl = '$legalSite/privacy';
}
