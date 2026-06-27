import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/features/dashboard/application/dashboard_layout_prefs.dart';

void main() {
  test('round-trips layout prefs json', () {
    const prefs = DashboardLayoutPrefs(
      showStats: false,
      showSmartInsights: true,
      showRecentTransactions: false,
      showLowStock: true,
    );

    final restored = DashboardLayoutPrefs.fromJsonString(prefs.toJsonString());

    expect(restored.showStats, false);
    expect(restored.showSmartInsights, true);
    expect(restored.showRecentTransactions, false);
    expect(restored.showLowStock, true);
  });
}
