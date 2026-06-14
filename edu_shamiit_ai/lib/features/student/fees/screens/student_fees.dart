import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/student_api_service.dart';
import 'package:edu_shamiit_ai/core/models/student_models.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:edu_shamiit_ai/shared/widgets/azure_grid.dart';
import 'package:edu_shamiit_ai/core/utils/download_helper_stub.dart'
    if (dart.library.js) 'package:edu_shamiit_ai/core/utils/download_helper_web.dart'
    if (dart.library.io) 'package:edu_shamiit_ai/core/utils/download_helper_mobile.dart';

class StudentFees extends ConsumerStatefulWidget {
  const StudentFees({super.key});

  @override
  ConsumerState<StudentFees> createState() => _StudentFeesState();
}

class _StudentFeesState extends ConsumerState<StudentFees>
    with SingleTickerProviderStateMixin {
  final StudentApiService _apiService = StudentApiService();
  late TabController _tabController;
  String _selectedFilter = 'Pending';
  final List<String> _filters = ['Pending', 'Paid', 'All', 'Receipts'];
  List<FeeRecord> _feeRecords = [];
  StudentProfile? _profile;
  double _totalOutstanding = 0;
  bool _isLoading = true;
  String? _error;
  bool _isOutstandingCollapsed = false;
  DateTime _selectedAcademicYearDate = DateTime(2025, 6, 1);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedFilter = _filters[_tabController.index];
        });
      }
    });
    _loadFees();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFees() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final records = await _apiService.getFeeRecords(status: null);
      final profile = await _apiService.getProfile();
      final totalOutstanding = await _apiService.getOutstandingBalance();

      setState(() {
        _feeRecords = records;
        _profile = profile;
        _totalOutstanding = totalOutstanding;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _getFeeIcon(String feeType) {
    final lower = feeType.toLowerCase();
    if (lower.contains('transport') || lower.contains('bus')) return '🚌';
    if (lower.contains('lab')) return '🔬';
    if (lower.contains('library')) return '📚';
    if (lower.contains('exam')) return '📝';
    if (lower.contains('sport')) return '⚽';
    if (lower.contains('uniform')) return '👕';
    if (lower.contains('tuition')) return '🎓';
    return '💳';
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatCurrentDate() {
    return _formatDate(DateTime.now());
  }

  String get _academicYearString {
    final year = _selectedAcademicYearDate.year;
    if (_selectedAcademicYearDate.month >= 6) {
      return '$year-${(year + 1) % 100}';
    } else {
      return '${year - 1}-${year % 100}';
    }
  }

  String _formatAmount(double value) {
    return value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'paid':
        return const Color(0xFF059669);
      case 'partial':
        return const Color(0xFFD97706);
      case 'overdue':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFEF4444);
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'paid':
        return const Color(0xFFECFDF5);
      case 'partial':
        return const Color(0xFFFFF7ED);
      case 'overdue':
        return const Color(0xFFFEF2F2);
      default:
        return const Color(0xFFFFF1F1);
    }
  }

  String _getStatusLabel(String status) {
    switch (status) {
      case 'paid':
        return 'PAID ✓';
      case 'partial':
        return 'PARTIAL';
      case 'overdue':
        return 'OVERDUE';
      default:
        return 'PENDING';
    }
  }



  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF059669))),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('⚠️', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: StudentColors.text3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadFees,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Grid Columns
    final columns = [
      AzureGridColumn<FeeRecord>(
        label: 'Fee Description',
        width: 180.0,
        compare: (a, b) => a.month.compareTo(b.month),
        cellBuilder: (fee) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_getFeeIcon(fee.month), style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fee.month,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      AzureGridColumn<FeeRecord>(
        label: 'Due Date',
        width: 120.0,
        compare: (a, b) => a.dueDate.compareTo(b.dueDate),
        cellBuilder: (fee) => Text(_formatDate(fee.dueDate)),
      ),
      AzureGridColumn<FeeRecord>(
        label: 'Amount',
        width: 100.0,
        compare: (a, b) => a.amount.compareTo(b.amount),
        cellBuilder: (fee) => Text('₹ ${_formatAmount(fee.amount)}'),
      ),
      AzureGridColumn<FeeRecord>(
        label: 'Paid Amount',
        width: 100.0,
        compare: (a, b) => a.paidAmount.compareTo(b.paidAmount),
        cellBuilder: (fee) => Text('₹ ${_formatAmount(fee.paidAmount)}'),
      ),
      AzureGridColumn<FeeRecord>(
        label: 'Outstanding',
        width: 100.0,
        cellBuilder: (fee) {
          final outstanding = fee.amount - fee.paidAmount;
          final isZero = outstanding <= 0;
          return Text(
            '₹ ${_formatAmount(outstanding)}',
            style: TextStyle(
              fontWeight: isZero ? FontWeight.normal : FontWeight.bold,
              color: isZero ? Colors.black87 : const Color(0xFFDC2626),
            ),
          );
        },
      ),
      AzureGridColumn<FeeRecord>(
        label: 'Status',
        width: 90.0,
        compare: (a, b) => a.status.compareTo(b.status),
        cellBuilder: (fee) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getStatusBgColor(fee.status),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _getStatusLabel(fee.status),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _getStatusColor(fee.status),
              ),
            ),
          );
        },
      ),
      AzureGridColumn<FeeRecord>(
        label: 'Action',
        width: 120.0,
        cellBuilder: (fee) {
          final isPaid = fee.status == 'paid';
          if (isPaid) {
            return SizedBox(
              height: 26,
              child: OutlinedButton.icon(
                onPressed: () => _downloadReceiptPdf([fee]),
                icon: const Icon(Icons.receipt_long, size: 12),
                label: const Text('Receipt', style: TextStyle(fontSize: 10)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  side: const BorderSide(color: Color(0xFF059669)),
                  foregroundColor: const Color(0xFF059669),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            );
          } else {
            return SizedBox(
              height: 26,
              child: ElevatedButton.icon(
                onPressed: () => _showPaymentModal(context),
                icon: const Icon(Icons.payment, size: 12, color: Colors.white),
                label: const Text('Pay', style: TextStyle(fontSize: 10, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  backgroundColor: const Color(0xFFEF4444),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
              ),
            );
          }
        },
      ),
    ];

    // Grid Filters
    final filters = [
      AzureGridFilter<FeeRecord>(
        label: 'Status',
        options: ['Paid', 'Partial', 'Overdue', 'Pending'],
        filterFn: (fee, selected) => fee.status.toLowerCase() == selected.toLowerCase(),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF0FDF9),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header with gradient
            Container(
              padding: EdgeInsets.fromLTRB(0, Responsive.headerTopPadding(context), 0, Responsive.isWide(context) ? 8 : 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF064E3B), Color(0xFF059669)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => safeGoBack(context, '/student/dashboard'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fees & Payments',
                                style: TextStyle(
                                  fontFamily: AppFonts.heading,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          // Academic Year Picker
                          InkWell(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _selectedAcademicYearDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() {
                                  _selectedAcademicYearDate = picked;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(30),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.calendar_month, color: Colors.white, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    'AY $_academicYearString',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Collapsible Toggle Button for Outstanding Card
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => setState(() => _isOutstandingCollapsed = !_isOutstandingCollapsed),
                    icon: Icon(_isOutstandingCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up, size: 16),
                    label: Text(_isOutstandingCollapsed ? 'Show Balance Details' : 'Hide Balance Details', style: const TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                ],
              ),
            ),

            // Outstanding Balance Card (overlapping slightly)
            if (!_isOutstandingCollapsed)
              Transform.translate(
                offset: const Offset(0, -14),
                child: Responsive.isWide(context)
                    ? Center(
                        child: SizedBox(
                          width: 500, // Limit width on wide screens
                          child: _buildOutstandingCard(),
                        ),
                      )
                    : _buildOutstandingCard(),
              ),

            // Content Grid Table
            Padding(
              padding: Responsive.contentPadding(context).copyWith(bottom: 16),
              child: AzureGrid<FeeRecord>(
                title: 'All Invoices',
                items: _feeRecords,
                columns: columns,
                filters: filters,
                enableSelection: true,
                disableVerticalScroll: true,
                bulkActions: (context, selected) {
                  final onlyPaid = selected.where((f) => f.status == 'paid').toList();
                  if (onlyPaid.isEmpty) return [];
                  return [
                    ElevatedButton.icon(
                      onPressed: () => _downloadReceiptPdf(onlyPaid),
                      icon: const Icon(Icons.receipt_long, size: 14, color: Colors.white),
                      label: const Text('Download Receipts', style: TextStyle(fontSize: 11, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    )
                  ];
                },
                searchMatcher: (fee) => '${fee.month} ${fee.status} ${fee.transactionId ?? ''}',
                onRefresh: _loadFees,
                mobileCardBuilder: (context, fee) {
                  // Reuses list card builders if defined, otherwise falls back to a card widget.
                  return _buildFeeCard(fee);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOutstandingCard() {
    final double amount = _totalOutstanding;
    final hasOutstanding = amount > 0;

    // Find next due date
    DateTime? nextDueDate;
    final pendingFees = _feeRecords
        .where((f) =>
            f.status == 'pending' ||
            f.status == 'partial' ||
            f.status == 'overdue')
        .toList();
    if (pendingFees.isNotEmpty) {
      pendingFees.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      nextDueDate = pendingFees.first.dueDate;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF065F46).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Outstanding Balance',
            style: TextStyle(
              fontSize: 11,
              color: StudentColors.text3,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '₹ ${_formatAmount(amount)}',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: hasOutstanding
                  ? const Color(0xFFEF4444)
                  : const Color(0xFF059669),
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          if (hasOutstanding && nextDueDate != null) ...[
            Text(
              '⚠️ Due by ${_formatDate(nextDueDate)}',
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else ...[
            const Text(
              '🎉 All fees have been cleared',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF059669),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (hasOutstanding) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showPaymentModal(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('💳', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 8),
                    Text(
                      'Pay Now via UPI / Card / Net Banking',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildFeeCard(FeeRecord fee, {bool showReceipt = false}) {
    final statusColor = _getStatusColor(fee.status);
    final statusBgColor = _getStatusBgColor(fee.status);
    final icon = _getFeeIcon(fee.month);

    final subtitleText = fee.status == 'paid' && fee.paidDate != null
        ? 'Paid: ${_formatDate(fee.paidDate!)}'
        : 'Due: ${_formatDate(fee.dueDate)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(icon, style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),

                // Title and date
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fee.month,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: StudentColors.text,
                        ),
                      ),
                      if (fee.feePeriod != null &&
                          fee.feePeriod!.isNotEmpty) ...[
                        const SizedBox(height: 1),
                        Text(
                          fee.feePeriod!,
                          style: const TextStyle(
                            color: Color(0xFF059669),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        subtitleText,
                        style: const TextStyle(
                          color: StudentColors.text3,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),

                // Amount and status
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${fee.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: statusColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _getStatusLabel(fee.status),
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Fee breakdown if there are late fines or discounts
          if (fee.lateFine > 0 ||
              fee.discount > 0 ||
              fee.status == 'partial') ...[
            Container(
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildBreakdownRow(
                      'Base Amount', fee.amount - fee.lateFine + fee.discount),
                  if (fee.lateFine > 0)
                    _buildBreakdownRow('Late Fine', fee.lateFine,
                        isNegative: false, isRed: true),
                  if (fee.discount > 0)
                    _buildBreakdownRow('Discount', fee.discount,
                        isNegative: true),
                  if (fee.status == 'partial' && fee.paidAmount > 0)
                    _buildBreakdownRow('Amount Paid', fee.paidAmount,
                        isNegative: true),
                  const Divider(height: 12, thickness: 0.5),
                  _buildBreakdownRow(
                    fee.status == 'partial' ? 'Balance Due' : 'Net Amount',
                    fee.dueAmount > 0
                        ? fee.dueAmount
                        : fee.amount + fee.lateFine - fee.discount,
                    isBold: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Action row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Row(
              children: [
                if (fee.paymentMethod != null && fee.status == 'paid') ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FFF4),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Text(
                      '${_getPayMethodIcon(fee.paymentMethod!)} ${fee.paymentMethod!.toUpperCase()}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF059669),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (fee.status == 'pending' ||
                    fee.status == 'partial' ||
                    fee.status == 'overdue') ...[
                  SizedBox(
                    height: 30,
                    child: ElevatedButton(
                      onPressed: () =>
                          _showPaymentModal(context, targetFee: fee),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF059669),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        fee.status == 'partial'
                            ? 'Pay Balance ₹${fee.dueAmount.toStringAsFixed(0)}'
                            : 'Pay Now',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ] else if (showReceipt || _selectedFilter == 'Receipts') ...[
                  SizedBox(
                    height: 30,
                    child: ElevatedButton.icon(
                      onPressed: () => _downloadReceiptPdf([fee]),
                      icon: const Icon(Icons.download, size: 12),
                      label: const Text(
                        'Receipt',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFECFDF5),
                        foregroundColor: const Color(0xFF059669),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownRow(
    String label,
    double amount, {
    bool isNegative = false,
    bool isRed = false,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: const Color(0xFF64748B),
              fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
          Text(
            '${isNegative ? '-' : ''}₹${amount.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 10,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: isRed
                  ? const Color(0xFFEF4444)
                  : isNegative
                      ? const Color(0xFF059669)
                      : const Color(0xFF1E293B),
            ),
          ),
        ],
      ),
    );
  }





  String _getPayMethodIcon(String method) {
    switch (method.toLowerCase()) {
      case 'upi':
        return '📱';
      case 'card':
        return '💳';
      case 'netbanking':
        return '🏦';
      default:
        return '💰';
    }
  }

  String _getPayMethodLabel(String? method) {
    if (method == null) return 'Online Payment';
    switch (method.toLowerCase()) {
      case 'upi':
        return 'UPI Transfer';
      case 'card':
        return 'Credit/Debit Card';
      case 'netbanking':
        return 'Net Banking';
      default:
        return method.toUpperCase();
    }
  }

  Future<void> _downloadReceiptPdf(List<FeeRecord> items) async {
    final firstFee = items.first;
    final studentName = _profile?.fullName ?? 'Student';
    final studentId = _profile?.rollNumber ?? 'N/A';
    final studentClass =
        '${_profile?.className ?? ''} ${_profile?.section ?? ''}'.trim();
    final txId = firstFee.transactionId ??
        'TXN-${firstFee.id.substring(0, 8).toUpperCase()}';
    final receiptNo =
        'REC/${firstFee.paidDate?.year ?? 2026}/${firstFee.id.substring(0, 6).toUpperCase()}';
    final payDate = firstFee.paidDate != null
        ? _formatDate(firstFee.paidDate!)
        : _formatCurrentDate();
    final payMethod = _getPayMethodLabel(firstFee.paymentMethod);
    final double totalPaidAmount =
        items.fold(0.0, (sum, f) => sum + f.paidAmount);

    // Generate PDF
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#059669'),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'EduSHAMIIT',
                          style: pw.TextStyle(
                            fontSize: 22,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'Fee Payment Receipt',
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.white,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          receiptNo,
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                        pw.Text(
                          'Academic Year 2025-26',
                          style: const pw.TextStyle(
                              fontSize: 10, color: PdfColors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              // Status badge
              pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#ECFDF5'),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColor.fromHex('#A7F3D0')),
                ),
                child: pw.Text(
                  'PAYMENT CONFIRMED',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#059669'),
                  ),
                ),
              ),

              pw.SizedBox(height: 20),

              // Student details section
              pw.Text(
                'Student Details',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1E293B'),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                ),
                child: pw.Column(
                  children: [
                    _pdfRow('Student Name', studentName),
                    _pdfRow('Roll Number', studentId),
                    if (studentClass.isNotEmpty) _pdfRow('Class', studentClass),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // Fee details section
              pw.Text(
                'Fee Details',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1E293B'),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                ),
                child: pw.Column(
                  children: [
                    if (items.length == 1) ...[
                      _pdfRow('Fee Type', firstFee.month),
                      if (firstFee.feePeriod != null)
                        _pdfRow('Period', firstFee.feePeriod!),
                      if (firstFee.description != null)
                        _pdfRow('Description', firstFee.description!),
                      _pdfRow('Base Amount',
                          'Rs. ${firstFee.amount.toStringAsFixed(2)}'),
                      if (firstFee.lateFine > 0)
                        _pdfRow('Late Fine',
                            'Rs. ${firstFee.lateFine.toStringAsFixed(2)}',
                            isRed: true),
                      if (firstFee.discount > 0)
                        _pdfRow('Discount',
                            '-Rs. ${firstFee.discount.toStringAsFixed(2)}',
                            isGreen: true),
                    ] else ...[
                      for (var item in items) ...[
                        _pdfRow('${item.month} (${item.feePeriod ?? ''})',
                            'Rs. ${item.paidAmount.toStringAsFixed(2)}'),
                        if (item.lateFine > 0)
                          _pdfRow('  - Late Fine',
                              'Rs. ${item.lateFine.toStringAsFixed(2)}',
                              isRed: true),
                        if (item.discount > 0)
                          _pdfRow('  - Discount',
                              '-Rs. ${item.discount.toStringAsFixed(2)}',
                              isGreen: true),
                      ],
                    ],
                    pw.Divider(color: PdfColor.fromHex('#E2E8F0')),
                    _pdfRow('Total Amount Paid',
                        'Rs. ${totalPaidAmount.toStringAsFixed(2)}',
                        isBold: true, isGreen: true),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // Payment details
              pw.Text(
                'Payment Details',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#1E293B'),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius:
                      const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColor.fromHex('#E2E8F0')),
                ),
                child: pw.Column(
                  children: [
                    _pdfRow('Payment Date', payDate),
                    _pdfRow('Payment Mode', payMethod),
                    _pdfRow('Transaction ID', txId),
                    _pdfRow('Status', 'Verified & Confirmed', isGreen: true),
                  ],
                ),
              ),

              pw.Spacer(),

              // Footer
              pw.Divider(color: PdfColor.fromHex('#E2E8F0')),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'This is a computer-generated receipt. No signature required.',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Generated: ${_formatDate(DateTime.now())}',
                    style: const pw.TextStyle(
                        fontSize: 8, color: PdfColors.grey600),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();
    final filename =
        'Receipt_${firstFee.month.replaceAll(' ', '_')}_$receiptNo.pdf';

    if (kIsWeb) {
      try {
        await getDownloadHelper().downloadBytes(pdfBytes, filename);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📄 Receipt downloaded successfully: $filename'),
              backgroundColor: const Color(0xFF059669),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      } catch (e) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async => pdfBytes,
          name: filename,
        );
      }
    } else {
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdfBytes,
        name: filename,
      );
    }
  }

  pw.Widget _pdfRow(
    String label,
    String value, {
    bool isBold = false,
    bool isRed = false,
    bool isGreen = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey600),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 11,
              fontWeight: isBold ? pw.FontWeight.bold : null,
              color: isRed
                  ? PdfColors.red700
                  : isGreen
                      ? PdfColor.fromHex('#059669')
                      : PdfColor.fromHex('#1E293B'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpiAppItem(
      String name, String emoji, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color:
                    isSelected ? const Color(0xFF4F46E5) : StudentColors.text2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPaymentModal(BuildContext context, {FeeRecord? targetFee}) {
    // If targetFee is null, we create a temporary "Outstanding Fee" representing the total outstanding balance
    final fee = targetFee ??
        FeeRecord(
          id: '',
          month: 'Outstanding Fee',
          amount: _totalOutstanding,
          paidAmount: 0,
          dueAmount: _totalOutstanding,
          status: 'pending',
          dueDate: DateTime.now(),
        );

    if (fee.id.isEmpty && _totalOutstanding <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending fees to pay.')),
      );
      return;
    }

    final double amountToPay = fee.dueAmount > 0 ? fee.dueAmount : fee.amount;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        String currentStep = 'select';
        String? errorMessage;

        final upiController = TextEditingController();
        final cardNumberController = TextEditingController();
        final cardExpiryController = TextEditingController();
        final cardCvvController = TextEditingController();
        final cardNameController = TextEditingController();
        final amountController =
            TextEditingController(text: amountToPay.toStringAsFixed(0));

        String selectedBank = 'State Bank of India';
        String? selectedUpiApp;

        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> processPayment(String method) async {
              final double paymentAmount =
                  double.tryParse(amountController.text) ?? 0.0;
              if (paymentAmount <= 0) {
                setModalState(() {
                  errorMessage = 'Please enter a valid amount to pay.';
                });
                return;
              }
              if (paymentAmount > amountToPay) {
                setModalState(() {
                  errorMessage =
                      'Payment amount cannot exceed the balance due of ₹${amountToPay.toStringAsFixed(0)}.';
                });
                return;
              }

              setModalState(() {
                currentStep = 'loading';
                errorMessage = null;
              });

              try {
                if (fee.id.isEmpty) {
                  // Pay all outstanding fees!
                  final pendingFeesList = _feeRecords
                      .where((f) =>
                          f.status == 'pending' ||
                          f.status == 'partial' ||
                          f.status == 'overdue')
                      .toList();

                  if (pendingFeesList.isEmpty) {
                    throw Exception('No pending fees found to pay');
                  }

                  final feeIds = pendingFeesList.map((f) => f.id).toList();
                  final result = await _apiService.payBulk(
                    feeIds: feeIds,
                    amount: paymentAmount,
                    paymentMethod: method,
                    upiId: method == 'upi' ? upiController.text : null,
                    cardNumber:
                        method == 'card' ? cardNumberController.text : null,
                    cardExpiry:
                        method == 'card' ? cardExpiryController.text : null,
                    cardCvv: method == 'card' ? cardCvvController.text : null,
                    bankName: method == 'netbanking' ? selectedBank : null,
                  );

                  if (ctx.mounted && Navigator.canPop(ctx)) {
                    Navigator.pop(ctx);
                  }
                  if (context.mounted) {
                    _showPaymentSuccess(context, result);
                  }
                  _loadFees();
                } else {
                  // Pay single fee
                  final result = await _apiService.payDirect(
                    feeId: fee.id,
                    amount: paymentAmount,
                    paymentMethod: method,
                    upiId: method == 'upi' ? upiController.text : null,
                    cardNumber:
                        method == 'card' ? cardNumberController.text : null,
                    cardExpiry:
                        method == 'card' ? cardExpiryController.text : null,
                    cardCvv: method == 'card' ? cardCvvController.text : null,
                    bankName: method == 'netbanking' ? selectedBank : null,
                  );

                  if (ctx.mounted && Navigator.canPop(ctx)) {
                    Navigator.pop(ctx);
                  }
                  if (context.mounted) {
                    _showPaymentSuccess(context, result);
                  }
                  _loadFees();
                }
              } catch (e) {
                setModalState(() {
                  currentStep = method;
                  errorMessage = e.toString().replaceAll('ApiException: ', '');
                });
              }
            }

            Widget buildHeader(String title) {
              return Column(
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: StudentColors.text,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            }

            Widget buildFeeSummary() {
              final double enteredAmount =
                  double.tryParse(amountController.text) ?? 0.0;
              final double remainingAmount = amountToPay - enteredAmount;
              final bool isInvalid =
                  enteredAmount <= 0 || enteredAmount > amountToPay;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fee.month,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: StudentColors.text),
                              ),
                              if (fee.feePeriod != null) ...[
                                const SizedBox(height: 2),
                                Text(fee.feePeriod!,
                                    style: const TextStyle(
                                        color: StudentColors.text3,
                                        fontSize: 10)),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          width: 110,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isInvalid
                                  ? Colors.red
                                  : const Color(0xFF059669),
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(left: 8, right: 2),
                                child: Text(
                                  '₹',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF059669),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: amountController,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                          decimal: true),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF059669),
                                  ),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(
                                        vertical: 8, horizontal: 2),
                                    border: InputBorder.none,
                                  ),
                                  onChanged: (val) {
                                    setModalState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16, thickness: 0.5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Remaining Balance after Payment:',
                          style: TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500),
                        ),
                        Text(
                          isInvalid
                              ? 'Invalid Amount'
                              : '₹ ${remainingAmount.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: remainingAmount > 0
                                ? const Color(0xFFD97706)
                                : const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }

            Widget buildLockBanner() {
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🔒', style: TextStyle(fontSize: 12)),
                    SizedBox(width: 8),
                    Text(
                      '256-bit SSL Encrypted · Secure Payment',
                      style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF059669),
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }

            Widget buildErrorMsg() {
              if (errorMessage == null) return const SizedBox.shrink();
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFCA5A5)),
                ),
                child: Row(
                  children: [
                    const Text('⚠️', style: TextStyle(fontSize: 14)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        errorMessage!,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFB91C1C),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              );
            }

            Widget body;
            if (currentStep == 'select') {
              body = Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  buildHeader('💳 Select Payment Method'),
                  buildFeeSummary(),
                  buildLockBanner(),
                  buildErrorMsg(),
                  _buildPaymentMethod(
                      '📱', 'UPI Payment', 'Google Pay, PhonePe, Paytm', () {
                    final double enteredAmount =
                        double.tryParse(amountController.text) ?? 0.0;
                    if (enteredAmount <= 0) {
                      setModalState(() {
                        errorMessage = 'Please enter a valid amount to pay.';
                      });
                      return;
                    }
                    if (enteredAmount > amountToPay) {
                      setModalState(() {
                        errorMessage =
                            'Payment amount cannot exceed the balance due of ₹${amountToPay.toStringAsFixed(0)}.';
                      });
                      return;
                    }
                    setModalState(() {
                      currentStep = 'upi';
                      errorMessage = null;
                    });
                  }),
                  _buildPaymentMethod(
                      '💳', 'Credit / Debit Card', 'Visa, Mastercard, RuPay',
                      () {
                    final double enteredAmount =
                        double.tryParse(amountController.text) ?? 0.0;
                    if (enteredAmount <= 0) {
                      setModalState(() {
                        errorMessage = 'Please enter a valid amount to pay.';
                      });
                      return;
                    }
                    if (enteredAmount > amountToPay) {
                      setModalState(() {
                        errorMessage =
                            'Payment amount cannot exceed the balance due of ₹${amountToPay.toStringAsFixed(0)}.';
                      });
                      return;
                    }
                    setModalState(() {
                      currentStep = 'card';
                      errorMessage = null;
                    });
                  }),
                  _buildPaymentMethod(
                      '🏦', 'Net Banking', 'All major banks supported', () {
                    final double enteredAmount =
                        double.tryParse(amountController.text) ?? 0.0;
                    if (enteredAmount <= 0) {
                      setModalState(() {
                        errorMessage = 'Please enter a valid amount to pay.';
                      });
                      return;
                    }
                    if (enteredAmount > amountToPay) {
                      setModalState(() {
                        errorMessage =
                            'Payment amount cannot exceed the balance due of ₹${amountToPay.toStringAsFixed(0)}.';
                      });
                      return;
                    }
                    setModalState(() {
                      currentStep = 'netbank';
                      errorMessage = null;
                    });
                  }),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                ],
              );
            } else if (currentStep == 'upi') {
              body = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildHeader('📱 UPI Payment'),
                  buildFeeSummary(),
                  buildLockBanner(),
                  buildErrorMsg(),
                  const Text(
                    'Select UPI App',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: StudentColors.text),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildUpiAppItem(
                          'Google Pay', '📱', selectedUpiApp == 'gpay', () {
                        setModalState(() {
                          selectedUpiApp = 'gpay';
                          upiController.text = 'student@okaxis';
                          errorMessage = null;
                        });
                      }),
                      _buildUpiAppItem(
                          'PhonePe', '💜', selectedUpiApp == 'phonepe', () {
                        setModalState(() {
                          selectedUpiApp = 'phonepe';
                          upiController.text = 'student@ybl';
                          errorMessage = null;
                        });
                      }),
                      _buildUpiAppItem('Paytm', '💙', selectedUpiApp == 'paytm',
                          () {
                        setModalState(() {
                          selectedUpiApp = 'paytm';
                          upiController.text = 'student@paytm';
                          errorMessage = null;
                        });
                      }),
                      _buildUpiAppItem('BHIM', '🇮🇳', selectedUpiApp == 'bhim',
                          () {
                        setModalState(() {
                          selectedUpiApp = 'bhim';
                          upiController.text = 'student@upi';
                          errorMessage = null;
                        });
                      }),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Or enter UPI ID manually',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: StudentColors.text),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: upiController,
                    decoration: InputDecoration(
                      hintText: 'e.g. mobile@upi',
                      hintStyle: const TextStyle(
                          fontSize: 12, color: StudentColors.text3),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.alternate_email, size: 16),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setModalState(() {
                            currentStep = 'select';
                          }),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (upiController.text.trim().isEmpty ||
                                !upiController.text.contains('@')) {
                              setModalState(() {
                                errorMessage = 'Invalid UPI ID Format';
                              });
                            } else {
                              processPayment('upi');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                              'Pay ₹${(double.tryParse(amountController.text) ?? amountToPay).toStringAsFixed(0)}'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            } else if (currentStep == 'card') {
              body = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildHeader('💳 Card Details'),
                  buildFeeSummary(),
                  buildLockBanner(),
                  buildErrorMsg(),
                  const Text('Cardholder Name',
                      style:
                          TextStyle(fontSize: 11, color: StudentColors.text3)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: cardNameController,
                    decoration: InputDecoration(
                      hintText: 'Naresh Upadhyay',
                      hintStyle: const TextStyle(
                          fontSize: 12, color: StudentColors.text3),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  const Text('Card Number',
                      style:
                          TextStyle(fontSize: 11, color: StudentColors.text3)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: cardNumberController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'XXXX XXXX XXXX XXXX',
                      hintStyle: const TextStyle(
                          fontSize: 12, color: StudentColors.text3),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.credit_card, size: 16),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Expiry Date',
                                style: TextStyle(
                                    fontSize: 11, color: StudentColors.text3)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: cardExpiryController,
                              decoration: InputDecoration(
                                hintText: 'MM/YY',
                                hintStyle: const TextStyle(
                                    fontSize: 12, color: StudentColors.text3),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('CVV',
                                style: TextStyle(
                                    fontSize: 11, color: StudentColors.text3)),
                            const SizedBox(height: 4),
                            TextField(
                              controller: cardCvvController,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              decoration: InputDecoration(
                                hintText: '•••',
                                hintStyle: const TextStyle(
                                    fontSize: 12, color: StudentColors.text3),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setModalState(() {
                            currentStep = 'select';
                          }),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            if (cardNameController.text.trim().isEmpty) {
                              setModalState(() {
                                errorMessage = 'Cardholder Name Required';
                              });
                            } else if (cardNumberController.text
                                    .replaceAll(' ', '')
                                    .length <
                                12) {
                              setModalState(() {
                                errorMessage = 'Invalid Card Number';
                              });
                            } else if (cardExpiryController.text
                                .trim()
                                .isEmpty) {
                              setModalState(() {
                                errorMessage = 'Card Expiry Required';
                              });
                            } else if (cardCvvController.text.length != 3) {
                              setModalState(() {
                                errorMessage = 'Invalid CVV (3 digits)';
                              });
                            } else {
                              processPayment('card');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                              'Pay ₹${(double.tryParse(amountController.text) ?? amountToPay).toStringAsFixed(0)}'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            } else if (currentStep == 'netbank') {
              body = Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  buildHeader('🏦 Net Banking'),
                  buildFeeSummary(),
                  buildLockBanner(),
                  buildErrorMsg(),
                  const Text(
                    'Select Your Bank',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: StudentColors.text),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedBank,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down),
                        items: <String>[
                          'State Bank of India',
                          'HDFC Bank',
                          'ICICI Bank',
                          'Axis Bank',
                          'Kotak Mahindra Bank',
                          'Punjab National Bank',
                          'Bank of Baroda',
                          'Canara Bank',
                        ].map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value,
                                style: const TextStyle(fontSize: 13)),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setModalState(() {
                              selectedBank = newValue;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'You will be redirected to your bank\'s secure payment portal.',
                    style: TextStyle(fontSize: 10, color: StudentColors.text3),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => setModalState(() {
                            currentStep = 'select';
                          }),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => processPayment('netbanking'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(
                              'Pay ₹${(double.tryParse(amountController.text) ?? amountToPay).toStringAsFixed(0)}'),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            } else {
              // Loading step
              body = const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Color(0xFF059669))),
                      SizedBox(height: 16),
                      Text(
                        'Processing secure payment...',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Do not close this window or press back.',
                        style:
                            TextStyle(color: StudentColors.text3, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Padding(
              padding:
                  EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.all(20),
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.85,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SingleChildScrollView(child: body),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentMethod(
      String icon, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Text(icon, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: StudentColors.text3, fontSize: 10)),
                ],
              ),
            ),
            const Text('›',
                style: TextStyle(fontSize: 20, color: Color(0xFFCBD5E1))),
          ],
        ),
      ),
    );
  }

  void _showPaymentSuccess(BuildContext context, Map<String, dynamic> result) {
    final data = result['data'] as Map<String, dynamic>? ?? {};
    final recipient = data['recipient_details'] as Map<String, dynamic>? ?? {};
    final String transactionId = data['transaction_id'] ??
        'TXN-${DateTime.now().millisecondsSinceEpoch}';
    final double amount =
        double.tryParse(data['amount']?.toString() ?? '0') ?? 0;
    final String method = data['payment_method'] ?? 'UPI';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.8),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('✅', style: TextStyle(fontSize: 40)),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Payment Successful!',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF059669),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '₹ ${amount.toStringAsFixed(0)} paid via ${method.toUpperCase()}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildSuccessRow('Transaction ID', transactionId),
                    const SizedBox(height: 6),
                    _buildSuccessRow('Date', _formatCurrentDate()),
                    const SizedBox(height: 6),
                    _buildSuccessRow('Status', '✓ Confirmed'),
                  ],
                ),
              ),
              if (recipient.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Recipient Details',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0284C7)),
                      ),
                      const SizedBox(height: 8),
                      _buildSuccessRow(
                          'Name', recipient['account_holder_name'] ?? ''),
                      if (method == 'upi' && recipient['upi_id'] != null) ...[
                        const SizedBox(height: 4),
                        _buildSuccessRow('UPI ID', recipient['upi_id']),
                      ] else if (recipient['account_number'] != null) ...[
                        const SizedBox(height: 4),
                        _buildSuccessRow('Bank', recipient['bank_name'] ?? ''),
                        const SizedBox(height: 4),
                        _buildSuccessRow(
                            'Account No.', recipient['account_number']),
                        const SizedBox(height: 4),
                        _buildSuccessRow(
                            'IFSC Code', recipient['ifsc_code'] ?? ''),
                      ],
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF059669),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Done',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
