/// Copy for Free vs Pro, used by the paywall and Complete features.
class ProFeatureLine {
  const ProFeatureLine(this.title, [this.detail]);

  final String title;
  final String? detail;
}

const freeFeatureLines = [
  ProFeatureLine('Scan documents', '10 free scans each week'),
  ProFeatureLine('All PDF tools', 'Convert, compress, merge, split and sign'),
  ProFeatureLine('Extract text from one page'),
  ProFeatureLine('Save and share PDF or JPEG'),
  ProFeatureLine('Folders on the home list'),
];

const proFeatureLines = [
  ProFeatureLine('Unlimited scans'),
  ProFeatureLine(
    'Auto-save by document type',
    'Passports go to Private. ID cards get a second copy in IDs.',
  ),
  ProFeatureLine('Searchable PDFs and extra OCR languages'),
  ProFeatureLine('Smart folders, favorites and private documents'),
  ProFeatureLine('PNG, print, selected pages and batch export'),
];
