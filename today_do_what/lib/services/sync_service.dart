import '../models/app_state.dart';

/// 同步服务抽象接口。
///
/// 不同后端（Supabase / 本地 mock / 局域网）实现这个接口；AppProvider 只依赖接口，
/// 不关心底层传输细节。实现需保证：
/// - 幂等：重复上传同一份状态不会产生副作用。
/// - 离线友好：网络不可用时返回错误而非崩溃。
abstract class SyncService {
  SyncService({required this.syncCode});

  /// 绑定的同步码（两台设备共用同一个码才能互相同步）。
  final String syncCode;

  /// 将 AppState 全量上传到云端。
  ///
  /// 返回 true 表示上传成功；false 表示失败（网络/权限等）。
  Future<bool> upload(AppState state);

  /// 从云端拉取最新的 AppState。
  ///
  /// 返回远端最新的状态；云端无数据时返回 null。
  Future<AppState?> download();

  /// 同时执行「拉取 → 合并 → 推送」完整同步。
  ///
  /// [local] 为本地当前状态。云端有更新则用 SyncMerger.merge 合并后再推回；
  /// 云端无数据则直接将本地状态上传。返回合并后的最终状态（可能 == local）。
  Future<AppState> sync(AppState local);
}
