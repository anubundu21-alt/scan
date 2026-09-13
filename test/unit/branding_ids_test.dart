import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/core/branding.dart';
import 'package:scan2/core/theme/brand.dart';

void main() {
  test('brand accent is #1F9A6B and wordmark splits Scan / ella', () {
    expect(Brand.accent, const Color(0xFF1F9A6B));
    expect(Brand.wordmarkScan, const Color(0xFF111111));
    expect(File('android/app/src/main/res/values/colors.xml').readAsStringSync(),
        contains('#1F9A6B'));
    expect(File('assets/brand/app_mark.png').existsSync(), isTrue);
  });

  test('store ids match Scanella on both platforms', () {
    expect(AppIdentity.name, 'Scanella');
    expect(AppIdentity.applicationId, 'com.scanella.mobile');
    expect(AppIdentity.photosAlbum, 'Scanella');

    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('applicationId = "${AppIdentity.applicationId}"'));
    expect(gradle, contains('namespace = "${AppIdentity.applicationId}"'));
    expect(gradle, isNot(contains('com.scan2.scan2')));

    final plist = File('ios/Runner/Info.plist').readAsStringSync();
    expect(plist, contains('<string>Scanella</string>'));
    expect(plist, contains('NSLocationWhenInUseUsageDescription'));
    expect(plist, contains('NSLocationAlwaysAndWhenInUseUsageDescription'));
    expect(plist, contains('NSLocationAlwaysUsageDescription'));
    expect(plist, contains('does not use your location'));

    final mainActivity = File(
      'android/app/src/main/kotlin/com/scanella/mobile/MainActivity.kt',
    );
    expect(mainActivity.existsSync(), isTrue);
    expect(
      File(
        'android/app/src/main/kotlin/com/scan2/scan2/MainActivity.kt',
      ).existsSync(),
      isFalse,
    );
  });

  test('analysis_options includes flutter_lints', () {
    final yaml = File('analysis_options.yaml').readAsStringSync();
    expect(yaml, contains('include: package:flutter_lints/flutter.yaml'));
  });

  test('Android release workflow builds a signed app bundle', () {
    final yml = File('.github/workflows/android-release.yml').readAsStringSync();
    expect(yml, contains('flutter build appbundle --release'));
    expect(yml, contains('com.scanella.mobile'));
    expect(yml, isNot(contains('Android release not configured yet')));
  });
}
