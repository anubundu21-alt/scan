import 'package:scan2/core/branding.dart';

/// In-app Terms and Privacy copy. These pages are the real documents, not
/// placeholders that wait on a website.
class LegalSection {
  const LegalSection({required this.heading, required this.body});

  final String heading;
  final String body;
}

enum LegalDocument { terms, privacy }

class LegalCopy {
  const LegalCopy._();

  static String title(LegalDocument document) => switch (document) {
    LegalDocument.terms => 'Terms of Use',
    LegalDocument.privacy => 'Privacy Policy',
  };

  static List<LegalSection> sections(LegalDocument document) =>
      switch (document) {
        LegalDocument.terms => _terms,
        LegalDocument.privacy => _privacy,
      };

  static const _terms = [
    LegalSection(
      heading: 'The app',
      body:
          'Scanella is an offline document scanner for your phone. These '
          'terms cover your use of the app on this device. If you do not '
          'agree, do not use Scanella.',
    ),
    LegalSection(
      heading: 'Your scans',
      body:
          'Pages you capture, import, or export belong to you. Scanella does '
          'not claim any rights in that content. You are responsible for '
          'having the right to scan, store, and share it.',
    ),
    LegalSection(
      heading: 'What the app does',
      body:
          'Scanella lets you photograph or import pages, crop and enhance '
          'them, keep them in a local library, and export PDFs or images. '
          'There is no Scanella account and no Scanella cloud. Features that '
          'need the system (camera, Photos, Files, Face ID) use the '
          'permissions you grant on the phone. Scanella Pro is an optional '
          'subscription billed by Apple or Google; prices are shown in the '
          'currency for your store or current country.',
    ),
    LegalSection(
      heading: 'Free scans',
      body:
          'The first time you install Scanella, the free plan includes 10 '
          'scans on this device. After those are used, you get 5 free scans '
          'every 30 days, and unused scans do not carry over. A scan is a new '
          'document you capture or import. Merging, splitting, or editing an '
          'existing document does not use another free scan. The count stays '
          'with the device: deleting the app and installing it again does not '
          'start over. Scanella Pro removes the limit.',
    ),
    LegalSection(
      heading: 'No account, no sync',
      body:
          'Scans live only on this device unless you export or share them '
          'yourself. Uninstalling the app, losing the phone, or clearing '
          'app data can delete your library. Keep copies of anything you '
          'need to keep.',
    ),
    LegalSection(
      heading: 'Acceptable use',
      body:
          'Use Scanella only in ways that are lawful where you are. Do not '
          'use it to scan or share content you are not allowed to copy.',
    ),
    LegalSection(
      heading: 'The software',
      body:
          'Scanella is provided as-is. Scanning depends on lighting, the '
          'camera, and the page in front of it, so results will not be '
          'perfect every time. We are not liable for lost scans, failed '
          'exports, or decisions you make from a scan.',
    ),
    LegalSection(
      heading: 'Changes',
      body:
          'These terms may change when the app changes. The copy in this '
          'version of Scanella is the agreement that applies while you use '
          'it.',
    ),
    LegalSection(
      heading: 'Contact',
      body:
          'Questions about these terms, a billing problem, or anything else '
          'about the app: write to ${AppIdentity.supportEmail}. Refunds for a '
          'subscription are handled by Apple or Google, not by us, but we can '
          'point you at the right form.',
    ),
  ];

  static const _privacy = [
    LegalSection(
      heading: 'Nothing is uploaded',
      body:
          'Scanella does not have a server, an account system, or analytics. '
          'Scans, PDFs, folder names, and settings stay on this phone. We '
          'do not collect, sell, or share your documents. Opening Scanella '
          'Pro may look up this connection’s country so the price can be '
          'shown in local currency. That request does not include scans.',
    ),
    LegalSection(
      heading: 'What stays on the device',
      body:
          'The library (page images and titles), your PIN hash if you turn '
          'on App lock, and preferences such as theme and default filter '
          'are stored in app storage on this device. A password for a PDF '
          'you export is written into that PDF on the device; it is not '
          'sent to us. A free-scan count is stored on this device '
          'so the allowance can reset after thirty days. That value is a '
          'number, not your pages.',
    ),
    LegalSection(
      heading: 'Permissions',
      body:
          'Camera is used only when you scan. Photos access is used only '
          'when you import from the library or save pages to a Scanella '
          'album. Face ID or fingerprint is used only to unlock the app, '
          'through the operating system; we never see the biometric data. '
          'You can refuse or revoke these in system Settings.',
    ),
    LegalSection(
      heading: 'Sharing you choose',
      body:
          'If you use Share, Save PDF to Files, or Save to Photos, the '
          'operating system hands those files to the app or folder you '
          'pick. That is your action, not an upload to Scanella.',
    ),
    LegalSection(
      heading: 'Children',
      body:
          'Scanella does not ask for an age or an account. It is not aimed '
          'at collecting information from children. A parent or guardian '
          'who lets a child use the phone should treat scans like any other '
          'files on that phone.',
    ),
    LegalSection(
      heading: 'Questions',
      body:
          'Because nothing is sent to us, there is no personal data on a '
          'Scanella server to access, correct, or delete. Removing the app '
          'deletes the on-device library. If you want to ask about this '
          'policy, or about anything the app does with your pages, write to '
          '${AppIdentity.supportEmail} and a person will answer.',
    ),
  ];
}
