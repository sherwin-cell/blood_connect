class BloodCompatibility {
  /// Evaluates if a donor can safely donate red cells to a specific recipient.
  /// Used for Donor -> Recipient checks.
  static bool canDonorDonateTo(
    String? donorBloodType,
    String? recipientBloodType,
  ) {
    if (donorBloodType == null || recipientBloodType == null) return false;

    final donor = donorBloodType.trim().toUpperCase();
    final recipient = recipientBloodType.trim().toUpperCase();

    final allowedRecipients = getCompatibleRecipients(donor);
    return allowedRecipients.contains(recipient);
  }

  /// Returns all compatible recipient types for a given donor blood type.
  /// (Donor -> Recipient matrix)
  static List<String> getCompatibleRecipients(String? donorBloodType) {
    if (donorBloodType == null) return [];

    switch (donorBloodType.trim().toUpperCase()) {
      case 'O-':
        return ['O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'];
      case 'O+':
        return ['O+', 'A+', 'B+', 'AB+'];
      case 'A-':
        return ['A-', 'A+', 'AB-', 'AB+'];
      case 'A+':
        return ['A+', 'AB+'];
      case 'B-':
        return ['B-', 'B+', 'AB-', 'AB+'];
      case 'B+':
        return ['B+', 'AB+'];
      case 'AB-':
        return ['AB-', 'AB+'];
      case 'AB+':
        return [
          'AB+',
        ]; // AB+ donors can only donate red cells to AB+ recipients
      default:
        return [];
    }
  }

  /// Returns all safe donor blood types for a given recipient (requester) blood type.
  /// (Recipient -> Donor matrix)
  static List<String> getCompatibleDonorsForRecipient(
    String? recipientBloodType,
  ) {
    if (recipientBloodType == null) return [];

    switch (recipientBloodType.trim().toUpperCase()) {
      case 'O-':
        return ['O-'];
      case 'O+':
        return ['O-', 'O+'];
      case 'A-':
        return ['O-', 'A-'];
      case 'A+':
        return ['O-', 'O+', 'A-', 'A+'];
      case 'B-':
        return ['O-', 'B-'];
      case 'B+':
        return ['O-', 'O+', 'B-', 'B+'];
      case 'AB-':
        return ['O-', 'A-', 'B-', 'AB-'];
      case 'AB+':
        return [
          'O-',
          'O+',
          'A-',
          'A+',
          'B-',
          'B+',
          'AB-',
          'AB+',
        ]; // Universal recipient
      default:
        return [];
    }
  }
}
