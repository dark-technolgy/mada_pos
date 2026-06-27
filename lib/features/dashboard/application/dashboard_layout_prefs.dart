import 'dart:convert';

class DashboardLayoutPrefs {
  const DashboardLayoutPrefs({
    this.showStats = true,
    this.showSmartInsights = true,
    this.showRecentTransactions = true,
    this.showLowStock = true,
  });

  static const settingsKey = 'dashboard_layout_prefs';

  static const defaults = DashboardLayoutPrefs();

  final bool showStats;
  final bool showSmartInsights;
  final bool showRecentTransactions;
  final bool showLowStock;

  DashboardLayoutPrefs copyWith({
    bool? showStats,
    bool? showSmartInsights,
    bool? showRecentTransactions,
    bool? showLowStock,
  }) {
    return DashboardLayoutPrefs(
      showStats: showStats ?? this.showStats,
      showSmartInsights: showSmartInsights ?? this.showSmartInsights,
      showRecentTransactions:
          showRecentTransactions ?? this.showRecentTransactions,
      showLowStock: showLowStock ?? this.showLowStock,
    );
  }

  Map<String, dynamic> toJson() => {
    'showStats': showStats,
    'showSmartInsights': showSmartInsights,
    'showRecentTransactions': showRecentTransactions,
    'showLowStock': showLowStock,
  };

  String toJsonString() => jsonEncode(toJson());

  factory DashboardLayoutPrefs.fromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return defaults;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      return DashboardLayoutPrefs(
        showStats: data['showStats'] as bool? ?? true,
        showSmartInsights: data['showSmartInsights'] as bool? ?? true,
        showRecentTransactions: data['showRecentTransactions'] as bool? ?? true,
        showLowStock: data['showLowStock'] as bool? ?? true,
      );
    } catch (_) {
      return defaults;
    }
  }
}
