import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/core/branding.dart';

void main() {
  test('Vercel legal pages exist and match the in-app copy', () {
    final terms = File('legal-site/terms/index.html').readAsStringSync();
    final privacy = File('legal-site/privacy/index.html').readAsStringSync();
    final home = File('legal-site/index.html').readAsStringSync();

    expect(home, contains('IBM+Plex+Sans'));
    expect(home, contains('What Scanella does'));
    expect(home, contains('Terms of Use'));
    expect(home, contains('Privacy Policy'));
    expect(home, contains('site-header'));
    expect(home, contains('/mark.png'));
    expect(File('legal-site/mark.png').existsSync(), isTrue);
    expect(home, contains('Scan<span class="ella">ella</span>'));
    expect(File('legal-site/styles.css').readAsStringSync(), contains('#1f9a6b'));
    expect(File('legal-site/styles.css').readAsStringSync(), contains('font-size: 125%'));
    expect(File('legal-site/styles.css').readAsStringSync(), isNot(contains('#1d9e75')));
    expect(File('legal-site/styles.css').readAsStringSync(), isNot(contains('#2563eb')));
    expect(File('legal-site/styles.css').readAsStringSync(), isNot(contains('#eef3fb')));
    expect(File('legal-site/styles.css').readAsStringSync(), isNot(contains('--phone:')));
    expect(terms, contains('IBM+Plex+Sans'));
    expect(privacy, contains('IBM+Plex+Sans'));
    expect(
      File('legal-site/styles.css').readAsStringSync(),
      contains('IBM Plex Sans'),
    );
    expect(terms, contains('belong to you'));
    expect(privacy, contains('does not have a server'));
    expect(AppIdentity.termsUrl, 'https://canela.vercel.app/terms');
    expect(AppIdentity.privacyUrl, 'https://canela.vercel.app/privacy');
  });
}
