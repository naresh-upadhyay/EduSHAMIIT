import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import '../providers/broadcast_provider.dart';
import 'schedule_broadcast_dialog.dart';

class ScheduledBroadcastsTabView extends StatefulWidget {
  final BroadcastProvider provider;

  const ScheduledBroadcastsTabView({super.key, required this.provider});

  @override
  State<ScheduledBroadcastsTabView> createState() => _ScheduledBroadcastsTabViewState();
}

class _ScheduledBroadcastsTabViewState extends State<ScheduledBroadcastsTabView> {
  String _searchQuery = '';
  String _selectedPlatformFilter = 'All';

  @override
  void initState() {
    super.initState();
    widget.provider.loadScheduledBroadcasts();
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.provider.scheduledList.where((item) {
      final matchesSearch = item.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.classSubject.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          item.broadcastCode.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesPlatform = _selectedPlatformFilter == 'All' || item.platform == _selectedPlatformFilter.toLowerCase();
      return matchesSearch && matchesPlatform;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Filter & Action Bar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search scheduled broadcasts...',
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                AppSearchableDropdown<String>.fromMenuItems(
                  value: _selectedPlatformFilter,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Platforms')),
                    DropdownMenuItem(value: 'youtube', child: Text('YouTube')),
                    DropdownMenuItem(value: 'facebook', child: Text('Facebook')),
                    DropdownMenuItem(value: 'custom_rtmp', child: Text('Custom RTMP')),
                  ],
                  onChanged: (v) => setState(() => _selectedPlatformFilter = v ?? 'All'),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => ScheduleBroadcastDialog(provider: widget.provider),
                    );
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Schedule Broadcast'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Data Table Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                // Table header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 2, child: Text('Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                      Expanded(flex: 4, child: Text('Class & Subject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                      Expanded(flex: 3, child: Text('Scheduled Date & Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('Platform', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('Privacy / Quality', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                    ],
                  ),
                ),
                const Divider(height: 1),

                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('No scheduled broadcasts found.', style: TextStyle(color: Color(0xFF94A3B8))),
                    ),
                  )
                else
                  ...list.map((item) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(item.broadcastCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF2563EB))),
                          ),
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF0F172A))),
                                Text(item.classSubject, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.scheduledDate, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
                                Text(item.scheduledTime, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                Icon(
                                  item.platform == 'facebook' ? Icons.facebook : Icons.play_circle_fill,
                                  color: item.platform == 'facebook' ? const Color(0xFF1877F2) : Colors.red,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(item.platform.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.privacy ?? 'Public', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600)),
                                Text(item.quality ?? '1080p', style: const TextStyle(fontSize: 9, color: Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                item.status.toUpperCase(),
                                style: const TextStyle(color: Color(0xFF2563EB), fontSize: 9, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.sensors, size: 18, color: Color(0xFF16A34A)),
                                  tooltip: 'Go Live Now',
                                  onPressed: () {
                                    widget.provider.setTabIndex(0);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.more_vert, size: 18, color: Color(0xFF94A3B8)),
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
