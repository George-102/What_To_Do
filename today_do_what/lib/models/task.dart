/// 任务模型。任务列表由用户自定义后保存在 [AppState.tasks] 中。
class Task {
  const Task({
    required this.id,
    required this.name,
    this.hint = '',
    this.frequency = 0,
  });

  final String id;
  final String name;

  /// 一句简短提示语，仅作视觉点缀，不影响逻辑。
  final String hint;

  /// 抽取频率：0=不限（随机抽取）、1=每天必抽、n=n 天一次
  /// （每 n 天内必须且仅有一天抽到该任务）。
  final int frequency;

  /// 频率的展示文案。
  String get frequencyLabel {
    switch (frequency) {
      case 0:
        return '不限';
      case 1:
        return '每天';
      default:
        return '每 $frequency 天一次';
    }
  }

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'hint': hint, 'frequency': frequency};

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        name: json['name'] as String,
        hint: json['hint'] as String,
        frequency: json['frequency'] as int? ?? 0,
      );

  /// 默认任务种子（8 个），首次使用或存档为空时注入 AppState.tasks。
  /// 向后兼容：已有历史记录里的 taskId 仍能通过 byId 匹配到这些默认任务。
  static const List<Task> seed = [
    Task(id: 'kaoyan', name: '考研', hint: '背一页单词，也算数。'),
    Task(id: 'intern', name: '实习工作', hint: '投一份简历，或推进一步。'),
    Task(id: 'reading', name: '阅读', hint: '读 10 页就好。'),
    Task(id: 'course', name: '大学课程', hint: '听懂一节课，或补一页笔记。'),
    Task(id: 'workout', name: '锻炼', hint: '动 20 分钟。'),
    Task(id: 'startup', name: '创业', hint: '写下一个想法。'),
    Task(id: 'research', name: '项目研究', hint: '推进一个小目标。'),
    Task(id: 'vocab', name: '英语背单词', hint: '背 20 个词，顺手复习昨天的。'),
  ];

  /// 在给定任务列表中按 id 查找任务；找不到返回 null。
  ///
  /// UI 层传入 AppState.tasks；为空或未找到时回退到 seed 中查找，
  /// 保证老用户历史里的 taskId 始终能解析。
  static Task? byId(String id, [List<Task>? tasks]) {
    final list = tasks ?? seed;
    for (final t in list) {
      if (t.id == id) return t;
    }
    // 回退：在默认种子里找（处理历史记录里的 id 还在但用户删了该任务的情况）
    for (final t in seed) {
      if (t.id == id) return t;
    }
    return null;
  }
}
