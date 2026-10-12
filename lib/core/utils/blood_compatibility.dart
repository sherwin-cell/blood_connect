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
