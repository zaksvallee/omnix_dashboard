enum ReportOutputMode {
  pdf('PDF'),
  excel('EXCEL'),
  json('JSON');

  const ReportOutputMode(this.label);

  final String label;
}
