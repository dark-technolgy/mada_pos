import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/app.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/auth/presentation/login_screen.dart';
import 'package:mada_pos/shared/providers/app_providers.dart';

Widget _buildApp({List<Override> overrides = const []}) {
  return ProviderScope(overrides: overrides, child: const MadaApp());
}

void main() {
  testWidgets('app boots to login screen', (WidgetTester tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      _buildApp(
        overrides: [
          databaseProvider.overrideWith((ref) => database),
          appBootstrapProvider.overrideWith((ref) async => <String, String>{}),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('اسم المستخدم'), findsOneWidget);
    expect(find.text('كلمة المرور'), findsOneWidget);
  });

  testWidgets('app boots with Kurdish locale', (WidgetTester tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      _buildApp(
        overrides: [
          databaseProvider.overrideWith((ref) => database),
          appBootstrapProvider.overrideWith((ref) async => <String, String>{}),
          localeProvider.overrideWith((ref) => const Locale('ku')),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('default admin is forced to change password on first login', (
    WidgetTester tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(
      _buildApp(
        overrides: [
          databaseProvider.overrideWith((ref) => database),
          appBootstrapProvider.overrideWith((ref) async => <String, String>{}),
          localeProvider.overrideWith((ref) => const Locale('en')),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), 'admin123');
    await tester.tap(find.byType(ElevatedButton).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Change Password'), findsOneWidget);
    expect(
      find.textContaining('default administrator password'),
      findsOneWidget,
    );
  });
}
