import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'driver_management_tab.dart';

class DriverManagementScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const DriverManagementScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<DriverManagementScreen> createState() => _DriverManagementScreenState();
}

class _DriverManagementScreenState extends ConsumerState<DriverManagementScreen> {
  final GlobalKey<DriverManagementTabState> _driverTabKey = GlobalKey<DriverManagementTabState>();

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.userData;
    final schoolId = user?['school_id']?.toString();

    return Scaffold(
      backgroundColor: _bg,
      body: DriverManagementTab(
        key: _driverTabKey,
        schoolId: schoolId,
        initialTab: widget.initialTab,
      ),
    );
  }
}
