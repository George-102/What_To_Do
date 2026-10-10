import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

/// 设备级信息与同步配置的持久化。
///
/// 这些配置不跟随 AppState 同步（deviceId 每台设备唯一，syncCode 是绑定键），
/// 因此独立存储在 SharedPreferences 中。
class DeviceInfo {
  DeviceInfo(this._prefs);

  final SharedPreferences _prefs;

  static const String _kDeviceId = 'device_id';
  static const String _kSyncCode = 'sync_code';

  /// 获取或生成本设备唯一 ID（首次启动时生成一个 UUID 样式的随机串）。
  String get deviceId {
    final existing = _prefs.getString(_kDeviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _generateDeviceId();
    _prefs.setString(_kDeviceId, generated);
    return generated;
  }

  /// 获取当前绑定的同步码；未绑定时返回 null。
  String? get syncCode => _prefs.getString(_kSyncCode);

  /// 绑定或更新同步码。
  Future<void> setSyncCode(String code) async {
    await _prefs.setString(_kSyncCode, code);
  }

  /// 清除同步绑定。
  Future<void> clearSyncCode() async {
    await _prefs.remove(_kSyncCode);
  }

  /// 生成一个简短的随机设备 ID。
  static String _generateDeviceId() {
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return 'dev-${now.substring(now.length - 8)}';
  }
}
