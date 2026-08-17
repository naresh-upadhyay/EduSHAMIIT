import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lookup_models.dart';
import '../providers/lookup_provider.dart';
import 'dialogs/create_edit_lookup_key_dialog.dart';
import 'dialogs/delete_lookup_confirmation_dialog.dart';
import 'dialogs/lookup_audit_log_drawer.dart';
import 'dialogs/lookup_usage_drawer.dart';
import 'lookup_stats_cards.dart';
import 'lookup_values_table.dart';

class LookupDetailView extends ConsumerWidget {
  final LookupKeyModel lookupKey;

  const LookupDetailView({
    super.key,
    required this.lookupKey,
  });

  IconData _getIconData(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'calendar_today_rounded':
      case 'calendar':
        return Icons.calendar_today_rounded;
      case 'grid_view_rounded':
      case 'modules':
        return Icons.grid_view_rounded;
      case 'directions_bus_rounded':
      case 'vehicle':
        return Icons.directions_bus_rounded;
      case 'people_outline_rounded':
      case 'users':
        return Icons.people_outline_rounded;
      case 'description_outlined':
      case 'document':
        return Icons.description_outlined;
      case 'receipt_long_rounded':
      case 'expense':
        return Icons.receipt_long_rounded;
      case 'event_busy_rounded':
      case 'leave':
        return Icons.event_busy_rounded;
      case 'account_balance_wallet_rounded':
      case 'fee':
        return Icons.account_balance_wallet_rounded;
      case 'alt_route_rounded':
      case 'route':
        return Icons.alt_route_rounded;
      case 'flag_rounded':
      case 'priority':
        return Icons.flag_rounded;
      default:
        return Icons.folder_outlined;
    }
  }

  Color _getIconBgColor(String keyCode) {
    final code = keyCode.toUpperCase();
    if (code.contains('CALENDAR')) return const Color(0xFF8B5CF6);
    if (code.contains('MODULE')) return const Color(0xFF3B82F6);
    if (code.contains('VEHICLE')) return const Color(0xFF0EA5E9);
    if (code.contains('USER')) return const Color(0xFFF59E0B);
    if (code.contains('DOCUMENT')) return const Color(0xFFEC4899);
    if (code.contains('EXPENSE')) return const Color(0xFFF97316);
    if (code.contains('LEAVE')) return const Color(0xFF6366F1);
    if (code.contains('FEE')) return const Color(0xFF10B981);
    if (code.contains('ROUTE')) return const Color(0xFF06B6D4);
    if (code.contains('PRIORITY')) return const Color(0xFFEF4444);
    return const Color(0xFF64748B);
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'N/A';
    // Format in Indian Standard Time (IST)
    final local = dt.toLocal();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final ampm = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year}, $hour:$minute $ampm';
  }

  void _exportSingleKey(BuildContext context, WidgetRef ref) {
    final state = ref.read(lookupProvider);
    if (state.values.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No values to export for this key')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln("value_name,value_code,status,sort_order,description");
    for (final v in state.values) {
      buffer.writeln(
        '"${v.valueName}","${v.valueCode}","${v.status}",${v.sortOrder},"${v.description}"'
      );
    }

    final uri = Uri.dataFromString(
      buffer.toString(),
      mimeType: 'text/csv',
      encoding: utf8,
    );
    launchUrl(uri);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${lookupKey.keyName} values to CSV!'),
        backgroundColor: const Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lookupProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = _getIconBgColor(lookupKey.keyCode);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon Box
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _getIconData(lookupKey.icon),
                        size: 26,
                        color: iconColor,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Title & Metadata
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                lookupKey.keyName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: lookupKey.isActive
                                      ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  lookupKey.isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: lookupKey.isActive
                                        ? const Color(0xFF10B981)
                                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Key Type Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: lookupKey.isSystem
                                      ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                                      : const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  lookupKey.isSystem ? 'System Key' : 'Custom Key',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: lookupKey.isSystem ? const Color(0xFF6366F1) : const Color(0xFF0EA5E9),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          // Code Row + Creator info
                          Wrap(
                            spacing: 12,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Code: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                    ),
                                  ),
                                  Text(
                                    lookupKey.keyCode,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      fontFamily: 'monospace',
                                      color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.copy_rounded, size: 13),
                                    padding: const EdgeInsets.symmetric(horizontal: 4),
                                    constraints: const BoxConstraints(),
                                    tooltip: 'Copy Code',
                                    onPressed: () {
                                      Clipboard.setData(ClipboardData(text: lookupKey.keyCode));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Copied ${lookupKey.keyCode}')),
                                      );
                                    },
                                  ),
                                ],
                              ),
                              Text(
                                '• Created by ${lookupKey.creatorName}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                '• ${_formatDate(lookupKey.createdAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Top Action Buttons
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (lookupKey.isOwner) ...[
                          OutlinedButton.icon(
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (ctx) => CreateEditLookupKeyDialog(lookupKey: lookupKey),
                              );
                            },
                            icon: const Icon(Icons.edit_outlined, size: 15),
                            label: const Text('Edit Key', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4F46E5),
                              side: const BorderSide(color: Color(0xFF4F46E5)),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],

                        // 3-dots Menu
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert_rounded,
                            size: 18,
                            color: isDark ? Colors.white : const Color(0xFF475569),
                          ),
                          onSelected: (val) {
                            if (val == 'export_csv') {
                              _exportSingleKey(context, ref);
                            } else if (val == 'audit_logs') {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (ctx) => LookupAuditLogDrawer(lookupKey: lookupKey),
                              );
                            } else if (val == 'usage') {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (ctx) => LookupUsageDrawer(lookupKey: lookupKey),
                              );
                            } else if (val == 'delete') {
                              showDialog(
                                context: context,
                                builder: (ctx) => DeleteLookupConfirmationDialog(lookupKey: lookupKey),
                              );
                            }
                          },
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(
                              value: 'export_csv',
                              child: Row(
                                children: [
                                  Icon(Icons.file_download_outlined, size: 16, color: Color(0xFF10B981)),
                                  SizedBox(width: 8),
                                  Text('Export Values to CSV', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'usage',
                              child: Row(
                                children: [
                                  Icon(Icons.pie_chart_outline_rounded, size: 16, color: Color(0xFF0EA5E9)),
                                  SizedBox(width: 8),
                                  Text('Usage Breakdown', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'audit_logs',
                              child: Row(
                                children: [
                                  Icon(Icons.history_rounded, size: 16, color: Color(0xFF6366F1)),
                                  SizedBox(width: 8),
                                  Text('Audit Logs Timeline', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                            if (lookupKey.isOwner) ...[
                              const PopupMenuDivider(),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded, size: 16, color: Colors.red),
                                    SizedBox(width: 8),
                                    Text('Delete Key', style: TextStyle(fontSize: 12, color: Colors.red)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ],
                ),

                if (lookupKey.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    lookupKey.description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 5 Stats KPI Cards
          LookupStatsCards(
            stats: state.stats,
            lookupKey: lookupKey,
          ),

          const SizedBox(height: 16),

          // Values Table
          LookupValuesTable(
            lookupKey: lookupKey,
            values: state.values,
            isOwner: state.isOwner,
          ),
        ],
      ),
    );
  }
}
