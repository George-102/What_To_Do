import '../models/app_state.dart';
import '../models/coin_log.dart';
import '../models/daily_record.dart';
import '../models/reward.dart';
import 'draw_service.dart';

/// 同步合并器：纯函数，将本地与远端两份 [AppState] 合并为一份。
///
/// 合并策略：
/// - DailyRecord 按 date 去重，同日取 updatedAt 更晚的（抽签冲突解决）。
/// - CoinLog / Reward 按 id 去重（跨设备 id 已加 deviceId 前缀，天然不碰撞）。
/// - 顶层字段（coinBalance、连续天数、lastCheckInDate、lastRerollWeek）
///   取两份 AppState 中 updatedAt 更晚的那份的值。
/// - taskStats 从合并后的 history 重新计算（保证与 history 一致）。
class SyncMerger {
  /// 合并两份 AppState，返回合并后的新状态。
  ///
  /// [now] 为当前时间戳，用于设置合并后 AppState.updatedAt；默认 DateTime.now。
  static AppState merge(AppState local, AppState remote, {DateTime? now}) {
    final DateTime effectiveNow = now ?? DateTime.now();

    // 1. 合并 DailyRecord（按 date 去重，同日取 updatedAt 更晚的）
    final mergedHistory = _mergeHistory(local.history, remote.history);

    // 2. 合并 CoinLog（按 id 去重）
    final mergedCoinLog = _mergeCoinLog(local.coinLog, remote.coinLog);

    // 3. 合并 Reward（按 id 去重）
    final mergedRewards = _mergeRewards(local.rewards, remote.rewards);

    // 4. 顶层字段：取两份 AppState 中 updatedAt 更晚的那份
    final topLevel = _resolveTopLevel(local, remote);

    // 5. taskStats 从合并后的 history 重新计算
    final mergedStats = DrawService.computeStats(mergedHistory);

    return AppState(
      coinBalance: topLevel.coinBalance,
      consecutiveCheckInDays: topLevel.consecutiveCheckInDays,
      lastCheckInDate: topLevel.lastCheckInDate,
      lastRerollWeek: topLevel.lastRerollWeek,
      history: mergedHistory,
      taskStats: mergedStats,
      rewards: mergedRewards,
      coinLog: mergedCoinLog,
      updatedAt: effectiveNow,
    );
  }

  /// 合并 DailyRecord 列表：按 date 分组，同日取 updatedAt 更晚的。
  static List<DailyRecord> _mergeHistory(
      List<DailyRecord> a, List<DailyRecord> b) {
    final map = <String, DailyRecord>{};
    for (final r in [...a, ...b]) {
      final existing = map[r.date];
      if (existing == null) {
        map[r.date] = r;
      } else {
        final existingTime = existing.updatedAt;
        final newTime = r.updatedAt;
        // updatedAt 为 null 的一方视为「很早以前」，取有时间戳或更晚的。
        // 时间戳相等时 remote（先进入 cloud 的那份，即 newTime 来自 b 也就是 remote）获胜。
        if (newTime != null &&
            (existingTime == null || !newTime.isBefore(existingTime))) {
          map[r.date] = r;
        }
      }
    }
    final result = map.values.toList()
      ..sort((x, y) => y.date.compareTo(x.date));
    return result;
  }

  /// 合并 CoinLog 列表：按 id 去重（同一个 id 只保留一份）。
  static List<CoinLog> _mergeCoinLog(List<CoinLog> a, List<CoinLog> b) {
    final map = <String, CoinLog>{};
    for (final log in [...a, ...b]) {
      map.putIfAbsent(log.id, () => log);
    }
    return map.values.toList();
  }

  /// 合并 Reward 列表：按 id 去重。
  static List<Reward> _mergeRewards(List<Reward> a, List<Reward> b) {
    final map = <String, Reward>{};
    for (final r in [...a, ...b]) {
      map.putIfAbsent(r.id, () => r);
    }
    return map.values.toList();
  }

  /// 解析顶层字段：取两份 AppState 中 updatedAt 更晚的那份的值。
  ///
  /// 时间戳相等时 remote（云端真相）获胜，因为云端数据是多设备合并后的最终态。
  static _TopLevelFields _resolveTopLevel(AppState local, AppState remote) {
    final localTime = local.updatedAt;
    final remoteTime = remote.updatedAt;

    // 取 remote 的条件：remote 有时间戳，且比 local 不早（≥）
    final useRemote = remoteTime != null &&
        (localTime == null || !remoteTime.isBefore(localTime));

    final source = useRemote ? remote : local;
    return _TopLevelFields(
      coinBalance: source.coinBalance,
      consecutiveCheckInDays: source.consecutiveCheckInDays,
      lastCheckInDate: source.lastCheckInDate,
      lastRerollWeek: source.lastRerollWeek,
    );
  }
}

class _TopLevelFields {
  _TopLevelFields({
    required this.coinBalance,
    required this.consecutiveCheckInDays,
    required this.lastCheckInDate,
    required this.lastRerollWeek,
  });

  final int coinBalance;
  final int consecutiveCheckInDays;
  final String? lastCheckInDate;
  final int? lastRerollWeek;
}
