import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/database/database.dart';
import 'package:mada_pos/features/auth/presentation/users_management_screen.dart';
import 'package:mada_pos/shared/providers/app_providers.dart';

User _adminUser() {
  return User(
    id: 1,
    username: 'admin',
    passwordHash: 'hash',
    fullName: 'Admin User',
    role: 'admin',
    isActive: true,
    createdAt: DateTime(2026, 3, 9),
    updatedAt: DateTime(2026, 3, 9),
  );
}

User _cashierUser() {
  return User(
    id: 2,
    username: 'cashier',
    passwordHash: 'hash',
    fullName: 'Cashier User',
    role: 'cashier',
    isActive: true,
    createdAt: DateTime(2026, 3, 9),
    updatedAt: DateTime(2026, 3, 9),
  );
}

Widget _buildApp(AppDatabase database, User? user) {
  return ProviderScope(
    overrides: [
      databaseProvider.overrideWith((ref) => database),
      currentUserProvider.overrideWith((ref) => user),
      localeProvider.overrideWith((ref) => const Locale('en')),
    ],
    child: const MaterialApp(home: UsersManagementScreen()),
  );
}

void main() {
  testWidgets('admin can see user management screen', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(_buildApp(database, _adminUser()));
    await tester.pumpAndSettle();

    expect(find.text('User Management'), findsOneWidget);
    expect(find.text('مدير النظام'), findsOneWidget);
    expect(find.text('Add User'), findsOneWidget);
  });

  testWidgets('non-admin sees unauthorized state', (tester) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);

    await tester.pumpWidget(_buildApp(database, _cashierUser()));
    await tester.pumpAndSettle();

    expect(find.text('Unauthorized'), findsOneWidget);
  });
}
