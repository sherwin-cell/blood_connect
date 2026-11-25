import 'package:blood_connect/features/donor/presentation/screens/apply_donor_welcomescreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Apply donor welcome shows the four steps and eligibility', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ApplyDonorWelcomeScreen()));

    expect(find.text('Give Blood, Save Lives'), findsOneWidget);

    // Same steps as the form's DonorStepIndicator.
    for (final step in [
      'Personal Information',
      'Blood Type & History',
      'Health Screening',
      'Review & Submit',
    ]) {
      await tester.scrollUntilVisible(find.text(step), 100);
      expect(find.text(step), findsOneWidget);
    }

    for (final requirement in [
      '16 to 65 years old',
      'At least 50 kg',
      'In good health',
    ]) {
      await tester.scrollUntilVisible(find.text(requirement), 100);
      expect(find.text(requirement), findsOneWidget);
    }

    expect(find.byTooltip('Help'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
