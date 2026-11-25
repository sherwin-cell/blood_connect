import 'package:blood_connect/features/blood_request/presentation/screens/post_request_step2_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildScreen() => const MaterialApp(
    home: PostRequestStep2Screen(
      patientName: 'JUAN DELA CRUZ',
      patientAge: 30,
      patientBirthday: '1996-01-01',
      patientSex: 'Male',
      contactNumber: '09123456789',
      relativeName: 'MARIA DELA CRUZ',
      relationship: 'Family Member',
    ),
  );

  Finder bloodTypeField() => find.byKey(const ValueKey('bloodTypeField'));
  Finder unitsField() => find.byKey(const ValueKey('unitsField'));

  Future<void> selectOption(
    WidgetTester tester,
    Finder field,
    String option,
  ) async {
    await tester.ensureVisible(field);
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  Future<void> pickNeededByDate(WidgetTester tester) async {
    final neededBy = find.byKey(const ValueKey('neededByField'));
    await tester.ensureVisible(neededBy);
    await tester.tap(neededBy);
    await tester.pumpAndSettle();
    expect(find.text('Blood needed by'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Blood Type and other fields stay selected after picking a Needed By date',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildScreen());

      await selectOption(tester, bloodTypeField(), 'B+');
      await selectOption(tester, unitsField(), '2');
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Latest Hemoglobin / Hematocrit (e.g., 9.5 g/dL)',
        ),
        '9.5 g/dL',
      );

      expect(
        find.descendant(of: bloodTypeField(), matching: find.text('B+')),
        findsOneWidget,
      );
      expect(find.text('Select date'), findsOneWidget);

      await pickNeededByDate(tester);

      // The date is set ...
      expect(find.text('Select date'), findsNothing);
      // ... and nothing entered before it was reset.
      expect(
        find.descendant(of: bloodTypeField(), matching: find.text('B+')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: unitsField(), matching: find.text('2')),
        findsOneWidget,
      );
      expect(find.text('9.5 g/dL'), findsOneWidget);

      // Changing the date again still keeps the Blood Type.
      await pickNeededByDate(tester);
      expect(
        find.descendant(of: bloodTypeField(), matching: find.text('B+')),
        findsOneWidget,
      );
    },
  );
}
