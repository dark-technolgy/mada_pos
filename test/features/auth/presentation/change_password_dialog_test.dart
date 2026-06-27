import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mada_pos/core/localization/generated/app_localizations.dart';
import 'package:mada_pos/features/auth/presentation/change_password_dialog.dart';

Widget _buildApp(Widget child) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

Future<void> _openDialog(
  WidgetTester tester, {
  required bool requireCurrentPassword,
  bool isMandatory = false,
}) async {
  await tester.pumpWidget(
    _buildApp(
      Builder(
        builder: (context) => TextButton(
          onPressed: () {
            ChangePasswordDialog.show(
              context,
              requireCurrentPassword: requireCurrentPassword,
              isMandatory: isMandatory,
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
  testWidgets('optional dialog shows cancel action', (tester) async {
    await _openDialog(tester, requireCurrentPassword: true);

    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Current password'), findsOneWidget);
  });

  testWidgets('mandatory dialog hides cancel action', (tester) async {
    await _openDialog(tester, requireCurrentPassword: false, isMandatory: true);

    expect(find.text('Cancel'), findsNothing);
    expect(
      find.text(
        'You must change the default administrator password before entering the system.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('shows mismatch validation for confirmation field', (
    tester,
  ) async {
    await _openDialog(tester, requireCurrentPassword: false);

    await tester.enterText(find.byType(TextFormField).at(0), 'NewPassword1');
    await tester.enterText(find.byType(TextFormField).at(1), 'WrongPassword1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('returns passwords when form is valid', (tester) async {
    ChangePasswordDialogResult? result;

    await tester.pumpWidget(
      _buildApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await ChangePasswordDialog.show(
                context,
                requireCurrentPassword: true,
              );
            },
            child: const Text('Open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), 'OldPassword1');
    await tester.enterText(find.byType(TextFormField).at(1), 'NewPassword1');
    await tester.enterText(find.byType(TextFormField).at(2), 'NewPassword1');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result?.currentPassword, 'OldPassword1');
    expect(result?.newPassword, 'NewPassword1');
  });
}
