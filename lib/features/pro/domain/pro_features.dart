import 'package:flutter/material.dart';
import 'package:scan2/core/theme/brand.dart';

/// Copy for Free vs Pro, used by the paywall and Complete features.
class ProFeatureLine {
  const ProFeatureLine(this.title, [this.detail]);

  final String title;
  final String? detail;
}

class PlanPerk {
  const PlanPerk({
    required this.icon,
    required this.color,
    required this.wash,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final Color wash;
  final String title;
  final String detail;
}

const freeFeatureLines = [
  ProFeatureLine(
    '50 free scans for new users, then 10 every week',
    'The first time you install Scanella, you get 50 scans. After those are '
        'used, you get 10 free scans each week. The weekly allowance resets '
        'the following week.',
  ),
  ProFeatureLine(
    'All PDF tools',
    'Convert, compress, merge, split and sign',
  ),
];

const proFeatureLines = [
  ProFeatureLine(
    'Unlimited scans',
    'Scan as many documents as you need.',
  ),
  ProFeatureLine(
    'Advanced OCR',
    'Searchable PDFs with extra OCR languages.',
  ),
  ProFeatureLine(
    'All PDF tools',
    'Convert, compress, merge, split, sign and more.',
  ),
];

const freePlanPerks = [
  PlanPerk(
    icon: Icons.crop_free_rounded,
    color: Color(0xFF1F9A6B),
    wash: Color(0xFFE4F3ED),
    title: '50 free scans for new users',
    detail: 'Then 10 free scans every week',
  ),
  PlanPerk(
    icon: Icons.picture_as_pdf_outlined,
    color: Color(0xFF7B61FF),
    wash: Color(0xFFF0ECFF),
    title: 'All PDF tools',
    detail: 'Convert, compress, merge, split and sign',
  ),
  PlanPerk(
    icon: Icons.document_scanner_outlined,
    color: Color(0xFF2C7BE5),
    wash: Color(0xFFE6F0FF),
    title: 'Extract text from scans',
    detail: 'Basic OCR',
  ),
  PlanPerk(
    icon: Icons.folder_outlined,
    color: Color(0xFFF5A524),
    wash: Color(0xFFFFF3DC),
    title: 'Smart organization',
    detail: 'Folders, favorites and private documents',
  ),
  PlanPerk(
    icon: Icons.ios_share_rounded,
    color: Color(0xFF1F9A6B),
    wash: Color(0xFFE4F3ED),
    title: 'Save & share',
    detail: 'Export as PDF or JPEG',
  ),
];

const freePlanLimits = [
  'Limited to 50 scans at start',
  'After that, 10 scans weekly',
];

const proPlanPerks = [
  PlanPerk(
    icon: Icons.all_inclusive_rounded,
    color: Color(0xFF1F9A6B),
    wash: Color(0xFFE4F3ED),
    title: 'Unlimited scans',
    detail: 'Scan as many documents as you need',
  ),
  PlanPerk(
    icon: Icons.document_scanner_outlined,
    color: Color(0xFF7B61FF),
    wash: Color(0xFFF0ECFF),
    title: 'Advanced OCR',
    detail: 'Searchable PDFs with extra OCR languages',
  ),
  PlanPerk(
    icon: Icons.picture_as_pdf_outlined,
    color: Color(0xFFE85A7A),
    wash: Color(0xFFFDE8EE),
    title: 'All PDF tools',
    detail: 'Convert, compress, merge, split, sign and more',
  ),
  PlanPerk(
    icon: Icons.folder_outlined,
    color: Brand.docBlue,
    wash: Color(0xFFE6F0FF),
    title: 'Smart organization',
    detail: 'Folders, favorites and private documents',
  ),
  PlanPerk(
    icon: Icons.file_upload_outlined,
    color: Color(0xFFE07A3D),
    wash: Color(0xFFFFEDE3),
    title: 'More export options',
    detail: 'PNG, print, selected pages and batch export',
  ),
];
