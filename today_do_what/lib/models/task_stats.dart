/// 单个任务的连续抽中记录，用于「连续排除规则」。
class TaskStats {
  const TaskStats({required this.taskId, this.streak = 0, this.lastSelectedDate});

  final String taskId;

  /// 连续被抽中的天数。
  final int streak;

  /// 最近一次被抽中的日期（yyyy-MM-dd），与 streak 配套使用。
  final String? lastSelectedDate;

  TaskStats copyWith({int? streak, String? lastSelectedDate}) {
    return TaskStats(
      taskId: taskId,
      streak: streak ?? this.streak,
      lastSelectedDate: lastSelectedDate ?? this.lastSelectedDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'taskId': taskId,
        'streak': streak,
        'lastSelectedDate': lastSelectedDate,
      };

  factory TaskStats.fromJson(Map<String, dynamic> json) => TaskStats(
        taskId: json['taskId'] as String,
        streak: json['streak'] as int? ?? 0,
        lastSelectedDate: json['lastSelectedDate'] as String?,
      );
}