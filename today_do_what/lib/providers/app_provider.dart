import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/app_state.dart';
import '../models/coin_log.dart';
import '../models/reward.dart';
import '../models/task.dart';
import '../models/task_stats.dart';
import '../services/coin_service.dart';
import '../services/date_util.dart';
import '../services/device_info.dart';
import '../services/draw_service.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';

/// 全局状态桥接层，UI 通过它读写 [AppState]。
///
/// 进程内只会有一个 AppProvider（由 root 注入）。启动时调用 [init] 从本地恢复
/// 存档；之后每次 [replace] 都会裁剪历史（最近 7 天）并异步写回本地。
///
/// 如果绑定了 [SyncService]，关键操作后会自动推送同步；也可手动 [syncNow]。
class AppProvider extends ChangeNotifier {
  AppProvider({
    DateTime Function()? now,
    this.storage,
    this.deviceInfo,
    this.syncService,
    DrawService? drawService,
    CoinService? coinService,
    AppState? initial,
  })  : _now = now ?? DateTime.now,
        drawService = drawService ?? DrawService(now: now),
        coinService = coinService ?? const CoinService(),
        _state = initial ?? const AppState();

  final DateTime Function() _now;

  /// 本地持久化服务；为空表示不持久化（仅用于测试）。
  final StorageService? storage;

  /// 设备级信息（deviceId、syncCode）；为空表示无设备级配置。
  final DeviceInfo? deviceInfo;

  /// 同步服务（SupabaseSyncService 或 mock）；为空表示不启用云同步。
  SyncService? syncService;

  /// 抽奖服务。
  final DrawService drawService;

  /// 金币服务。
  final CoinService coinService;
  AppState _state;

  AppState get state => _state;

  /// 是否正在同步中（UI 可显示 loading 状态）。
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// 最近一次同步的时间戳（null 表示从未同步）。
  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// 最近一次同步的错误信息（null 表示成功或未尝试）。
  String? _lastSyncError;
  String? get lastSyncError => _lastSyncError;

  /// 本设备的唯一标识（由 DeviceInfo 提供，空则用默认值）。
  String get _deviceId => deviceInfo?.deviceId ?? 'unknown';

