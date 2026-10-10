import 'package:flutter_test/flutter_test.dart';
import 'package:today_do_what/services/coin_service.dart';

void main() {
  const service = CoinService();

  test('首次打卡（昨天未打卡）从 1 开始，无加成，应得 10', () {
    final r = service.checkIn(checkedYesterday: false, consecutiveCheckInDays: 0);
    expect(r.streak, 1);
    expect(r.bonus, 0);
    expect(r.earn, 10);
  });

  test('昨日已打卡则连续天数累加，第 3 天触发 +5', () {
    final r = service.checkIn(checkedYesterday: true, consecutiveCheckInDays: 2);
    expect(r.streak, 3);
    expect(r.bonus, 5);
    expect(r.earn, 15);
  });

  test('第 5 天 +10、第 7 天 +15', () {
    final d5 = service.checkIn(checkedYesterday: true, consecutiveCheckInDays: 4);
    expect(d5.bonus, 10);
    expect(d5.earn, 20);

    final d7 = service.checkIn(checkedYesterday: true, consecutiveCheckInDays: 6);
    expect(d7.bonus, 15);
    expect(d7.earn, 25);
  });

  test('非加成日（第 2/4/6 天）无加成', () {
    final d2 = service.checkIn(checkedYesterday: true, consecutiveCheckInDays: 1);
    expect(d2.bonus, 0);
    expect(d2.streak, 2);

    final d4 = service.checkIn(checkedYesterday: true, consecutiveCheckInDays: 3);
    expect(d4.bonus, 0);
    expect(d4.streak, 4);
  });

  test('断签：昨日未打卡时连续天数归零从 1 重计', () {
    final r = service.checkIn(checkedYesterday: false, consecutiveCheckInDays: 6);
    expect(r.streak, 1);
    expect(r.bonus, 0);
    expect(r.earn, 10);
  });
}