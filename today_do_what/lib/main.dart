import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'providers/app_provider.dart';
import 'services/device_info.dart';
import 'services/storage_service.dart';
import 'services/supabase_sync_service.dart';
import 'services/sync_service.dart';
import 'ui/app_colors.dart';
import 'ui/history_page.dart';
import 'ui/rewards_page.dart';
import 'ui/settings_page.dart';
import 'ui/today_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 初始化 Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    publishableKey: SupabaseConfig.supabaseAnonKey,
  );

  // 2. 初始化本地服务
  final storage = StorageService();
  final prefs = await SharedPreferences.getInstance();
  final deviceInfo = DeviceInfo(prefs);

  // 3. 构建同步服务（如果有 syncCode 则激活）
  SyncService? syncService;
  final syncCode = deviceInfo.syncCode;
  if (syncCode != null && syncCode.isNotEmpty) {
    syncService = SupabaseSyncService(
      syncCode: syncCode,
      client: Supabase.instance.client,
    );
  }

  // 4. 构建 AppProvider 并启动
  final appProvider = AppProvider(
    storage: storage,
    deviceInfo: deviceInfo,
    syncService: syncService,
  );
  await appProvider.init();

  runApp(
    ChangeNotifierProvider<AppProvider>.value(
      value: appProvider,
      child: const TodayDoWhatApp(),
    ),
  );
}

/// 应用根组件。
class TodayDoWhatApp extends StatelessWidget {
  const TodayDoWhatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '今天干点啥',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: const AppShell(),
    );
  }
}

/// 底部导航外壳：今日 / 历史 / 奖励 / 设置。
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          TodayPage(),
          HistoryPage(),
          RewardsPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: AppColors.surface,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: '今日',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: '历史',
          ),
          NavigationDestination(
            icon: Icon(Icons.redeem_outlined),
            selectedIcon: Icon(Icons.redeem),
            label: '奖励',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}