  /// 今天的本地日期字符串（yyyy-MM-dd）。
  String get todayString {
    final n = _now();
    final y = n.year.toString().padLeft(4, '0');
    final m = n.month.toString().padLeft(2, '0');
    final d = n.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// 启动时从本地恢复状态，然后尝试从云端拉取合并。
  Future<void> init() async {
    final loaded = await storage?.load();
    if (loaded != null) {
      _state = StorageService.prune(loaded, todayString);
      notifyListeners();
    }
    // 如果有 syncService，自动从云端拉取一次
    if (syncService != null) {
      unawaited(syncNow());
    }
  }

  /// 绑定一个 SyncService（运行时设置 syncCode 后调用）。
  void bindSyncService(SyncService service) {
    syncService = service;
    unawaited(syncNow());
  }

  /// 解绑 SyncService（设置页清除 syncCode 后调用）。
  void unbindSyncService() {
    syncService = null;
    _lastSyncTime = null;
    _lastSyncError = null;
    notifyListeners();
  }

  /// 手动触发一次完整同步（拉取→合并→推送）。
  Future<bool> syncNow() async {
    final service = syncService;
    if (service == null) return false;

    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();

    try {
      final merged = await service.sync(_state);
      // 合并后如果有新数据（远端更新覆盖了本地），更新本地
      if (merged != _state) {
        _state = StorageService.prune(merged, todayString);
        final s = storage;
        if (s != null) unawaited(s.save(_state));
      }
      _lastSyncTime = _now();
      _isSyncing = false;
      notifyListeners();
      return true;
    } catch (e) {
      _lastSyncError = e.toString();
      _isSyncing = false;
      notifyListeners();
      return false;
    }
  }

  /// 内部：关键操作后异步推送到云端（不等结果，不阻塞 UI）。
  void _autoPush() {
    final service = syncService;
    if (service == null) return;
    unawaited(service.upload(_state));
  }

  /// 用新的 [AppState] 整体替换：先裁剪历史，更新 updatedAt，再异步持久化，最后广播变更。
  void replace(AppState next) {
    final pruned = StorageService.prune(next, todayString);
    _state = pruned.copyWith(updatedAt: _now());
    final s = storage;
    if (s != null) {
      unawaited(s.save(_state));
    }
    notifyListeners();
    _autoPush();
  }

  /// 抽取今天的任务（当天已抽则结果固定不变）。
  void drawToday() {
    replace(drawService.drawForDay(_state, todayString));
  }

  /// 标记今天整体打卡，并发放金币（幂等：已打卡或今天未抽则不操作、不发币）。
  ///
  /// 金币 = 固定 10 + 全勤加成（连续第 3/5/7 天分别 +5/+10/+15）。断签时连续
  /// 天数从 1 重新计。本次入账会写入 coinLog 流水。
  void checkIn() {
    final today = todayString;
    final idx = _state.history.indexWhere((r) => r.date == today);
    if (idx < 0) return;
    final rec = _state.history[idx];
    if (rec.isCheckedIn) return;
    final now = _now();

    final history = [..._state.history];
    history[idx] = rec.copyWith(isCheckedIn: true, checkedInAt: now, updatedAt: now);

    final result = coinService.checkIn(
      checkedYesterday: _state.lastCheckInDate == yesterdayOf(today),
      consecutiveCheckInDays: _state.consecutiveCheckInDays,
    );
    final deviceTag = '$_deviceId-${now.microsecondsSinceEpoch}';
    final logs = <CoinLog>[
      CoinLog(
        id: '$deviceTag-base',
        date: today,
        type: 'earn',
        amount: CoinService.baseCoin,
        note: '每日打卡',
        createdAt: now,
      ),
      if (result.bonus > 0)
        CoinLog(
          id: '$deviceTag-bonus',
          date: today,
          type: 'earn',
          amount: result.bonus,
          note: '全勤 ${result.streak} 天奖励',
          createdAt: now,
        ),
    ];

    replace(_state.copyWith(
      history: history,
      coinBalance: _state.coinBalance + result.earn,
      consecutiveCheckInDays: result.streak,
      lastCheckInDate: today,
      coinLog: [..._state.coinLog, ...logs],
    ));
  }

  /// 添加一个自定义奖励（名称 + 兑换价格金币）。
  void addReward({required String name, required int price}) {
    final id = 'r-$_deviceId-${_now().microsecondsSinceEpoch}';
    replace(_state.copyWith(
      rewards: [..._state.rewards, Reward(id: id, name: name, price: price)],
    ));
  }

  /// 兑换奖励。成功返回 true；余额不足或奖励不存在返回 false（不扣币、不记流水）。
  bool redeemReward(String rewardId) {
    final reward = _state.rewards.where((r) => r.id == rewardId).firstOrNull;
    if (reward == null) return false;
    if (_state.coinBalance < reward.price) return false;

    final now = _now();
    final log = CoinLog(
      id: '$_deviceId-${now.microsecondsSinceEpoch}-spend',
      date: todayString,
      type: 'spend',
      amount: -reward.price,
      note: reward.name,
      createdAt: now,
    );
    replace(_state.copyWith(
      coinBalance: _state.coinBalance - reward.price,
      coinLog: [..._state.coinLog, log],
    ));
    return true;
  }

  /// 添加一个自定义任务。返回是否成功（名称为空或 id 已存在时返回 false）。
  bool addTask({required String name, String hint = ''}) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;

    final existingIds = _state.tasks.map((t) => t.id).toSet();
    // 生成唯一 id：用户输入的中文名 hash + 时间戳，避免中文直接作为 id
    final idBase = trimmed.replaceAll(RegExp(r'\s+'), '_').toLowerCase();
    var id = idBase.isEmpty ? 'task_${_now().millisecondsSinceEpoch}' : idBase;
    var counter = 1;
    while (existingIds.contains(id)) {
      id = '${idBase}_$counter';
      counter++;
    }

    final task = Task(id: id, name: trimmed, hint: hint.trim());
    replace(_state.copyWith(
      tasks: [..._state.tasks, task],
      taskStats: [
        ..._state.taskStats,
        TaskStats(taskId: id),
      ],
    ));
    return true;
  }

  /// 删除一个任务。已出现在历史记录中的任务仍能解析（回退到 Task.seed 或显示"未知"）。
  void removeTask(String taskId) {
    replace(_state.copyWith(
      tasks: _state.tasks.where((t) => t.id != taskId).toList(),
      taskStats: _state.taskStats.where((s) => s.taskId != taskId).toList(),
    ));
  }

  /// 获取当前任务列表（空则回退默认种子）。
  List<Task> get currentTasks =>
      _state.tasks.isEmpty ? Task.seed : _state.tasks;

  /// 本周是否还有反悔机会（自然周重置，默认本周已用则无）。
  bool get canReroll {
    final week = isoWeek(_now());
    return _state.lastRerollWeek != week;
  }

  /// 反悔重抽当天结果。本周已用或今天未抽返回 false；成功重抽返回 true。
  bool rerollToday() {
    final next = drawService.rerollToday(_state, todayString, isoWeek(_now()));
    if (next == null) return false;
    replace(next);
    return true;
  }
}
