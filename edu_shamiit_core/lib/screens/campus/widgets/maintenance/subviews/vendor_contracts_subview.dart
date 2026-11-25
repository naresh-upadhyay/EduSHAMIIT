import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../models/maintenance_models.dart';
import '../../../providers/maintenance_provider.dart';
import '../dialogs/add_edit_vendor_contract_dialog.dart';
import '../dialogs/create_edit_maintenance_dialog.dart';

class VendorContractsSubview extends ConsumerStatefulWidget {
  const VendorContractsSubview({super.key});

  @override
  ConsumerState<VendorContractsSubview> createState() => _VendorContractsSubviewState();
}

class _VendorContractsSubviewState extends ConsumerState<VendorContractsSubview> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _selectedStatus = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAddEditModal([MaintenanceVendorItem? vendor]) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddEditVendorContractDialog(
        vendor: vendor,
        onSaved: () => ref.read(maintenanceProvider.notifier).loadVendors(),
      ),
    );
  }

  Future<void> _deleteVendor(MaintenanceVendorItem v) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Vendor Contract'),
        content: Text('Are you sure you want to delete vendor "${v.vendorName}"? Active maintenance assignments may be affected.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await ref.read(maintenanceProvider.notifier).deleteVendor(v.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Vendor contract removed successfully!' : 'Failed to delete vendor.'),
            backgroundColor: success ? const Color(0xFF059669) : const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  void _viewAgreementDocument(MaintenanceVendorItem v) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.picture_as_pdf, color: Colors.red, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                v.contractDocumentName ?? 'Service_Agreement_Contract.pdf',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    _buildDocMetaRow('Vendor Organization', v.vendorName, textPrimary, textMuted),
                    _buildDocMetaRow('Contract Reference', v.contractRefNo ?? 'AMC-2026-N/A', textPrimary, textMuted),
                    _buildDocMetaRow('Agreement Period', '${v.contractStart != null ? DateFormat('dd MMM yyyy').format(v.contractStart!) : "N/A"} to ${v.contractEnd != null ? DateFormat('dd MMM yyyy').format(v.contractEnd!) : "N/A"}', textPrimary, textMuted),
                    _buildDocMetaRow('Contract Annual Value', '₹ ${NumberFormat('#,##,###').format(v.contractValue)}', const Color(0xFF10B981), textMuted),
                    _buildDocMetaRow('Guaranteed SLA', '${v.slaResponseHours}h Response / ${v.slaResolutionHours}h Resolution', const Color(0xFF2563EB), textMuted),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('Document Storage URL:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted)),
              const SizedBox(height: 4),
              SelectableText(
                v.agreementUrl ?? 'https://assets.edushamiit.org/contracts/Vendor_Contract.pdf',
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), decoration: TextDecoration.underline),
              ),
              if (v.notes != null && v.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Terms & Notes:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted)),
                const SizedBox(height: 4),
                Text(v.notes!, style: TextStyle(fontSize: 11.5, color: textPrimary)),
              ],
            ],
          ),
        ),
        actions: [
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: v.agreementUrl ?? ''));
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contract link copied to clipboard!')));
            },
            icon: const Icon(Icons.copy, size: 14),
            label: const Text('Copy Link', style: TextStyle(fontSize: 11.5)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Downloading contract "${v.contractDocumentName ?? "agreement.pdf"}"...'),
                  backgroundColor: const Color(0xFF2563EB),
                ),
              );
            },
            icon: const Icon(Icons.download, size: 14, color: Colors.white),
            label: const Text('Download Contract', style: TextStyle(fontSize: 11.5, color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
          ),
        ],
      ),
    );
  }

  Widget _buildDocMetaRow(String label, String value, Color valColor, Color labelColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11.5, color: labelColor)),
          Text(value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: valColor)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(maintenanceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final allVendors = state.vendors;

    // Filter vendors by search, category, and status
    final query = _searchController.text.trim().toLowerCase();
    final filtered = allVendors.where((v) {
      if (_selectedCategory != 'All' && v.serviceCategory != _selectedCategory) return false;
      if (_selectedStatus == 'Active' && !v.isActive) return false;
      if (_selectedStatus == 'Inactive' && v.isActive) return false;
      if (query.isNotEmpty) {
        final match = v.vendorName.toLowerCase().contains(query) ||
            (v.contactPerson ?? '').toLowerCase().contains(query) ||
            (v.phone ?? '').toLowerCase().contains(query) ||
            (v.email ?? '').toLowerCase().contains(query) ||
            (v.contractRefNo ?? '').toLowerCase().contains(query);
        if (!match) return false;
      }
      return true;
    }).toList();

    // Metrics calculations
    final totalVendors = allVendors.length;
    final activeAmcs = allVendors.where((v) => v.isActive && v.contractType == 'AMC').length;
    final totalVal = allVendors.fold<double>(0.0, (acc, v) => acc + v.contractValue);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. KPI Badges Bar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    'Total Vendors',
                    '$totalVendors Partners',
                    Icons.store_mall_directory_outlined,
                    const Color(0xFF2563EB),
                    isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    'Active AMC Contracts',
                    '$activeAmcs Active',
                    Icons.verified_outlined,
                    const Color(0xFF10B981),
                    isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    'Annual Contract Value',
                    '₹ ${NumberFormat('#,##,###').format(totalVal)}',
                    Icons.currency_rupee,
                    const Color(0xFFF59E0B),
                    isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildMetricTile(
                    'Avg Response SLA',
                    '4.0 Hours',
                    Icons.timer_outlined,
                    const Color(0xFF8B5CF6),
                    isDark,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Main Vendor Contracts Table Card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Action & Filter Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.handshake_outlined, size: 16, color: Color(0xFF2563EB)),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Service Vendors & AMC Contracts (${filtered.length})',
                            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: textPrimary),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openAddEditModal(),
                        icon: const Icon(Icons.add, size: 15, color: Colors.white),
                        label: const Text('Add Vendor / Contract', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, thickness: 1),

                // Search & Filter Bar
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: borderColor),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (_) => setState(() {}),
                            style: TextStyle(fontSize: 12, color: textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Search by vendor name, contact person, phone, email, ref...',
                              hintStyle: TextStyle(fontSize: 12, color: textMuted),
                              prefixIcon: Icon(Icons.search, size: 16, color: textMuted),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: borderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: AppSearchableDropdown<String>.fromMenuItems(
                            value: _selectedCategory,
                            style: TextStyle(fontSize: 12, color: textPrimary),
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All Categories')),
                              DropdownMenuItem(value: 'HVAC', child: Text('HVAC (AC)')),
                              DropdownMenuItem(value: 'Electrical', child: Text('Electrical')),
                              DropdownMenuItem(value: 'Plumbing', child: Text('Plumbing')),
                              DropdownMenuItem(value: 'AV Equipment', child: Text('AV Equipment')),
                              DropdownMenuItem(value: 'Civil / Building', child: Text('Civil')),
                            ],
                            onChanged: (v) => setState(() => _selectedCategory = v ?? 'All'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: borderColor),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: AppSearchableDropdown<String>.fromMenuItems(
                            value: _selectedStatus,
                            style: TextStyle(fontSize: 12, color: textPrimary),
                            items: const [
                              DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                              DropdownMenuItem(value: 'Active', child: Text('Active AMCs')),
                              DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                            ],
                            onChanged: (v) => setState(() => _selectedStatus = v ?? 'All'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Table
                filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.handshake_outlined, size: 40, color: textMuted),
                              const SizedBox(height: 10),
                              Text('No vendor contracts match your criteria.', style: TextStyle(fontSize: 13, color: textMuted)),
                              const SizedBox(height: 10),
                              ElevatedButton(
                                onPressed: () => _openAddEditModal(),
                                child: const Text('Add First Vendor Contract'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minWidth: 1000),
                          child: DataTable(
                            headingRowHeight: 36,
                            dataRowMinHeight: 44,
                            dataRowMaxHeight: 52,
                            horizontalMargin: 12,
                            columnSpacing: 14,
                            headingRowColor: WidgetStateProperty.all(
                              isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            ),
                            columns: const [
                              DataColumn(label: Text('#', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Vendor Name & Ref', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Contact Person', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Mobile Number', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Email ID', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Category & Type', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Contract Value', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Agreement Document', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Status', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                              DataColumn(label: Text('Actions', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                            ],
                            rows: List.generate(filtered.length, (idx) {
                              final v = filtered[idx];
                              return DataRow(
                                cells: [
                                  DataCell(Text('${idx + 1}', style: TextStyle(fontSize: 11.5, color: textMuted))),
                                  DataCell(
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(v.vendorName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textPrimary)),
                                        Text(v.contractRefNo ?? 'REF-N/A', style: TextStyle(fontSize: 10.5, color: textMuted)),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(v.contactPerson ?? 'Unassigned', style: TextStyle(fontSize: 11.5, color: textPrimary))),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.phone, size: 12, color: Color(0xFF10B981)),
                                        const SizedBox(width: 4),
                                        Text(v.phone ?? 'N/A', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary)),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.email_outlined, size: 12, color: Color(0xFF2563EB)),
                                        const SizedBox(width: 4),
                                        ConstrainedBox(
                                          constraints: const BoxConstraints(maxWidth: 130),
                                          child: Text(v.email ?? 'N/A', style: TextStyle(fontSize: 11, color: textMuted), overflow: TextOverflow.ellipsis),
                                        ),
                                      ],
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('${v.serviceCategory} • ${v.contractType}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                                    ),
                                  ),
                                  DataCell(
                                    Text('₹ ${NumberFormat('#,##,###').format(v.contractValue)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                                  ),
                                  DataCell(
                                    InkWell(
                                      onTap: () => _viewAgreementDocument(v),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: borderColor),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.picture_as_pdf_outlined, size: 13, color: Colors.red),
                                            const SizedBox(width: 4),
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 90),
                                              child: Text(
                                                v.contractDocumentName ?? 'View PDF',
                                                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: v.isActive ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        v.isActive ? 'Active AMC' : 'Inactive',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: v.isActive ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                        ),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 15),
                                          tooltip: 'Edit Vendor Contract',
                                          color: const Color(0xFF2563EB),
                                          onPressed: () => _openAddEditModal(v),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          icon: const Icon(Icons.add_task_outlined, size: 15),
                                          tooltip: 'Raise Work Order for this Vendor',
                                          color: const Color(0xFF10B981),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              barrierDismissible: false,
                                              builder: (_) => CreateEditMaintenanceDialog(
                                                initialTitle: '${v.serviceCategory} Service Call - ${v.vendorName}',
                                              ),
                                            );
                                          },
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                        ),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 15),
                                          tooltip: 'Delete Vendor',
                                          color: const Color(0xFFEF4444),
                                          onPressed: () => _deleteVendor(v),
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(4),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
