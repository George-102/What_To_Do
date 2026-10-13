import 'package:flutter_test/flutter_test.dart';
import 'package:today_do_what/models/app_state.dart';
import 'package:today_do_what/models/daily_record.dart';
import 'package:today_do_what/models/task.dart';
import 'package:today_do_what/services/date_util.dart';
import 'package:today_do_what/services/draw_service.dart';

void main() {
  test('每次返回 3 个不同任务 id', () {
    final draw = DrawService();
    final res = draw.drawIds(pool: Task.seed);
    expect(res.length, 3);
    expect(res.toSet().length, 3);
  });

  test('当天已抽签后结果不变', () {
    final draw = DrawService();
    final state = const AppState();
    final drawn = draw.drawForDay(state, '2026-10-07');
    expect(drawn.history.length, 1);
    final drawnAgain = draw.drawForDay(drawn, '2026-10-07');
    expect(drawnAgain.history.length, 1);
    expect(drawnAgain.history.first.taskIds, drawn.history.first.taskIds);
  });

  test('不同天可抽不同结果', () {
    final draw = DrawService();
    final state = const AppState();
    final day1 = draw.drawForDay(state, '2026-10-07');
    final day2 = draw.drawForDay(day1, '2026-10-08');
    expect(day2.history.length, 2);
    expect(day2.history[0].date, '2026-10-07');
    expect(day2.history[1].date, '2026-10-08');
  });

  test('连续两天被抽中，第三天从池中排除', () {
    final draw = DrawService();
    final state = AppState(
      history: [
        DailyRecord(date: '2026-10-05', taskIds: ['kaoyan', 'intern', 'reading']),
        DailyRecord(date: '2026-10-06', taskIds: ['kaoyan', 'workout', 'course']),
      ],
    );
    final res = draw.drawForDay(state, '2026-10-07');
    final today = res.history.last;
    expect(today.date, '2026-10-07');
    expect(today.taskIds.length, 3);
    expect(today.taskIds.contains('kaoyan'), isFalse);
  });

  test('重算 taskStats：连续与最近日期正确', () {
    final draw = DrawService();
    final state = AppState(
      history: [
        DailyRecord(date: '2026-10-05', taskIds: ['kaoyan', 'intern', 'reading']),
        DailyRecord(date: '2026-10-06', taskIds: ['kaoyan', 'workout', 'course']),
      ],
    );
    final res = draw.drawForDay(state, '2026-10-07');
    final kaoyan = res.taskStats.firstWhere((s) => s.taskId == 'kaoyan');
    // kaoyan 在 10-05、10-06 连续被抽，10-07 被排除未中签 → streak 停在 2。
    expect(kaoyan.streak, 2);
    expect(kaoyan.lastSelectedDate, '2026-10-06');
  });

  test('反悔重抽：移除当天后重抽并标记 isRerolled 与 lastRerollWeek', () {
    final draw = DrawService();
    final drawn =
        draw.drawForDay(const AppState(), '2026-10-07'); // week 41 (大约)
    final now = DateTime(2026, 10, 7);
    final week = isoWeek(now);
    expect(drawn.history.single.isRerolled, isFalse);

    final rerolled = draw.rerollToday(drawn, '2026-10-07', week);
    expect(rerolled, isNotNull);
    expect(rerolled!.history.single.date, '2026-10-07');
    expect(rerolled.history.single.isRerolled, isTrue);
    expect(rerolled.lastRerollWeek, week);
  });

  test('同一周只能用一次反悔，第二次返回 null', () {
    final draw = DrawService();
    final drawn = draw.drawForDay(const AppState(), '2026-10-07');
    final week = isoWeek(DateTime(2026, 10, 7));
    final first = draw.rerollToday(drawn, '2026-10-07', week);
    expect(first, isNotNull);
    // 第二次在同一周反悔 → null。
    final second = draw.rerollToday(first!, '2026-10-07', week);
    expect(second, isNull);
  });

  test('反悔重抽遵守连续排除规则（kaoyan 连 2 被排除）', () {
    final draw = DrawService();
    // kaoyan 在 10-05、10-06 连续被抽（昨天 streak 已达 2）。
    final state = AppState(
      history: [
        DailyRecord(date: '2026-10-05', taskIds: ['kaoyan', 'intern', 'project']),
        DailyRecord(date: '2026-10-06', taskIds: ['kaoyan', 'workout', 'course']),
      ],
    );
    final todayDrawn = draw.drawForDay(state, '2026-10-07');

    final rerolled = draw.rerollToday(
      todayDrawn,
      '2026-10-07',
      isoWeek(DateTime(2026, 10, 7)),
    );
    expect(rerolled, isNotNull);
    // 重抽后当天结果排除 kaoyan，且天数不变。
    expect(rerolled!.history.last.taskIds.contains('kaoyan'), isFalse);
    expect(rerolled.history.length, 3);
    // stats 重算正确：kaoyan 连续停在 2。
    final kaoyan =
        rerolled.taskStats.firstWhere((s) => s.taskId == 'kaoyan');
    expect(kaoyan.streak, 2);
  });

  test('频率规则：每天任务连续 3 天必抽（绕过连续排除），总数补足 3 个', () {
    final pool = [
      const Task(id: 'daily', name: '每日必做', hint: '', frequency: 1),
      const Task(id: 'a', name: 'A', hint: ''),
      const Task(id: 'b', name: 'B', hint: ''),
      const Task(id: 'c', name: 'C', hint: ''),
      const Task(id: 'd', name: 'D', hint: ''),
    ];
    final draw = DrawService();
    var state = AppState(tasks: pool);
    for (final day in ['2026-10-07', '2026-10-08', '2026-10-09']) {
      state = draw.drawForDay(state, day);
      final rec = state.history.last;
      // 第 3 天时 daily 的 streak 已达 2，连续排除规则本会踢掉它，但必抽优先。
      expect(rec.taskIds.contains('daily'), isTrue, reason: '$day 应必抽 daily');
      expect(rec.taskIds.length, 3, reason: '$day 应为 1 必抽 + 2 随机');
    }
  });

  test('频率规则：每 2 天一次 → 首日必抽，隔天必不抽，第 3 天到期必抽', () {
    final pool = [
      const Task(id: 'alt', name: '隔天任务', hint: '', frequency: 2),
      const Task(id: 'a', name: 'A', hint: ''),
      const Task(id: 'b', name: 'B', hint: ''),
      const Task(id: 'c', name: 'C', hint: ''),
      const Task(id: 'd', name: 'D', hint: ''),
      const Task(id: 'e', name: 'E', hint: ''),
    ];
    final draw = DrawService();
    var state = AppState(tasks: pool);

    state = draw.drawForDay(state, '2026-10-07'); // 从未抽过 → 必抽
    expect(state.history.last.taskIds.contains('alt'), isTrue);

    state = draw.drawForDay(state, '2026-10-08'); // 距上次 1 天 < 2 → 必不抽
    expect(state.history.last.taskIds.contains('alt'), isFalse);

    state = draw.drawForDay(state, '2026-10-09'); // 距上次 2 天 >= 2 → 到期必抽
    expect(state.history.last.taskIds.contains('alt'), isTrue);
    expect(state.history.last.taskIds.length, 3);
  });

  test('频率规则：每 3 天一次 → 抽中后两天不出现，第 3 天到期必抽', () {
    final pool = [
      const Task(id: 'tri', name: '三天任务', hint: '', frequency: 3),
      const Task(id: 'a', name: 'A', hint: ''),
      const Task(id: 'b', name: 'B', hint: ''),
      const Task(id: 'c', name: 'C', hint: ''),
      const Task(id: 'd', name: 'D', hint: ''),
      const Task(id: 'e', name: 'E', hint: ''),
    ];
    final draw = DrawService();
    var state = AppState(tasks: pool);

    state = draw.drawForDay(state, '2026-10-07');
    expect(state.history.last.taskIds.contains('tri'), isTrue);

    state = draw.drawForDay(state, '2026-10-08'); // D=1 < 3
    expect(state.history.last.taskIds.contains('tri'), isFalse);

    state = draw.drawForDay(state, '2026-10-09'); // D=2 < 3
    expect(state.history.last.taskIds.contains('tri'), isFalse);

    state = draw.drawForDay(state, '2026-10-10'); // D=3 >= 3
    expect(state.history.last.taskIds.contains('tri'), isTrue);
  });

  test('频率规则：必抽任务超过 3 个时全部入选，不再随机补足', () {
    final pool = [
      const Task(id: 'd1', name: '每天1', hint: '', frequency: 1),
      const Task(id: 'd2', name: '每天2', hint: '', frequency: 1),
      const Task(id: 'd3', name: '每天3', hint: '', frequency: 1),
      const Task(id: 'd4', name: '每天4', hint: '', frequency: 1),
      const Task(id: 'a', name: 'A', hint: ''),
    ];
    final draw = DrawService();
    final state = draw.drawForDay(AppState(tasks: pool), '2026-10-07');
    final ids = state.history.last.taskIds;
    expect(ids.length, 4);
    expect(ids.toSet().containsAll(['d1', 'd2', 'd3', 'd4']), isTrue);
    expect(ids.contains('a'), isFalse);
  });
}