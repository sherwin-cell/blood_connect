import 'package:blood_connect/features/donor/domain/request_match.dart';
import 'package:blood_connect/features/donor/presentation/screens/matched_donor_detail_screen.dart';
import 'package:blood_connect/features/donor/presentation/screens/matched_donors_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Timestamp _ts(int day, [int hour = 9]) =>
    Timestamp.fromDate(DateTime(2026, 11, day, hour));

final _requests = <MapEntry<String, Map<String, dynamic>>>[
  MapEntry('reqMatched', {
    'userId': 'u1',
    'status': 'matched',
    'bloodType': 'A+',
    'unitsRequired': 2,
    'hospitalName': 'Sorsogon Provincial Hospital',
    'createdAt': _ts(15),
    'reviewedAt': _ts(15, 11),
  }),
  MapEntry('reqPending', {
    'userId': 'u1',
    'status': 'active',
    'bloodType': 'O-',
    'unitsRequired': 1,
    'createdAt': _ts(14),
  }),
  MapEntry('reqNone', {
    'userId': 'u1',
    'status': 'approved',
    'bloodType': 'B+',
    'unitsRequired': 1,
    'createdAt': _ts(13),
  }),
  // Not approved yet: not listed.
  MapEntry('reqReview', {
    'userId': 'u1',
    'status': 'pending',
    'bloodType': 'AB+',
    'createdAt': _ts(16),
  }),
];

final _offers = <String, List<MapEntry<String, Map<String, dynamic>>>>{
  'reqMatched': [
    MapEntry('offer1', {
      'status': 'approved',
      'donorId': 'secretUid',
      'donorName': 'Maria Santos',
      'donorContact': '09171234567',
      'donorBloodType': 'A+',
      'approvedAt': _ts(16, 10),
    }),
  ],
  'reqPending': [
    MapEntry('offer2', {'status': 'pending', 'donorName': 'Jose Rizal'}),
  ],
  'reqNone': [],
};

Stream<List<MapEntry<String, Map<String, dynamic>>>> _offersFor(String id) =>
    Stream.value(_offers[id] ?? const []);

void main() {
  test('donor code is stable, 4 digits and prefers a stored code', () {
    final code = MatchedDonor.donorCode('offer1');
    expect(code, matches(RegExp(r'^DNR-\d{4}$')));
    expect(MatchedDonor.donorCode('offer1'), code);
    expect(MatchedDonor.donorCode('offer1', 'dnr-0023'), 'DNR-0023');
    expect(MatchedDonor.donorCode('offer1', 'Maria'), code);
  });

  testWidgets('lists approved requests with their match state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MatchedDonorsScreen(
          userId: 'u1',
          requests: Stream.value(_requests),
          offersFor: _offersFor,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('My Blood Requests with Matched Donor'), findsOneWidget);
    expect(find.text('A+ • 2 units'), findsOneWidget);
    expect(find.text('Matched Donor'), findsOneWidget);
    expect(find.text('Matching in Progress'), findsOneWidget);
    expect(find.text('No Match Yet'), findsOneWidget);
    expect(find.textContaining('AB+'), findsNothing);
    expect(find.textContaining('Maria'), findsNothing);
    expect(find.textContaining('Jose'), findsNothing);
  });

  testWidgets('detail shows only the anonymised donor and the timeline', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MatchedDonorDetailScreen(
          requestId: 'reqMatched',
          request: Stream.value(_requests.first.value),
          offers: _offersFor('reqMatched'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Donor Matched'), findsNWidgets(2)); // pill + step
    expect(find.text(MatchedDonor.donorCode('offer1')), findsOneWidget);
    expect(find.text('Blood Type: A+'), findsOneWidget);
    expect(find.text('Confirmed'), findsOneWidget);
    expect(find.text('Request Approved'), findsOneWidget);
    expect(find.text('Donation Completed'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(
      find.text('You cannot chat, contact, or respond to the donor.'),
      findsOneWidget,
    );
    expect(find.textContaining('Maria'), findsNothing);
    expect(find.textContaining('0917'), findsNothing);
    expect(find.textContaining('secretUid'), findsNothing);
    expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
    expect(find.byIcon(Icons.call), findsNothing);
  });

  testWidgets('fulfilled request shows Donation Completed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MatchedDonorDetailScreen(
          requestId: 'reqMatched',
          request: Stream.value({
            ..._requests.first.value,
            'status': 'fulfilled',
            'fulfilledAt': _ts(18),
          }),
          offers: Stream.value([
            MapEntry('offer1', {
              ..._offers['reqMatched']!.first.value,
              'status': 'donated',
              'donatedAt': _ts(17),
            }),
          ]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Donation Completed'), findsNWidgets(2)); // pill + step
    expect(find.text('Pending'), findsNothing);
    expect(find.text('Nov 18, 2026 • 9:00 AM'), findsOneWidget);
  });
}
