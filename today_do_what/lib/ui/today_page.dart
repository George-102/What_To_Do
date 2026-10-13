import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/daily_record.dart';
import '../models/task.dart';
import '../providers/app_provider.dart';
import '../services/draw_service.dart';
import 'app_colors.dart';

/// 今日页：抽签、查看当天任务、打卡的核心页面。
class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> with TickerProviderStateMixin {
  /// 当前是否在播放抽卡动画中。
  bool _isAnimating = false;

  /// 卡片动画控制器（每张依次翻转揭晓；数量随当天任务数变化，默认 3 张）。
  late List<AnimationController> _flipControllers;
  late List<Animation<double>> _flipAnimations;

  @override
  void initState() {
    super.initState();
    _flipControllers = _buildControllers(DrawService.dailyCount);
    _flipAnimations = _flipControllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeInOut))
        .toList();
  }

  List<AnimationController> _buildControllers(int count) => List.generate(
        count,
        (_) => AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 500),
        ),
      );

  /// 按当天任务数重建动画控制器（必抽任务超过 3 个时卡片数会大于 3）。
  void _rebuildControllers(int count) {
    for (final c in _flipControllers) {
      c.dispose();
    }
    _flipControllers = _buildControllers(count);
    _flipAnimations = _flipControllers
        .map((c) => CurvedAnimation(parent: c, curve: Curves.easeInOut))
        .toList();
  }

  @override
  void dispose() {
    for (final c in _flipControllers) {
      c.dispose();
    }
    super.dispose();
  }

  /// 点击抽奖后，先执行 provider.drawToday（数据立即落地），
  /// 然后按当天实际任务数依次启动翻牌动画。
  Future<void> _onDraw() async {
    if (_isAnimating) return;

    final provider = context.read<AppProvider>();
    provider.drawToday();

    final todayRec = _recordOn(provider.state.history, provider.todayString);
    final count = todayRec == null || todayRec.taskIds.isEmpty
        ? DrawService.dailyCount
        : todayRec.taskIds.length;

    setState(() {
      _isAnimating = true;
      if (count != _flipControllers.length) {
        _rebuildControllers(count);
      }
    });

    // 依次翻牌：每张间隔 350ms，翻牌动画 500ms
    for (var i = 0; i < _flipControllers.length; i++) {
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      await _flipControllers[i].forward();
    }

    if (!mounted) return;
    // 动画全部播放完毕，再给一点时间让用户看到最后一张揭晓
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() {
      _isAnimating = false;
      // 重置动画控制器，下一次可以重新播放
      for (final c in _flipControllers) {
        c.reset();
      }
    });
  }

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
              child: _isAnimating
                  ? _DrawAnimation(animations: _flipAnimations)
                  : todayRec == null
                      ? _DrawEmpty(onDraw: _onDraw)
                      : _TaskList(
                          taskIds: todayRec.taskIds,
                          isCheckedIn: todayRec.isCheckedIn,
                          canReroll: provider.canReroll,
                          onCheckIn: provider.checkIn,
                          onReroll: () => _confirmReroll(context, provider),
                          tasks: provider.currentTasks,
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

/// 抽卡动画：N 张背面朝下的卡片（N = 当天任务数），依次翻转显示结果。
///
/// 动画播放期间 provider.drawToday 已经执行完毕，state 中有真实的
/// [AppState.history] 数据，但动画层自行根据 AnimationController 状态
/// 决定显示"背面"还是"正面"（正面内容从 provider 实时读取）。
class _DrawAnimation extends StatelessWidget {
  const _DrawAnimation({required this.animations});

  final List<Animation<double>> animations;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppProvider>();
    final todayRec = _TodayPageState._recordOn(
      provider.state.history,
      provider.todayString,
    );
    final taskIds = todayRec?.taskIds ?? const [];

    return Column(
      children: [
        for (var i = 0; i < animations.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          _FlipCard(
            animation: animations[i],
            task: i < taskIds.length
                ? Task.byId(taskIds[i], provider.currentTasks)
                : null,
            order: i + 1,
          ),
        ],
        const SizedBox(height: 16),
        Text(
          '正在揭晓今天的幸运任务...',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

/// 单张翻牌动画 widget。
///
/// 背面显示一个问号，正面显示真实任务内容。
/// 动画值从 0→1 时，卡片先做 Y 轴 90° 旋转（看起来翻走了），
/// 再做剩余 90° 旋转（翻过来显示正面）。
class _FlipCard extends StatelessWidget {
  const _FlipCard({
    required this.animation,
    required this.task,
    required this.order,
  });

  final Animation<double> animation;
  final Task? task;
  final int order;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        // 用动画值决定显示正面还是背面（0.5 是翻到一半的切换点）
        final showFront = animation.value > 0.5;
        // 旋转角度：0° → 90° → 180°
        final angle = animation.value * 3.14159;

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.rotationY(angle),
          child: showFront
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(3.14159),
                  child: _buildFront(),
                )
              : _buildBack(),
        );
      },
    );
  }

  Widget _buildBack() {
    return Container(
      width: double.infinity,
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: const Center(
        child: Text(
          '?',
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildFront() {
    return _TaskCard(
      order: order,
      task: task,
      done: false,
    );
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
    required this.tasks,
  });

  final List<String> taskIds;
  final bool isCheckedIn;
  final bool canReroll;
  final VoidCallback onCheckIn;
  final VoidCallback onReroll;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < taskIds.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _TaskCard(
              order: i + 1,
              task: Task.byId(taskIds[i], tasks),
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
