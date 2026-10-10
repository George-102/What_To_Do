import 'package:flutter_test/flutter_test.dart';

import 'package:today_do_what/models/app_state.dart';
import 'package:today_do_what/models/coin_log.dart';
import 'package:today_do_what/models/daily_record.dart';
import 'package:today_do_what/models/reward.dart';
import 'package:today_do_what/services/sync_merger.dart';

void main() {
  final t1 = DateTime(2026, 10, 9, 10, 0); // 今天 10:00
  final t2 = DateTime(2026, 10, 9, 12, 0); // 今天 12:00（更晚）
  final t3 = DateTime(2026, 10, 8, 10, 0); // 昨天 10:00
  const today = '2026-10-09';
  const yesterday = '2026-10-08';

  AppState makeEmpty({DateTime? updatedAt}) => AppState(updatedAt: updatedAt);

  AppState makeState({
    int coinBalance = 0,
    DateTime? updatedAt,
    List<DailyRecord> history = const [],
    List<CoinLog> coinLog = const [],
    List<Reward> rewards = const [],
  }) {
    return AppState(
      coinBalance: coinBalance,
      history: history,
      coinLog: coinLog,
      rewards: rewards,
      updatedAt: updatedAt,
    );
  }

  group('SyncMerger.merge', () {
    test('两份空状态合并 → 空状态', () {
      final result = SyncMerger.merge(makeEmpty(updatedAt: t1), makeEmpty(updatedAt: t2));
      expect(result.coinBalance, 0);
      expect(result.history, isEmpty);
      expect(result.updatedAt, isNotNull); // 合并后有新时间戳
    });

    test('本地有数据、远端空（updatedAt=null） → 保留本地', () {
      final local = makeState(
        coinBalance: 100,
        updatedAt: t1,
        history: [DailyRecord(date: today, taskIds: ['kaoyan'], updatedAt: t1)],
      );
      final result = SyncMerger.merge(local, makeEmpty(updatedAt: null));
      expect(result.coinBalance, 100);
      expect(result.history, hasLength(1));
      expect(result.history.first.date, today);
    });

    test('远端 updatedAt 更晚 → 顶层字段取远端', () {
      final local = makeState(coinBalance: 50, updatedAt: t1);
      final remote = makeState(coinBalance: 200, updatedAt: t2); // 更晚
      final result = SyncMerger.merge(local, remote, now: DateTime(2026));
      expect(result.coinBalance, 200);
    });

    test('本地 updatedAt 更晚 → 顶层字段取本地', () {
      final local = makeState(coinBalance: 50, updatedAt: t2); // 更晚
      final remote = makeState(coinBalance: 200, updatedAt: t1);
      final result = SyncMerger.merge(local, remote, now: DateTime(2026));
      expect(result.coinBalance, 50);
    });

    test('DailyRecord 不同日期 → 两边都保留', () {
      final local = makeState(
        updatedAt: t1,
        history: [DailyRecord(date: yesterday, taskIds: ['kaoyan'], updatedAt: t3)],
      );
      final remote = makeState(
        updatedAt: t1,
        history: [DailyRecord(date: today, taskIds: ['reading'], updatedAt: t1)],
      );
      final result = SyncMerger.merge(local, remote, now: DateTime(2026));
      expect(result.history, hasLength(2));
      final dates = result.history.map((r) => r.date).toSet();
      expect(dates, contains(yesterday));
      expect(dates, contains(today));
    });

    test('DailyRecord 同日冲突 → 取 updatedAt 更晚的（远端）', () {
      final local = makeState(
        updatedAt: t1,
        history: [DailyRecord(date: today, taskIds: ['kaoyan'], updatedAt: t1)],
      );
      final remote = makeState(
        updatedAt: t2,
        history: [DailyRecord(date: today, taskIds: ['reading'], updatedAt: t2)],
      );
      final result = SyncMerger.merge(local, remote, now: DateTime(2026));
      expect(result.history, hasLength(1));
      expect(result.history.first.taskIds, ['reading']); // 远端的，因为 updatedAt 更晚
    });

    test('DailyRecord 同日冲突 → 取 updatedAt 更晚的（本地）', () {
      final local = makeState(
        updatedAt: t2,
        history: [DailyRecord(date: today, taskIds: ['kaoyan'], updatedAt: t2)],
      );
      final remote = makeState(
        updatedAt: t1,
        history: [DailyRecord(date: today, taskIds: ['reading'], updatedAt: t1)],
      );
      final result = SyncMerger.merge(local, remote, now: DateTime(2026));
      expect(result.history, hasLength(1));
      expect(result.history.first.taskIds, ['kaoyan']); // 本地的
    });

    test('CoinLog 不同 id → 两边都保留', () {
      final local = makeState(
        updatedAt: t1,
        coinLog: [
          CoinLog(id: 'devA-1-base', date: today, type: 'earn', amount: 10, note: '', createdAt: t1),
        ],
      );
      final remote = makeState(
        updatedAt: t1,
        coinLog: [
          CoinLog(id: 'devB-1-base', date: today, type: 'earn', amount: 10, note: '', createdAt: t1),
        ],
      );
      final result = SyncMerger.merge(local, remote, now: DateTime(2026));
      expect(result.coinLog, hasLength(2));
    });

    test('CoinLog 同 id → 去重只保留一份（防金币重复发放）', () {
      final log = CoinLog(id: 'devA-1-base', date: today, type: 'earn', amount: 10, note: '', createdAt: t1);
      final local = makeState(updatedAt: t1, coinLog: [log]);
      final remote = makeState(updatedAt: t1, coinLog: [log]); // 同一份流水
      final result = SyncMerger.merge(local, remote, now: DateTime(2026));
      expect(result.coinLog, hasLength(1)); // 去重
    });

    test('Reward 同 id → 去重', () {
      final reward = Reward(id: 'devA-1', name: '奶茶', price: 50);
      final local = makeState(updatedAt: t1, rewards: [reward]);
      final remote = makeState(updatedAt: t1, rewards: [reward]);
      final result = SyncMerger.merge(local, remote, now: DateTime(2026));
      expect(result.rewards, hasLength(1));
    });

    test('Reward 不同 id → 两边都保留', () {
      final local = makeState(
        updatedAt: t1,
        rewards: [Reward(id: 'devA-1', name: '奶茶', price: 50)],
      );
      final remote = makeState(
        updatedAt: t1,
        rewards: [Reward(id: 'devB-2', name: '游戏', price: 100)],
      );
      final result = SyncMerger.merge(local, remote, now: DateTime(2026));
      expect(result.rewards, hasLength(2));
    });

    test('taskStats 从合并后的 history 重新计算', () {
      final local = makeState(
        updatedAt: t1,
        history: [DailyRecord(date: yesterday, taskIds: ['kaoyan'], updatedAt: t3)],
      );
      final remote = makeState(
        updatedAt: t2,
        history: [DailyRecord(date: today, taskIds: ['kaoyan'], updatedAt: t2)],
      );
      final result = SyncMerger.merge(local, remote, now: DateTime(2026));
      // kaoyan 连续两天被抽，taskStats 里 streak 应该是 2
      final kaoyanStats = result.taskStats.firstWhere((s) => s.taskId == 'kaoyan');
      expect(kaoyanStats.streak, 2);
      expect(kaoyanStats.lastSelectedDate, today);
    });

    test('merged history 按日期倒序排列（最新在前）', () {
      final local = makeState(
        updatedAt: t1,
        history: [DailyRecord(date: yesterday, taskIds: ['kaoyan'], updatedAt: t3)],
      );
      final remote = makeState(
        updatedAt: t1,
        history: [DailyRecord(date: today, taskIds: ['reading'], updatedAt: t1)],
      );
      final result = SyncMerger.merge(local, remote, now: DateTime(2026));
      expect(result.history.first.date, today);
      expect(result.history.last.date, yesterday);
    });
  });
}
