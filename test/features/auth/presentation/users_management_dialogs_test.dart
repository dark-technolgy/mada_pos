import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/features/auth/presentation/widgets/users_management_dialogs.dart';

Widget _buildApp(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

Future<void> _openCreateDialog(WidgetTester tester) async {
  await tester.pumpWidget(
    _buildApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () {
            showUserManagementDialog(
              context: context,
              mode: UserDialogMode.create,
              title: 'Add User',
              fullNameLabel: 'Full name',
              usernameLabel: 'Username',
              roleLabel: 'Role',
              initialPasswordLabel: 'Initial password',
              activeLabel: 'Active',
              passwordRequiredLabel: 'Enter password',
              usernameRequiredLabel: 'Enter username',
              fullNameRequiredLabel: 'Enter full name',
              saveLabel: 'Save',
              cancelLabel: 'Cancel',
            );
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _openEditDialog(WidgetTester tester) async {
  await tester.pumpWidget(
    _buildApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () {
            showUserManagementDialog(
              context: context,
              mode: UserDialogMode.edit,
              title: 'Edit',
              fullNameLabel: 'Full name',
              usernameLabel: 'Username',
              roleLabel: 'Role',
              initialPasswordLabel: 'Initial password',
              activeLabel: 'Active',
              passwordRequiredLabel: 'Enter password',
              usernameRequiredLabel: 'Enter username',
              fullNameRequiredLabel: 'Enter full name',
              saveLabel: 'Save',
              cancelLabel: 'Cancel',
              initialFullName: 'Existing User',
              initialUsername: 'existing',
              initialRole: 'manager',
              initialIsActive: true,
            );
          },
          child: const Text('Open'),
        ),
      ),
    ),
  );

  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('create dialog validates required fields', (tester) async {
    await _openCreateDialog(tester);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Enter full name'), findsOneWidget);
    expect(find.text('Enter username'), findsOneWidget);
    expect(find.text('Enter password'), findsOneWidget);
  });

  testWidgets('create dialog returns entered values', (tester) async {
    UserDialogResult? result;

    await tester.pumpWidget(
      _buildApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showUserManagementDialog(
                context: context,
                mode: UserDialogMode.create,
                title: 'Add User',
                fullNameLabel: 'Full name',
                usernameLabel: 'Username',
                roleLabel: 'Role',
                initialPasswordLabel: 'Initial password',
                activeLabel: 'Active',
                passwordRequiredLabel: 'Enter password',
                usernameRequiredLabel: 'Enter username',
                fullNameRequiredLabel: 'Enter full name',
                saveLabel: 'Save',
                cancelLabel: 'Cancel',
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'New User');
    await tester.enterText(find.byType(TextFormField).at(1), 'newuser');
    await tester.enterText(find.byType(TextFormField).at(2), 'Password123');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result?.fullName, 'New User');
    expect(result?.username, 'newuser');
    expect(result?.password, 'Password123');
    expect(result?.isActive, isTrue);
  });

  testWidgets('edit dialog hides password field and keeps username read only', (
    tester,
  ) async {
    await _openEditDialog(tester);

    expect(find.text('Initial password'), findsNothing);
    final usernameField = tester.widget<TextFormField>(
      find.byType(TextFormField).at(1),
    );
    expect(usernameField.enabled, isFalse);
    expect(find.byType(SwitchListTile), findsOneWidget);
  });

  testWidgets('reset password dialog validates and returns password', (
    tester,
  ) async {
    String? result;

    await tester.pumpWidget(
      _buildApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showResetPasswordDialog(
                context: context,
                title: 'Reset Password',
                newPasswordLabel: 'New password',
                passwordRequiredLabel: 'Enter password',
                saveLabel: 'Save',
                cancelLabel: 'Cancel',
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Enter password'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'Reset123');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, 'Reset123');
  });
}
