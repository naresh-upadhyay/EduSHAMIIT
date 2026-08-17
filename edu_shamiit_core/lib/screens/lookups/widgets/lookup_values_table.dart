import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lookup_models.dart';
import '../providers/lookup_provider.dart';
import 'dialogs/add_edit_lookup_value_dialog.dart';
import 'dialogs/bulk_add_values_dialog.dart';
import 'dialogs/delete_lookup_confirmation_dialog.dart';
import 'dialogs/import_lookup_values_dialog.dart';
import 'dialogs/lookup_audit_log_drawer.dart';
import 'dialogs/lookup_usage_drawer.dart';

class LookupValuesTable extends ConsumerStatefulWidget {
  final LookupKeyModel lookupKey;
  final List<LookupValueModel> values;
  final bool isOwner;

  const LookupValuesTable({
    super.key,
    required this.lookupKey,
    required this.values,
    required this.isOwner,
  });

  @override
  ConsumerState<LookupValuesTable> createState() => _LookupValuesTableState();
}

class _LookupValuesTableState extends ConsumerState<LookupValuesTable> {
  bool _isReorderMode = false;
  List<LookupValueModel> _reorderList = [];
  final TextEditingController _valSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _reorderList = List.from(widget.values);
  }

  @override
  void didUpdateWidget(covariant LookupValuesTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isReorderMode) {
      _reorderList = List.from(widget.values);
    }
  }

  @override
  void dispose() {
    _valSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(lookupProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  'Values',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${state.valuesTotalRecords}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ),
                const Spacer(),

                if (_isReorderMode) ...[
                  // Reorder Controls
                  OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isReorderMode = false;
                        _reorderList = List.from(widget.values);
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () async {
                      final orderedIds = _reorderList.map((e) => e.id).toList();
                      final ok = await ref.read(lookupProvider.notifier).reorderValues(orderedIds);
                      if (ok) {
                        setState(() => _isReorderMode = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sort order updated successfully'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Save Order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                ] else ...[
                  // Add Value Button (Creator/Owner Only)
                  if (widget.isOwner) ...[
                    ElevatedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => const AddEditLookupValueDialog(),
                        );
                      },
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Add Value', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // More Menu (Bulk Add, Import CSV, Reorder, Audit Logs)
                  PopupMenuButton<String>(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.more_horiz_rounded,
                        size: 16,
                        color: isDark ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                    onSelected: (val) {
                      if (val == 'bulk_add') {
                        showDialog(
                          context: context,
                          builder: (ctx) => BulkAddValuesDialog(lookupKey: widget.lookupKey),
                        );
                      } else if (val == 'import_csv') {
                        showDialog(
                          context: context,
                          builder: (ctx) => ImportLookupValuesDialog(lookupKey: widget.lookupKey),
                        );
                      } else if (val == 'reorder') {
                        setState(() {
                          _isReorderMode = true;
                          _reorderList = List.from(widget.values);
                        });
                      } else if (val == 'audit_logs') {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => LookupAuditLogDrawer(lookupKey: widget.lookupKey),
                        );
                      } else if (val == 'usage') {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => LookupUsageDrawer(lookupKey: widget.lookupKey),
                        );
                      }
                    },
                    itemBuilder: (ctx) => [
                      if (widget.isOwner) ...[
                        const PopupMenuItem(
                          value: 'bulk_add',
                          child: Row(
                            children: [
                              Icon(Icons.playlist_add_rounded, size: 16, color: Color(0xFF4F46E5)),
                              SizedBox(width: 8),
                              Text('Bulk Add Values', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'import_csv',
                          child: Row(
                            children: [
                              Icon(Icons.upload_file_rounded, size: 16, color: Color(0xFF0EA5E9)),
                              SizedBox(width: 8),
                              Text('Import from CSV', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'reorder',
                          child: Row(
                            children: [
                              Icon(Icons.drag_indicator_rounded, size: 16, color: Color(0xFFF59E0B)),
                              SizedBox(width: 8),
                              Text('Reorder Sequence', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                      ],
                      const PopupMenuItem(
                        value: 'audit_logs',
                        child: Row(
                          children: [
                            Icon(Icons.history_rounded, size: 16, color: Color(0xFF6366F1)),
                            SizedBox(width: 8),
                            Text('Audit Trail Logs', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'usage',
                        child: Row(
                          children: [
                            Icon(Icons.pie_chart_outline_rounded, size: 16, color: Color(0xFF10B981)),
                            SizedBox(width: 8),
                            Text('Usage Breakdown', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const Divider(height: 1),

          // Values Content
          if (state.isValuesLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
            )
          else if (widget.values.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.format_list_bulleted_rounded,
                      size: 40,
                      color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No values found for this lookup key',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    if (widget.isOwner) ...[
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => const AddEditLookupValueDialog(),
                          );
                        },
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text('Add First Value'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else if (_isReorderMode)
            _buildReorderableList(isDark)
          else
            _buildStandardTable(context, isDark, isMobile),

          // Pagination Footer
          if (!_isReorderMode && state.valuesTotalPages > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Page ${state.valuesPage} of ${state.valuesTotalPages} (${state.valuesTotalRecords} total)',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded),
                        iconSize: 18,
                        onPressed: state.valuesPage > 1
                            ? () => ref.read(lookupProvider.notifier).setValuesPage(state.valuesPage - 1)
                            : null,
                      ),
                      Text(
                        '${state.valuesPage}',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded),
                        iconSize: 18,
                        onPressed: state.valuesPage < state.valuesTotalPages
                            ? () => ref.read(lookupProvider.notifier).setValuesPage(state.valuesPage + 1)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReorderableList(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Premium Reordering Instruction Banner
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1E1B4B), const Color(0xFF0F172A)]
                  : [const Color(0xFFEEF2FF), const Color(0xFFF8FAFC)],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.swap_vert_rounded, color: Color(0xFF6366F1), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Drag & Drop Sequence Ordering',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1E1B4B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Hold and drag items using the grip handle to customize the sequence options appear in dropdowns across ERP modules.',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Interactive Drag-and-Drop Cards List (Entire row draggable, no default handle overlap)
        ReorderableListView.builder(
          buildDefaultDragHandles: false,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          itemCount: _reorderList.length,
          onReorderItem: (oldIdx, newIdx) {
            setState(() {
              final item = _reorderList.removeAt(oldIdx);
              _reorderList.insert(newIdx, item);
            });
          },
          itemBuilder: (ctx, idx) {
            final val = _reorderList[idx];
            return ReorderableDragStartListener(
              key: ValueKey(val.id),
              index: idx,
              child: MouseRegion(
                cursor: SystemMouseCursors.grab,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      // Drag Grip Handle Container
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.drag_indicator_rounded,
                          color: Color(0xFF6366F1),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Order Sequence Number Pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          '#${idx + 1}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Value Name & Code
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              val.valueName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE0E7FF),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    val.valueCode,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF4F46E5),
                                    ),
                                  ),
                                ),
                                if (val.description.isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      val.description,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: val.isActive
                              ? const Color(0xFF10B981).withValues(alpha: 0.12)
                              : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: val.isActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              val.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: val.isActive
                                    ? const Color(0xFF10B981)
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Position Indicator Pill (Fully visible with no overlay)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.reorder_rounded,
                              size: 13,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Position #${idx + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStandardTable(BuildContext context, bool isDark, bool isMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableContent = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Full-Width Responsive Table Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'VALUE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'CODE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'STATUS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      'SORT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'USED IN',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Text(
                      'ACTIONS',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Table Rows
            ...widget.values.map((val) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? const Color(0xFF334155).withValues(alpha: 0.5) : const Color(0xFFF1F5F9),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Value Name & Description
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            val.valueName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          if (val.description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                val.description,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Value Code
                    Expanded(
                      flex: 2,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              ),
                            ),
                            child: Text(
                              val.valueCode,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 13),
                            color: const Color(0xFF94A3B8),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Copy Code',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: val.valueCode));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Copied ${val.valueCode} to clipboard'),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Status Badge
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: val.isActive
                                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: val.isActive ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  val.isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: val.isActive
                                        ? const Color(0xFF10B981)
                                        : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Sort Order
                    Expanded(
                      flex: 1,
                      child: Text(
                        '#${val.sortOrder}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        ),
                      ),
                    ),

                    // Used In
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (ctx) => LookupUsageDrawer(
                              lookupKey: widget.lookupKey,
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  val.usage.modulesSummary.isNotEmpty ? val.usage.modulesSummary : '0 Modules',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0EA5E9),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(Icons.info_outline_rounded, size: 12, color: Color(0xFF0EA5E9)),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Actions
                    SizedBox(
                      width: 80,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.isOwner) ...[
                            // Edit Button
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16),
                              color: const Color(0xFF4F46E5),
                              tooltip: 'Edit Value',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AddEditLookupValueDialog(value: val),
                                );
                              },
                            ),
                            const SizedBox(width: 6),
                            // Delete Button
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 16),
                              color: Colors.red,
                              tooltip: 'Delete Value',
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => DeleteLookupValueDialog(lookupKey: widget.lookupKey, value: val),
                                );
                              },
                            ),
                          ] else ...[
                            const Tooltip(
                              message: 'View only (Only the owner can modify)',
                              child: Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        );

        if (constraints.maxWidth < 680) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 680,
              child: tableContent,
            ),
          );
        }

        return tableContent;
      },
    );
  }
}
