import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/space_booking_models.dart';

/// Legacy right panel placeholder - All capabilities have been migrated:
/// - "Book a Space" -> Central CreateEditBookingDialog modal
/// - "Quick Actions" -> Contextual table & timeline actions
/// - "Utilization Donut Graph" -> Dedicated Usage & Reports screen
/// - Left & Center Panels now take full width for spacious calendar & grids.
class SpaceBookingRightPanel extends ConsumerWidget {
  final VoidCallback? onOpenRecurringModal;
  final VoidCallback? onOpenManageApprovals;
  final VoidCallback? onOpenUtilizationReport;
  final Function(SpaceBookingRequestItem item)? onInspectRequest;
  final bool isCompact;

  const SpaceBookingRightPanel({
    super.key,
    this.onOpenRecurringModal,
    this.onOpenManageApprovals,
    this.onOpenUtilizationReport,
    this.onInspectRequest,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SizedBox.shrink();
  }
}
