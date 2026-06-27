import 'package:drift/drift.dart' show Value;

import '../database/database.dart';

/// Tax configuration loaded from the `settings` table.
class TaxSettings {
  const TaxSettings({
    this.ratePercent = 0,
    this.taxIncluded = false,
  });

  final double ratePercent;
  final bool taxIncluded;

  bool get isEnabled => ratePercent > 0;
}

class TaxBreakdown {
  const TaxBreakdown({
    required this.taxableBase,
    required this.taxAmount,
    required this.total,
  });

  /// Amount after line and invoice discounts, before tax is applied or extracted.
  final double taxableBase;
  final double taxAmount;
  final double total;
}

class TaxCalculator {
  TaxCalculator._();

  static TaxBreakdown compute({
    required double taxableBase,
    required TaxSettings settings,
  }) {
    final base = taxableBase < 0 ? 0.0 : taxableBase;
    if (!settings.isEnabled) {
      return TaxBreakdown(taxableBase: base, taxAmount: 0, total: base);
    }

    final rate = settings.ratePercent / 100;
    if (settings.taxIncluded) {
      final taxAmount = base - (base / (1 + rate));
      return TaxBreakdown(
        taxableBase: base,
        taxAmount: taxAmount,
        total: base,
      );
    }

    final taxAmount = base * rate;
    return TaxBreakdown(
      taxableBase: base,
      taxAmount: taxAmount,
      total: base + taxAmount,
    );
  }
}

class TaxSettingsLoader {
  TaxSettingsLoader._();

  static Future<TaxSettings> load(AppDatabase db) async {
    final rows = await db.select(db.settings).get();
    final map = {for (final row in rows) row.key: row.value};
    final rate = double.tryParse(map['tax_rate'] ?? '') ?? 0;
    final included = map['tax_included'] == 'true';
    return TaxSettings(
      ratePercent: rate.clamp(0, 100),
      taxIncluded: included,
    );
  }

  static Future<void> save(
    AppDatabase db, {
    required double ratePercent,
    required bool taxIncluded,
  }) async {
    await _upsert(db, 'tax_rate', ratePercent.clamp(0, 100).toString());
    await _upsert(db, 'tax_included', taxIncluded ? 'true' : 'false');
  }

  static Future<void> _upsert(AppDatabase db, String key, String value) async {
    final existing = await (db.select(db.settings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    if (existing != null) {
      await (db.update(db.settings)..where((s) => s.key.equals(key))).write(
        SettingsCompanion(value: Value(value)),
      );
      return;
    }
    await db.into(db.settings).insert(
          SettingsCompanion.insert(
            key: key,
            value: value,
            group: const Value('tax'),
          ),
        );
  }
}
