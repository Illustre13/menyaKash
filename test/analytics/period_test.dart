import 'package:flutter_test/flutter_test.dart';
import 'package:i_momo/analytics/period.dart';

void main() {
  group('week', () {
    test('starts on Monday and spans 7 days', () {
      // Wednesday 2026-07-08
      final period = Period.containing(PeriodGranularity.week, DateTime(2026, 7, 8));
      expect(period.start, DateTime(2026, 7, 6)); // Monday
      expect(period.end, DateTime(2026, 7, 13));
    });

    test('previous/next shift by exactly 7 days', () {
      final period = Period.containing(PeriodGranularity.week, DateTime(2026, 7, 8));
      expect(period.previous.start, DateTime(2026, 6, 29));
      expect(period.next.start, DateTime(2026, 7, 13));
    });
  });

  group('month', () {
    test('spans the full calendar month', () {
      final period = Period.containing(PeriodGranularity.month, DateTime(2026, 2, 15));
      expect(period.start, DateTime(2026, 2, 1));
      expect(period.end, DateTime(2026, 3, 1));
    });

    test('rolls over year boundary going to previous', () {
      final period = Period.containing(PeriodGranularity.month, DateTime(2026, 1, 15));
      final prev = period.previous;
      expect(prev.start, DateTime(2025, 12, 1));
      expect(prev.end, DateTime(2026, 1, 1));
    });

    test('rolls over year boundary going to next', () {
      final period = Period.containing(PeriodGranularity.month, DateTime(2026, 12, 15));
      final next = period.next;
      expect(next.start, DateTime(2027, 1, 1));
      expect(next.end, DateTime(2027, 2, 1));
    });
  });

  group('quarter', () {
    test('Q3 covers July-September', () {
      final period = Period.containing(PeriodGranularity.quarter, DateTime(2026, 8, 1));
      expect(period.start, DateTime(2026, 7, 1));
      expect(period.end, DateTime(2026, 10, 1));
      expect(period.label(), 'Q3 2026');
    });

    test('Q4 rolls into Q1 of next year', () {
      final period = Period.containing(PeriodGranularity.quarter, DateTime(2026, 11, 1));
      final next = period.next;
      expect(next.start, DateTime(2027, 1, 1));
      expect(next.end, DateTime(2027, 4, 1));
    });
  });

  group('year', () {
    test('spans the full calendar year', () {
      final period = Period.containing(PeriodGranularity.year, DateTime(2026, 6, 1));
      expect(period.start, DateTime(2026, 1, 1));
      expect(period.end, DateTime(2027, 1, 1));
      expect(period.label(), '2026');
    });
  });

  group('containsCurrent', () {
    test('true when now falls within the period', () {
      final period = Period.containing(PeriodGranularity.month, DateTime(2026, 7, 1));
      expect(period.containsCurrent(DateTime(2026, 7, 15)), isTrue);
    });

    test('false when now falls outside the period', () {
      final period = Period.containing(PeriodGranularity.month, DateTime(2026, 7, 1));
      expect(period.containsCurrent(DateTime(2026, 8, 15)), isFalse);
    });
  });
}
