import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/websocket_service.dart';
import 'dashboard_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';

class MainNavigationShell extends StatefulWidget {
  final int initialIndex;

  const MainNavigationShell({super.key, this.initialIndex = 0});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    // Connect to WebSocket for live transaction and sync events
    WebSocketService().connect();
  }

  @override
  void dispose() {
    WebSocketService().disconnect();
    super.dispose();
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        onNavigateTab: _onTabSelected,
      ),
      NotificationsScreen(
        onBack: () => _onTabSelected(0),
      ),
      TransactionsScreen(
        onBack: () => _onTabSelected(0),
      ),
      SettingsScreen(
        onBack: () => _onTabSelected(0),
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabSelected,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primaryBlue,
          unselectedItemColor: AppColors.textMuted,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.notifications_none_outlined),
              activeIcon: Icon(Icons.notifications),
              label: 'Notifications',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.receipt_long_outlined),
              activeIcon: Icon(Icons.receipt_long),
              label: 'Transactions',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined),
              activeIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
