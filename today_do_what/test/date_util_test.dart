import 'package:flutter_test/flutter_test.dart';
import 'package:today_do_what/services/date_util.dart';

void main() {
  test('ymd 格式化', () {
    expect(ymd(DateTime(2026, 10, 7)), '2026-10-07');
    expect(ymd(DateTime(2026, 1, 1)), '2026-01-01');
  });

  test('subtractDays 跨月 / 跨年', () {
    expect(subtractDays('2026-10-07', 7), '2026-09-30');
    expect(subtractDays('2026-03-01', 1), '2026-02-28');
    expect(subtractDays('2026-01-01', 1), '2025-12-31');
  });

  test('yesterdayOf', () {
    expect(yesterdayOf('2026-10-07'), '2026-10-06');
  });
}