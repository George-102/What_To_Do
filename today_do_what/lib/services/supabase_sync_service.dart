import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_state.dart';
import 'sync_merger.dart';
import 'sync_service.dart';

/// 基于 Supabase 的 SyncService 实现。
///
/// 数据存在一张 `sync_data` 表中，每行代表一份同步组的全量状态：
/// ```sql
/// create table sync_data (
///   sync_code text primary key,
///   app_state jsonb not null,
///   updated_at timestamptz not null default now(),
///   device_id text
/// );
/// ```
/// 上传时用 upsert（sync_code 已存在则覆盖，不存在则插入），云端永远只有一条记录。
class SupabaseSyncService extends SyncService {
  SupabaseSyncService({
    required super.syncCode,
    required this.client,
    this.tableName = 'sync_data',
  });

  final SupabaseClient client;
  final String tableName;

  @override
  Future<bool> upload(AppState state) async {
    try {
      await client.from(tableName).upsert({
        'sync_code': syncCode,
        'app_state': state.toJson(),
        // updated_at 不能为 null（列是 not null），空则用当前时间。
        'updated_at': (state.updatedAt ?? DateTime.now()).toIso8601String(),
      });
      return true;
    } catch (e) {
      // 不再静默吞掉：把真实错误打到控制台，便于排查 RLS/网络/表结构问题。
      debugPrint('[sync] upload 失败: $e');
      return false;
    }
  }

  @override
  Future<AppState?> download() async {
    try {
      final rows = await client
          .from(tableName)
          .select('app_state')
          .eq('sync_code', syncCode)
          .limit(1);
      if (rows.isEmpty) return null;
      final json = rows.first['app_state'] as Map<String, dynamic>;
      return AppState.fromJson(json);
    } catch (e) {
      // 下载失败必须显式抛给上层（syncNow 会显示错误），不能用 null 蒙混成「云端无数据」。
      debugPrint('[sync] download 失败: $e');
      rethrow;
    }
  }

  @override
  Future<AppState> sync(AppState local) async {
    final remote = await download(); // 失败会在这里 rethrow，冒泡到 syncNow
    if (remote == null) {
      // 云端无数据，直接上传本地
      final ok = await upload(local);
      if (!ok) {
        throw Exception('同步上传失败：请检查网络与 Supabase 表权限（RLS）');
      }
      return local;
    }
    // 有云端数据，合并后推回
    final merged = SyncMerger.merge(local, remote);
    final ok = await upload(merged);
    if (!ok) {
      throw Exception('同步上传失败：请检查网络与 Supabase 表权限（RLS）');
    }
    return merged;
  }
}
