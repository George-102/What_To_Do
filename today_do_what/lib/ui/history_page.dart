import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily_record.dart';
import '../models/task.dart';
import '../providers/app_provider.dart';
import 'app_colors.dart';

/// 历史页：展示最近一周每天的任务与打卡状态。
class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<AppProvider>().state.history;
    final tasks = context.watch<AppProvider>().currentTasks;
    // 最新在前。
    final sorted = [...history]..sort((a, b) => b.date.compareTo(a.date));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Text(
              '最近一年',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: sorted.isEmpty
                  ? const Center(
                      child: Text(
                        '还没有记录，先去抽今天吧',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.separated(
                      itemCount: sorted.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) =>
                          _HistoryCard(rec: sorted[i], tasks: tasks),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 单日记录卡片：日期 + 打卡状态 + 当天任务。
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.rec, required this.tasks});

  final DailyRecord rec;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                rec.date,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Row(
                children: [
                  if (rec.isRerolled) ...[
                    const Text(
                      '已反悔',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _StatusChip(isCheckedIn: rec.isCheckedIn),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final id in rec.taskIds)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    Task.byId(id, tasks)?.name ?? '未知',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 打卡状态小标签。
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.isCheckedIn});

  final bool isCheckedIn;

  @override
  Widget build(BuildContext context) {
    final color = isCheckedIn ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCheckedIn ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isCheckedIn ? '已完成' : '未打卡',
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}