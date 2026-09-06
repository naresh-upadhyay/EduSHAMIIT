import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';
import '../providers/request_provider.dart';
import 'dialogs/create_request_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class RequestHeaderBar extends ConsumerWidget {
  const RequestHeaderBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(requestProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isDesktop = Responsive.isDesktop(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 28 : 16,
        vertical: 18,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2E) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Title & Subtitle (Left)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Requests',
                  style: TextStyle(
                    fontSize: isDesktop ? 24 : 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'View and manage all library requests raised by members.',
                  style: TextStyle(
                    fontSize: isDesktop ? 13 : 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: 16),

          // 2. Action Buttons (Right)
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // + New Request Primary Button
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text(
                  'New Request',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1), // Royal Purple/Indigo consistent with ERP
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 16 : 12,
                    vertical: isDesktop ? 12 : 10,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => const CreateRequestDialog(),
                  );
                },
              ),

              // More Actions Dropdown
              PopupMenuButton<String>(
                tooltip: 'More Actions',
                onSelected: (val) async {
                  if (val == 'export') {
                    final url = Uri.parse(notifier.getExportCsvUrl());
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url);
                    }
                  } else if (val == 'refresh') {
                    notifier.init();
                  } else if (val == 'bulk_activate') {
                    final res = await notifier.performBulkAction(action: 'ACTIVATE');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(res['message']?.toString() ?? 'Bulk activate completed')),
                      );
                    }
                  }
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'export',
                    child: Row(
                      children: [
                        Icon(Icons.download_rounded, size: 18, color: Color(0xFF64748B)),
                        SizedBox(width: 10),
                        Text('Export Requests CSV', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'refresh',
                    child: Row(
                      children: [
                        Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF64748B)),
                        SizedBox(width: 10),
                        Text('Refresh Data', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'bulk_activate',
                    child: Row(
                      children: [
                        Icon(Icons.done_all_rounded, size: 18, color: Color(0xFF10B981)),
                        SizedBox(width: 10),
                        Text('Bulk Accept Selected', style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isDesktop ? 14 : 10,
                    vertical: isDesktop ? 10 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Text(
                        'More Actions',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Color(0xFF64748B)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
