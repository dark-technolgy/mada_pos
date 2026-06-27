import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/core/localization/generated/app_localizations.dart';
import 'package:mada_pos/core/localization/kurdish_fallback_localizations.dart';
import 'package:mada_pos/core/utils/currency_formatter.dart';
import 'package:mada_pos/features/invoices/presentation/invoices_screen.dart';
import 'package:mada_pos/shared/providers/app_providers.dart';

Widget _buildTestApp(AppDatabase database) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWith((ref) => database),
      localeProvider.overrideWith((ref) => const Locale('en')),
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
      home: const InvoicesScreen(),
    ),
  );
}

double _topOf(WidgetTester tester, Finder finder) {
  return tester.getTopLeft(finder).dy;
}

void main() {
  testWidgets('Invoices screen restores the last saved filters', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final now = DateTime.now();
    final olderDate = now.subtract(const Duration(days: 45));
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final customerId = await database
        .into(database.customers)
        .insert(CustomersCompanion.insert(name: 'Persisted Customer'));
    final productId = await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            nameAr: 'Persisted Product',
            sellingPrice: const Value(10.0),
          ),
        );

    final recentInvoiceId = await database
        .into(database.invoices)
        .insert(
          InvoicesCompanion.insert(
            invoiceNumber: 'INV-PERSIST-001',
            type: 'sale',
            customerId: Value(customerId),
            userId: 1,
            warehouseId: const Value(1),
            subtotal: const Value(10.0),
            total: const Value(10.0),
            paidAmount: const Value(10.0),
            remaining: const Value(0.0),
            currencyCode: const Value('USD'),
            exchangeRate: const Value(1480.0),
            paymentMethod: const Value('card'),
            status: const Value('paid'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    await database
        .into(database.invoiceItems)
        .insert(
          InvoiceItemsCompanion.insert(
            invoiceId: recentInvoiceId,
            productId: productId,
            quantity: 1,
            unitPrice: 10,
            discount: const Value(0),
            total: 10,
            warehouseId: const Value(1),
          ),
        );

    final oldInvoiceId = await database
        .into(database.invoices)
        .insert(
          InvoicesCompanion.insert(
            invoiceNumber: 'INV-PERSIST-OLD',
            type: 'sale',
            customerId: Value(customerId),
            userId: 1,
            warehouseId: const Value(1),
            subtotal: const Value(10.0),
            total: const Value(10.0),
            paidAmount: const Value(10.0),
            remaining: const Value(0.0),
            currencyCode: const Value('IQD'),
            exchangeRate: const Value(1.0),
            paymentMethod: const Value('cash'),
            status: const Value('paid'),
            createdAt: Value(olderDate),
            updatedAt: Value(olderDate),
          ),
        );
    await database
        .into(database.invoiceItems)
        .insert(
          InvoiceItemsCompanion.insert(
            invoiceId: oldInvoiceId,
            productId: productId,
            quantity: 1,
            unitPrice: 10,
            discount: const Value(0),
            total: 10,
            warehouseId: const Value(1),
          ),
        );

    await tester.pumpWidget(_buildTestApp(database));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Date: All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Date: Today').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Payment Method: All'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payment Method: Card').last);
    await tester.pumpAndSettle();

    expect(find.text('INV-PERSIST-001'), findsOneWidget);
    expect(find.text('INV-PERSIST-OLD'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(_buildTestApp(database));
    await tester.pumpAndSettle();

    expect(find.text('Date: Today'), findsOneWidget);
    expect(find.text('Payment Method: Card'), findsOneWidget);
    expect(find.text('INV-PERSIST-001'), findsOneWidget);
    expect(find.text('INV-PERSIST-OLD'), findsNothing);
  });

  testWidgets('Invoices screen sorts rows by customer and date direction', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1600, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    final zuluCustomerId = await database
        .into(database.customers)
        .insert(CustomersCompanion.insert(name: 'Zulu Customer'));
    final alphaCustomerId = await database
        .into(database.customers)
        .insert(CustomersCompanion.insert(name: 'Alpha Customer'));
    final productId = await database
        .into(database.products)
        .insert(
          ProductsCompanion.insert(
            nameAr: 'Sortable Product',
            sellingPrice: const Value(10.0),
          ),
        );

    final olderInvoiceId = await database
        .into(database.invoices)
        .insert(
          InvoicesCompanion.insert(
            invoiceNumber: 'INV-ZULU-001',
            type: 'sale',
            customerId: Value(zuluCustomerId),
            userId: 1,
            warehouseId: const Value(1),
            subtotal: const Value(10.0),
            total: const Value(10.0),
            paidAmount: const Value(10.0),
            remaining: const Value(0.0),
            currencyCode: const Value('USD'),
            exchangeRate: const Value(1480.0),
            paymentMethod: const Value('cash'),
            status: const Value('paid'),
            createdAt: Value(DateTime(2026, 3, 1, 8, 0)),
            updatedAt: Value(DateTime(2026, 3, 1, 8, 0)),
          ),
        );
    await database
        .into(database.invoiceItems)
        .insert(
          InvoiceItemsCompanion.insert(
            invoiceId: olderInvoiceId,
            productId: productId,
            quantity: 1,
            unitPrice: 10,
            discount: const Value(0),
            total: 10,
            warehouseId: const Value(1),
          ),
        );

    final newerInvoiceId = await database
        .into(database.invoices)
        .insert(
          InvoicesCompanion.insert(
            invoiceNumber: 'INV-ALPHA-001',
            type: 'sale',
            customerId: Value(alphaCustomerId),
            userId: 1,
            warehouseId: const Value(1),
            subtotal: const Value(10.0),
            total: const Value(10.0),
            paidAmount: const Value(10.0),
            remaining: const Value(0.0),
            currencyCode: const Value('USD'),
            exchangeRate: const Value(1480.0),
            paymentMethod: const Value('cash'),
            status: const Value('paid'),
            createdAt: Value(DateTime(2026, 3, 8, 8, 0)),
            updatedAt: Value(DateTime(2026, 3, 8, 8, 0)),
          ),
        );
    await database
        .into(database.invoiceItems)
        .insert(
          InvoiceItemsCompanion.insert(
            invoiceId: newerInvoiceId,
            productId: productId,
            quantity: 1,
            unitPrice: 10,
            discount: const Value(0),
            total: 10,
            warehouseId: const Value(1),
          ),
        );

    await tester.pumpWidget(_buildTestApp(database));
    await tester.pumpAndSettle();

    expect(
      _topOf(tester, find.text('INV-ALPHA-001').first),
      lessThan(_topOf(tester, find.text('INV-ZULU-001').first)),
    );

    await tester.tap(find.text('Sort By: Date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort By: Customer').last);
    await tester.pumpAndSettle();

    expect(
      _topOf(tester, find.text('INV-ZULU-001').first),
      lessThan(_topOf(tester, find.text('INV-ALPHA-001').first)),
    );

    await tester.tap(find.text('Descending'));
    await tester.pumpAndSettle();

    expect(
      _topOf(tester, find.text('INV-ALPHA-001').first),
      lessThan(_topOf(tester, find.text('INV-ZULU-001').first)),
    );

    await tester.tap(find.text('Sort By: Customer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort By: Date').last);
    await tester.pumpAndSettle();

    expect(
      _topOf(tester, find.text('INV-ZULU-001').first),
      lessThan(_topOf(tester, find.text('INV-ALPHA-001').first)),
    );
  });

  testWidgets(
    'Invoices screen filters by payment method, currency, and discount',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final now = DateTime.now();
      final olderDate = now.subtract(const Duration(days: 45));

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      final customerId = await database
          .into(database.customers)
          .insert(CustomersCompanion.insert(name: 'Filter Customer'));
      final discountedProductId = await database
          .into(database.products)
          .insert(
            ProductsCompanion.insert(
              nameAr: 'Discounted Invoice Product',
              sellingPrice: const Value(20.0),
            ),
          );
      final regularProductId = await database
          .into(database.products)
          .insert(
            ProductsCompanion.insert(
              nameAr: 'Regular Invoice Product',
              sellingPrice: const Value(10000.0),
            ),
          );

      final usdInvoiceId = await database
          .into(database.invoices)
          .insert(
            InvoicesCompanion.insert(
              invoiceNumber: 'INV-USD-001',
              type: 'sale',
              customerId: Value(customerId),
              userId: 1,
              warehouseId: const Value(1),
              subtotal: const Value(20.0),
              discountAmount: const Value(2.0),
              total: const Value(18.0),
              paidAmount: const Value(18.0),
              remaining: const Value(0.0),
              currencyCode: const Value('USD'),
              exchangeRate: const Value(1480.0),
              paymentMethod: const Value('card'),
              status: const Value('paid'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await database
          .into(database.invoiceItems)
          .insert(
            InvoiceItemsCompanion.insert(
              invoiceId: usdInvoiceId,
              productId: discountedProductId,
              quantity: 1,
              unitPrice: 20,
              discount: const Value(0),
              total: 20,
              warehouseId: const Value(1),
            ),
          );

      final iqdInvoiceId = await database
          .into(database.invoices)
          .insert(
            InvoicesCompanion.insert(
              invoiceNumber: 'INV-IQD-001',
              type: 'sale',
              customerId: Value(customerId),
              userId: 1,
              warehouseId: const Value(1),
              subtotal: const Value(10000.0),
              discountAmount: const Value(0.0),
              total: const Value(10000.0),
              paidAmount: const Value(10000.0),
              remaining: const Value(0.0),
              currencyCode: const Value('IQD'),
              exchangeRate: const Value(1.0),
              paymentMethod: const Value('cash'),
              status: const Value('paid'),
              createdAt: Value(olderDate),
              updatedAt: Value(olderDate),
            ),
          );
      await database
          .into(database.invoiceItems)
          .insert(
            InvoiceItemsCompanion.insert(
              invoiceId: iqdInvoiceId,
              productId: regularProductId,
              quantity: 1,
              unitPrice: 10000,
              discount: const Value(0),
              total: 10000,
              warehouseId: const Value(1),
            ),
          );

      await tester.pumpWidget(_buildTestApp(database));
      await tester.pumpAndSettle();

      expect(find.text(CurrencyFormatter.format(36640, 'IQD')), findsWidgets);
      expect(find.text('Export PDF'), findsOneWidget);
      expect(find.text('INV-USD-001'), findsOneWidget);
      expect(find.text('INV-IQD-001'), findsOneWidget);
      expect(find.text(r'$2.00'), findsOneWidget);

      await tester.tap(find.text('Date: All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Date: Today').last);
      await tester.pumpAndSettle();

      expect(find.text(CurrencyFormatter.format(26640, 'IQD')), findsWidgets);
      expect(find.text('INV-USD-001'), findsOneWidget);
      expect(find.text('INV-IQD-001'), findsNothing);

      await tester.tap(find.text('Date: Today'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Date: Custom').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('From:'), findsOneWidget);
      expect(find.textContaining('To:'), findsOneWidget);
      expect(find.text(CurrencyFormatter.format(26640, 'IQD')), findsWidgets);
      expect(find.text('INV-USD-001'), findsOneWidget);
      expect(find.text('INV-IQD-001'), findsNothing);

      await tester.tap(find.text('Date: Custom'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Date: All').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Payment Method: All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Payment Method: Card').last);
      await tester.pumpAndSettle();

      expect(find.text(CurrencyFormatter.format(26640, 'IQD')), findsWidgets);
      expect(find.text('INV-USD-001'), findsOneWidget);
      expect(find.text('INV-IQD-001'), findsNothing);

      await tester.tap(find.text('Currency: All'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Currency: USD').last);
      await tester.pumpAndSettle();

      expect(find.text('INV-USD-001'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Discount'));
      await tester.pumpAndSettle();

      expect(find.text('INV-USD-001'), findsOneWidget);

      await tester.tap(find.text('Payment Method: Card'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Payment Method: All').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Currency: USD'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Currency: All').last);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilterChip, 'Discount'));
      await tester.pumpAndSettle();

      expect(find.text('INV-USD-001'), findsOneWidget);
      expect(find.text('INV-IQD-001'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'INV-USD');
      await tester.pumpAndSettle();

      expect(find.text('Clear Filters'), findsOneWidget);

      await tester.tap(find.text('Clear Filters'));
      await tester.pumpAndSettle();

      expect(find.text('Date: All'), findsOneWidget);
      expect(find.text('Payment Method: All'), findsOneWidget);
      expect(find.text('Currency: All'), findsOneWidget);
      expect(find.text('Sort By: Date'), findsOneWidget);
      expect(find.text('Descending'), findsOneWidget);
      expect(find.text('INV-USD-001'), findsOneWidget);
      expect(find.text('INV-IQD-001'), findsOneWidget);
      expect(find.text('Clear Filters'), findsNothing);
    },
  );

  testWidgets(
    'Invoices screen opens the invoice details dialog with item breakdown',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);

      final customerId = await database
          .into(database.customers)
          .insert(CustomersCompanion.insert(name: 'Test Customer'));
      final productId = await database
          .into(database.products)
          .insert(
            ProductsCompanion.insert(
              nameAr: 'Invoice Product',
              barcode: const Value('1234567890'),
              sellingPrice: const Value(10.0),
            ),
          );
      final invoiceId = await database
          .into(database.invoices)
          .insert(
            InvoicesCompanion.insert(
              invoiceNumber: 'INV-000001',
              type: 'sale',
              customerId: Value(customerId),
              userId: 1,
              warehouseId: const Value(1),
              subtotal: const Value(10.0),
              discountAmount: const Value(1.0),
              total: const Value(8.0),
              paidAmount: const Value(8.0),
              remaining: const Value(0.0),
              currencyCode: const Value('USD'),
              exchangeRate: const Value(1480.0),
              paymentMethod: const Value('cash'),
              status: const Value('paid'),
              createdAt: Value(DateTime(2026, 3, 8, 12, 30)),
              updatedAt: Value(DateTime(2026, 3, 8, 12, 30)),
            ),
          );
      await database
          .into(database.invoiceItems)
          .insert(
            InvoiceItemsCompanion.insert(
              invoiceId: invoiceId,
              productId: productId,
              quantity: 1,
              unitPrice: 10,
              discount: const Value(1),
              total: 9,
              warehouseId: const Value(1),
            ),
          );

      await tester.pumpWidget(_buildTestApp(database));
      await tester.pumpAndSettle();

      expect(find.text('INV-000001'), findsOneWidget);

      await tester.tap(find.text('INV-000001'));
      await tester.pumpAndSettle();

      expect(find.text('Test Customer'), findsWidgets);
      expect(find.text('Invoice Product'), findsOneWidget);
      expect(find.text('1234567890'), findsOneWidget);
      expect(find.text('مدير النظام'), findsOneWidget);
      expect(find.text('USD'), findsWidgets);
      expect(find.text('1480.00'), findsOneWidget);
      expect(find.text(r'$10.00'), findsWidgets);
      expect(find.text(r'$1.00'), findsWidgets);
      expect(find.text(r'$8.00'), findsWidgets);
      expect(find.text('Print'), findsOneWidget);

      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.text('Invoice Product'), findsNothing);
    },
  );
}
