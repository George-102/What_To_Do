import 'package:flutter_test/flutter_test.dart';

import 'package:today_do_what/models/app_state.dart';
import 'package:today_do_what/models/daily_record.dart';
import 'package:today_do_what/services/sync_merger.dart';
import 'package:today_do_what/services/sync_service.dart';

/// 基于内存的 SyncService mock，用于端到端同步逻辑测试。
///
/// 把所有实例共享的状态放在类变量里（模拟云端存储），
/// 不同实例（代表不同设备）之间通过这个共享存储互相同步。
class MockSyncService extends SyncService {
  MockSyncService({required super.syncCode});

  /// 模拟云端存储：syncCode → AppState
  static final Map<String, AppState> _cloud = {};

  static void reset() => _cloud.clear();

  @override
  Future<bool> upload(AppState state) async {
    _cloud[syncCode] = state;
    return true;
  }

  @override
  Future<AppState?> download() async => _cloud[syncCode];

  @override
  Future<AppState> sync(AppState local) async {
    final remote = await download();
    if (remote == null) {
      await upload(local);
      return local;
    }
    final merged = SyncMerger.merge(local, remote);
    await upload(merged);
    return merged;
  }
}

void main() {
  const code = 'TESTSYNC';
  final t1 = DateTime(2026, 10, 9, 10, 0);
  final t2 = DateTime(2026, 10, 9, 12, 0);
  const today = '2026-10-09';

  AppState makeState({
    int coinBalance = 0,
    DateTime? updatedAt,
    List<DailyRecord> history = const [],
  }) {
    return AppState(
      coinBalance: coinBalance,
      history: history,
      updatedAt: updatedAt,
    );
  }

  setUp(() => MockSyncService.reset());

  group('SyncService sync round-trip (Mock)', () {
    test('云端空 → 本地直接上传', () async {
      final svc = MockSyncService(syncCode: code);
      final local = makeState(coinBalance: 100, updatedAt: t1);
      final result = await svc.sync(local);
      expect(result.coinBalance, 100);
      // 模拟云端里应该有数据了
      expect(await svc.download(), isNotNull);
    });

    test('A 端上传 → B 端拉取 → 数据一致', () async {
      final svcA = MockSyncService(syncCode: code);
      final svcB = MockSyncService(syncCode: code);

      final stateA = makeState(
        coinBalance: 200,
        updatedAt: t1,
        history: [DailyRecord(date: today, taskIds: ['kaoyan'], updatedAt: t1)],
      );
      await svcA.upload(stateA);

      final resultB = await svcB.sync(AppState(updatedAt: t1));
      expect(resultB.coinBalance, 200);
      expect(resultB.history, hasLength(1));
      expect(resultB.history.first.taskIds, ['kaoyan']);
    });

    test('两端独立修改 → sync 合并（last-write-wins）', () async {
      final svcA = MockSyncService(syncCode: code);
      final svcB = MockSyncService(syncCode: code);

      // 先让 A 端有一份基础数据
      await svcA.sync(makeState(coinBalance: 50, updatedAt: t1));

      // A 端再改：打卡 +10，更新时间 t1
      final localA = makeState(coinBalance: 60, updatedAt: t1);

      // B 端独立：兑换 -20，更新时间 t2（更晚）
      final localB = makeState(coinBalance: 30, updatedAt: t2);

      // B 先 sync：云端已有 A 的 50，合并后用 B 的（t2 更晚）
      final resultB = await svcB.sync(localB);
      expect(resultB.coinBalance, 30); // B 的值（t2 > t1）

      // A 再 sync：云端现在是 B 的 30，合并 A 的 60，A 更新时间早，所以结果还是 30
      final resultA = await svcA.sync(localA);
      expect(resultA.coinBalance, 30); // B 的值获胜

      // 两端最终一致
      final finalA = await svcA.download();
      final finalB = await svcB.download();
      expect(finalA?.coinBalance, 30);
      expect(finalB?.coinBalance, 30);
    });

    test('不同日期的 DailyRecord → 两端都保留', () async {
      final svcA = MockSyncService(syncCode: code);
      final svcB = MockSyncService(syncCode: code);

      // A 端昨天有记录
      final localA = makeState(
        updatedAt: t1,
        history: [DailyRecord(date: '2026-10-08', taskIds: ['reading'], updatedAt: t1)],
      );

      // B 端今天有记录
      final localB = makeState(
        updatedAt: t2,
        history: [DailyRecord(date: today, taskIds: ['workout'], updatedAt: t2)],
      );

      // B 先 sync（云端空，直接上传 B）
      await svcB.sync(localB);

      // A 再 sync（云端有 B 的今天，合并后 A 的昨天 + B 的今天）
      final resultA = await svcA.sync(localA);
      expect(resultA.history, hasLength(2));
      final dates = resultA.history.map((r) => r.date).toSet();
      expect(dates, contains('2026-10-08'));
      expect(dates, contains(today));
    });

    test('同一个 MockSyncService 实例重复 sync → 幂等', () async {
      final svc = MockSyncService(syncCode: code);
      final state = makeState(coinBalance: 100, updatedAt: t1);

      final r1 = await svc.sync(state);
      final r2 = await svc.sync(state);
      final r3 = await svc.sync(state);

      expect(r1.coinBalance, 100);
      expect(r2.coinBalance, 100);
      expect(r3.coinBalance, 100);
      // 云端始终只有一份
      final cloud = await svc.download();
      expect(cloud?.coinBalance, 100);
    });
  });
}
