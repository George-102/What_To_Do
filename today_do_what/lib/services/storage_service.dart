import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_state.dart';
import '../models/coin_log.dart';
import '../models/daily_record.dart';
import 'date_util.dart';

/// 本地持久化：把整个 [AppState] 序列化为 JSON 存进 shared_preferences。
///
/// 仅负责「读写」，天数的裁剪（历史保留最近 7 天）由静态方法 [prune] 负责。
class StorageService {
  /// shared_preferences 中保存应用状态的 key。
  static const String key = 'app_state_v1';

  /// 保留最近 N 天（含今天）的历史与流水。
  static const int historyRetainDays = 7;

  /// 从本地读取并反序列化 AppState；没有存档时返回 null。
  Future<AppState?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return null;
    return AppState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// 把 AppState 序列化并写回本地。
  Future<void> save(AppState state) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, jsonEncode(state.toJson()));
  }

  /// 裁剪出最近 7 天（含 [today]）的历史与金币流水，返回副本，不改动原状态。
  static AppState prune(AppState state, String today) {
    final cutoff = subtractDays(today, historyRetainDays - 1);
    final history = state.history
        .where((DailyRecord r) => r.date.compareTo(cutoff) >= 0)
        .toList();
    final coinLog = state.coinLog
        .where((CoinLog l) => l.date.compareTo(cutoff) >= 0)
        .toList();
    return state.copyWith(history: history, coinLog: coinLog);
  }
}