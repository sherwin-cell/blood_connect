class BloodCompatibility {
  /// Checks whether a donor can be matched to a recipient/request.
  ///
  /// Blood-Connect matching rule:
  /// The donor and recipient/request must have the EXACT SAME
  /// blood type.
  ///
  /// Examples:
  /// A+ donor -> A+ request = true
  /// A+ donor -> O+ request = false
  /// O- donor -> O- request = true
  /// O- donor -> O+ request = false
  static bool canDonorDonateTo(
    String? donorBloodType,
    String? recipientBloodType,
  ) {
    if (donorBloodType == null || recipientBloodType == null) {
      return false;
    }

    final donor = donorBloodType.trim().toUpperCase();
    final recipient = recipientBloodType.trim().toUpperCase();

    if (donor.isEmpty || recipient.isEmpty) {
      return false;
    }

    return donor == recipient;
  }

  /// Returns the compatible recipient blood type for a donor.
  ///
  /// Blood-Connect uses exact blood-type matching only.
  ///
  /// Example:
  /// A+ donor -> ['A+']
  /// O+ donor -> ['O+']
  /// AB- donor -> ['AB-']
  static List<String> getCompatibleRecipients(String? donorBloodType) {
    if (donorBloodType == null) {
      return [];
    }

    final donor = donorBloodType.trim().toUpperCase();

    switch (donor) {
      case 'O-':
        return ['O-'];

      case 'O+':
        return ['O+'];

      case 'A-':
        return ['A-'];

      case 'A+':
        return ['A+'];

      case 'B-':
        return ['B-'];

      case 'B+':
        return ['B+'];

      case 'AB-':
        return ['AB-'];

      case 'AB+':
        return ['AB+'];

      default:
        return [];
    }
  }

  /// Returns the compatible donor blood type for a recipient/request.
  ///
  /// Blood-Connect uses exact blood-type matching only.
  ///
  /// Example:
  /// A+ request -> ['A+']
  /// O+ request -> ['O+']
  /// AB- request -> ['AB-']
  static List<String> getCompatibleDonorsForRecipient(
    String? recipientBloodType,
  ) {
    if (recipientBloodType == null) {
      return [];
    }

    final recipient = recipientBloodType.trim().toUpperCase();

    switch (recipient) {
      case 'O-':
        return ['O-'];

      case 'O+':
        return ['O+'];

      case 'A-':
        return ['A-'];

      case 'A+':
        return ['A+'];

      case 'B-':
        return ['B-'];

      case 'B+':
        return ['B+'];

      case 'AB-':
        return ['AB-'];

      case 'AB+':
        return ['AB+'];

      default:
        return [];
    }
  }
}

/// Waiting period between whole-blood donations.
///
/// PRC records the authoritative `nextEligibleDonationDate` on
/// `donors/{uid}` after each donation; this 56-day rule is only the fallback
/// when PRC has not set one yet.
abstract final class DonationInterval {
  static const days = 56;

  /// The first day the donor may give blood again.
  ///
  /// [prcNextEligible] (set by PRC) wins over the 56-day estimate from
  /// [lastDonation]. Returns null when neither is known.
  static DateTime? nextEligibleDate({
    DateTime? lastDonation,
    DateTime? prcNextEligible,
  }) {
    if (prcNextEligible != null) return _dateOnly(prcNextEligible);
    if (lastDonation == null) return null;
    final last = _dateOnly(lastDonation);
    return DateTime(last.year, last.month, last.day + days);
  }

  /// Whether the waiting period is over on [today].
  static bool isEligible(DateTime? nextEligible, {DateTime? today}) {
    if (nextEligible == null) return true;
    return !_dateOnly(
      today ?? DateTime.now(),
    ).isBefore(_dateOnly(nextEligible));
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
