import 'dart:math';

import '../models/app_state.dart';
import '../models/daily_record.dart';
import '../models/task.dart';
import '../models/task_stats.dart';
import 'date_util.dart';

/// 抽奖服务：从任务池随机抽取当天任务，并落地「连续排除规则」。
///
/// 连续排除规则：某任务连续两天被抽中，第三天从池中排除；若某天未抽中，
/// 连续计数即中断（规则语义见 plan.md 第三节）。
///
/// 任务来源：[state.tasks]（用户自定义列表）；为空时回退到 [Task.seed]。
class DrawService {
  DrawService({Random? random, DateTime Function()? now})
      : _random = random ?? Random(),
        _now = now ?? DateTime.now;

  final Random _random;
  final DateTime Function() _now;

  /// 每天抽取的任务数。
  static const int dailyCount = 3;

  /// 直接用任务池随机取 [count] 个不重复 id（不代入排除规则）。
  List<String> drawIds({required List<Task> pool, int count = dailyCount}) {
    final ids = pool.map((t) => t.id).toList();
    return _pick(ids, count);
  }

  /// 为某天抽取任务。
  ///
  /// 当天已有结果则原样返回（结果固定，不重抽）；否则基于已有历史计算每个任务的
  /// 「连续抽中天数」并排除需停用任务，再随机抽 [dailyCount] 个，最后重算 taskStats。
  AppState drawForDay(AppState state, String today) {
    if (_isDrawn(state, today)) return state;

    final pool = _resolveTasks(state.tasks);
    final yesterday = yesterdayOf(today);
    final excluded = <String>{
      for (final t in pool)
        if (_consecutiveSelectedStatic(state.history, yesterday, t.id) >= 2) t.id,
    };

    final drawPool =
        pool.map((t) => t.id).where((id) => !excluded.contains(id)).toList();
    final ids = _pick(drawPool, dailyCount);

    final history = [
      ...state.history,
      DailyRecord(date: today, taskIds: ids, updatedAt: _now()),
    ];
    final stats = computeStats(history, pool);
    return state.copyWith(history: history, taskStats: stats);
  }

  /// 反悔重抽当天结果：移除当天记录后，基于之前历史重新抽取并标记 [DailyRecord.isRerolled]。
  ///
  /// [currentWeek] 为当前 ISO 周序号；若 [state.lastRerollWeek] 与之相同说明本周
  /// 反悔次数已用完，返回 null。当天未抽签也返回 null。反悔会正确重算 taskStats
  /// 与「连续排除」的新结果。
  AppState? rerollToday(AppState state, String today, int currentWeek) {
    if (state.lastRerollWeek == currentWeek) return null;
    if (!_isDrawn(state, today)) return null;

    // 移除当天记录，回到「当天未抽」状态，再走一次常规抽取。
    final withoutToday = state.copyWith(
      history: state.history.where((r) => r.date != today).toList(),
    );
    final redrawn = drawForDay(withoutToday, today);
    final now = _now();

    final history = [
      for (final r in redrawn.history)
        r.date == today
            ? r.copyWith(isRerolled: true, updatedAt: now)
            : r,
    ];
    return redrawn.copyWith(history: history, lastRerollWeek: currentWeek);
  }

  /// 从 [pool] 随机取 [count] 个不重复项；池数量不足时全取。
  List<String> _pick(List<String> pool, int count) {
    final list = [...pool]..shuffle(_random);
    return list.take(count).toList();
  }

  /// 解析任务池：用户自定义列表优先，空则回退默认种子。
  static List<Task> _resolveTasks(List<Task> tasks) {
    if (tasks.isNotEmpty) return tasks;
    return Task.seed;
  }

  bool _isDrawn(AppState state, String today) {
    for (final r in state.history) {
      if (r.date == today) return true;
    }
    return false;
  }

  /// 基于历史重算每个任务的统计：最近一次被抽日期 + 该日期的连续抽中天数。
  ///
  /// [tasks] 决定要统计哪些任务（与 AppState.tasks 保持一致）。
  static List<TaskStats> computeStats(
      List<DailyRecord> history, List<Task> tasks) {
    final pool = _resolveTasks(tasks);
    final sorted = [...history]..sort((a, b) => b.date.compareTo(a.date));
    return [
      for (final t in pool)
        () {
          for (final r in sorted) {
            if (r.taskIds.contains(t.id)) {
              return TaskStats(
                taskId: t.id,
                lastSelectedDate: r.date,
                streak: _consecutiveSelectedStatic(history, r.date, t.id),
              );
            }
          }
          return TaskStats(taskId: t.id);
        }(),
    ];
  }

  /// 该任务在 [date]（含当天）往前连续被抽中的天数。
  static int _consecutiveSelectedStatic(
      List<DailyRecord> history, String date, String taskId) {
    var n = 0;
    var d = date;
    while (_isSelectedOnStatic(history, d, taskId)) {
      n++;
      d = yesterdayOf(d);
    }
    return n;
  }

  static bool _isSelectedOnStatic(
      List<DailyRecord> history, String date, String taskId) {
    for (final r in history) {
      if (r.date == date) return r.taskIds.contains(taskId);
    }
    return false;
  }
}
