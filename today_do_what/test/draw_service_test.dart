import 'package:flutter_test/flutter_test.dart';
import 'package:today_do_what/models/app_state.dart';
import 'package:today_do_what/models/daily_record.dart';
import 'package:today_do_what/services/date_util.dart';
import 'package:today_do_what/services/draw_service.dart';

void main() {
  test('每次返回 3 个不同任务 id', () {
    final draw = DrawService();
    final res = draw.drawIds();
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
}