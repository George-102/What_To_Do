import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:today_do_what/main.dart';
import 'package:today_do_what/models/app_state.dart';
import 'package:today_do_what/models/daily_record.dart';
import 'package:today_do_what/providers/app_provider.dart';

void main() {
  testWidgets('应用启动并显示四个底部导航 Tab', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppProvider(),
        child: const TodayDoWhatApp(),
      ),
    );

    expect(find.text('今天，做点什么？'), findsOneWidget);
    expect(find.text('今日'), findsOneWidget);
    expect(find.text('历史'), findsOneWidget);
    expect(find.text('奖励'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('历史页展示最近记录与打卡状态', (tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AppProvider(
          now: () => DateTime(2026, 10, 7),
          initial: const AppState(
            history: [
              DailyRecord(
                date: '2026-10-07',
                taskIds: ['kaoyan', 'reading'],
                isCheckedIn: true,
              ),
              DailyRecord(
                date: '2026-10-06',
                taskIds: ['workout'],
                isCheckedIn: false,
              ),
            ],
          ),
        ),
        child: const TodayDoWhatApp(),
      ),
    );

    // 切到历史 Tab。
    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();

    expect(find.text('最近一周'), findsOneWidget);
    expect(find.text('2026-10-07'), findsOneWidget);
    expect(find.text('已打卡'), findsNothing);
    expect(find.text('已完成'), findsOneWidget);
    expect(find.text('2026-10-06'), findsOneWidget);
    expect(find.text('未打卡'), findsOneWidget);
  });
}