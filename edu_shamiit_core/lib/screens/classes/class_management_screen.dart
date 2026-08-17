import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/class_provider.dart';
import 'widgets/class_header_bar.dart';
import 'widgets/class_tabs_bar.dart';
import 'widgets/classes_tab_view.dart';
import 'widgets/sections_tab_view.dart';
import 'widgets/subjects_tab_view.dart';

class ClassManagementScreen extends ConsumerWidget {
  const ClassManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(classProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Listen for error messages
    ref.listen<ClassState>(classProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(next.errorMessage!)),
              ],
            ),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9),
      body: Column(
        children: [
          // 1. Top ERP Header Bar
          const ClassHeaderBar(),

          // 2. Exact 3 Tabs Pill Bar ([ Classes ] [ Sections ] [ Subjects ])
          const ClassTabsBar(),

          // 3. Tab Body
          Expanded(
            child: IndexedStack(
              index: state.activeTab,
              children: const [
                ClassesTabView(),
                SectionsTabView(),
                SubjectsTabView(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
