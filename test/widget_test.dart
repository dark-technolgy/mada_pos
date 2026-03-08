import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keenx_pos/app.dart';
import 'package:keenx_pos/features/auth/presentation/login_screen.dart';
import 'package:keenx_pos/shared/providers/app_providers.dart';

void main() {
  testWidgets('app boots to login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: KeenXApp()));
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('اسم المستخدم'), findsOneWidget);
    expect(find.text('كلمة المرور'), findsOneWidget);
  });

  testWidgets('app boots with Kurdish locale', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [localeProvider.overrideWith((ref) => const Locale('ku'))],
        child: const KeenXApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
