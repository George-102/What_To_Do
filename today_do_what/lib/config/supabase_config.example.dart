/// Supabase 项目配置模板。
///
/// 使用方法：
/// 1. 复制本文件为同目录下的 `supabase_config.dart`（该文件已被 .gitignore 排除）。
/// 2. 到 Supabase Dashboard → Project Settings → API 填入你自己的 URL 和 anon key。
///
/// ⚠️ 不要把填好真实值的 supabase_config.dart 提交到公共仓库。
class SupabaseConfig {
  /// Supabase Project URL，形如 `https://<project-ref>.supabase.co`
  static const String supabaseUrl = 'https://YOUR_PROJECT_REF.supabase.co';

  /// Supabase anon public key（客户端使用，设计上可公开，但建议不要随仓库分发）。
  static const String supabaseAnonKey = 'YOUR_ANON_KEY';
}
