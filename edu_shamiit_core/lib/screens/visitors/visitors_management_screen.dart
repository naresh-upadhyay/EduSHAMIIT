import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/visitors_provider.dart';
import 'widgets/visitors_header_bar.dart';
import 'widgets/tabs/all_visitors_tab.dart';
import 'widgets/tabs/scheduled_visitors_tab.dart';
import 'widgets/tabs/blacklisted_visitors_tab.dart';

class VisitorsManagementScreen extends ConsumerStatefulWidget {
  final bool isEmbedded;
  final int initialTab;

  const VisitorsManagementScreen({
    super.key,
    this.isEmbedded = false,
    this.initialTab = 0,
  });

  @override
  ConsumerState<VisitorsManagementScreen> createState() => _VisitorsManagementScreenState();
}

class _VisitorsManagementScreenState extends ConsumerState<VisitorsManagementScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(visitorsProvider.notifier);
      if (widget.initialTab != 0) {
        notifier.setActiveTab(widget.initialTab.clamp(0, 2));
      }
      notifier.fetchKPIs();
      notifier.fetchVisits();
      notifier.fetchAppointments();
      notifier.fetchRestrictions();
      notifier.fetchAnalytics();
      notifier.fetchLocations();
    });
  }

  @override
  void didUpdateWidget(covariant VisitorsManagementScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(visitorsProvider.notifier).setActiveTab(widget.initialTab.clamp(0, 2));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(visitorsProvider);
    final notifier = ref.read(visitorsProvider.notifier);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Listen to messages for snackbars
    ref.listen<VisitorsState>(visitorsProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
        notifier.clearNotifications();
      } else if (next.successMessage != null && next.successMessage != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.successMessage!),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
        notifier.clearNotifications();
      }
    });

    final bodyContent = Column(
      children: [
        // Top Header Bar with Title, Subtitle, Date Range & the 3 PRIMARY TABS
        VisitorsHeaderBar(isEmbedded: widget.isEmbedded),

        // Active Primary Tab View (0: All Visitors, 1: Scheduled, 2: Blacklisted)
        Expanded(
          child: IndexedStack(
            index: state.activeTab.clamp(0, 2),
            children: const [
              AllVisitorsTab(),
              ScheduledVisitorsTab(),
              BlacklistedVisitorsTab(),
            ],
          ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return bodyContent;
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: bodyContent,
      ),
    );
  }
}
