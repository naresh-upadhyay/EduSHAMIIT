import 'package:flutter/material.dart';
import '../core/platform_bridge.dart';
import '../core/theme.dart';
import '../services/websocket_service.dart';
import '../widgets/app_drawer.dart';
import 'dashboard_screen.dart';
import 'logs_screen.dart';
import 'monitoring_screen.dart';
import 'settings_screen.dart';

class MainNavigationShell extends StatefulWidget {
  final int initialIndex;
  const MainNavigationShell({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey<DashboardScreenState>();
  final GlobalKey<LogsScreenState> _logsKey = GlobalKey<LogsScreenState>();
  final GlobalKey<MonitoringScreenState> _monitorKey = GlobalKey<MonitoringScreenState>();
  final GlobalKey<SettingsScreenState> _settingsKey = GlobalKey<SettingsScreenState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    WebSocketService().connect();
    PlatformBridge.startGatewayService();
  }

  @override
  void dispose() {
    WebSocketService().disconnect();
    super.dispose();
  }

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (index) {
        case 0:
          _dashboardKey.currentState?.refresh();
          break;
        case 1:
          _logsKey.currentState?.refresh();
          break;
        case 2:
          _monitorKey.currentState?.refresh();
          break;
        case 3:
          _settingsKey.currentState?.refresh();
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screens = [
      DashboardScreen(key: _dashboardKey, onNavigateTab: _onTabSelected),
      LogsScreen(key: _logsKey),
      MonitoringScreen(key: _monitorKey),
      SettingsScreen(key: _settingsKey, onNavigateTab: _onTabSelected),
    ];

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(onSelectTab: _onTabSelected),
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          border: Border(
            top: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
          ),
        ),
        child: SafeArea(
          top: false,
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: _onTabSelected,
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.receipt_long_outlined),
                activeIcon: Icon(Icons.receipt_long_rounded),
                label: 'Logs',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined),
                activeIcon: Icon(Icons.bar_chart_rounded),
                label: 'Monitor',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings_rounded),
                label: 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
