import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lookup_models.dart';
import '../providers/lookup_provider.dart';
import 'dialogs/add_edit_lookup_value_dialog.dart';
import 'dialogs/create_edit_lookup_key_dialog.dart';
import 'dialogs/delete_lookup_confirmation_dialog.dart';

class LookupKeyCard extends ConsumerWidget {
  final LookupKeyModel lookupKey;
  final bool isSelected;
  final VoidCallback onTap;

  const LookupKeyCard({
    super.key,
    required this.lookupKey,
    required this.isSelected,
    required this.onTap,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = _getIconBgColor(lookupKey.keyCode);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF312E81).withValues(alpha: 0.3) : const Color(0xFFEEF2FF))
              : (isDark ? const Color(0xFF1E293B) : Colors.white),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF6366F1)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Left Rounded Icon
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getIconData(lookupKey.icon),
                size: 20,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 12),

            // Middle: Name, Code, Badges
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          lookupKey.keyName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: lookupKey.isActive
                              ? const Color(0xFF10B981).withValues(alpha: 0.12)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          lookupKey.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: lookupKey.isActive
                                ? const Color(0xFF10B981)
                                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),

                  // Code with Copy Button
                  Row(
                    children: [
                      Text(
                        'Code: ',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ),
                      Flexible(
                        child: Text(
                          lookupKey.keyCode,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: lookupKey.keyCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied ${lookupKey.keyCode} to clipboard'),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(Icons.copy_rounded, size: 12, color: Color(0xFF94A3B8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Right: Values Count & Type
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${lookupKey.totalValuesCount} Values',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lookupKey.keyType == 'SYSTEM' ? 'System' : 'Custom',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Owner Indicator Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: lookupKey.isOwner
                            ? const Color(0xFF6366F1).withValues(alpha: 0.12)
                            : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        lookupKey.isOwner ? 'Owner' : 'View Only',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: lookupKey.isOwner
                              ? const Color(0xFF6366F1)
                              : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // More Actions Menu
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert_rounded,
                size: 16,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              padding: EdgeInsets.zero,
              onSelected: (val) async {
                if (val == 'edit') {
                  showDialog(
                    context: context,
                    builder: (ctx) => CreateEditLookupKeyDialog(lookupKey: lookupKey),
                  );
                } else if (val == 'add_value') {
                  showDialog(
                    context: context,
                    builder: (ctx) => const AddEditLookupValueDialog(),
                  );
                } else if (val == 'toggle_status') {
                  final newStatus = lookupKey.isActive ? 'INACTIVE' : 'ACTIVE';
                  await ref.read(lookupProvider.notifier).updateLookupKey(lookupKey.id, {'status': newStatus});
                } else if (val == 'delete') {
                  showDialog(
                    context: context,
                    builder: (ctx) => DeleteLookupConfirmationDialog(lookupKey: lookupKey),
                  );
                }
              },
              itemBuilder: (ctx) => [
                if (lookupKey.isOwner) ...[
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit_outlined, size: 15, color: Color(0xFF4F46E5)),
                        SizedBox(width: 8),
                        Text('Edit Key', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'add_value',
                    child: Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded, size: 15, color: Color(0xFF10B981)),
                        SizedBox(width: 8),
                        Text('Add Value', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'toggle_status',
                    child: Row(
                      children: [
                        Icon(
                          lookupKey.isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                          size: 15,
                          color: const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 8),
                        Text(lookupKey.isActive ? 'Deactivate Key' : 'Activate Key', style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded, size: 15, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete Key', style: TextStyle(fontSize: 12, color: Colors.red)),
                      ],
                    ),
                  ),
                ] else ...[
                  const PopupMenuItem(
                    enabled: false,
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 15, color: Color(0xFF94A3B8)),
                        SizedBox(width: 8),
                        Text('View Only (Non-Owner)', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
