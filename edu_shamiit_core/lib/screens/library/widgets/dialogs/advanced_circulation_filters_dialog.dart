import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/circulation_provider.dart';
import 'premium_date_range_dialog.dart';

class AdvancedCirculationFiltersDialog extends ConsumerStatefulWidget {
  const AdvancedCirculationFiltersDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const AdvancedCirculationFiltersDialog(),
    );
  }

  @override
  ConsumerState<AdvancedCirculationFiltersDialog> createState() => _AdvancedCirculationFiltersDialogState();
}

class _AdvancedCirculationFiltersDialogState extends ConsumerState<AdvancedCirculationFiltersDialog> {
  late String _selectedStatus;
  late String _selectedType;
  late String _searchIn;
  late String? _dateFrom;
  late String? _dateTo;
  String _selectedRole = 'ALL';
  String _selectedFineFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    final state = ref.read(circulationProvider);
    _selectedStatus = state.selectedStatus;
    _selectedType = state.selectedTransactionType;
    _searchIn = state.searchIn;
    _dateFrom = state.dateFrom;
    _dateTo = state.dateTo;
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_selectedStatus != 'All' && _selectedStatus != 'ALL') count++;
    if (_selectedType != 'All' && _selectedType != 'ALL') count++;
    if (_searchIn != 'All Transactions') count++;
    if (_dateFrom != null || _dateTo != null) count++;
    if (_selectedRole != 'ALL') count++;
    if (_selectedFineFilter != 'ALL') count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(circulationProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 700;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: isCompact ? 380 : 640,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131B2E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(isDark),

              const Divider(height: 1),

              // Filter Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section 1: Transaction Status
                      _buildSectionLabel('TRANSACTION STATUS', isDark),
                      const SizedBox(height: 8),
                      _buildChipsGroup(
                        options: ['All', 'ISSUED', 'RETURNED', 'OVERDUE', 'RENEWED', 'LOST', 'DAMAGED'],
                        selectedValue: _selectedStatus,
                        onSelected: (val) => setState(() => _selectedStatus = val),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 18),

                      // Section 2: Transaction Type
                      _buildSectionLabel('TRANSACTION TYPE', isDark),
                      const SizedBox(height: 8),
                      _buildChipsGroup(
                        options: ['All', 'MANUAL_ISSUE', 'ONLINE_REQUEST', 'SELF_CHECKOUT', 'RENEWAL'],
                        selectedValue: _selectedType,
                        onSelected: (val) => setState(() => _selectedType = val),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 18),

                      // Section 3: Search Scope
                      _buildSectionLabel('SEARCH FIELD SCOPE', isDark),
                      const SizedBox(height: 8),
                      _buildChipsGroup(
                        options: state.filterOptions.searchInFields.isNotEmpty
                            ? state.filterOptions.searchInFields
                            : ['All Transactions', 'Member Name', 'Member Code', 'Book Title', 'ISBN', 'Barcode', 'Transaction ID'],
                        selectedValue: _searchIn,
                        onSelected: (val) => setState(() => _searchIn = val),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 18),

                      // Section 4: Date Range Filter
                      _buildSectionLabel('DATE RANGE FILTER', isDark),
                      const SizedBox(height: 8),
                      _buildDateRangeSelector(isDark),
                      const SizedBox(height: 18),

                      // Section 5: Member Role
                      _buildSectionLabel('BORROWER ROLE', isDark),
                      const SizedBox(height: 8),
                      _buildChipsGroup(
                        options: state.filterOptions.roles.isNotEmpty
                            ? state.filterOptions.roles.map((r) => r.toLowerCase() == 'all' ? 'ALL' : r.toLowerCase()).toList()
                            : ['ALL', 'student', 'teacher', 'staff', 'parent'],
                        labels: {
                          'ALL': 'All Roles',
                          for (final r in state.filterOptions.roles)
                            if (r.toLowerCase() != 'all') r.toLowerCase(): '${r[0].toUpperCase()}${r.substring(1)}s'
                        },
                        selectedValue: _selectedRole,
                        onSelected: (val) => setState(() => _selectedRole = val),
                        isDark: isDark,
                      ),
                      const SizedBox(height: 18),


                      // Section 6: Fine & Payment
                      _buildSectionLabel('FINES & FINANCIAL STATUS', isDark),
                      const SizedBox(height: 8),
                      _buildChipsGroup(
                        options: ['ALL', 'NO_FINE', 'HAS_FINE', 'UNPAID', 'PAID', 'WAIVED'],
                        labels: {
                          'ALL': 'All Fines',
                          'NO_FINE': 'No Fine (₹0)',
                          'HAS_FINE': 'Has Overdue Fine',
                          'UNPAID': 'Unpaid Fines',
                          'PAID': 'Paid Fines',
                          'WAIVED': 'Waived Fines'
                        },
                        selectedValue: _selectedFineFilter,
                        onSelected: (val) => setState(() => _selectedFineFilter = val),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: 1),

              // Footer
              _buildFooter(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.filter_list_rounded, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Text(
                  'More Filters',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                if (_activeFiltersCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_activeFiltersCount active',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.7,
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
      ),
    );
  }

  Widget _buildChipsGroup({
    required List<String> options,
    Map<String, String>? labels,
    required String selectedValue,
    required ValueChanged<String> onSelected,
    required bool isDark,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final isSelected = selectedValue.toUpperCase() == opt.toUpperCase();
        final displayLabel = labels != null && labels.containsKey(opt)
            ? labels[opt]!
            : (opt == 'ALL' || opt == 'All'
                ? 'All'
                : opt.replaceAll('_', ' ').toLowerCase().split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' '));

        return ChoiceChip(
          selected: isSelected,
          showCheckmark: false,
          label: Text(
            displayLabel,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
            ),
          ),
          selectedColor: const Color(0xFF6366F1),
          backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: isSelected
                  ? const Color(0xFF6366F1)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            ),
          ),
          onSelected: (_) => onSelected(opt),
        );
      }).toList(),
    );
  }

  Widget _buildDateRangeSelector(bool isDark) {
    final hasDates = _dateFrom != null && _dateTo != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasDates ? const Color(0xFF6366F1) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.date_range_rounded, size: 18, color: Color(0xFF6366F1)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              hasDates
                  ? '${DateFormat('dd MMM yyyy').format(DateTime.parse(_dateFrom!))} — ${DateFormat('dd MMM yyyy').format(DateTime.parse(_dateTo!))}'
                  : 'No date range selected (All transactions)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: hasDates ? FontWeight.w700 : FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
          if (hasDates) ...[
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 16),
              tooltip: 'Clear date filter',
              onPressed: () {
                setState(() {
                  _dateFrom = null;
                  _dateTo = null;
                });
              },
            ),
          ],
          ElevatedButton.icon(
            icon: const Icon(Icons.edit_calendar_rounded, size: 14, color: Colors.white),
            label: Text(hasDates ? 'Change' : 'Select Range', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final result = await PremiumDateRangeDialog.show(
                context,
                initialStartDate: _dateFrom != null ? DateTime.tryParse(_dateFrom!) : null,
                initialEndDate: _dateTo != null ? DateTime.tryParse(_dateTo!) : null,
              );
              if (result != null) {
                setState(() {
                  if (result.isCleared) {
                    _dateFrom = null;
                    _dateTo = null;
                  } else if (result.start != null && result.end != null) {
                    _dateFrom = DateFormat('yyyy-MM-dd').format(result.start!);
                    _dateTo = DateFormat('yyyy-MM-dd').format(result.end!);
                  }
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton.icon(
            icon: const Icon(Icons.restart_alt_rounded, size: 16),
            label: const Text('Reset All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
            onPressed: () {
              setState(() {
                _selectedStatus = 'All';
                _selectedType = 'All';
                _searchIn = 'All Transactions';
                _dateFrom = null;
                _dateTo = null;
                _selectedRole = 'ALL';
                _selectedFineFilter = 'ALL';
              });
            },
          ),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                  label: const Text('Apply Filters', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: () {
                    final notifier = ref.read(circulationProvider.notifier);
                    notifier.setStatus(_selectedStatus);
                    notifier.setTransactionType(_selectedType);
                    notifier.setSearchIn(_searchIn);
                    notifier.setDateRange(_dateFrom, _dateTo);
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
