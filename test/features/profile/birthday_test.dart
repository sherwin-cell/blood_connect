import 'package:blood_connect/features/profile/domain/birthday.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Birthday.parse', () {
    test('reads YYYY-MM-DD', () {
      expect(Birthday.parse('2000-03-15'), DateTime(2000, 3, 15));
    });

    test('reads legacy MM/DD/YYYY', () {
      expect(Birthday.parse('03/15/2000'), DateTime(2000, 3, 15));
    });

    test('reads a Timestamp as a date only', () {
      final ts = Timestamp.fromDate(DateTime(2000, 3, 15, 13, 45));
      expect(Birthday.parse(ts), DateTime(2000, 3, 15));
    });

    test('returns null for missing or bad values', () {
      expect(Birthday.parse(null), isNull);
      expect(Birthday.parse(''), isNull);
      expect(Birthday.parse('not a date'), isNull);
    });

    test('fromUserData prefers birthday, falls back to birthDate', () {
      expect(
        Birthday.fromUserData({'birthday': '1999-01-02'}),
        DateTime(1999, 1, 2),
      );
      expect(
        Birthday.fromUserData({'birthDate': '1998-05-06'}),
        DateTime(1998, 5, 6),
      );
      expect(Birthday.fromUserData({}), isNull);
      expect(Birthday.fromUserData(null), isNull);
    });
  });

  test('format pads to YYYY-MM-DD', () {
    expect(Birthday.format(DateTime(2001, 2, 3)), '2001-02-03');
  });

  group('Birthday.age', () {
    final now = DateTime(2026, 6, 15);

    test('counts the birthday itself', () {
      expect(Birthday.age(DateTime(2000, 6, 15), now: now), 26);
    });

    test('day before the birthday is one year less', () {
      expect(Birthday.age(DateTime(2000, 6, 16), now: now), 25);
      expect(Birthday.age(DateTime(2000, 12, 1), now: now), 25);
    });
  });

  group('Birthday.validate', () {
    final now = DateTime(2026, 6, 15, 10);

    test('requires a date', () {
      expect(Birthday.validate(null, now: now), isNotNull);
    });

    test('rejects a future date', () {
      expect(Birthday.validate(DateTime(2026, 6, 16), now: now), isNotNull);
    });

    test('accepts today and past dates', () {
      expect(Birthday.validate(DateTime(2026, 6, 15), now: now), isNull);
      expect(Birthday.validate(DateTime(1990, 1, 1), now: now), isNull);
    });

    test('rejects dates before 1900', () {
      expect(Birthday.validate(DateTime(1899, 12, 31), now: now), isNotNull);
    });
  });
}
