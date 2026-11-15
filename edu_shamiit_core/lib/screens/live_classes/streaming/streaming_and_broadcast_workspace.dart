import 'package:flutter/material.dart';
import 'providers/broadcast_provider.dart';
import 'widgets/live_streaming_tab_view.dart';
import 'widgets/scheduled_broadcasts_tab_view.dart';
import 'widgets/past_streams_tab_view.dart';
import 'widgets/stream_analytics_tab_view.dart';
import 'widgets/broadcast_settings_tab_view.dart';

class StreamingAndBroadcastWorkspace extends StatefulWidget {
  const StreamingAndBroadcastWorkspace({super.key});

  @override
  State<StreamingAndBroadcastWorkspace> createState() => _StreamingAndBroadcastWorkspaceState();
}

class _StreamingAndBroadcastWorkspaceState extends State<StreamingAndBroadcastWorkspace> {
  late BroadcastProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = BroadcastProvider();
    _provider.loadOverview();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, child) {
        final provider = _provider;
        return Container(
          color: const Color(0xFFF8FAFC),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Header Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.sensors, color: Color(0xFF2563EB), size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Streaming & Broadcast',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Live stream your class to a larger audience or broadcast to external platforms (e.g., YouTube, Facebook, etc.).',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 5 Sub-tab Pills Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                color: Colors.white,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTabPill(index: 0, label: 'Live Streaming', icon: Icons.sensors, provider: provider),
                      const SizedBox(width: 8),
                      _buildTabPill(index: 1, label: 'Scheduled Broadcasts', icon: Icons.calendar_today, provider: provider),
                      const SizedBox(width: 8),
                      _buildTabPill(index: 2, label: 'Past Streams', icon: Icons.play_circle_outline, provider: provider),
                      const SizedBox(width: 8),
                      _buildTabPill(index: 3, label: 'Stream Analytics', icon: Icons.bar_chart, provider: provider),
                      const SizedBox(width: 8),
                      _buildTabPill(index: 4, label: 'Settings', icon: Icons.settings, provider: provider),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),

              // Tab Content Body
              provider.isLoading && provider.overview == null
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _buildActiveTabView(provider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabPill({
    required int index,
    required String label,
    required IconData icon,
    required BroadcastProvider provider,
  }) {
    final isSelected = provider.selectedTabIndex == index;

    return InkWell(
      onTap: () => provider.setTabIndex(index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : const Color(0xFF475569),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF334155),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTabView(BroadcastProvider provider) {
    switch (provider.selectedTabIndex) {
      case 0:
        return LiveStreamingTabView(provider: provider);
      case 1:
        return ScheduledBroadcastsTabView(provider: provider);
      case 2:
        return PastStreamsTabView(provider: provider);
      case 3:
        return StreamAnalyticsTabView(provider: provider);
      case 4:
        return BroadcastSettingsTabView(provider: provider);
      default:
        return LiveStreamingTabView(provider: provider);
    }
  }
}
