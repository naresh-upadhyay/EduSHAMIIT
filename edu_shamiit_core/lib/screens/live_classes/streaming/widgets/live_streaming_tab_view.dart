import 'package:flutter/material.dart';
import '../models/broadcast_models.dart';
import '../providers/broadcast_provider.dart';
import 'live_stream_player.dart';
import 'live_analytics_chart.dart';
import 'add_destination_dialog.dart';
import 'schedule_broadcast_dialog.dart';

class LiveStreamingTabView extends StatelessWidget {
  final BroadcastProvider provider;

  const LiveStreamingTabView({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final overview = provider.overview;
    final active = overview?.activeBroadcast;
    final destinations = overview?.destinations ?? [];
    final analyticsPoints = overview?.analyticsPoints ?? [];
    final scheduled = overview?.scheduledBroadcasts ?? [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1250;

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ==========================================
              // TOP ROW: Player | Stream Setup | Destinations
              // ==========================================
              if (isNarrow) ...[
                // Stack vertically for narrow screens
                SizedBox(
                  height: 250,
                  child: LiveStreamPlayer(
                    title: active?.title ?? 'Live Stream',
                    formattedDuration: provider.formattedLiveDuration,
                    viewers: active?.currentViewers ?? 426,
                  ),
                ),
                const SizedBox(height: 14),
                _buildStreamSetupCard(context, active),
                const SizedBox(height: 14),
                _buildDestinationsCard(context, destinations),
              ] else ...[
                // 3 Columns layout matching mockup
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Column 1: Video Player (flex 4)
                      Expanded(
                        flex: 4,
                        child: LiveStreamPlayer(
                          title: active?.title ?? 'Live Stream',
                          formattedDuration: provider.formattedLiveDuration,
                          viewers: active?.currentViewers ?? 426,
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Column 2: Stream Setup Card (flex 4)
                      Expanded(
                        flex: 4,
                        child: _buildStreamSetupCard(context, active),
                      ),
                      const SizedBox(width: 14),

                      // Column 3: Broadcast Destinations (flex 3)
                      Expanded(
                        flex: 3,
                        child: _buildDestinationsCard(context, destinations),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ==========================================
              // MIDDLE ROW: Stream Status | Live Analytics | Scheduled Preview
              // ==========================================
              if (isNarrow) ...[
                _buildStreamStatusCard(active),
                const SizedBox(height: 14),
                _buildLiveAnalyticsCard(active, analyticsPoints),
                const SizedBox(height: 14),
                _buildScheduledUpcomingCard(context, scheduled),
              ] else ...[
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Stream Status (flex 3)
                      Expanded(
                        flex: 3,
                        child: _buildStreamStatusCard(active),
                      ),
                      const SizedBox(width: 14),

                      // Live Analytics (flex 4)
                      Expanded(
                        flex: 4,
                        child: _buildLiveAnalyticsCard(active, analyticsPoints),
                      ),
                      const SizedBox(width: 14),

                      // Scheduled Upcoming (flex 4)
                      Expanded(
                        flex: 4,
                        child: _buildScheduledUpcomingCard(context, scheduled),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ==========================================
              // BOTTOM ROW: 4 Action Shortcut Cards
              // ==========================================
              _buildBottomActionCards(context, isNarrow),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  // --------------------------------------------------------------------------
  // Stream Setup Card
  // --------------------------------------------------------------------------
  Widget _buildStreamSetupCard(BuildContext context, LiveBroadcastItem? active) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Row(
                children: [
                  Icon(Icons.sensors, color: Color(0xFF2563EB), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Stream Setup',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Stream Title
              RichText(
                text: const TextSpan(
                  text: 'Stream Title ',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  children: [
                    TextSpan(text: '*', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 34,
                child: TextField(
                  controller: provider.titleController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Description
              const Text(
                'Description',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 52,
                child: TextField(
                  controller: provider.descriptionController,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 11),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Row: Category & Privacy
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 34,
                          child: DropdownButtonFormField<String>(
                            initialValue: provider.selectedCategory,
                            isExpanded: true,
                            isDense: true,
                            items: const [
                              DropdownMenuItem(value: 'Education', child: Text('Education', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'Science', child: Text('Science', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'Language', child: Text('Language', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (v) => provider.selectedCategory = v ?? 'Education',
                            decoration: InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Privacy', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 34,
                          child: DropdownButtonFormField<String>(
                            initialValue: provider.selectedPrivacy,
                            isExpanded: true,
                            isDense: true,
                            items: const [
                              DropdownMenuItem(value: 'Public', child: Text('Public', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'Unlisted', child: Text('Unlisted', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: 'Private', child: Text('Private', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (v) => provider.selectedPrivacy = v ?? 'Public',
                            decoration: InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Row: Stream Quality & Bitrate
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Stream Quality', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 34,
                          child: DropdownButtonFormField<String>(
                            initialValue: provider.selectedQuality,
                            isExpanded: true,
                            isDense: true,
                            items: const [
                              DropdownMenuItem(value: '1080p (Full HD)', child: Text('1080p', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: '720p (HD)', child: Text('720p', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: '4K (Ultra HD)', child: Text('4K', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (v) => provider.selectedQuality = v ?? '1080p (Full HD)',
                            decoration: InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Bitrate', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 34,
                          child: DropdownButtonFormField<String>(
                            initialValue: provider.selectedBitrate,
                            isExpanded: true,
                            isDense: true,
                            items: const [
                              DropdownMenuItem(value: 'Auto (Recommended)', child: Text('Auto', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: '4500 Kbps', child: Text('4.5 Mbps', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                              DropdownMenuItem(value: '6000 Kbps', child: Text('6.0 Mbps', style: TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis)),
                            ],
                            onChanged: (v) => provider.selectedBitrate = v ?? 'Auto (Recommended)',
                            decoration: InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Action Buttons matching mockup:
          // [ Stop Stream (Red) ] [ Pause Stream ] [ Go Live ] [ End & Save ]
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Stop Stream (Red)
                ElevatedButton.icon(
                  onPressed: () async {
                    final ok = await provider.stopBroadcast();
                    if (context.mounted && ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Stream stopped')),
                      );
                    }
                  },
                  icon: const Icon(Icons.stop, size: 14),
                  label: const Text('Stop Stream', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
                const SizedBox(width: 8),

                // Pause Stream
                OutlinedButton.icon(
                  onPressed: () async {
                    if (active?.status == 'paused') {
                      await provider.resumeBroadcast();
                    } else {
                      await provider.pauseBroadcast();
                    }
                  },
                  icon: Icon(active?.status == 'paused' ? Icons.play_arrow : Icons.pause, size: 14),
                  label: Text(
                    active?.status == 'paused' ? 'Resume' : 'Pause Stream',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF334155),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),

                // Go Live
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await provider.startBroadcast();
                    if (context.mounted && ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Stream is now LIVE!'), backgroundColor: Color(0xFF16A34A)),
                      );
                    }
                  },
                  icon: const Icon(Icons.sensors, size: 14, color: Color(0xFF2563EB)),
                  label: const Text('Go Live', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    side: const BorderSide(color: Color(0xFF93C5FD)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 8),

                // End & Save
                OutlinedButton.icon(
                  onPressed: () async {
                    final ok = await provider.endAndSaveBroadcast();
                    if (context.mounted && ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Stream ended and saved to Recordings catalog!'), backgroundColor: Color(0xFF2563EB)),
                      );
                    }
                  },
                  icon: const Icon(Icons.save_alt, size: 14, color: Color(0xFF2563EB)),
                  label: const Text('End & Save', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    side: const BorderSide(color: Color(0xFF93C5FD)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Broadcast Destinations Card
  // --------------------------------------------------------------------------
  Widget _buildDestinationsCard(BuildContext context, List<BroadcastDestinationItem> destinations) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.layers, color: Color(0xFF2563EB), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Broadcast Destinations',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Checklist
              ...destinations.map((d) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      // Checkbox
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Checkbox(
                          value: d.isActive,
                          activeColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) {
                            if (val != null) {
                              provider.toggleDestination(d.id, val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Platform icon badge
                      _buildPlatformLogo(d.platformKey),
                      const SizedBox(width: 6),

                      // Destination Name
                      Expanded(
                        child: Text(
                          d.destinationName,
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      // Status Badge (Connected / Configured / Not Connected)
                      _buildStatusPill(d),
                      const SizedBox(width: 2),

                      // Gear Settings Icon
                      IconButton(
                        icon: const Icon(Icons.settings, size: 14, color: Color(0xFF94A3B8)),
                        constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          // Quick view details
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(d.destinationName),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('RTMP Server: ${d.rtmpUrl}', style: const TextStyle(fontSize: 12)),
                                  const SizedBox(height: 6),
                                  Text('Stream Key: ${d.streamKey.substring(0, (d.streamKey.length * 0.3).round())}******', style: const TextStyle(fontSize: 12)),
                                  const SizedBox(height: 6),
                                  Text('Sync Status: ${d.syncStatus}', style: const TextStyle(fontSize: 12)),
                                ],
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),

          // Add Platform Button
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AddDestinationDialog(provider: provider),
                  );
                },
                icon: const Icon(Icons.add, size: 14, color: Color(0xFF2563EB)),
                label: const Text('Add Platform', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  side: const BorderSide(color: Color(0xFF93C5FD)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformLogo(String platformKey) {
    if (platformKey == 'youtube') {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(4)),
        child: const Icon(Icons.play_circle_fill, color: Colors.red, size: 16),
      );
    } else if (platformKey == 'facebook') {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
        child: const Icon(Icons.facebook, color: Color(0xFF1877F2), size: 16),
      );
    } else if (platformKey == 'teams') {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(4)),
        child: const Icon(Icons.groups, color: Color(0xFF6264A7), size: 16),
      );
    } else if (platformKey == 'zoom') {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
        child: const Icon(Icons.videocam, color: Color(0xFF2D8CFF), size: 16),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.indigo.shade50, borderRadius: BorderRadius.circular(4)),
        child: const Icon(Icons.link, color: Color(0xFF4F46E5), size: 16),
      );
    }
  }

  Widget _buildStatusPill(BroadcastDestinationItem d) {
    Color bg;
    Color fg;
    String label;

    if (d.isConnected) {
      if (d.platformKey == 'custom_rtmp') {
        bg = const Color(0xFFEFF6FF);
        fg = const Color(0xFF2563EB);
        label = 'Configured';
      } else {
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF16A34A);
        label = 'Connected';
      }
    } else {
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF64748B);
      label = 'Not Connected';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 9.5, fontWeight: FontWeight.bold),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Stream Status Card
  // --------------------------------------------------------------------------
  Widget _buildStreamStatusCard(LiveBroadcastItem? active) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.speed, color: Color(0xFF2563EB), size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Stream Status',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF16A34A), shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text('Live', style: TextStyle(color: Color(0xFF16A34A), fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildMetricRow(
            icon: Icons.health_and_safety,
            label: 'Stream Health',
            value: active?.streamHealth ?? 'Excellent',
            valueColor: const Color(0xFF16A34A),
            hasIndicatorDot: true,
          ),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          _buildMetricRow(
            icon: Icons.hd,
            label: 'Resolution',
            value: active?.resolution ?? '1080p',
          ),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          _buildMetricRow(
            icon: Icons.network_check,
            label: 'Bitrate',
            value: '${active?.actualBitrateKbps ?? 4500} Kbps',
          ),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          _buildMetricRow(
            icon: Icons.slow_motion_video,
            label: 'Frame Rate',
            value: '${active?.actualFps ?? 30} fps',
          ),
          const Divider(height: 18, color: Color(0xFFF1F5F9)),
          _buildMetricRow(
            icon: Icons.timer,
            label: 'Uptime',
            value: provider.formattedLiveUptime,
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
    bool hasIndicatorDot = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
        ),
        const Spacer(),
        if (hasIndicatorDot) ...[
          Container(width: 6, height: 6, decoration: BoxDecoration(color: valueColor, shape: BoxShape.circle)),
          const SizedBox(width: 4),
        ],
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: valueColor ?? const Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // Live Analytics Card
  // --------------------------------------------------------------------------
  Widget _buildLiveAnalyticsCard(LiveBroadcastItem? active, List<AnalyticsPoint> points) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart, color: Color(0xFF2563EB), size: 18),
              SizedBox(width: 8),
              Text(
                'Live Analytics',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 4 metric tiles in a row
          Row(
            children: [
              _buildStatTile(
                value: '${active?.currentViewers ?? 426}',
                label: 'Live Viewers',
                icon: Icons.group,
                color: const Color(0xFF2563EB),
                bg: const Color(0xFFEFF6FF),
              ),
              const SizedBox(width: 8),
              _buildStatTile(
                value: '${active?.totalViews ?? 1248}',
                label: 'Total Views',
                icon: Icons.visibility,
                color: const Color(0xFF7C3AED),
                bg: const Color(0xFFF5F3FF),
              ),
              const SizedBox(width: 8),
              _buildStatTile(
                value: provider.formattedLiveDuration,
                label: 'Live Duration',
                icon: Icons.schedule,
                color: const Color(0xFF16A34A),
                bg: const Color(0xFFDCFCE7),
              ),
              const SizedBox(width: 8),
              _buildStatTile(
                value: '${active?.likesCount ?? 267}',
                label: 'Likes',
                icon: Icons.favorite,
                color: const Color(0xFFDC2626),
                bg: const Color(0xFFFEF2F2),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Chart
          LiveAnalyticsChart(
            points: points,
            currentPeak: active?.currentViewers ?? 426,
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required String value,
    required String label,
    required IconData icon,
    required Color color,
    required Color bg,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Scheduled Broadcasts Upcoming Card
  // --------------------------------------------------------------------------
  Widget _buildScheduledUpcomingCard(BuildContext context, List<ScheduledBroadcastItem> scheduled) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.event_note, color: Color(0xFF2563EB), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Scheduled Broadcasts (Upcoming)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => provider.setTabIndex(1),
                child: const Row(
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    Icon(Icons.arrow_forward, size: 13, color: Color(0xFF2563EB)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Expanded(flex: 4, child: Text('Date & Time', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                Expanded(flex: 4, child: Text('Class / Subject', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                Expanded(flex: 2, child: Text('Platform', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
                Expanded(flex: 3, child: Text('Status', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)))),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // Table Rows
          ...scheduled.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.scheduledDate, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                        Text(item.scheduledTime, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      item.classSubject,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF334155)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _buildPlatformLogo(item.platform),
                  ),
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Scheduled',
                            style: TextStyle(color: Color(0xFF2563EB), fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.more_vert, size: 16, color: Color(0xFF94A3B8)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // Bottom 4 Quick Action Cards
  // --------------------------------------------------------------------------
  Widget _buildBottomActionCards(BuildContext context, bool isNarrow) {
    final cards = [
      _ActionCardData(
        title: 'Create Scheduled Broadcast',
        subtitle: 'Plan and configure a future live stream.',
        icon: Icons.video_call,
        color: const Color(0xFF2563EB),
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => ScheduleBroadcastDialog(provider: provider),
          );
        },
      ),
      _ActionCardData(
        title: 'Manage Destinations',
        subtitle: 'Connect and manage YouTube, Facebook, Teams, Zoom or custom RTMP.',
        icon: Icons.settings_input_antenna,
        color: const Color(0xFF0284C7),
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => AddDestinationDialog(provider: provider),
          );
        },
      ),
      _ActionCardData(
        title: 'View Stream Analytics',
        subtitle: 'Live and past stream performance, views, engagement and reach.',
        icon: Icons.insights,
        color: const Color(0xFF7C3AED),
        onTap: () => provider.setTabIndex(3),
      ),
      _ActionCardData(
        title: 'Access Recordings',
        subtitle: 'Manage recordings of completed streams and broadcasts.',
        icon: Icons.cloud_download,
        color: const Color(0xFF0D9488),
        onTap: () => provider.setTabIndex(2),
      ),
    ];

    if (isNarrow) {
      return Column(
        children: cards.map((c) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _buildActionCard(c))).toList(),
      );
    }

    return Row(
      children: cards.map((c) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildActionCard(c),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActionCard(_ActionCardData data) {
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(data.icon, color: data.color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    data.subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCardData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _ActionCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
