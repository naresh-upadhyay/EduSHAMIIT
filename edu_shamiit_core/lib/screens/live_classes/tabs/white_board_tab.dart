import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/live_class_management_provider.dart';
import '../whiteboard/widgets/whiteboard_workspace.dart';

/// Standalone interactive White Board tab for offline classroom teaching
/// without launching an online live meeting.
class WhiteBoardTab extends ConsumerWidget {
  const WhiteBoardTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isTabActive = ref.watch(
      liveClassManagementProvider.select((s) => s.selectedTabIndex == 2),
    );
    final screenW = MediaQuery.of(context).size.width;
    final padding = screenW < 600 ? 8.0 : 14.0;

    return Padding(
      padding: EdgeInsets.all(padding),
      child: WhiteboardWorkspace(
        sessionId: null,
        sessionTitle: 'Offline Class Whiteboard',
        isOfflineTab: true,
        isTabActive: isTabActive,
      ),
    );
  }
}
