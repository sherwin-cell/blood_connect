import 'package:blood_connect/core/constants/statuses.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RequestStatus', () {
    test('only in-progress requests can be cancelled', () {
      for (final status in ['pending', 'approved', 'active', 'matched']) {
        expect(RequestStatus.canBeCancelled(status), isTrue, reason: status);
      }
      for (final status in [
        'fulfilled',
        'cancelled',
        'rejected',
        'expired',
        null,
      ]) {
        expect(RequestStatus.canBeCancelled(status), isFalse, reason: status);
      }
    });

    test('approved and legacy active requests are open to donors', () {
      expect(RequestStatus.isOpenToDonors('active'), isTrue);
      expect(RequestStatus.isOpenToDonors(' Approved '), isTrue);
      expect(RequestStatus.isOpenToDonors('pending'), isFalse);
      expect(RequestStatus.isOpenToDonors('matched'), isFalse);
    });
  });

  group('OfferStatus', () {
    test('pending, approved and legacy accepted offers are active', () {
      expect(OfferStatus.isActive('pending'), isTrue);
      expect(OfferStatus.isActive('approved'), isTrue);
      expect(OfferStatus.isActive('accepted'), isTrue);
      expect(OfferStatus.isActive('withdrawn'), isFalse);
      expect(OfferStatus.isActive('donated'), isFalse);
      expect(OfferStatus.isActive('rejected'), isFalse);
    });

    test('confirmed offers include approved, legacy accepted and donated', () {
      expect(OfferStatus.isConfirmed('approved'), isTrue);
      expect(OfferStatus.isConfirmed('accepted'), isTrue);
      expect(OfferStatus.isConfirmed('donated'), isTrue);
      expect(OfferStatus.isConfirmed('pending'), isFalse);
    });
  });

  group('DonorEligibility', () {
    final today = DateTime(2026, 11, 22);
    Map<String, dynamic> donor({
      String status = 'approved',
      bool isDonor = true,
      bool available = true,
      String? nextEligible,
    }) => {
      'donorStatus': status,
      'isDonor': isDonor,
      'isAvailableForDonation': available,
      'nextEligibleDonationDate': ?nextEligible,
    };

    test('approved, available donor with no interval can donate', () {
      expect(DonorEligibility.canDonate(donor(), today: today), isTrue);
    });

    test('pending donor cannot donate', () {
      expect(
        DonorEligibility.blockingReason(donor(status: 'pending'), today: today),
        contains('approved by PRC'),
      );
    });

    test('donor marked unavailable cannot donate', () {
      expect(
        DonorEligibility.canDonate(donor(available: false), today: today),
        isFalse,
      );
    });

    test('donor inside the donation interval cannot donate', () {
      expect(
        DonorEligibility.blockingReason(
          donor(nextEligible: '2026-12-01'),
          today: today,
        ),
        'You can donate again from 2026-12-01.',
      );
    });

    test('donor can donate on the next eligible date itself', () {
      expect(
        DonorEligibility.canDonate(
          donor(nextEligible: '2026-11-22'),
          today: DateTime(2026, 11, 22, 18, 30),
        ),
        isTrue,
      );
    });

    test('malformed next eligible date is ignored', () {
      expect(
        DonorEligibility.nextEligibleDate(donor(nextEligible: '12/01/2026')),
        isNull,
      );
    });
  });
}
