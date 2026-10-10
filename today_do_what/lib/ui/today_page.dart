import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily_record.dart';
import '../models/task.dart';
import '../providers/app_provider.dart';
import 'app_colors.dart';

/// 今日页：抽签、查看当天任务、打卡的核心页面。
class TodayPage extends StatelessWidget {
  const TodayPage({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final state = provider.state;
    final todayRec = _recordOn(state.history, provider.todayString);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              '今天，做点什么？',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            _StatusBar(
              coin: state.coinBalance,
              streak: state.consecutiveCheckInDays,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: todayRec == null
                  ? _DrawEmpty(onDraw: provider.drawToday)
                  : _TaskList(
                      taskIds: todayRec.taskIds,
                      isCheckedIn: todayRec.isCheckedIn,
                      canReroll: provider.canReroll,
                      onCheckIn: provider.checkIn,
                      onReroll: () => _confirmReroll(context, provider),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  static DailyRecord? _recordOn(List<DailyRecord> history, String date) {
    for (final r in history) {
      if (r.date == date) return r;
    }
    return null;
  }
}

/// 未抽签状态：居中大按钮。
class _DrawEmpty extends StatelessWidget {
  const _DrawEmpty({required this.onDraw});

  final VoidCallback onDraw;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton(
        onPressed: onDraw,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        child: const Text('开始抽奖'),
      ),
    );
  }
}

/// 已抽签状态：当天 3 个任务卡片。
class _TaskList extends StatelessWidget {
  const _TaskList({
    required this.taskIds,
    required this.isCheckedIn,
    required this.canReroll,
    required this.onCheckIn,
    required this.onReroll,
  });

  final List<String> taskIds;
  final bool isCheckedIn;
  final bool canReroll;
  final VoidCallback onCheckIn;
  final VoidCallback onReroll;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < taskIds.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TaskCard(
              order: i + 1,
              task: Task.byId(taskIds[i]),
              done: isCheckedIn,
            ),
          ),
        if (isCheckedIn)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 20),
                SizedBox(width: 6),
                Text(
                  '今天也坚持住了，真有你的',
                  style: TextStyle(fontSize: 14, color: AppColors.success),
                ),
              ],
            ),
          )
        else ...[
          const SizedBox(height: 4),
          const Text(
            '今天的结果，明天再见分晓',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onCheckIn,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              child: const Text('完成打卡'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: canReroll ? onReroll : null,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              child: Text(canReroll ? '不满意，反悔重抽（每周 1 次）' : '本周反悔次数已用完'),
            ),
          ),
        ],
      ],
    );
  }
}

/// 弹二次确认后执行反悔重抽。
Future<void> _confirmReroll(BuildContext context, AppProvider provider) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('反悔重抽'),
      content: const Text('会用掉本周唯一一次反悔机会，确定吗？'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('再想想'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('确定重抽'),
        ),
      ],
    ),
  );
  if (ok != true) return;
  final success = provider.rerollToday();
  if (!success && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('本周次数已用完，无法反悔')),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.order, required this.task, this.done = false});

  final int order;
  final Task? task;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final task = this.task;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$order',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task?.name ?? '未知任务',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                if (task != null && task.hint.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    task.hint,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (done) ...[
            const SizedBox(width: 12),
            const Icon(Icons.check_circle, color: AppColors.success, size: 22),
          ],
        ],
      ),
    );
  }
}

/// 顶部状态条：金币余额 + 连续打卡天数。
class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.coin, required this.streak});

  final int coin;
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _StatusItem(
          value: '$coin',
          label: '金币余额',
          valueColor: AppColors.coin,
        ),
        _StatusItem(
          value: '$streak',
          label: '连续打卡（天）',
          valueColor: AppColors.primary,
        ),
      ],
    );
  }
}

class _StatusItem extends StatelessWidget {
  const _StatusItem({
    required this.value,
    required this.label,
    required this.valueColor,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: valueColor,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}