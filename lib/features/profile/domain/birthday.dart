import 'package:cloud_firestore/cloud_firestore.dart';

/// Date of Birth helpers shared by Sign Up, Complete Profile and the
/// donor / requester application forms.
///
/// The birthday is entered once and stored in `users/{uid}.birthday` as
/// `YYYY-MM-DD`. Age is never stored on the profile; it is derived.
class Birthday {
  Birthday._();

  /// Earliest date the pickers allow.
  static final DateTime firstDate = DateTime(1900);

  /// Parses a stored birthday: a `YYYY-MM-DD` string, a legacy
  /// `MM/DD/YYYY` string, a [Timestamp] or a [DateTime]. Returns a
  /// date-only value, or null when missing or unreadable.
  static DateTime? parse(dynamic value) {
    DateTime? date;
    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    } else if (value is String && value.trim().isNotEmpty) {
      final text = value.trim();
      date = DateTime.tryParse(text);
      if (date == null) {
        final m = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(text);
        if (m != null) {
          date = DateTime(
            int.parse(m.group(3)!),
            int.parse(m.group(1)!),
            int.parse(m.group(2)!),
          );
        }
      }
    }
    return date == null ? null : DateTime(date.year, date.month, date.day);
  }

  /// Reads the birthday from a `users/{uid}` document map.
  static DateTime? fromUserData(Map<String, dynamic>? data) =>
      data == null ? null : parse(data['birthday'] ?? data['birthDate']);

  /// `YYYY-MM-DD`, the format stored in Firestore.
  static String format(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Whole years between [birthDate] and [now] (today by default).
  static int age(DateTime birthDate, {DateTime? now}) {
    final today = now ?? DateTime.now();
    var years = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      years--;
    }
    return years;
  }

  /// Returns an error message, or null when [date] is a valid birthday.
  static String? validate(DateTime? date, {DateTime? now}) {
    if (date == null) return 'Date of Birth is required';
    final today = now ?? DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    if (date.isAfter(todayDate)) {
      return 'Date of Birth cannot be in the future';
    }
    if (date.isBefore(firstDate)) return 'Enter a valid Date of Birth';
    return null;
  }
}
