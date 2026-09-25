import 'package:flutter/material.dart';
import 'package:scan2/core/theme/brand.dart';
import 'package:scan2/features/pro/domain/scan_quota.dart';

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
    '${ScanQuota.starterLimit} free scans to start, then '
        '${ScanQuota.monthlyLimit} every ${ScanQuota.resetDays} days',
    'Unused scans do not carry over.',
  ),
  ProFeatureLine('All PDF tools', 'Convert, compress, merge, split and sign'),
];

const proFeatureLines = [
  ProFeatureLine('Unlimited scans', 'Scan as many documents as you need.'),
  ProFeatureLine(
    'No ${ScanQuota.resetDays}-day wait',
    'Keep scanning after the free scans run out.',
  ),
];

const freePlanPerks = [
  PlanPerk(
    icon: Icons.crop_free_rounded,
    color: Color(0xFF1F9A6B),
    wash: Color(0xFFE4F3ED),
    title: '${ScanQuota.starterLimit} free scans to start',
    detail: 'Then ${ScanQuota.monthlyLimit} every ${ScanQuota.resetDays} days',
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
    detail: 'Any page count, any language',
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
    detail: 'PDF, JPEG, PNG, searchable PDF and selected pages',
  ),
];

const freePlanLimits = [
  '${ScanQuota.starterLimit} scans to start',
  'Then ${ScanQuota.monthlyLimit} scans every ${ScanQuota.resetDays} days',
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
    icon: Icons.schedule_rounded,
    color: Color(0xFF7B61FF),
    wash: Color(0xFFF0ECFF),
    title: 'No ${ScanQuota.resetDays}-day wait',
    detail: 'Keep scanning after the free scans run out',
  ),
  PlanPerk(
    icon: Icons.check_circle_outline_rounded,
    color: Brand.docBlue,
    wash: Color(0xFFE6F0FF),
    title: 'Everything in Free',
    detail: 'All other features stay free for everyone',
  ),
];
