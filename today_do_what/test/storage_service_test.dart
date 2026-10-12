import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:today_do_what/models/app_state.dart';
import 'package:today_do_what/models/daily_record.dart';
import 'package:today_do_what/services/date_util.dart';
import 'package:today_do_what/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  DailyRecord recordOn(String date) =>
      DailyRecord(date: date, taskIds: const ['a', 'b', 'c']);

  test('无存档时 load 返回 null', () async {
    final storage = StorageService();
    expect(await storage.load(), isNull);
  });

  test('save / load 能完整还原状态', () async {
    final storage = StorageService();
    final state = AppState(
      coinBalance: 50,
      consecutiveCheckInDays: 3,
      lastCheckInDate: '2026-10-07',
      history: [recordOn('2026-10-07')],
      taskStats: const [],
    );
    await storage.save(state);

    final loaded = await storage.load();
    expect(loaded, isNotNull);
    expect(loaded!.coinBalance, 50);
    expect(loaded.consecutiveCheckInDays, 3);
    expect(loaded.lastCheckInDate, '2026-10-07');
    expect(loaded.history.single.taskIds, ['a', 'b', 'c']);
  });

  test('prune 只保留最近 365 天', () {
    const today = '2026-10-07';
    final state = AppState(
      history: [
        for (var i = 400; i >= 0; i--) recordOn(subtractDays(today, i)),
      ],
    );

    final pruned = StorageService.prune(state, today);

    expect(pruned.history.length, 365);
    expect(pruned.history.first.date, subtractDays(today, 364));
    expect(pruned.history.last.date, today);
  });
}