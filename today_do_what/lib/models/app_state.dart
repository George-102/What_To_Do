import 'coin_log.dart';
import 'daily_record.dart';
import 'reward.dart';
import 'task.dart';
import 'task_stats.dart';

/// 应用顶层状态聚合，整个「今天干点啥」的所有数据都保存在这里。
class AppState {
  const AppState({
    this.coinBalance = 0,
    this.consecutiveCheckInDays = 0,
    this.lastCheckInDate,
    this.lastRerollWeek,
    this.history = const [],
    this.taskStats = const [],
    this.tasks = const [],
    this.rewards = const [],
    this.coinLog = const [],
    this.updatedAt,
  });

  final int coinBalance;

  /// 当前连续完成打卡的天数（断签重归零）。
  final int consecutiveCheckInDays;

  /// 最近一次打卡的日期（yyyy-MM-dd）。
  final String? lastCheckInDate;

  /// 最近一次使用反悔所在的 ISO 周序号，用于「每周一次反悔」的判定。
  final int? lastRerollWeek;

  /// 最近 N 天（默认 365）的每日记录。
  final List<DailyRecord> history;

  /// 每个任务的连续抽中统计。
  final List<TaskStats> taskStats;

  /// 用户自定义的任务列表；空时由 DrawService 从 Task.seed 补齐。
  final List<Task> tasks;

  final List<Reward> rewards;

  final List<CoinLog> coinLog;

  /// 这份数据最后一次被修改的时间戳，用于同步时的 last-write-wins 合并。
  final DateTime? updatedAt;

  AppState copyWith({
    int? coinBalance,
    int? consecutiveCheckInDays,
    String? lastCheckInDate,
    int? lastRerollWeek,
    List<DailyRecord>? history,
    List<TaskStats>? taskStats,
    List<Task>? tasks,
    List<Reward>? rewards,
    List<CoinLog>? coinLog,
    DateTime? updatedAt,
  }) {
    return AppState(
      coinBalance: coinBalance ?? this.coinBalance,
      consecutiveCheckInDays:
          consecutiveCheckInDays ?? this.consecutiveCheckInDays,
      lastCheckInDate: lastCheckInDate ?? this.lastCheckInDate,
      lastRerollWeek: lastRerollWeek ?? this.lastRerollWeek,
      history: history ?? this.history,
      taskStats: taskStats ?? this.taskStats,
      tasks: tasks ?? this.tasks,
      rewards: rewards ?? this.rewards,
      coinLog: coinLog ?? this.coinLog,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'coinBalance': coinBalance,
        'consecutiveCheckInDays': consecutiveCheckInDays,
        'lastCheckInDate': lastCheckInDate,
        'lastRerollWeek': lastRerollWeek,
        'history': history.map((e) => e.toJson()).toList(),
        'taskStats': taskStats.map((e) => e.toJson()).toList(),
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'rewards': rewards.map((e) => e.toJson()).toList(),
        'coinLog': coinLog.map((e) => e.toJson()).toList(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory AppState.fromJson(Map<String, dynamic> json) {
    // tasks 向后兼容：老存档没有 tasks 字段时用默认种子注入。
    final tasksList = (json['tasks'] as List<dynamic>? ?? const [])
        .map((e) => Task.fromJson(e as Map<String, dynamic>))
        .toList();
    final tasks = tasksList.isEmpty ? Task.seed : tasksList;

    return AppState(
      coinBalance: json['coinBalance'] as int? ?? 0,
      consecutiveCheckInDays: json['consecutiveCheckInDays'] as int? ?? 0,
      lastCheckInDate: json['lastCheckInDate'] as String?,
      lastRerollWeek: json['lastRerollWeek'] as int?,
      history: (json['history'] as List<dynamic>? ?? const [])
          .map((e) => DailyRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      taskStats: (json['taskStats'] as List<dynamic>? ?? const [])
          .map((e) => TaskStats.fromJson(e as Map<String, dynamic>))
          .toList(),
      tasks: tasks,
      rewards: (json['rewards'] as List<dynamic>? ?? const [])
          .map((e) => Reward.fromJson(e as Map<String, dynamic>))
          .toList(),
      coinLog: (json['coinLog'] as List<dynamic>? ?? const [])
          .map((e) => CoinLog.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
    );
  }
}
