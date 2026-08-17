import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/lookup_provider.dart';
import 'dialogs/create_edit_lookup_key_dialog.dart';

class LookupHeaderBar extends ConsumerWidget {
  final VoidCallback? onRefresh;

  const LookupHeaderBar({
    super.key,
    this.onRefresh,
  });

  void _exportAllLookups(BuildContext context, WidgetRef ref) {
    final state = ref.read(lookupProvider);
    if (state.keys.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No lookup keys to export')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln("key_name,key_code,key_type,status,total_values,active_values,created_by,description");
    for (final k in state.keys) {
      buffer.writeln(
        '"${k.keyName}","${k.keyCode}","${k.keyType}","${k.status}",${k.totalValuesCount},${k.activeValuesCount},"${k.creatorName}","${k.description}"'
      );
    }

    final uri = Uri.dataFromString(
      buffer.toString(),
      mimeType: 'text/csv',
      encoding: utf8,
    );
    launchUrl(uri);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Exported all lookup keys to CSV!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 24,
        vertical: isMobile ? 12 : 18,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Title & Badge
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 10,
                  runSpacing: 6,
                  children: [
                    Text(
                      'Lookup Management',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 24,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'Independent Key-Value System',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Refresh Button
                  IconButton(
                    onPressed: () {
                      ref.read(lookupProvider.notifier).loadKeys();
                      if (onRefresh != null) onRefresh!();
                    },
                    icon: Icon(
                      Icons.refresh_rounded,
                      size: 20,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    tooltip: 'Refresh Lookups',
                  ),
                  const SizedBox(width: 8),

                  // Export Dropdown
                  OutlinedButton.icon(
                    onPressed: () => _exportAllLookups(context, ref),
                    icon: const Icon(Icons.file_download_outlined, size: 16),
                    label: Text(
                      isMobile ? 'Export' : 'Export CSV',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark ? Colors.white : const Color(0xFF334155),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Create Lookup Key Primary Button
                  ElevatedButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => const CreateEditLookupKeyDialog(),
                      );
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: Text(
                      isMobile ? 'New Key' : 'Create Lookup Key',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Create and manage reusable lookup keys and their values across your institution. These lookups are independent and can be used by any ERP module.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}
