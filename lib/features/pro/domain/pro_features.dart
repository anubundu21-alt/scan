/// Copy for Free vs Pro, used by the paywall and Complete features.
class ProFeatureLine {
  const ProFeatureLine(this.title, [this.detail]);

  final String title;
  final String? detail;
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
