import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import '../../core/database/database.dart';
import '../../core/security/session_manager.dart';
import '../../core/utils/currency_conversion.dart';

// ─── DATABASE ───
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

// ─── SESSION ───
final sessionManagerProvider = Provider<SessionManager>((ref) {
  final db = ref.watch(databaseProvider);
  final session = SessionManager(db);
  ref.onDispose(() => session.dispose());
  return session;
});

// ─── CURRENT USER ───
final currentUserProvider = StateProvider<User?>((ref) => null);

// ─── THEME MODE ───
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.dark);

// ─── LOCALE ───
final localeProvider = StateProvider<Locale>((ref) => const Locale('ar'));

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

// ─── SIDEBAR ───
final sidebarExpandedProvider = StateProvider<bool>((ref) => true);
final selectedMenuIndexProvider = StateProvider<int>((ref) => 0);
