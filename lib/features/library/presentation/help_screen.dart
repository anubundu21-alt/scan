import 'package:flutter/material.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/pro/domain/scan_quota.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static final _topics = [
    (
      'Camera permission',
      'The first scan asks for Camera once. If you tapped Don’t Allow, open '
          'iOS Settings → Scanella → Camera, then try again.',
    ),
    (
      'Where PDFs go',
      'Open a scan, tap Export, then Save PDF to Files. You name the PDF, '
          'then the Files app opens so you choose the folder. Share PDF sends '
          'it to Mail or Messages.',
    ),
    (
      'Crop vs Enhance',
      'After a photo, Crop & rotate lines up the page and turns it. Next is '
          'Enhance, where filters, brightness and contrast live. Save writes '
          'the finished page.',
    ),
    (
      'Trash',
      'Deleted scans sit in Trash for 30 days. Restore them from the menu, or '
          'empty Trash to delete for good.',
    ),
    (
      'App lock',
      'Turn on App lock in Settings. Use a PIN, and Face ID when the phone '
          'offers it. Scans still never leave this device.',
    ),
    ('ID card', 'All tools → ID card captures front and back as one two-page scan.'),
    (
      'Import from file',
      'Home → Import from file. Choose a PDF from Files — it is not scanned. '
          'Then reorder, rotate, add pages from Photos or Files, merge, or split.',
    ),
    (
      'Sign PDF',
      'All tools → Sign PDF. Upload a PDF from Files, or open one you already '
          'uploaded. Draw a signature and place it on a page. Camera scans '
          'stay in Documents — they are not in this list.',
    ),
    (
      'PDF to Word',
      'All tools → PDF to Word. Upload a PDF, or pick one you '
          'already uploaded, and share the .docx. Converting needs a '
          'connection: the file is sent to our converter and deleted as soon '
          'as the Word file comes back. Nothing is kept.',
    ),
    (
      'Word to PDF',
      'All tools → Word to PDF. Upload a DOC, DOCX, ODT or RTF '
          'and share the PDF. Like PDF to Word it converts online, and the '
          'file is deleted as soon as the PDF comes back.',
    ),
    (
      'Compress PDF',
      'All tools → Compress PDF. Upload a PDF from Files. The '
          'text stays selectable; photographs and scans inside are what '
          'shrink. Needs a connection: the file is sent to our converter and '
          'deleted as soon as the smaller PDF comes back.',
    ),
    (
      'Merge PDF',
      'All tools → Merge PDF. Pick two or more PDFs from Files '
          'and get one back with all of their pages, in the order you set. '
          'Needs a connection, and the files are deleted as soon as the '
          'merged PDF comes back.',
    ),
    (
      'Split PDF',
      'All tools → Split PDF. Pick a PDF first, then keep named '
          'pages as one PDF or cut the file into pieces. Pages are copied as '
          'they are. Needs a connection, and the file is deleted as soon as '
          'it comes back.',
    ),
    (
      'PDF to JPG',
      'All tools → PDF to JPG. Upload a PDF from Files. Each '
          'page is saved as a JPG or PNG on this device. Several pages come '
          'back as a zip. Nothing is uploaded.',
    ),
    (
      'Image to PDF',
      'All tools → Image to PDF. Pick JPG or PNG photos and '
          'get one PDF, one page per image, in the order you chose. Runs on '
          'this device.',
    ),
    (
      'Scanella Pro',
      'Menu → Scanella Pro, or Settings → Scanella Pro. Payment goes '
          'through the App Store and your Apple ID — not a card form in the '
          'app. Pro adds unlimited scans, all tools, auto-save by document '
          'type (passports to Private, a second ID copy in IDs), searchable '
          'PDFs, more OCR languages, smart folders, tags, favorites, private '
          'documents, PNG, print, selected pages and batch share. PDF tools '
          'stay open on the free plan. Pro is for scanning after the free '
          'scans are used.',
    ),
    (
      'Free scans',
      'The first time you install Scanella, the free plan includes '
          '${ScanQuota.starterLimit} scans. After those are used, you get '
          '${ScanQuota.weeklyLimit} free scans each week. The weekly count '
          'resets after one week. A scan is a document you capture or '
          'import. Editing, merging, or restoring does not use another. '
          'Scanella Pro removes the limit.',
    ),
    (
      'Private documents',
      'Long-press a scan → Make private. It leaves the main list. Open '
          'Private from the menu with Face ID to see it again. The file never '
          'leaves this phone. Scanella Pro also files a scanned passport '
          'there automatically.',
    ),
    (
      'IDs',
      'Menu → IDs lists identity cards. Scanella Pro reads a new scan and '
          'saves a second copy there when it is an ID card. Passports go to '
          'Private instead.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        itemCount: _topics.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final topic = _topics[index];
          return Material(
            color: theme.brightness == Brightness.light
                ? Colors.white
                : theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Brand.radiusCard),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(topic.$1, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Text(topic.$2, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
