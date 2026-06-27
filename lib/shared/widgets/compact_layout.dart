import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';

/// UI density helpers when [compactLayoutProvider] is enabled.
class CompactLayout {
  CompactLayout._();

  static const String settingsKey = 'ui_compact_layout';

  static bool isCompact(WidgetRef ref) => ref.watch(compactLayoutProvider);

  static double pagePadding(WidgetRef ref) => isCompact(ref) ? 16 : 24;

  static double headerTitleSize(WidgetRef ref) => isCompact(ref) ? 20 : 22;

  static double sidebarExpandedWidth(WidgetRef ref) => isCompact(ref) ? 220 : 260;

  static double sidebarCollapsedWidth(WidgetRef ref) => isCompact(ref) ? 60 : 72;

  static EdgeInsets pageHeaderPadding(WidgetRef ref) {
    final p = pagePadding(ref);
    return EdgeInsets.fromLTRB(p, p, p, isCompact(ref) ? 12 : 16);
  }
}
