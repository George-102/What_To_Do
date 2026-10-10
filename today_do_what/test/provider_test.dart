import 'package:flutter_test/flutter_test.dart';
import 'package:today_do_what/models/app_state.dart';
import 'package:today_do_what/models/daily_record.dart';
import 'package:today_do_what/models/reward.dart';
import 'package:today_do_what/providers/app_provider.dart';
import 'package:today_do_what/services/coin_service.dart';
import 'package:today_do_what/services/date_util.dart';

void main() {
  test('打卡生效且幂等', () {
    final provider = AppProvider(
      now: () => DateTime(2026, 10, 7),
      initial: AppState(
        history: [
          DailyRecord(
            date: '2026-10-07',
            taskIds: const ['kaoyan', 'reading', 'workout'],
          ),
        ],
      ),
    );

    provider.checkIn();
    final today = provider.state.history.single;
    expect(today.isCheckedIn, isTrue);
    expect(today.checkedInAt, isNotNull);

    final before = provider.state.history.length;
    final firstTime = today.checkedInAt;
    provider.checkIn();
    expect(provider.state.history.length, before);
    expect(provider.state.history.single.checkedInAt, firstTime);
  });

  test('今天未抽签时打卡不生效', () {
    final provider = AppProvider(now: () => DateTime(2026, 10, 7));
    provider.checkIn();
    expect(provider.state.history, isEmpty);
    expect(provider.state.coinBalance, 0);
  });

  test('打卡发放基础金币并记录流水，二次打卡不重复入账', () {
    final provider = AppProvider(
      now: () => DateTime(2026, 10, 7),
      initial: AppState(
        history: [
          DailyRecord(
            date: '2026-10-07',
            taskIds: const ['kaoyan', 'reading', 'workout'],
          ),
        ],
      ),
    );

    provider.checkIn();
    expect(provider.state.coinBalance, CoinService.baseCoin);
    expect(provider.state.consecutiveCheckInDays, 1);
    expect(provider.state.lastCheckInDate, '2026-10-07');
    expect(provider.state.coinLog.single.type, 'earn');
    expect(provider.state.coinLog.single.amount, CoinService.baseCoin);

    provider.checkIn();
    expect(provider.state.coinBalance, CoinService.baseCoin);
    expect(provider.state.coinLog.length, 1);
  });

  test('全勤加成：连续第 3 天打卡额外 +5', () {
    final provider = AppProvider(
      now: () => DateTime(2026, 10, 9),
      initial: AppState(
        consecutiveCheckInDays: 2,
        lastCheckInDate: '2026-10-08',
        history: [
          DailyRecord(
            date: '2026-10-09',
            taskIds: const ['kaoyan', 'reading', 'workout'],
          ),
        ],
      ),
    );

    provider.checkIn();
    expect(provider.state.coinBalance, CoinService.baseCoin + 5);
    expect(provider.state.consecutiveCheckInDays, 3);
    // 两条流水：基础 + 加成
    expect(provider.state.coinLog.length, 2);
  });

  test('添加奖励成功并写入列表', () {
    final provider = AppProvider(now: () => DateTime(2026, 10, 7));
    provider.addReward(name: '奶茶', price: 50);
    expect(provider.state.rewards.length, 1);
    expect(provider.state.rewards.single.name, '奶茶');
    expect(provider.state.rewards.single.price, 50);
  });

  test('余额足够时兑换成功：扣币 + 记 spend 流水', () {
    final provider = AppProvider(
      now: () => DateTime(2026, 10, 7),
      initial: AppState(
        coinBalance: 60,
        rewards: const [Reward(id: 'r1', name: '奶茶', price: 50)],
      ),
    );

    expect(provider.redeemReward('r1'), isTrue);
    expect(provider.state.coinBalance, 10);
    expect(provider.state.coinLog.single.type, 'spend');
    expect(provider.state.coinLog.single.amount, -50);
    expect(provider.state.coinLog.single.note, '奶茶');
  });

  test('余额不足时兑换失败：不扣币、不记流水', () {
    final provider = AppProvider(
      now: () => DateTime(2026, 10, 7),
      initial: AppState(
        coinBalance: 30,
        rewards: const [Reward(id: 'r1', name: '奶茶', price: 50)],
      ),
    );

    expect(provider.redeemReward('r1'), isFalse);
    expect(provider.state.coinBalance, 30);
    expect(provider.state.coinLog, isEmpty);
  });

  test('兑换不存在的奖励返回 false', () {
    final provider = AppProvider(
      now: () => DateTime(2026, 10, 7),
      initial: AppState(coinBalance: 100),
    );
    expect(provider.redeemReward('nope'), isFalse);
    expect(provider.state.coinBalance, 100);
  });

  test('本周有反悔机会成功重抽；再次反悔失败且设置 lastRerollWeek', () {
    final provider = AppProvider(
      now: () => DateTime(2026, 10, 7),
      initial: const AppState(),
    );
    provider.drawToday(); // today 2026-10-07 已抽
    final week = isoWeek(DateTime(2026, 10, 7));

    expect(provider.canReroll, isTrue);
    expect(provider.rerollToday(), isTrue);
    expect(provider.state.history.single.isRerolled, isTrue);
    expect(provider.state.lastRerollWeek, week);

    // 本周第二次反悔失败。
    final before = provider.state.history.single.taskIds;
    expect(provider.canReroll, isFalse);
    expect(provider.rerollToday(), isFalse);
    expect(provider.state.history.single.taskIds, before);
  });
}