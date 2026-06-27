import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/features/reports/application/report_filter_state.dart';

void main() {
  test('round-trips filter state json', () {
    final state = ReportFilterState(
      startDate: DateTime(2025, 1, 1),
      endDate: DateTime(2025, 1, 31),
      selectedReport: 'sales',
    );

    final restored = ReportFilterState.fromJsonString(state.toJsonString());

    expect(restored.startDate, state.startDate);
    expect(restored.endDate, state.endDate);
    expect(restored.selectedReport, 'sales');
  });

  test('returns defaults for invalid json', () {
    final restored = ReportFilterState.fromJsonString('not-json');
    expect(restored.selectedReport, 'sales');
  });
}
