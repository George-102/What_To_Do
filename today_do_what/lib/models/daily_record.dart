/// 某一天的记录：当天抽中的任务 + 是否打卡。
class DailyRecord {
  const DailyRecord({
    required this.date,
    required this.taskIds,
    this.isCheckedIn = false,
    this.checkedInAt,
    this.isRerolled = false,
    this.updatedAt,
  });

  /// 本地日期字符串，格式 yyyy-MM-dd。
  final String date;

  /// 当天抽中的 3 个任务 id。
  final List<String> taskIds;

  final bool isCheckedIn;
  final DateTime? checkedInAt;

  /// 是否为反悔后重新抽取的结果。
  final bool isRerolled;

  /// 这条记录最后被修改的时间戳（抽签/反悔/打卡）。
  final DateTime? updatedAt;

  DailyRecord copyWith({
    List<String>? taskIds,
    bool? isCheckedIn,
    DateTime? checkedInAt,
    bool? isRerolled,
    DateTime? updatedAt,
  }) {
    return DailyRecord(
      date: date,
      taskIds: taskIds ?? this.taskIds,
      isCheckedIn: isCheckedIn ?? this.isCheckedIn,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      isRerolled: isRerolled ?? this.isRerolled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'taskIds': taskIds,
        'isCheckedIn': isCheckedIn,
        'checkedInAt': checkedInAt?.toIso8601String(),
        'isRerolled': isRerolled,
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory DailyRecord.fromJson(Map<String, dynamic> json) => DailyRecord(
        date: json['date'] as String,
        taskIds: (json['taskIds'] as List<dynamic>).cast<String>(),
        isCheckedIn: json['isCheckedIn'] as bool? ?? false,
        checkedInAt: json['checkedInAt'] == null
            ? null
            : DateTime.parse(json['checkedInAt'] as String),
        isRerolled: json['isRerolled'] as bool? ?? false,
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.parse(json['updatedAt'] as String),
      );
}