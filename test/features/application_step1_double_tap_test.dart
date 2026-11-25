import 'dart:async';

import 'package:blood_connect/features/blood_request/presentation/screens/post_request_step1_screen.dart';
import 'package:blood_connect/features/blood_request/presentation/screens/post_request_step2_screen.dart';
import 'package:blood_connect/features/donor/presentation/screens/apply_donor_step1_screen.dart';
import 'package:blood_connect/features/donor/presentation/screens/apply_donor_step2_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Step 1 of both application forms saves a legacy account's birthday
/// before opening step 2. A second tap on Next while that save is running
/// must not save again or open step 2 twice.
void main() {
  void bigScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> pickDropdown(
    WidgetTester tester,
    String label,
    String option,
  ) async {
    final field = find.widgetWithText(DropdownButtonFormField<String>, label);
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  Future<void> pickBirthday(WidgetTester tester, String label) async {
    final field = find.widgetWithText(TextFormField, label);
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  Future<void> doubleTapNext(WidgetTester tester, Key key) async {
    final next = find.byKey(key);
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pump(); // saving starts, button disabled
    await tester.tap(next, warnIfMissed: false);
    await tester.pump();
  }

  testWidgets(
    'Request form: double tap on Next saves once, opens step 2 once',
    (tester) async {
      bigScreen(tester);
      final save = Completer<void>();
      var saves = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: PostRequestStep1Screen(
            currentUid: () => 'u1',
            fetchBirthday: (_) async => null, // legacy: no saved birthday
            saveBirthdayIfMissing: (uid, date) {
              saves++;
              return save.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Patient Name (Surname, First, Middle)',
        ),
        'DELA CRUZ, JUAN',
      );
      await pickDropdown(tester, 'Relationship to Patient', 'Self');
      await pickBirthday(tester, 'Birthday (YYYY-MM-DD)');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contact Number'),
        '09123456789',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Name of Relative / Contact Person'),
        'MARIA DELA CRUZ',
      );

      await doubleTapNext(tester, const ValueKey('requestStep1Next'));

      expect(saves, 1);
      expect(
        tester
            .widget<ElevatedButton>(
              find.byKey(const ValueKey('requestStep1Next')),
            )
            .onPressed,
        isNull,
        reason: 'Next is disabled while the birthday saves',
      );
      expect(find.byType(PostRequestStep2Screen), findsNothing);

      save.complete();
      await tester.pumpAndSettle();

      expect(saves, 1);
      expect(
        find.byType(PostRequestStep2Screen, skipOffstage: false),
        findsOneWidget,
      );
    },
  );

  testWidgets('Donor form: double tap on Next saves once, opens step 2 once', (
    tester,
  ) async {
    bigScreen(tester);
    final save = Completer<void>();
    var saves = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ApplyDonorStep1Screen(
          currentUser: () =>
              (uid: 'u1', email: 'u1@example.test', phoneNumber: null),
          // Legacy profile: everything but a birthday.
          loadProfile: (_) async => {
            'firstName': 'JUAN',
            'lastName': 'DELA CRUZ',
            'mobileNo': '09123456789',
            'permanentAddress': 'Purok 3, Burabod, Sorsogon City',
            'occupation': 'Employed',
          },
          saveBirthdayIfMissing: (uid, date) {
            saves++;
            return save.future;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await pickBirthday(tester, 'Birthday (MM/DD/YYYY)');
    await pickDropdown(tester, 'Civil Status', 'Single');
    await pickDropdown(tester, 'Sex', 'Female');
    await pickDropdown(tester, 'Education', 'College Graduate');

    await doubleTapNext(tester, const ValueKey('donorStep1Next'));

    expect(saves, 1);
    expect(
      tester
          .widget<ElevatedButton>(find.byKey(const ValueKey('donorStep1Next')))
          .onPressed,
      isNull,
      reason: 'Next is disabled while the birthday saves',
    );
    expect(find.byType(ApplyDonorStep2Screen), findsNothing);

    save.complete();
    await tester.pumpAndSettle();

    expect(saves, 1);
    expect(
      find.byType(ApplyDonorStep2Screen, skipOffstage: false),
      findsOneWidget,
    );
  });
}
