import 'package:flutter/material.dart';
import '../providers/broadcast_provider.dart';

class PastStreamsTabView extends StatefulWidget {
  final BroadcastProvider provider;

  const PastStreamsTabView({super.key, required this.provider});

  @override
  State<PastStreamsTabView> createState() => _PastStreamsTabViewState();
}

class _PastStreamsTabViewState extends State<PastStreamsTabView> {
  @override
  void initState() {
    super.initState();
    widget.provider.loadPastStreams();
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.provider.pastStreams;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Summary Row
          Row(
            children: [
              _buildSummaryBox('Total Recorded Streams', '${list.length}', Icons.video_library, const Color(0xFF2563EB), const Color(0xFFEFF6FF)),
              const SizedBox(width: 14),
              _buildSummaryBox('Total Stream Time', '124.5 hrs', Icons.schedule, const Color(0xFF16A34A), const Color(0xFFDCFCE7)),
              const SizedBox(width: 14),
              _buildSummaryBox('Total Historical Views', '4,550', Icons.visibility, const Color(0xFF7C3AED), const Color(0xFFF5F3FF)),
            ],
          ),
          const SizedBox(height: 16),

          // Streams List Card
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: const Row(
                    children: [
                      Expanded(flex: 4, child: Text('Stream Title & Subject', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                      Expanded(flex: 3, child: Text('Streamed Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                      Expanded(flex: 2, child: Text('Views / Likes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                      Expanded(flex: 3, child: Text('Recording Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF475569)))),
                    ],
                  ),
                ),
                const Divider(height: 1),

                if (list.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No past streams recorded.', style: TextStyle(color: Color(0xFF94A3B8)))),
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
                            flex: 4,
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0F172A),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                      Text(item.classSubject, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(item.streamedOn, style: const TextStyle(fontSize: 11, color: Color(0xFF334155))),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text('${item.durationMinutes} mins', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${item.totalViews} views', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                                Text('${item.likes} likes', style: const TextStyle(fontSize: 10, color: Color(0xFFDC2626))),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Playing recording: ${item.title}')),
                                    );
                                  },
                                  icon: const Icon(Icons.play_circle, size: 14),
                                  label: const Text('Play', style: TextStyle(fontSize: 11)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                OutlinedButton.icon(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Downloading MP4: ${item.title}')),
                                    );
                                  },
                                  icon: const Icon(Icons.download, size: 14),
                                  label: const Text('MP4', style: TextStyle(fontSize: 11)),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  ),
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

  Widget _buildSummaryBox(String label, String value, IconData icon, Color color, Color bg) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
