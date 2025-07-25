import 'package:groupscholar_award_appeal_tracker/groupscholar_award_appeal_tracker.dart';
import 'package:test/test.dart';

void main() {
  test('normalizeStatus trims and underscores', () {
    expect(normalizeStatus(' Pending Review '), 'pending_review');
  });

  test('formatCurrency shows two decimals', () {
    expect(formatCurrency(1500), '\$1500.00');
    expect(formatCurrency(42.5), '\$42.50');
  });

  test('renderTable aligns columns', () {
    final output = renderTable(
      ['Name', 'Status'],
      [
        ['Avery', 'pending'],
        ['Zoe', 'approved'],
      ],
    );
    final lines = output.split('\n');
    expect(lines.length, 4);
    expect(lines.first.contains('Name'), isTrue);
  });

  test('daysBetween counts whole days ignoring time', () {
    final start = DateTime(2026, 2, 1, 23, 30);
    final end = DateTime(2026, 2, 3, 1, 5);
    expect(daysBetween(start, end), 2);
  });

}
