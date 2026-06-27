import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/core/localization/generated/app_localizations.dart';
import 'package:mada_pos/core/localization/kurdish_fallback_localizations.dart';
import 'package:mada_pos/features/pos/presentation/pos_screen.dart';
import 'package:mada_pos/shared/providers/app_providers.dart';

import '../../../helpers/test_database_helpers.dart';

Finder _textContaining(String fragment) {
  return find.byWidgetPredicate(
    (widget) => widget is Text && (widget.data?.contains(fragment) ?? false),
  );
}

User _buildCurrentUser() {
  return User(
    id: 1,
    username: 'admin',
    passwordHash: 'hash',
    fullName: 'Admin User',
    role: 'admin',
    isActive: true,
    createdAt: DateTime(2026, 3, 8),
    updatedAt: DateTime(2026, 3, 8),
  );
}

Widget _buildTestApp(AppDatabase database, {User? currentUser}) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWith((ref) {
        ref.onDispose(database.close);
        return database;
      }),
      localeProvider.overrideWith((ref) => const Locale('en')),
      currentUserProvider.overrideWith((ref) => currentUser),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        AppMaterialLocalizationsDelegate(),
        AppCupertinoLocalizationsDelegate(),
        AppWidgetsLocalizationsDelegate(),
      ],
      home: const PosScreen(),
    ),
  );
}

void main() {
  testWidgets(
    'POS supports currency selection and item-level percentage discount',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      await insertProductWithStock(
        database,
        nameAr: 'منتج تجريبي',
        sellingPrice: 14800,
      );

      await tester.pumpWidget(
        _buildTestApp(database, currentUser: _buildCurrentUser()),
      );
      await tester.pumpAndSettle();

      expect(find.text('منتج تجريبي'), findsOneWidget);

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('USD - \$').last);
      await tester.pumpAndSettle();

      expect(_textContaining(r'$10.00'), findsWidgets);

      await tester.tap(find.text('منتج تجريبي'));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byIcon(Icons.discount_outlined));
      await tester.tap(find.byIcon(Icons.discount_outlined));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).last, '10');
      await tester.tap(find.text('Percentage').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();

      expect(_textContaining(r'$1.00'), findsWidgets);
      expect(_textContaining(r'$9.00'), findsWidgets);
    },
  );

  testWidgets('POS can hold and recall the current invoice', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await insertProductWithStock(
      database,
      nameAr: 'منتج معلق',
      sellingPrice: 10000,
    );

    await tester.pumpWidget(
      _buildTestApp(database, currentUser: _buildCurrentUser()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('منتج معلق'));
    await tester.pumpAndSettle();

    expect(find.text('1 items'), findsOneWidget);

    await tester.tap(find.text('Hold Invoice'));
    await tester.pumpAndSettle();

    expect(_textContaining('Invoice placed on hold'), findsOneWidget);
    expect(find.text('0 items'), findsOneWidget);

    await tester.tap(find.text('Recall Invoice'));
    await tester.pumpAndSettle();

    expect(find.text('Held invoices'), findsOneWidget);
    expect(find.text('INV-000001'), findsOneWidget);

    await tester.tap(find.text('INV-000001'));
    await tester.pumpAndSettle();

    expect(find.text('1 items'), findsOneWidget);
    expect(find.text('منتج معلق'), findsWidgets);
  });
}
