
enum ReportCategory {
  danger,
  safe,
}

class ReportType {
  final String id;
  final String label;
  final String icon;
  final ReportCategory category;

  const ReportType({
    required this.id,
    required this.label,
    required this.icon,
    required this.category,
  });
}

// User requested to EXCLUDE 'Snake' and 'Poison' for now.
const List<ReportType> reportTypes = [
  ReportType(id: 'GLASS', label: 'Broken Glass', icon: '🦶❌', category: ReportCategory.danger),
  ReportType(id: 'ANIMAL', label: 'Aggressive Animal', icon: '🐕‍🦺', category: ReportCategory.danger),
  ReportType(id: 'TRASH', label: 'Trash/Waste', icon: '🗑️', category: ReportCategory.danger),
  ReportType(id: 'OTHER', label: 'Other Hazard', icon: '⚠️', category: ReportCategory.danger),
];
