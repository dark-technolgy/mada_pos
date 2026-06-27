import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import '../../core/database/database.dart';
import '../../core/security/session_manager.dart';
import '../../core/utils/currency_conversion.dart';
import '../../core/setup/windows_prerequisites.dart';
import '../../features/backup/application/auto_backup_service.dart';
import '../../core/services/app_notifications_service.dart';
import '../../core/services/branch_context_service.dart';

// ─── DATABASE ───
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// ─── SESSION ───
final screenLockedProvider = StateProvider<bool>((ref) => false);

final sessionManagerProvider = Provider<SessionManager>((ref) {
  final db = ref.watch(databaseProvider);
  final session = SessionManager(
    db,
    onUserChanged: (user) {
      ref.read(currentUserProvider.notifier).state = user;
      if (user == null) {
        ref.read(screenLockedProvider.notifier).state = false;
      }
    },
    onLockChanged: (locked) {
      ref.read(screenLockedProvider.notifier).state = locked;
    },
  );
  ref.onDispose(() => session.dispose());
  return session;
});

final appNotificationsProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  final db = ref.watch(databaseProvider);
  final branchId = ref.watch(activeBranchIdProvider);
  return const AppNotificationsService().load(db, branchId: branchId);
});

// ─── CURRENT USER ───
final currentUserProvider = StateProvider<User?>((ref) => null);

// ─── THEME MODE ───
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

// ─── LOCALE ───
final localeProvider = StateProvider<Locale>((ref) => const Locale('ar'));

final appBootstrapProvider = FutureProvider<Map<String, String>>((ref) async {
  if (Platform.isWindows) {
    await WindowsPrerequisites.ensureInstalled();
  }

  final db = ref.read(databaseProvider);
  final persistedSettings = await db.select(db.settings).get();
  final settingsMap = {
    for (final setting in persistedSettings) setting.key: setting.value,
  };

  final savedThemeMode = settingsMap['theme_mode'];
  if (savedThemeMode != null) {
    ref.read(themeModeProvider.notifier).state = switch (savedThemeMode) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  final savedLanguage = settingsMap['language'];
  if (savedLanguage != null && {'ar', 'en', 'ku'}.contains(savedLanguage)) {
    ref.read(localeProvider.notifier).state = Locale(savedLanguage);
  }

  final compactLayout = settingsMap['ui_compact_layout'];
  if (compactLayout != null) {
    ref.read(compactLayoutProvider.notifier).state = compactLayout == 'true';
  }

  await const AutoBackupService().runIfDue(db);
  final defaultBranchId =
      await const BranchContextService().ensureDefaultBranch(db);
  ref.read(activeBranchIdProvider.notifier).state = defaultBranchId;

  return settingsMap;
});

final branchesProvider = FutureProvider<List<Branche>>((ref) async {
  final db = ref.watch(databaseProvider);
  return const BranchContextService().loadActiveBranches(db);
});

final activeBranchIdProvider = StateProvider<int?>((ref) => null);

final activeBranchProvider = FutureProvider<Branche?>((ref) async {
  final id = ref.watch(activeBranchIdProvider);
  if (id == null) return null;
  final db = ref.watch(databaseProvider);
  return (db.select(db.branches)..where((b) => b.id.equals(id)))
      .getSingleOrNull();
});

// ─── CURRENCIES ───
final currenciesProvider = FutureProvider<List<Currency>>((ref) async {
  final db = ref.watch(databaseProvider);
  return (db.select(db.currencies)..orderBy([
        (c) => OrderingTerm.desc(c.isDefault),
        (c) => OrderingTerm.asc(c.code),
      ]))
      .get();
});

final currencyMapProvider = FutureProvider<Map<String, Currency>>((ref) async {
  final currencies = await ref.watch(currenciesProvider.future);
  return {for (final currency in currencies) currency.code: currency};
});

final defaultCurrencyProvider = FutureProvider<Currency?>((ref) async {
  final currencies = await ref.watch(currenciesProvider.future);
  return CurrencyConversion.findDefaultCurrency(currencies);
});

// ─── UI DENSITY ───
final compactLayoutProvider = StateProvider<bool>((ref) => false);

// ─── SIDEBAR ───
final sidebarExpandedProvider = StateProvider<bool>((ref) => true);
final selectedMenuIndexProvider = StateProvider<int>((ref) => 0);

/// Set by global search when navigating to invoices with a specific number.
final pendingInvoiceSearchProvider = StateProvider<String?>((ref) => null);
