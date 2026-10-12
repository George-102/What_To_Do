import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/task.dart';
import '../providers/app_provider.dart';
import '../services/supabase_sync_service.dart';
import 'app_colors.dart';

/// 设置页：同步码管理 + 手动同步 + 状态显示。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _codeController = TextEditingController();
  final _newTaskController = TextEditingController();
  final _newHintController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    _newTaskController.dispose();
    _newHintController.dispose();
    super.dispose();
  }

  /// 生成一个随机同步码（6 位大写字母 + 数字）。
  String _generateSyncCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(rand.nextInt(chars.length))),
    );
  }

  /// 绑定同步码。
  Future<void> _bindSyncCode() async {
    final provider = context.read<AppProvider>();
    final deviceInfo = provider.deviceInfo;
    if (deviceInfo == null) return;

    final code = _codeController.text.trim().toUpperCase();
    if (code.isEmpty) {
      _showSnack('请输入同步码');
      return;
    }

    setState(() => _isSubmitting = true);
    await deviceInfo.setSyncCode(code);

    final service = SupabaseSyncService(
      syncCode: code,
      client: Supabase.instance.client,
    );
    provider.bindSyncService(service);

    setState(() => _isSubmitting = false);
    if (mounted) {
      _showSnack('已绑定同步码：$code');
    }
  }

  /// 清除同步绑定。
  Future<void> _clearSyncCode() async {
    final provider = context.read<AppProvider>();
    final deviceInfo = provider.deviceInfo;
    if (deviceInfo == null) return;

    await deviceInfo.clearSyncCode();
    provider.unbindSyncService();
    _codeController.clear();
    _showSnack('已清除同步绑定');
  }

  Future<void> _manualSync() async {
    final provider = context.read<AppProvider>();
    if (provider.syncService == null) {
      _showSnack('请先绑定同步码');
      return;
    }
    final ok = await provider.syncNow();
    if (mounted) {
      _showSnack(ok ? '同步成功 ✅' : '同步失败 ❌');
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  /// 添加自定义任务（名称 + 可选提示语）。
  void _addTask() {
    final name = _newTaskController.text.trim();
    final hint = _newHintController.text.trim();
    if (name.isEmpty) {
      _showSnack('请输入任务名');
      return;
    }
    final provider = context.read<AppProvider>();
    final ok = provider.addTask(name: name, hint: hint);
    if (ok) {
      _newTaskController.clear();
      _newHintController.clear();
      _showSnack('已添加「$name」');
    } else {
      _showSnack('添加失败，请检查名称');
    }
  }

  /// 确认删除任务。
  Future<void> _confirmDeleteTask(Task task) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除任务'),
        content: Text('确定删除「${task.name}」吗？历史记录不受影响。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<AppProvider>().removeTask(task.id);
      _showSnack('已删除「${task.name}」');
    }
  }

  /// 格式化上次同步时间。
  String _formatTime(DateTime? t) {
    if (t == null) return '从未同步';
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inSeconds < 5) return '刚刚';
    if (diff.inMinutes < 1) return '${diff.inSeconds} 秒前';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final deviceInfo = provider.deviceInfo;
    final boundCode = deviceInfo?.syncCode;
    final synced = provider.syncService != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 同步状态卡片
          _StatusCard(
            synced: synced,
            syncCode: boundCode,
            lastSyncTime: _formatTime(provider.lastSyncTime),
            isSyncing: provider.isSyncing,
            error: provider.lastSyncError,
          ),
          const SizedBox(height: 20),

          // 同步码绑定
          Card(
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('同步码绑定',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    '两台设备输入同一个同步码就能互相同步数据。',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      hintText: synced ? boundCode : '输入或生成同步码',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _isSubmitting
                              ? null
                              : () {
                                  _codeController.text = _generateSyncCode();
                                },
                          icon: const Icon(Icons.auto_awesome, size: 18),
                          label: const Text('生成'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: BorderSide(color: AppColors.primary),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _bindSyncCode,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(_isSubmitting ? '绑定中...' : '绑定'),
                        ),
                      ),
                    ],
                  ),
                  if (synced) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _clearSyncCode,
                      icon: const Icon(Icons.link_off, size: 18),
                      label: const Text('清除同步绑定'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 手动同步按钮
          if (synced)
            Card(
              color: AppColors.surface,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '上次同步：${_formatTime(provider.lastSyncTime)}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          if (provider.lastSyncError != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '错误：${provider.lastSyncError}',
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: provider.isSyncing ? null : _manualSync,
                      icon: provider.isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync, size: 18),
                      label: Text(provider.isSyncing ? '同步中...' : '立即同步'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),

          // 任务管理
          Card(
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('任务管理',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    '自定义每天可能抽到的任务，删除后历史记录不受影响。',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newTaskController,
                          decoration: InputDecoration(
                            hintText: '输入新任务名',
                            hintStyle: TextStyle(color: AppColors.textSecondary),
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          onSubmitted: (_) => _addTask(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _addTask,
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('添加'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _newHintController,
                    decoration: InputDecoration(
                      hintText: '任务描述（选填，比如"背一页单词"）',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onSubmitted: (_) => _addTask(),
                  ),
                  const SizedBox(height: 12),
                  Consumer<AppProvider>(
                    builder: (context, provider, _) {
                      final tasks = provider.currentTasks;
                      return Column(
                        children: [
                          for (var i = 0; i < tasks.length; i++) ...[
                            if (i > 0) const SizedBox(height: 4),
                            _TaskRow(
                              task: tasks[i],
                              onDelete: () => _confirmDeleteTask(tasks[i]),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 关于信息
          Card(
            color: AppColors.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('关于',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  const SizedBox(height: 8),
                  _InfoRow(label: '设备 ID', value: deviceInfo?.deviceId ?? '-'),
                  _InfoRow(label: '数据存储', value: synced ? 'Supabase 云端 + 本地' : '仅本地'),
                  _InfoRow(label: '版本', value: '1.0.0'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.synced,
    required this.syncCode,
    required this.lastSyncTime,
    required this.isSyncing,
    required this.error,
  });

  final bool synced;
  final String? syncCode;
  final String lastSyncTime;
  final bool isSyncing;
  final String? error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: synced ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: synced ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            synced ? Icons.cloud_sync : Icons.cloud_off,
            color: synced ? Colors.green : Colors.grey,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  synced ? '云同步已开启' : '云同步未开启',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: synced ? Colors.green : Colors.grey,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  synced
                      ? '同步码：$syncCode · 上次：$lastSyncTime'
                      : '绑定同步码后即可多端同步',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (isSyncing)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task, required this.onDelete});

  final Task task;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                if (task.hint.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    task.hint,
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
            style: IconButton.styleFrom(
              foregroundColor: Colors.redAccent,
            ),
          ),
        ],
      ),
    );
  }
}
