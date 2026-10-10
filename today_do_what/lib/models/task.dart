/// 任务模型与固定的任务池。
class Task {
  const Task({required this.id, required this.name, required this.hint});

  final String id;
  final String name;

  /// 一句简短提示语，仅作视觉点缀，不影响逻辑。
  final String hint;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'hint': hint};

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        name: json['name'] as String,
        hint: json['hint'] as String,
      );

  /// 固定任务池。
  static const List<Task> pool = [
    Task(id: 'kaoyan', name: '考研', hint: '背一页单词，也算数。'),
    Task(id: 'intern', name: '实习工作', hint: '投一份简历，或推进一步。'),
    Task(id: 'reading', name: '阅读', hint: '读 10 页就好。'),
    Task(id: 'course', name: '大学课程', hint: '听懂一节课，或补一页笔记。'),
    Task(id: 'workout', name: '锻炼', hint: '动 20 分钟。'),
    Task(id: 'startup', name: '创业', hint: '写下一个想法。'),
    Task(id: 'research', name: '项目研究', hint: '推进一个小目标。'),
    Task(id: 'vocab', name: '英语背单词', hint: '背 20 个词，顺手复习昨天的。'),
  ];

  static Task? byId(String id) {
    for (final t in pool) {
      if (t.id == id) return t;
    }
    return null;
  }
}