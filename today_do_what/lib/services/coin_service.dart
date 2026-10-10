/// 金币服务：打卡入账与全勤加成计算。
///
/// 只做纯计算，不改状态；由 AppProvider 依据结果更新 [AppState] 并持久化。
/// 断签判定由调用方给出：昨天已打卡才延续连续天数，否则从 1 重新计。
class CoinService {
  const CoinService();

  /// 每次打卡的基础金币。
  static const int baseCoin = 10;

  /// 全勤加成：连续第 N 天打卡额外奖励的金币数。
  static const Map<int, int> bonusByStreak = {3: 5, 5: 10, 7: 15};

  /// 计算一次打卡后的连续天数与加成。
  ///
  /// [checkedYesterday] 表示昨天是否已打卡；[consecutiveCheckInDays] 为当前
  /// State 中记录的连续天数。返回本次打卡后的 streak 与 bonus。
  CoinCheckInResult checkIn({
    required bool checkedYesterday,
    required int consecutiveCheckInDays,
  }) {
    final streak = checkedYesterday ? consecutiveCheckInDays + 1 : 1;
    final bonus = bonusByStreak[streak] ?? 0;
    return CoinCheckInResult(streak: streak, bonus: bonus);
  }
}

/// 一次打卡的结果：本次后的连续天数与额外加成。
class CoinCheckInResult {
  const CoinCheckInResult({required this.streak, required this.bonus});

  /// 本次打卡后的连续天数。
  final int streak;

  /// 全勤加成金币（可能为 0）。
  final int bonus;

  /// 本次总入账金币 = 基础 + 加成。
  int get earn => CoinService.baseCoin + bonus;
}