import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:scan2/core/branding.dart';
import 'package:scan2/features/legal/legal_copy.dart';

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

  test('every legal page offers the support address', () {
    const email = 'support@scanella.com';
    const link = 'mailto:$email';
    expect(AppIdentity.supportEmail, email);

    // Every page routes to Contact; the documents and Contact itself also
    // spell the address out. The home page just links through.
    for (final path in [
      'legal-site/index.html',
      'legal-site/terms/index.html',
      'legal-site/privacy/index.html',
      'legal-site/contact/index.html',
    ]) {
      final page = File(path).readAsStringSync();
      expect(
        page,
        contains('href="/contact"'),
        reason: '$path does not link the Contact page',
      );
      expect(
        page,
        contains('All rights reserved'),
        reason: '$path has no copyright line',
      );
    }

    for (final path in [
      'legal-site/terms/index.html',
      'legal-site/privacy/index.html',
      'legal-site/contact/index.html',
    ]) {
      final page = File(path).readAsStringSync();
      expect(page, contains(link), reason: '$path has no mailto link');
      expect(page, contains(email), reason: '$path does not show the address');
    }

    final contact = File('legal-site/contact/index.html').readAsStringSync();
    expect(contact, contains('<title>Contact — Scanella</title>'));
    expect(contact, contains('Write to us'));
  });

  test('in-app Terms and Privacy carry the support address', () {
    String bodies(LegalDocument document) =>
        LegalCopy.sections(document).map((s) => s.body).join('\n');

    expect(bodies(LegalDocument.terms), contains(AppIdentity.supportEmail));
    expect(bodies(LegalDocument.privacy), contains(AppIdentity.supportEmail));
  });
}
