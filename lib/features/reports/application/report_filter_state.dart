import 'dart:convert';

class ReportFilterState {
  const ReportFilterState({
    required this.startDate,
    required this.endDate,
    this.selectedReport = 'sales',
  });

  static const _settingKey = 'reports_last_filters';

  static String get settingsKey => _settingKey;

  final DateTime startDate;
  final DateTime endDate;
  final String selectedReport;

  static ReportFilterState defaults() {
    final now = DateTime.now();
    return ReportFilterState(
      startDate: now.subtract(const Duration(days: 30)),
      endDate: now,
      selectedReport: 'sales',
    );
  }

  ReportFilterState copyWith({
    DateTime? startDate,
    DateTime? endDate,
    String? selectedReport,
  }) {
    return ReportFilterState(
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      selectedReport: selectedReport ?? this.selectedReport,
    );
  }

  Map<String, dynamic> toJson() => {
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'selectedReport': selectedReport,
  };

  String toJsonString() => jsonEncode(toJson());

  factory ReportFilterState.fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return ReportFilterState.defaults();
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final start = DateTime.tryParse(data['startDate'] as String? ?? '');
      final end = DateTime.tryParse(data['endDate'] as String? ?? '');
      if (start == null || end == null) return ReportFilterState.defaults();
      return ReportFilterState(
        startDate: start,
        endDate: end,
        selectedReport: data['selectedReport'] as String? ?? 'sales',
      );
    } catch (_) {
      return ReportFilterState.defaults();
    }
  }
}
