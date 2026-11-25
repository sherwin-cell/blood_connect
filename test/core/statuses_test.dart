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
    // Activated donors always carry the date PRC set at activation.
    Map<String, dynamic> donor({
      String status = 'approved',
      bool isDonor = true,
      bool available = true,
      Object? nextEligible = '2026-01-15',
    }) => {
      'donorStatus': status,
      'isDonor': isDonor,
      'isAvailableForDonation': available,
      'nextEligibleDonationDate': ?nextEligible,
    };

    test('approved, available donor past their interval can donate', () {
      expect(DonorEligibility.canDonate(donor(), today: today), isTrue);
    });

    test('fails closed without a valid next eligible date', () {
      final missing = donor()..remove('nextEligibleDonationDate');
      final cases = <String, Map<String, dynamic>>{
        'missing': missing,
        'null': {...donor(), 'nextEligibleDonationDate': null},
        'empty': donor(nextEligible: ''),
        'slashes': donor(nextEligible: '01/15/2026'),
        'single-digit month': donor(nextEligible: '2026-1-15'),
        'leading space': donor(nextEligible: ' 2026-01-15'),
        'month 13': donor(nextEligible: '2026-13-01'),
        'impossible Feb 31': donor(nextEligible: '2026-02-31'),
        'number': donor(nextEligible: 20260115),
        'DateTime object': donor(nextEligible: DateTime(2026, 1, 15)),
      };
      for (final entry in cases.entries) {
        expect(
          DonorEligibility.blockingReason(entry.value, today: today),
          DonorEligibility.missingDateReason,
          reason: entry.key,
        );
        expect(
          DonorEligibility.canDonate(entry.value, today: today),
          isFalse,
          reason: entry.key,
        );
      }
    });

    test('impossible dates are not rolled over', () {
      expect(
        DonorEligibility.nextEligibleDate(donor(nextEligible: '2026-02-31')),
        isNull,
      );
      expect(
        DonorEligibility.nextEligibleDate(donor(nextEligible: '2024-02-29')),
        DateTime(2024, 2, 29),
      );
    });

    test('"today" is the Philippine date, not the device date', () {
      // 2026-11-21 17:30 UTC is already 2026-11-22 01:30 in the Philippines.
      expect(
        DonorEligibility.philippinesToday(
          nowUtc: DateTime.utc(2026, 11, 21, 17, 30),
        ),
        DateTime(2026, 11, 22),
      );
      expect(
        DonorEligibility.philippinesToday(
          nowUtc: DateTime.utc(2026, 11, 21, 15, 59),
        ),
        DateTime(2026, 11, 21),
      );
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

    test('malformed next eligible date parses to null', () {
      expect(
        DonorEligibility.nextEligibleDate(donor(nextEligible: '12/01/2026')),
        isNull,
      );
    });
  });
}
