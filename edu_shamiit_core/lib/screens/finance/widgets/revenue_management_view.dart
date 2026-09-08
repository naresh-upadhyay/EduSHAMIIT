import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/finance_provider.dart';
import '../models/finance_models.dart';

class RevenueManagementView extends ConsumerStatefulWidget {
  const RevenueManagementView({super.key});

  @override
  ConsumerState<RevenueManagementView> createState() => _RevenueManagementViewState();
}

class _RevenueManagementViewState extends ConsumerState<RevenueManagementView> {
  String _selectedCategory = 'All Categories';
  String _searchQuery = '';

  static const List<String> _categories = [
    'All Categories',
    'Tuition Fee',
    'Admission Fee',
    'Registration Fee',
    'Examination Fee',
    'Transport Fee',
    'Hostel Fee',
    'Library Fee',
    'Laboratory Fee',
    'Computer & Tech Fee',
    'Sports & Activity Fee',
    'Donations & Grants',
    'Facility & Ground Rental',
    'Other Revenue',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Sample/mock institutional revenue records for visualization & API sync
    final revenueRecords = [
      {
        'date': '2026-09-01',
        'ref': 'REV-2026-00891',
        'category': 'Tuition Fee',
        'party': 'Aarav Sharma (Class 10A)',
        'method': 'Online UPI',
        'amount': 25000,
        'status': 'Received',
      },
      {
        'date': '2026-09-01',
        'ref': 'REV-2026-00890',
        'category': 'Facility & Ground Rental',
        'party': 'City Sports Club',
        'method': 'Bank Transfer',
        'amount': 150000,
        'status': 'Received',
      },
      {
        'date': '2026-08-31',
        'ref': 'REV-2026-00889',
        'category': 'Donations & Grants',
        'party': 'Education Trust India',
        'method': 'Cheque',
        'amount': 500000,
        'status': 'Received',
      },
      {
        'date': '2026-08-30',
        'ref': 'REV-2026-00888',
        'category': 'Admission Fee',
        'party': 'Priya Verma (Class 1B)',
        'method': 'Cash',
        'amount': 12000,
        'status': 'Received',
      },
      {
        'date': '2026-08-28',
        'ref': 'REV-2026-00887',
        'category': 'Transport Fee',
        'party': 'Rohan Patel (Class 8C)',
        'method': 'Online Gateway',
        'amount': 4500,
        'status': 'Received',
      },
    ];

    final filteredRecords = revenueRecords.where((r) {
      final matchesCategory = _selectedCategory == 'All Categories' || r['category'] == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          r['ref'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r['party'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r['category'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header & Primary Action ─────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Institutional Revenue Management',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Track student fees, grants, facility rentals, donations, and non-fee revenue sources.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _showRecordRevenueModal(context),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Record Revenue'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ─── Revenue Summary KPI Row ──────────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width > 1100 ? 4 : (width > 700 ? 2 : 1);
              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildSummaryCard('Total Revenue (YTD)', '₹3,52,91,560', '+14.2% vs last year', Icons.trending_up_rounded, const Color(0xFF10B981), isDark),
                  _buildSummaryCard('This Month Revenue', '₹42,80,000', '+8.5% vs target', Icons.account_balance_rounded, const Color(0xFF6366F1), isDark),
                  _buildSummaryCard('Other Non-Fee Revenue', '₹8,91,560', 'Grants, Rentals & Donations', Icons.volunteer_activism_rounded, const Color(0xFFF59E0B), isDark),
                  _buildSummaryCard('Expected Collections', '₹85,83,440', 'Pending Student Dues', Icons.pending_actions_rounded, const Color(0xFFEF4444), isDark),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          // ─── Filters & Search Bar ────────────────────────────────────────────
          Card(
            elevation: 0,
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search reference, student, party, or category...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: isDark ? Colors.white24 : const Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  DropdownButton<String>(
                    value: _selectedCategory,
                    underline: const SizedBox(),
                    items: _categories.map((cat) {
                      return DropdownMenuItem(
                        value: cat,
                        child: Text(cat, style: const TextStyle(fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedCategory = val);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ─── Revenue Transactions Table ──────────────────────────────────────
          Card(
            elevation: 0,
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Revenue Transactions Ledger',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Showing ${filteredRecords.length} records',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(
                        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      ),
                      columns: const [
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Reference No')),
                        DataColumn(label: Text('Category')),
                        DataColumn(label: Text('Party / Student')),
                        DataColumn(label: Text('Payment Method')),
                        DataColumn(label: Text('Amount (₹)')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: filteredRecords.map((r) {
                        final amountVal = (r['amount'] as int);
                        final formattedAmount = '₹${amountVal.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}';

                        return DataRow(
                          cells: [
                            DataCell(Text(r['date'].toString(), style: const TextStyle(fontSize: 13))),
                            DataCell(Text(r['ref'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  r['category'].toString(),
                                  style: const TextStyle(color: Color(0xFF6366F1), fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                            DataCell(Text(r['party'].toString(), style: const TextStyle(fontSize: 13))),
                            DataCell(Text(r['method'].toString(), style: const TextStyle(fontSize: 13))),
                            DataCell(Text(formattedAmount, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF10B981), fontSize: 13))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  r['status'].toString(),
                                  style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.print_rounded, size: 18),
                                    onPressed: () {},
                                    tooltip: 'Print Receipt',
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.file_download_outlined, size: 18),
                                    onPressed: () {},
                                    tooltip: 'Download PDF',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, String sub, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontFamily: 'Outfit',
                  ),
                ),
                Text(
                  sub,
                  style: TextStyle(
                    fontSize: 11,
                    color: color,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showRecordRevenueModal(BuildContext context) {
    final catController = TextEditingController(text: 'Tuition Fee');
    final amountController = TextEditingController();
    final partyController = TextEditingController();
    final refController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Record Institutional Revenue'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 450,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: catController,
                    decoration: const InputDecoration(labelText: 'Revenue Category', hintText: 'e.g. Tuition Fee, Facility Rental, Grant'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Amount (₹)', hintText: 'e.g. 50000'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: partyController,
                    decoration: const InputDecoration(labelText: 'Student / Party Name', hintText: 'e.g. Aarav Sharma or Education Trust'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: refController,
                    decoration: const InputDecoration(labelText: 'Transaction Reference No.', hintText: 'e.g. UPI-99881100'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Revenue transaction recorded successfully!')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
              child: const Text('Save Revenue', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
