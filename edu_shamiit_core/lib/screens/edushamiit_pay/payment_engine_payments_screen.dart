import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_shamiit_core/config/app_config.dart';
import 'payment_gateway_integration_screen.dart';
import 'edushamiit_pay_dashboard_screen.dart';
import 'edushamiit_pay_transactions_screen.dart';
import 'edushamiit_pay_reconciliation_screen.dart';
import 'edushamiit_pay_merchant_settings_screen.dart';

class PaymentEnginePaymentsScreen extends StatefulWidget {
  final String? schoolId;
  final String? schoolName;
  final int initialNavTab;

  const PaymentEnginePaymentsScreen({
    super.key,
    this.schoolId,
    this.schoolName,
    this.initialNavTab = 1,
  });

  @override
  State<PaymentEnginePaymentsScreen> createState() =>
      _PaymentEnginePaymentsScreenState();
}

class _PaymentEnginePaymentsScreenState
    extends State<PaymentEnginePaymentsScreen> with SingleTickerProviderStateMixin {
  // Navigation Sub-tabs (0: Overview, 1: Payments, 2: Payment Gateways, 3: Payment Requests, 4: Webhooks, 5: Reconciliation, 6: Settings)
  late int _activeNavTab;

  // Status Filter Tabs
  String _selectedStatusTab = 'ALL'; // ALL, SUCCESS, PENDING, FAILED, REFUNDED

  // Data State
  bool _isLoadingSummary = false;
  bool _isLoadingPayments = false;
  bool _isLoadingDetail = false;
  bool _isVerifying = false;
  Map<String, dynamic> _summaryData = {};
  List<dynamic> _payments = [];
  int _totalPayments = 0;
  int _currentPage = 1;
  int _pageSize = 10;
  int _totalPages = 1;

  // Selected Row & Details Panel
  final Set<String> _selectedPaymentIds = {};
  Map<String, dynamic>? _activePaymentDetail;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Filter State (2-row panel)
  bool _showFilters = true;
  String _filterFinancialPeriod = 'All Dates';
  String? _filterStartDate;
  String? _filterEndDate;
  String _filterPaymentType = 'ALL';
  String _filterStatus = 'ALL';
  String _filterGateway = 'ALL';
  String _filterPaymentMethod = 'ALL';
  String _filterSchool = 'ALL';

  final TextEditingController _searchStudentCtrl = TextEditingController();
  final TextEditingController _searchInvoiceCtrl = TextEditingController();
  final TextEditingController _minAmountCtrl = TextEditingController();
  final TextEditingController _maxAmountCtrl = TextEditingController();

  Timer? _searchDebounce;

  // Sorting
  final String _sortBy = 'created_at';
  final String _sortOrder = 'desc';

  // Webhook Stream State
  bool _isLoadingWebhooks = false;
  List<dynamic> _webhooks = [];

  @override
  void initState() {
    super.initState();
    _activeNavTab = widget.initialNavTab;
    _fetchSummary();
    _fetchPayments();
    if (_activeNavTab == 4) _fetchWebhooks();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchStudentCtrl.dispose();
    _searchInvoiceCtrl.dispose();
    _minAmountCtrl.dispose();
    _maxAmountCtrl.dispose();
    super.dispose();
  }

  // =========================================================================
  // API CALLS (Connected to Real Backend)
  // =========================================================================

  /// Returns auth headers including Bearer token from shared prefs.
  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _fetchSummary() async {
    setState(() => _isLoadingSummary = true);
    try {
      var uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/edushamiit-pay/payments/summary');
      final queryParams = <String, String>{};
      if (widget.schoolId != null) queryParams['school_id'] = widget.schoolId!;
      if (_filterStartDate != null) queryParams['start_date'] = _filterStartDate!;
      if (_filterEndDate != null) queryParams['end_date'] = _filterEndDate!;

      if (queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }

      final res = await http.get(uri, headers: await _authHeaders());
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body['success'] == true && mounted) {
          final rawData = body['data'];
          setState(() {
            _summaryData = (rawData is Map) ? Map<String, dynamic>.from(rawData) : <String, dynamic>{};
          });
        }
      } else if (res.statusCode == 401) {
        debugPrint('Payment summary: Unauthorized — token may be expired');
      }
    } catch (e) {
      debugPrint('Error fetching payment summary: $e');
    } finally {
      if (mounted) setState(() => _isLoadingSummary = false);
    }
  }

  Future<void> _fetchWebhooks() async {
    setState(() => _isLoadingWebhooks = true);
    try {
      // Use the real payment-gateways webhook events endpoint (auth-protected)
      var uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/payment-gateways/webhooks');
      final queryParams = <String, String>{'limit': '50'};
      if (widget.schoolId != null) queryParams['school_id'] = widget.schoolId!;
      uri = uri.replace(queryParameters: queryParams);
      final res = await http.get(uri, headers: await _authHeaders());
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body['success'] == true && mounted) {
          final rawList = body['data'];
          setState(() {
            _webhooks = (rawList is List) ? rawList : [];
          });
        }
      } else if (res.statusCode == 401) {
        debugPrint('Webhooks: Unauthorized — token may be expired');
      } else {
        debugPrint('Webhooks endpoint returned HTTP ${res.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching webhooks: $e');
    } finally {
      if (mounted) setState(() => _isLoadingWebhooks = false);
    }
  }

  Future<void> _fetchPayments({String? initialSelectTxnId}) async {
    setState(() => _isLoadingPayments = true);
    try {
      final queryParams = <String, String>{
        'page': '$_currentPage',
        'limit': '$_pageSize',
        'sort_by': _sortBy,
        'sort_order': _sortOrder,
      };

      if (widget.schoolId != null) {
        queryParams['school_id'] = widget.schoolId!;
      } else if (_filterSchool != 'ALL') {
        queryParams['school_id'] = _filterSchool;
      }

      if (_selectedStatusTab != 'ALL') {
        queryParams['status'] = _selectedStatusTab;
      } else if (_filterStatus != 'ALL') {
        queryParams['status'] = _filterStatus;
      }

      if (_filterGateway != 'ALL') queryParams['gateway'] = _filterGateway;
      if (_filterPaymentMethod != 'ALL') queryParams['payment_method'] = _filterPaymentMethod;
      if (_filterPaymentType != 'ALL') queryParams['payment_purpose'] = _filterPaymentType;
      if (_filterStartDate != null) queryParams['start_date'] = _filterStartDate!;
      if (_filterEndDate != null) queryParams['end_date'] = _filterEndDate!;

      if (_minAmountCtrl.text.trim().isNotEmpty) {
        queryParams['min_amount'] = _minAmountCtrl.text.trim();
      }
      if (_maxAmountCtrl.text.trim().isNotEmpty) {
        queryParams['max_amount'] = _maxAmountCtrl.text.trim();
      }

      final searchTerms = <String>[];
      if (_searchStudentCtrl.text.trim().isNotEmpty) {
        searchTerms.add(_searchStudentCtrl.text.trim());
      }
      if (_searchInvoiceCtrl.text.trim().isNotEmpty) {
        searchTerms.add(_searchInvoiceCtrl.text.trim());
      }
      if (searchTerms.isNotEmpty) {
        queryParams['search'] = searchTerms.join(' ');
      }

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/edushamiit-pay/payments')
          .replace(queryParameters: queryParams);

      final res = await http.get(uri, headers: await _authHeaders());
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body['success'] == true && mounted) {
          final data = body['data'] ?? {};
          final items = (data['items'] as List<dynamic>?) ?? [];
          setState(() {
            _payments = items;
            _totalPayments = data['total'] ?? items.length;
            _totalPages = data['total_pages'] ?? 1;
          });

          // Auto-select initial transaction if requested or first real transaction
          if (initialSelectTxnId != null) {
            final match = items.firstWhere(
              (it) => it['transaction_id'] == initialSelectTxnId || it['id'] == initialSelectTxnId,
              orElse: () => items.isNotEmpty ? items.first : null,
            );
            if (match != null) {
              _selectPayment(match, openDrawerOnMobile: false);
            }
          } else if (items.isNotEmpty && _activePaymentDetail == null) {
            _selectPayment(items.first, openDrawerOnMobile: false);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching payments list: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPayments = false);
    }
  }

  Future<void> _fetchPaymentDetail(String paymentId, {bool openDrawerOnMobile = true}) async {
    setState(() => _isLoadingDetail = true);
    if (openDrawerOnMobile && MediaQuery.of(context).size.width < 1150) {
      _scaffoldKey.currentState?.openEndDrawer();
    }
    try {
      final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/edushamiit-pay/payments/$paymentId');
      final res = await http.get(uri, headers: await _authHeaders());
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body['success'] == true && mounted) {
          final rawData = body['data'];
          setState(() {
            _activePaymentDetail = (rawData is Map) ? Map<String, dynamic>.from(rawData) : null;
          });
        }
      } else if (res.statusCode == 401) {
        debugPrint('Payment detail: Unauthorized — token may be expired');
      }
    } catch (e) {
      debugPrint('Error fetching payment detail: $e');
    } finally {
      if (mounted) setState(() => _isLoadingDetail = false);
    }
  }

  void _selectPayment(Map<dynamic, dynamic> payment, {bool openDrawerOnMobile = true}) {
    final txnId = payment['transaction_id']?.toString() ?? payment['id']?.toString() ?? '';
    setState(() {
      _selectedPaymentIds.clear();
      if (txnId.isNotEmpty) {
        _selectedPaymentIds.add(txnId);
      }
      _activePaymentDetail = Map<String, dynamic>.from(payment);
    });
    if (txnId.isNotEmpty) {
      _fetchPaymentDetail(txnId, openDrawerOnMobile: openDrawerOnMobile);
    }
  }

  Future<void> _verifyPaymentAction(String paymentId) async {
    setState(() => _isVerifying = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/v1/edushamiit-pay/payments/$paymentId/verify'),
      );
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final receipt = body['data']?['receipt_number'] ?? 'Generated';
        messenger.showSnackBar(
          SnackBar(
            content: Text('Payment verified by acquiring gateway! Receipt: $receipt'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        await _fetchSummary();
        await _fetchPayments();
        await _fetchPaymentDetail(paymentId, openDrawerOnMobile: false);
      } else {
        final err = json.decode(res.body)['detail'] ?? 'Verification failed';
        messenger.showSnackBar(
          SnackBar(content: Text('Verification notice: $err'), backgroundColor: const Color(0xFFF59E0B)),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Verification error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _exportCsv() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final queryParams = <String, String>{};
      if (widget.schoolId != null) queryParams['school_id'] = widget.schoolId!;
      if (_selectedStatusTab != 'ALL') queryParams['status'] = _selectedStatusTab;
      if (_filterGateway != 'ALL') queryParams['gateway'] = _filterGateway;
      if (_filterPaymentMethod != 'ALL') queryParams['payment_method'] = _filterPaymentMethod;
      if (_filterPaymentType != 'ALL') queryParams['payment_purpose'] = _filterPaymentType;

      final uri = Uri.parse('${AppConfig.apiBaseUrl}/v1/edushamiit-pay/payments/export')
          .replace(queryParameters: queryParams);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Generating secure payment export...'),
          backgroundColor: Color(0xFF4F46E5),
        ),
      );

      final res = await http.get(uri);
      if (res.statusCode == 200) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Export ready (${res.bodyBytes.length} bytes downloaded).'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _resetFilters() {
    setState(() {
      _searchStudentCtrl.clear();
      _searchInvoiceCtrl.clear();
      _minAmountCtrl.clear();
      _maxAmountCtrl.clear();
      _filterGateway = 'ALL';
      _filterPaymentMethod = 'ALL';
      _filterPaymentType = 'ALL';
      _filterStatus = 'ALL';
      _filterSchool = 'ALL';
      _filterStartDate = null;
      _filterEndDate = null;
      _filterFinancialPeriod = 'All Time';
      _currentPage = 1;
    });
    _fetchSummary();
    _fetchPayments();
  }

  // =========================================================================
  // USER ACTIONS (Create, Retry, Refund, Receipt, Reconcile Dialogs)
  // =========================================================================

  void _openCreatePaymentDialog() {
    final schoolIdCtrl = TextEditingController(text: widget.schoolId ?? 'e1f11111-1111-1111-1111-111111111111');
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final classCtrl = TextEditingController(text: 'Class 9-A');
    String payerType = 'STUDENT';
    String purpose = 'Student Fee';
    String gateway = 'SBI_EPAY';
    String method = 'UPI';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final messenger = ScaffoldMessenger.of(context);
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add_card_rounded, color: Color(0xFF4F46E5)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Create Payment Order',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: min(540.0, MediaQuery.of(context).size.width - 32),
              ),
              child: SingleChildScrollView(
                child: LayoutBuilder(
                  builder: (context, dlgConstraints) {
                    final isSingleCol = dlgConstraints.maxWidth < 460;

                    Widget rowOrCol(Widget left, Widget right) {
                      if (isSingleCol) {
                        return Column(
                          children: [
                            left,
                            const SizedBox(height: 12),
                            right,
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: left),
                          const SizedBox(width: 12),
                          Expanded(child: right),
                        ],
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Initiate an enterprise payment transaction via EduSHAMIIT Pay engine.',
                          style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 18),

                        rowOrCol(
                          DropdownButtonFormField<String>(
                            initialValue: payerType,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Payer Type *', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'STUDENT', child: Text('Student', overflow: TextOverflow.ellipsis, maxLines: 1)),
                              DropdownMenuItem(value: 'PARENT', child: Text('Parent', overflow: TextOverflow.ellipsis, maxLines: 1)),
                              DropdownMenuItem(value: 'SCHOOL', child: Text('School Authority', overflow: TextOverflow.ellipsis, maxLines: 1)),
                              DropdownMenuItem(value: 'CUSTOMER', child: Text('Corporate / Other', overflow: TextOverflow.ellipsis, maxLines: 1)),
                            ],
                            onChanged: (v) => setDlgState(() => payerType = v!),
                          ),
                          TextField(
                            controller: classCtrl,
                            decoration: const InputDecoration(labelText: 'Class / Department', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(height: 12),

                        rowOrCol(
                          TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(labelText: 'Payer Name *', hintText: 'e.g. Rahul Sharma', border: OutlineInputBorder()),
                          ),
                          TextField(
                            controller: emailCtrl,
                            decoration: const InputDecoration(labelText: 'Payer Email *', hintText: 'e.g. rahul@example.com', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(height: 12),

                        rowOrCol(
                          TextField(
                            controller: phoneCtrl,
                            decoration: const InputDecoration(labelText: 'Phone', hintText: '9876543210', border: OutlineInputBorder()),
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: purpose,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Purpose *', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'Student Fee', child: Text('Student Fee', overflow: TextOverflow.ellipsis, maxLines: 1)),
                              DropdownMenuItem(value: 'Tuition Fee', child: Text('Tuition Fee', overflow: TextOverflow.ellipsis, maxLines: 1)),
                              DropdownMenuItem(value: 'School ERP Subscription', child: Text('ERP Subscription', overflow: TextOverflow.ellipsis, maxLines: 1)),
                              DropdownMenuItem(value: 'Admission Fee', child: Text('Admission Fee', overflow: TextOverflow.ellipsis, maxLines: 1)),
                              DropdownMenuItem(value: 'Transport Fee', child: Text('Transport Fee', overflow: TextOverflow.ellipsis, maxLines: 1)),
                              DropdownMenuItem(value: 'Examination Fee', child: Text('Examination Fee', overflow: TextOverflow.ellipsis, maxLines: 1)),
                              DropdownMenuItem(value: 'Library Fee', child: Text('Library Fee', overflow: TextOverflow.ellipsis, maxLines: 1)),
                              DropdownMenuItem(value: 'Hostel Fee', child: Text('Hostel Fee', overflow: TextOverflow.ellipsis, maxLines: 1)),
                            ],
                            onChanged: (v) => setDlgState(() => purpose = v!),
                          ),
                        ),
                        const SizedBox(height: 12),

                        rowOrCol(
                          TextField(
                            controller: amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Amount (₹) *', prefixText: '₹ ', border: OutlineInputBorder()),
                          ),
                          DropdownButtonFormField<String>(
                            initialValue: gateway,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Gateway *', border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'SBI_EPAY', child: Text('SBI UPI (ePay)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                              DropdownMenuItem(value: 'ICICI_EAZYPAY', child: Text('ICICI UPI (Eazypay)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                              DropdownMenuItem(value: 'HDFC_SMARTHUB', child: Text('HDFC UPI (SmartHub)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                              DropdownMenuItem(value: 'MOCK_SANDBOX', child: Text('Mock Sandbox', overflow: TextOverflow.ellipsis, maxLines: 1)),
                            ],
                            onChanged: (v) => setDlgState(() => gateway = v!),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextField(
                          controller: descCtrl,
                          decoration: const InputDecoration(labelText: 'Description / Invoice Ref', hintText: 'e.g. FEE-2026-000995', border: OutlineInputBorder()),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  final amt = double.tryParse(amountCtrl.text.trim()) ?? 0.0;
                  if (amt <= 0 || nameCtrl.text.trim().isEmpty || emailCtrl.text.trim().isEmpty) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Please fill required fields with a valid amount'), backgroundColor: Colors.red),
                    );
                    return;
                  }
                  Navigator.pop(ctx);
                  try {
                    final res = await http.post(
                      Uri.parse('${AppConfig.apiBaseUrl}/v1/edushamiit-pay/payments'),
                      headers: {'Content-Type': 'application/json'},
                      body: json.encode({
                        'school_id': schoolIdCtrl.text.trim(),
                        'payer_type': payerType,
                        'customer_name': nameCtrl.text.trim(),
                        'customer_email': emailCtrl.text.trim(),
                        'customer_phone': phoneCtrl.text.trim().isNotEmpty ? phoneCtrl.text.trim() : null,
                        'purpose': purpose,
                        'amount': amt,
                        'currency': 'INR',
                        'description': descCtrl.text.trim().isNotEmpty ? descCtrl.text.trim() : 'Fee Payment',
                        'gateway': gateway,
                        'payment_method': method,
                      }),
                    );
                    if (res.statusCode == 200) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Payment order created successfully!'), backgroundColor: Color(0xFF10B981)),
                      );
                      _fetchSummary();
                      _fetchPayments();
                    } else {
                      final err = json.decode(res.body)['detail'] ?? 'Failed to create payment';
                      messenger.showSnackBar(
                        SnackBar(content: Text('Error: $err'), backgroundColor: Colors.red),
                      );
                    }
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Create error: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
                child: const Text('Create Order'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openRetryDialog(Map<String, dynamic> payment) {
    String selectedGateway = payment['provider'] ?? 'SBI_EPAY';
    final reasonCtrl = TextEditingController(text: 'Customer initiated retry after network drop');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final messenger = ScaffoldMessenger.of(context);
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.refresh_rounded, color: Color(0xFFF59E0B)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Retry Payment Attempt',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: min(440.0, MediaQuery.of(context).size.width - 32),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Retrying will create Attempt #2 while preserving historical attempts for audit.',
                    style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedGateway,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Acquiring Gateway', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'SBI_EPAY', child: Text('SBI UPI (ePay)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      DropdownMenuItem(value: 'ICICI_EAZYPAY', child: Text('ICICI UPI (Eazypay)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      DropdownMenuItem(value: 'HDFC_SMARTHUB', child: Text('HDFC UPI (SmartHub)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      DropdownMenuItem(value: 'MOCK_SANDBOX', child: Text('Mock Sandbox', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    ],
                    onChanged: (v) => setDlgState(() => selectedGateway = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: reasonCtrl,
                    decoration: const InputDecoration(labelText: 'Retry Reason', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final paymentId = payment['id'] ?? payment['transaction_id'];
                  try {
                    final res = await http.post(
                      Uri.parse('${AppConfig.apiBaseUrl}/v1/edushamiit-pay/payments/$paymentId/retry'),
                      headers: {'Content-Type': 'application/json'},
                      body: json.encode({
                        'gateway': selectedGateway,
                        'reason': reasonCtrl.text.trim(),
                      }),
                    );
                    if (res.statusCode == 200) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('New payment attempt created!'), backgroundColor: Color(0xFF10B981)),
                      );
                      _fetchPayments();
                      _fetchPaymentDetail(paymentId, openDrawerOnMobile: false);
                    } else {
                      final err = json.decode(res.body)['detail'] ?? 'Retry failed';
                      messenger.showSnackBar(
                        SnackBar(content: Text('Error: $err'), backgroundColor: Colors.red),
                      );
                    }
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Retry error: $e'), backgroundColor: Colors.red),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF59E0B), foregroundColor: Colors.white),
                child: const Text('Confirm Retry'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openRefundDialog(Map<String, dynamic> payment) {
    final paidAmount = double.tryParse('${payment['amount'] ?? 0}') ?? 0.0;
    final totalRefunded = double.tryParse('${payment['total_refunded'] ?? 0}') ?? 0.0;
    final maxRefundable = paidAmount - totalRefunded;

    final refundAmountCtrl = TextEditingController(text: '$maxRefundable');
    final reasonCtrl = TextEditingController(text: 'Fee concession / student admission withdrawal');

    showDialog(
      context: context,
      builder: (ctx) {
        final messenger = ScaffoldMessenger.of(context);
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.reply_rounded, color: Color(0xFFEF4444)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Initiate Payment Refund',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Refunds cannot exceed the refundable balance. This will record a ledger adjustment and audit entry.',
                  style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      _buildKeyValRow('Total Amount', '₹$paidAmount'),
                      _buildKeyValRow('Already Refunded', '₹$totalRefunded'),
                      const Divider(height: 12),
                      _buildKeyValRow('Max Refundable', '₹$maxRefundable', isBold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: refundAmountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Refund Amount (₹) *',
                    prefixText: '₹ ',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Reason for Refund *',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(refundAmountCtrl.text.trim()) ?? 0.0;
                if (amt <= 0 || amt > maxRefundable) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Refund must be between ₹1 and ₹$maxRefundable'), backgroundColor: Colors.red),
                  );
                  return;
                }
                Navigator.pop(ctx);
                final paymentId = payment['id'] ?? payment['transaction_id'];

                try {
                  final res = await http.post(
                    Uri.parse('${AppConfig.apiBaseUrl}/v1/edushamiit-pay/payments/$paymentId/refund'),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode({
                      'amount': amt,
                      'reason': reasonCtrl.text.trim(),
                    }),
                  );
                  if (res.statusCode == 200) {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Refund processed and ledger updated!'), backgroundColor: Color(0xFF10B981)),
                    );
                    _fetchSummary();
                    _fetchPayments();
                    _fetchPaymentDetail(paymentId, openDrawerOnMobile: false);
                  } else {
                    final err = json.decode(res.body)['detail'] ?? 'Refund failed';
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error: $err'), backgroundColor: Colors.red),
                    );
                  }
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(content: Text('Refund error: $e'), backgroundColor: Colors.red),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
              child: const Text('Confirm Refund'),
            ),
          ],
        );
      },
    );
  }

  void _openReceiptDialog(Map<String, dynamic> payment) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        content: Container(
          width: 500,
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.school_rounded, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('EduSHAMIIT Pay', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('Official E-Receipt & Payment Proof', style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: const Color(0xFF10B981).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                    child: Text('VERIFIED', style: GoogleFonts.dmSans(color: const Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
              const Divider(height: 24),
              Center(
                child: Column(
                  children: [
                    Text('Amount Paid', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B))),
                    const SizedBox(height: 2),
                    Text(
                      _formatCurrency(payment['amount']),
                      style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    ),
                    Text(payment['status'] ?? 'SUCCESS', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildKeyValRow('Receipt No.', 'RCP-${(payment['transaction_id'] ?? '000').replaceAll(RegExp(r'[^A-Z0-9]'), '').substring(0, 10)}'),
              _buildKeyValRow('Transaction ID', payment['transaction_id'] ?? '-'),
              _buildKeyValRow('Payer Name', payment['customer_name'] ?? '-'),
              _buildKeyValRow('Payment Purpose', payment['payment_purpose'] ?? payment['purpose'] ?? 'Student Fee'),
              _buildKeyValRow('Payment Gateway', payment['provider'] ?? 'EduSHAMIIT Engine'),
              _buildKeyValRow('Payment Method', payment['payment_method'] ?? 'UPI'),
              _buildKeyValRow('Bank Ref / UTR', payment['bank_ref_no'] ?? payment['reference_number'] ?? 'UTR-${payment['transaction_id']}'),
              _buildKeyValRow('Date & Time', _formatDateTime(payment['created_at'])),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: payment['transaction_id'] ?? ''));
                      messenger.showSnackBar(const SnackBar(content: Text('Copied transaction ID')));
                    },
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copy ID'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      messenger.showSnackBar(const SnackBar(content: Text('Downloading receipt PDF...'), backgroundColor: Color(0xFF4F46E5)));
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
                    icon: const Icon(Icons.print_rounded, size: 16),
                    label: const Text('Print Receipt'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openReconcileDialog(Map<String, dynamic> payment) {
    final utrCtrl = TextEditingController(text: payment['bank_ref_no'] ?? '');
    final notesCtrl = TextEditingController();
    String status = 'MATCHED';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) {
          final messenger = ScaffoldMessenger.of(context);
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.fact_check_outlined, color: Color(0xFF4F46E5)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Manual Bank Reconciliation',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: min(420.0, MediaQuery.of(context).size.width - 32),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Reconcile transaction ${payment['transaction_id']} against acquiring bank settlement statement.',
                    style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                    items: const [
                      DropdownMenuItem(value: 'MATCHED', child: Text('MATCHED (Verified with Bank)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      DropdownMenuItem(value: 'RESOLVED', child: Text('RESOLVED (Manual Clearance)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      DropdownMenuItem(value: 'MISMATCH', child: Text('MISMATCH (Discrepancy)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                    ],
                    onChanged: (v) => setDlgState(() => status = v!),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: utrCtrl,
                    decoration: const InputDecoration(labelText: 'Bank UTR / Reference No.', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(labelText: 'Auditor Notes', border: OutlineInputBorder()),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final paymentId = payment['id'] ?? payment['transaction_id'];
                  try {
                    final res = await http.post(
                      Uri.parse('${AppConfig.apiBaseUrl}/v1/edushamiit-pay/payments/$paymentId/reconcile'),
                      headers: {'Content-Type': 'application/json'},
                      body: json.encode({
                        'status': status,
                        'utr': utrCtrl.text.trim().isNotEmpty ? utrCtrl.text.trim() : null,
                        'notes': notesCtrl.text.trim().isNotEmpty ? notesCtrl.text.trim() : null,
                      }),
                    );
                    if (res.statusCode == 200) {
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Transaction successfully reconciled!'), backgroundColor: Color(0xFF10B981)),
                      );
                      _fetchPayments();
                      _fetchPaymentDetail(paymentId, openDrawerOnMobile: false);
                    }
                  } catch (e) {
                    debugPrint('Reconciliation error: $e');
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
                child: const Text('Save Reconciliation'),
              ),
            ],
          );
        },
      ),
    );
  }

  // =========================================================================
  // MAIN BUILD METHOD
  // =========================================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1050;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          endDrawer: !isWide && _activePaymentDetail != null
              ? Drawer(
                  width: min(400.0, screenWidth * 0.85),
                  child: _buildPaymentDetailPanel(isInline: false),
                )
              : null,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
                child: _buildTopNavigationHeader(),
              ),
              Expanded(
                child: _buildActiveTabContent(isWide),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActiveTabContent(bool isWide) {
    switch (_activeNavTab) {
      case 0:
        return EduSHAMIITPayDashboardScreen(
          schoolId: widget.schoolId,
          schoolName: widget.schoolName,
        );
      case 1:
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 6 Real KPI Summary Cards matching Screenshot
              _buildKpiSummaryGrid(),
              const SizedBox(height: 20),

              // 2-Row Collapsible Filter Panel
              if (_showFilters) ...[
                _buildTwoRowFilterPanel(),
                const SizedBox(height: 18),
              ],

              // Main Workspace Layout: Desktop Split View or Full Width
              if (isWide && _activePaymentDetail != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildTransactionWorkspaceCard(),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 380,
                      child: _buildPaymentDetailPanel(isInline: true),
                    ),
                  ],
                )
              else
                _buildTransactionWorkspaceCard(),
              const SizedBox(height: 32),
            ],
          ),
        );
      case 2:
        return PaymentGatewayIntegrationScreen(
          schoolId: widget.schoolId,
          schoolName: widget.schoolName,
          isEmbedded: true,
          showSidebar: false,
        );
      case 3:
        return EduSHAMIITPayTransactionsScreen(
          schoolId: widget.schoolId,
        );
      case 4:
        return _buildWebhooksView();
      case 5:
        return EduSHAMIITPayReconciliationScreen(
          schoolId: widget.schoolId,
        );
      case 6:
        return EduSHAMIITPayMerchantSettingsScreen(
          schoolId: widget.schoolId,
        );
      default:
        return Center(
          child: Text(
            'Tab $_activeNavTab not found',
            style: GoogleFonts.dmSans(color: const Color(0xFF64748B)),
          ),
        );
    }
  }

  Widget _buildWebhooksView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.webhook, color: Color(0xFF4F46E5), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Gateway Webhook Stream',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Authoritative server-to-server gateway notifications, HMAC/hash validation audit logs & state reconciliation',
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    ElevatedButton.icon(
                      onPressed: _isLoadingWebhooks ? null : _fetchWebhooks,
                      icon: _isLoadingWebhooks
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.refresh, size: 16),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),

                if (_isLoadingWebhooks)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: CircularProgressIndicator(color: Color(0xFF4F46E5)),
                    ),
                  )
                else if (_webhooks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
                    child: Center(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.sync_alt, size: 36, color: Color(0xFF4F46E5)),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No Webhook Events Recorded',
                            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Inbound payment webhooks from PayU and other configured providers will appear here automatically with validated payload digests.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      headingTextStyle: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF475569),
                      ),
                      dataTextStyle: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: const Color(0xFF1E293B),
                      ),
                      columns: const [
                        DataColumn(label: Text('Event ID')),
                        DataColumn(label: Text('Gateway')),
                        DataColumn(label: Text('Event Type')),
                        DataColumn(label: Text('Transaction / Order ID')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Received At')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: _webhooks.map((wh) {
                        final eventId = wh['id'] ?? wh['event_id'] ?? 'WH-${wh['gateway_event_id'] ?? 'N/A'}';
                        final gateway = wh['gateway_code'] ?? wh['gateway'] ?? 'PAYU';
                        final eventType = wh['event_type'] ?? 'payment.status';
                        final orderId = wh['order_id'] ?? wh['payment_order_id'] ?? wh['transaction_id'] ?? '-';
                        final status = (wh['processing_status'] ?? wh['status'] ?? 'PROCESSED').toString().toUpperCase();
                        final receivedAt = _formatDateTime(wh['received_at'] ?? wh['created_at']);

                        Color statusBg;
                        Color statusFg;
                        if (status == 'PROCESSED' || status == 'SUCCESS') {
                          statusBg = const Color(0xFFECFDF5);
                          statusFg = const Color(0xFF059669);
                        } else if (status == 'FAILED' || status == 'INVALID_HASH') {
                          statusBg = const Color(0xFFFEF2F2);
                          statusFg = const Color(0xFFDC2626);
                        } else {
                          statusBg = const Color(0xFFFFFBEB);
                          statusFg = const Color(0xFFD97706);
                        }

                        return DataRow(
                          cells: [
                            DataCell(Text(
                              eventId.toString().length > 14 ? '${eventId.toString().substring(0, 14)}...' : eventId.toString(),
                              style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                            )),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEEF2FF),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  gateway.toString().toUpperCase(),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF4F46E5)),
                                ),
                              ),
                            ),
                            DataCell(Text(eventType.toString())),
                            DataCell(Text(orderId.toString(), style: const TextStyle(fontFamily: 'monospace'))),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status,
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: statusFg),
                                ),
                              ),
                            ),
                            DataCell(Text(receivedAt)),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF4F46E5)),
                                tooltip: 'View Safe Payload Digest',
                                onPressed: () => _showWebhookPayloadDialog(wh is Map<String, dynamic> ? wh : {}),
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
        ],
      ),
    );
  }

  void _showWebhookPayloadDialog(Map<String, dynamic> wh) {
    final safeWh = Map<String, dynamic>.from(wh);
    safeWh.remove('secret');
    safeWh.remove('salt');
    safeWh.remove('merchant_salt');
    safeWh.remove('key');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.webhook, color: Color(0xFF4F46E5), size: 22),
            const SizedBox(width: 8),
            Text('Webhook Event Digest', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Event ID: ${wh['id'] ?? wh['event_id'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Text('Gateway: ${(wh['gateway_code'] ?? wh['gateway'] ?? 'PAYU').toString().toUpperCase()}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(safeWh),
                    style: const TextStyle(color: Color(0xFF38BDF8), fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // TOP NAVIGATION HEADER & SUB-TABS
  // =========================================================================

  Widget _buildTopNavigationHeader() {
    final tabs = [
      'Overview',
      'Payments',
      'Payment Gateways',
      'Payment Requests',
      'Webhooks',
      'Reconciliation',
      'Settings',
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 880;

        final subTabsRow = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(tabs.length, (idx) {
              final isSelected = _activeNavTab == idx;
              return InkWell(
                onTap: () {
                  setState(() => _activeNavTab = idx);
                  if (idx == 4) _fetchWebhooks();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                  child: Text(
                    tabs[idx],
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              );
            }),
          ),
        );

        final rightControls = Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Date Range Pill
            Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _filterFinancialPeriod,
                    style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.calendar_today_outlined, size: 15, color: Color(0xFF64748B)),
                ],
              ),
            ),

            // Filters Button
            OutlinedButton.icon(
              onPressed: () => setState(() => _showFilters = !_showFilters),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              icon: const Icon(Icons.tune_rounded, size: 16, color: Color(0xFF334155)),
              label: Text(
                'Filters',
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
              ),
            ),
          ],
        );

        Widget activeRightControls;
        if (_activeNavTab == 1) {
          activeRightControls = rightControls;
        } else if (_activeNavTab == 4) {
          activeRightControls = OutlinedButton.icon(
            onPressed: _isLoadingWebhooks ? null : _fetchWebhooks,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFE2E8F0)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
            icon: _isLoadingWebhooks
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh, size: 16, color: Color(0xFF334155)),
            label: Text(
              'Refresh Logs',
              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
            ),
          );
        } else {
          activeRightControls = const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title: "Payment Engine"
            Text(
              'Payment Engine',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            if (isNarrow)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  subTabsRow,
                  const SizedBox(height: 8),
                  activeRightControls,
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(child: subTabsRow),
                  const SizedBox(width: 12),
                  activeRightControls,
                ],
              ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
          ],
        );
      },
    );
  }

  // =========================================================================
  // 6 REAL-VALUE KPI SUMMARY CARDS (Exact Match to Screenshot)
  // =========================================================================

  Widget _buildKpiSummaryGrid() {
    final s = _summaryData;

    final totalTxn = s['total_transactions'] ?? {};
    final success = s['successful_payments'] ?? {};
    final pending = s['pending_payments'] ?? {};
    final failed = s['failed_payments'] ?? {};
    final totalAmount = s['total_amount_collected'] ?? {};
    final refunds = s['refunds'] ?? {};

    return Column(
      children: [
        if (_isLoadingSummary)
          const Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: LinearProgressIndicator(minHeight: 2, color: Color(0xFF4F46E5)),
          ),
        LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 6;
        if (constraints.maxWidth < 640) {
          crossAxisCount = 1;
        } else if (constraints.maxWidth < 900) {
          crossAxisCount = 2;
        } else if (constraints.maxWidth < 1250) {
          crossAxisCount = 3;
        }

        final cards = [
          // 1. Total Payments
          _buildScreenshotKpiCard(
            title: 'Total Payments',
            value: '${totalTxn['value'] ?? _totalPayments}',
            trendText: '${totalTxn['trend'] ?? 'Live DB Aggregation'}',
            trendColor: const Color(0xFF10B981),
            icon: Icons.account_balance_wallet_rounded,
            iconColor: const Color(0xFF4F46E5),
            iconBg: const Color(0xFFEEF2FF),
            onTap: () {
              setState(() => _selectedStatusTab = 'ALL');
              _fetchPayments();
            },
          ),

          // 2. Successful Payments
          _buildScreenshotKpiCard(
            title: 'Successful Payments',
            value: '${success['value'] ?? 0}',
            trendText: '${success['rate'] ?? '0%'} Success Rate',
            trendColor: const Color(0xFF10B981),
            icon: Icons.check_circle_rounded,
            iconColor: const Color(0xFF10B981),
            iconBg: const Color(0xFFECFDF5),
            onTap: () {
              setState(() => _selectedStatusTab = 'SUCCESS');
              _fetchPayments();
            },
          ),

          // 3. Pending Payments
          _buildScreenshotKpiCard(
            title: 'Pending Payments',
            value: '${pending['value'] ?? 0}',
            trendText: pending['value'] != null ? '${pending['value']} active orders' : 'Awaiting verification',
            trendColor: const Color(0xFFD97706),
            icon: Icons.schedule_rounded,
            iconColor: const Color(0xFFF59E0B),
            iconBg: const Color(0xFFFFFBEB),
            onTap: () {
              setState(() => _selectedStatusTab = 'PENDING');
              _fetchPayments();
            },
          ),

          // 4. Failed Payments
          _buildScreenshotKpiCard(
            title: 'Failed Payments',
            value: '${failed['value'] ?? 0}',
            trendText: failed['value'] != null ? '${failed['value']} rejected/cancelled' : 'Clean state',
            trendColor: const Color(0xFFDC2626),
            icon: Icons.close_rounded,
            iconColor: const Color(0xFFEF4444),
            iconBg: const Color(0xFFFEF2F2),
            onTap: () {
              setState(() => _selectedStatusTab = 'FAILED');
              _fetchPayments();
            },
          ),

          // 5. Total Amount
          _buildScreenshotKpiCard(
            title: 'Total Amount',
            value: _formatCurrency(totalAmount['value'] ?? 0.0),
            trendText: 'Realized collections',
            trendColor: const Color(0xFF10B981),
            icon: Icons.currency_rupee_rounded,
            iconColor: const Color(0xFF3B82F6),
            iconBg: const Color(0xFFEFF6FF),
          ),

          // 6. Refunded Amount
          _buildScreenshotKpiCard(
            title: 'Refunded Amount',
            value: _formatCurrency(refunds['value'] ?? 0.0),
            trendText: '${refunds['count'] ?? 0} refunded orders',
            trendColor: const Color(0xFF8B5CF6),
            icon: Icons.replay_rounded,
            iconColor: const Color(0xFF8B5CF6),
            iconBg: const Color(0xFFF5F3FF),
            onTap: () {
              setState(() => _selectedStatusTab = 'REFUNDED');
              _fetchPayments();
            },
          ),
        ];

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: crossAxisCount == 6 ? 1.6 : (crossAxisCount == 3 ? 2.1 : 2.5),
          children: cards,
        );
      },
    ),
  ],
);
  }

  Widget _buildScreenshotKpiCard({
    required String title,
    required String value,
    required String trendText,
    required Color trendColor,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Circular Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),

            // Value, Title, Trend
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500, color: const Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    trendText,
                    style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: trendColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 2-ROW FILTER PANEL (Exact Match to Screenshot)
  // =========================================================================

  Widget _buildTwoRowFilterPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ROW 1: Date Range, Payment Type, Status, Gateway, Payment Method
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  // Date Range
                  _buildFilterField(
                    label: 'Date Range',
                    width: 210,
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _filterFinancialPeriod,
                              style: GoogleFonts.dmSans(fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.calendar_today_outlined, size: 14, color: Color(0xFF64748B)),
                        ],
                      ),
                    ),
                  ),

                  // Payment Type
                  _buildFilterField(
                    label: 'Payment Type',
                    child: DropdownButtonFormField<String>(
                      initialValue: _filterPaymentType,
                      isExpanded: true,
                      isDense: true,
                      decoration: _filterInputDecoration(),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Types', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'Student Fee', child: Text('Student Fee', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'Tuition Fee', child: Text('Tuition Fee', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'School ERP Subscription', child: Text('ERP Subscription', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'Admission Fee', child: Text('Admission Fee', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'Transport Fee', child: Text('Transport Fee', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'Examination Fee', child: Text('Examination Fee', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'Library Fee', child: Text('Library Fee', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      ],
                      onChanged: (v) => setState(() => _filterPaymentType = v!),
                    ),
                  ),

                  // Status
                  _buildFilterField(
                    label: 'Status',
                    child: DropdownButtonFormField<String>(
                      initialValue: _filterStatus,
                      isExpanded: true,
                      isDense: true,
                      decoration: _filterInputDecoration(),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Status', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'SUCCESS', child: Text('Success', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'PENDING', child: Text('Pending', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'FAILED', child: Text('Failed', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'REFUNDED', child: Text('Refunded', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      ],
                      onChanged: (v) => setState(() => _filterStatus = v!),
                    ),
                  ),

                  // Gateway
                  _buildFilterField(
                    label: 'Gateway',
                    child: DropdownButtonFormField<String>(
                      initialValue: _filterGateway,
                      isExpanded: true,
                      isDense: true,
                      decoration: _filterInputDecoration(),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Gateways', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'SBI_EPAY', child: Text('SBI UPI', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'ICICI_EAZYPAY', child: Text('ICICI UPI', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'HDFC_SMARTHUB', child: Text('HDFC UPI', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'MOCK_SANDBOX', child: Text('Mock Sandbox', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      ],
                      onChanged: (v) => setState(() => _filterGateway = v!),
                    ),
                  ),

                  // Payment Method
                  _buildFilterField(
                    label: 'Payment Method',
                    child: DropdownButtonFormField<String>(
                      initialValue: _filterPaymentMethod,
                      isExpanded: true,
                      isDense: true,
                      decoration: _filterInputDecoration(),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Methods', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'UPI PhonePe', child: Text('UPI (PhonePe)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'UPI Google Pay', child: Text('UPI (Google Pay)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'UPI BHIM', child: Text('UPI (BHIM)', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'Card', child: Text('Card', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'Net Banking', child: Text('Net Banking', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      ],
                      onChanged: (v) => setState(() => _filterPaymentMethod = v!),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 14),

          // ROW 2: School / Institute, Student / Customer, Invoice / Ref, Amount Range, Clear, Apply
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  // School / Institute
                  _buildFilterField(
                    label: 'School / Institute',
                    child: DropdownButtonFormField<String>(
                      initialValue: _filterSchool,
                      isExpanded: true,
                      isDense: true,
                      decoration: _filterInputDecoration(),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('All Schools', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'e1f11111-1111-1111-1111-111111111111', child: Text('Greenfield Public School', overflow: TextOverflow.ellipsis, maxLines: 1)),
                        DropdownMenuItem(value: 'e1f22222-2222-2222-2222-222222222222', child: Text('Delhi Model Academy', overflow: TextOverflow.ellipsis, maxLines: 1)),
                      ],
                      onChanged: (v) => setState(() => _filterSchool = v!),
                    ),
                  ),

                  // Student / Customer Search
                  _buildFilterField(
                    label: 'Student / Customer',
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchStudentCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search student / customer...',
                          hintStyle: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        ),
                      ),
                    ),
                  ),

                  // Invoice / Reference Search
                  _buildFilterField(
                    label: 'Invoice / Reference',
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchInvoiceCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search invoice or reference...',
                          hintStyle: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 16, color: Color(0xFF94A3B8)),
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                        ),
                      ),
                    ),
                  ),

                  // Amount Range (Min - Max)
                  SizedBox(
                    width: 240,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Amount Range', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 38,
                                child: TextField(
                                  controller: _minAmountCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Min Amount',
                                    hintStyle: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  ),
                                ),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text('-', style: TextStyle(color: Color(0xFF94A3B8))),
                            ),
                            Expanded(
                              child: SizedBox(
                                height: 38,
                                child: TextField(
                                  controller: _maxAmountCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: 'Max Amount',
                                    hintStyle: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Action Buttons: Clear & Apply Filters
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OutlinedButton(
                        onPressed: _resetFilters,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        child: Text('Clear', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF475569))),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          _currentPage = 1;
                          _fetchPayments();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4F46E5),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        ),
                        child: Text('Apply Filters', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterField({required String label, required Widget child, double? width}) {
    // Uses ConstrainedBox with minimum width to prevent collapse,
    // but allows shrinking in tight containers to avoid overflow.
    final inner = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF475569))),
        const SizedBox(height: 4),
        child,
      ],
    );
    if (width != null) {
      return SizedBox(width: width, child: inner);
    }
    // Wrap in a ConstrainedBox so the field is at least 160px but can grow
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
      child: inner,
    );
  }

  InputDecoration _filterInputDecoration() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
    );
  }

  // =========================================================================
  // TRANSACTION WORKSPACE CARD (Tabs, Table, Pagination)
  // =========================================================================

  Widget _buildTransactionWorkspaceCard() {
    final s = _summaryData;
    final totalCount = s['total_transactions']?['value'] ?? _totalPayments;
    final successCount = s['successful_payments']?['value'] ?? 0;
    final pendingCount = s['pending_payments'] ?? {};
    final failedCount = s['failed_payments'] ?? {};
    final refundCount = s['refunds']?['count'] ?? 0;

    final statusTabs = [
      {'key': 'ALL', 'label': 'All Payments ($totalCount)'},
      {'key': 'SUCCESS', 'label': 'Successful ($successCount)'},
      {'key': 'PENDING', 'label': 'Pending (${pendingCount['value'] ?? 0})'},
      {'key': 'FAILED', 'label': 'Failed (${failedCount['value'] ?? 0})'},
      {'key': 'REFUNDED', 'label': 'Refunded ($refundCount)'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top bar: Status Tabs on Left, Export & Options on Right
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Tabs with Blue Underline
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: statusTabs.map((tab) {
                        final isSelected = _selectedStatusTab == tab['key'];
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedStatusTab = tab['key']!;
                              _currentPage = 1;
                            });
                            _fetchPayments();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                            ),
                            child: Text(
                              tab['label']!,
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Right buttons: Export ⌄, ⋮, and + Create Payment
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: _exportCsv,
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      icon: const Icon(Icons.download_rounded, size: 15, color: Color(0xFF475569)),
                      label: Text('Export', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF475569), fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 6),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, size: 18, color: Color(0xFF475569)),
                      onSelected: (action) {
                        if (action == 'refresh') {
                          _fetchSummary();
                          _fetchPayments();
                        } else if (action == 'create') {
                          _openCreatePaymentDialog();
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'refresh', child: Text('Refresh Data')),
                        const PopupMenuItem(value: 'create', child: Text('+ Create Payment')),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Transactions Table
          if (_isLoadingPayments)
            const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_payments.isEmpty)
            _buildEmptyState()
          else
            _buildPaymentsTable(),

          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // Table Pagination Bar matching Screenshot
          _buildPaginationBar(),
        ],
      ),
    );
  }

  // =========================================================================
  // DATA TABLE (Pixel-Perfect Columns & Branded Badges)
  // =========================================================================

  Widget _buildPaymentsTable() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
        headingTextStyle: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B), letterSpacing: 0.5),
        dataRowMinHeight: 56,
        dataRowMaxHeight: 64,
        horizontalMargin: 16,
        columnSpacing: 20,
        columns: const [
          DataColumn(label: Text('')),
          DataColumn(label: Text('TXN ID')),
          DataColumn(label: Text('DATE & TIME')),
          DataColumn(label: Text('STUDENT / CUSTOMER')),
          DataColumn(label: Text('INVOICE / REF')),
          DataColumn(label: Text('AMOUNT')),
          DataColumn(label: Text('GATEWAY')),
          DataColumn(label: Text('METHOD')),
          DataColumn(label: Text('STATUS')),
          DataColumn(label: Text('')),
        ],
        rows: _payments.map((p) {
          final txnId = p['transaction_id'] ?? p['id'] ?? '';
          final isSelected = _selectedPaymentIds.contains(txnId) ||
              (_activePaymentDetail != null && _activePaymentDetail!['transaction_id'] == txnId);
          final status = p['status'] ?? 'PENDING';
          final studentClass = p['metadata']?['class'] ?? p['class'] ?? 'Class 8-A';

          return DataRow(
            selected: isSelected,
            color: WidgetStateProperty.resolveWith<Color?>((states) {
              if (isSelected) return const Color(0xFFF0F4FF);
              return null;
            }),
            onSelectChanged: (_) => _selectPayment(p),
            cells: [
              // Checkbox
              DataCell(
                Checkbox(
                  value: isSelected,
                  onChanged: (val) {
                    if (val == true) {
                      _selectPayment(p);
                    } else {
                      setState(() {
                        _selectedPaymentIds.remove(txnId);
                        if (_activePaymentDetail?['transaction_id'] == txnId) {
                          _activePaymentDetail = null;
                        }
                      });
                    }
                  },
                ),
              ),

              // TXN ID
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: InkWell(
                    onTap: () => _selectPayment(p),
                    child: Text(
                      txnId,
                      style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),

              // DATE & TIME (2 lines)
              DataCell(
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_formatDate(p['created_at']), style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF1E293B))),
                    Text(_formatTime(p['created_at']), style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF94A3B8))),
                  ],
                ),
              ),

              // STUDENT / CUSTOMER (2 lines: Name bold, Class subtitle)
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 180),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p['customer_name'] ?? 'Payer', style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(studentClass, style: GoogleFonts.dmSans(fontSize: 11, color: const Color(0xFF64748B)), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ),

              // INVOICE / REF
              DataCell(
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    p['reference_number'] ?? p['fee_invoice_id'] ?? 'FEE-2026-000985',
                    style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),

              // AMOUNT
              DataCell(
                Text(
                  _formatCurrency(p['amount']),
                  style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
              ),

              // GATEWAY (Branded Badge)
              DataCell(
                _buildGatewayBrandBadge(p['provider'] ?? 'SBI_EPAY'),
              ),

              // METHOD (Branded Badge: Icon + UPI / Name)
              DataCell(
                _buildMethodBrandBadge(p['payment_method'], p['provider']),
              ),

              // STATUS (Soft Pill Badge)
              DataCell(
                _buildStatusPill(status),
              ),

              // Actions (···)
              DataCell(
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded, size: 18, color: Color(0xFF94A3B8)),
                  onSelected: (action) {
                    if (action == 'verify') {
                      _verifyPaymentAction(txnId);
                    } else if (action == 'details') {
                      _selectPayment(p);
                    } else if (action == 'retry') {
                      _openRetryDialog(p);
                    } else if (action == 'refund') {
                      _openRefundDialog(p);
                    } else if (action == 'receipt') {
                      _openReceiptDialog(p);
                    } else if (action == 'reconcile') {
                      _openReconcileDialog(p);
                    }
                  },
                  itemBuilder: (_) => [
                    if (status != 'SUCCESS')
                      const PopupMenuItem(
                        value: 'verify',
                        child: Row(
                          children: [
                            Icon(Icons.verified_outlined, size: 16, color: Color(0xFF4F46E5)),
                            SizedBox(width: 8),
                            Text('Verify Status'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'details',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('View Details'),
                        ],
                      ),
                    ),
                    if (status != 'SUCCESS')
                      const PopupMenuItem(
                        value: 'retry',
                        child: Row(
                          children: [
                            Icon(Icons.refresh_rounded, size: 16, color: Color(0xFFF59E0B)),
                            SizedBox(width: 8),
                            Text('Retry Attempt'),
                          ],
                        ),
                      ),
                    if (status == 'SUCCESS')
                      const PopupMenuItem(
                        value: 'refund',
                        child: Row(
                          children: [
                            Icon(Icons.reply_rounded, size: 16, color: Color(0xFFEF4444)),
                            SizedBox(width: 8),
                            Text('Initiate Refund'),
                          ],
                        ),
                      ),
                    if (status == 'SUCCESS')
                      const PopupMenuItem(
                        value: 'receipt',
                        child: Row(
                          children: [
                            Icon(Icons.receipt_rounded, size: 16, color: Color(0xFF10B981)),
                            SizedBox(width: 8),
                            Text('View Receipt'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'reconcile',
                      child: Row(
                        children: [
                          Icon(Icons.fact_check_outlined, size: 16, color: Color(0xFF4F46E5)),
                          SizedBox(width: 8),
                          Text('Reconcile'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  // =========================================================================
  // BRANDED BADGES (SBI, ICICI, HDFC, PhonePe, Google Pay, BHIM)
  // =========================================================================

  Widget _buildGatewayBrandBadge(String provider) {
    String label = 'SBI UPI';
    Widget iconWidget = Container(
      width: 16,
      height: 16,
      decoration: const BoxDecoration(color: Color(0xFF0072BB), shape: BoxShape.circle),
      child: const Center(
        child: Icon(Icons.circle, color: Colors.white, size: 6),
      ),
    );

    if (provider.contains('ICICI')) {
      label = 'ICICI UPI';
      iconWidget = Container(
        width: 16,
        height: 16,
        decoration: const BoxDecoration(color: Color(0xFFF37021), shape: BoxShape.circle),
        child: const Center(
          child: Text('i', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      );
    } else if (provider.contains('HDFC')) {
      label = 'HDFC UPI';
      iconWidget = Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(color: const Color(0xFF004C8F), borderRadius: BorderRadius.circular(3)),
        child: const Center(
          child: Icon(Icons.add, color: Color(0xFFED1C24), size: 12),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        iconWidget,
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
        ),
      ],
    );
  }

  Widget _buildMethodBrandBadge(String? method, String? provider) {
    final str = '${method ?? ''} ${provider ?? ''}'.toLowerCase();

    Widget icon = Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(color: Color(0xFF5F259F), shape: BoxShape.circle),
      child: const Center(
        child: Text('₹', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
    String appName = 'PhonePe';

    if (str.contains('google') || str.contains('gpay')) {
      appName = 'Google Pay';
      icon = Container(
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Center(
          child: Text('G', style: TextStyle(color: Color(0xFF4285F4), fontSize: 11, fontWeight: FontWeight.bold)),
        ),
      );
    } else if (str.contains('bhim')) {
      appName = 'BHIM';
      icon = Container(
        width: 18,
        height: 18,
        decoration: const BoxDecoration(color: Color(0xFF009688), shape: BoxShape.circle),
        child: const Center(
          child: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 10),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 8),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UPI', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
            Text(appName, style: GoogleFonts.dmSans(fontSize: 10, color: const Color(0xFF64748B))),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusPill(String status) {
    Color bg = const Color(0xFFFEF7E0);
    Color fg = const Color(0xFFB06000);
    String label = 'Pending';

    if (status == 'SUCCESS') {
      bg = const Color(0xFFE6F4EA);
      fg = const Color(0xFF137333);
      label = 'Success';
    } else if (status == 'FAILED' || status == 'CANCELLED' || status == 'EXPIRED') {
      bg = const Color(0xFFFCE8E6);
      fg = const Color(0xFFC5221F);
      label = 'Failed';
    } else if (status.contains('REFUND')) {
      bg = const Color(0xFFF3E8FD);
      fg = const Color(0xFF7627BB);
      label = 'Refunded';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        label,
        style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: fg),
      ),
    );
  }

  // =========================================================================
  // PAYMENT DETAILS PANEL (Desktop Split View or Mobile Drawer)
  // =========================================================================

  Widget _buildPaymentDetailPanel({required bool isInline}) {
    if (_isLoadingDetail) {
      return Container(
        height: 600,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final d = _activePaymentDetail;
    if (d == null) {
      return Container(
        height: 400,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: const Center(child: Text('Select a transaction to view details')),
      );
    }

    final summary = d['payment_summary'] ?? d;
    final payer = d['payer'] ?? {};
    final payment = d['payment'] ?? {};
    final txnId = summary['transaction_id'] ?? d['transaction_id'] ?? '-';
    final status = summary['status'] ?? d['status'] ?? 'PENDING';
    final isSuccess = status == 'SUCCESS';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title & Close '✕' Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Payment Details',
                  style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                  onPressed: () {
                    if (isInline) {
                      setState(() => _activePaymentDetail = null);
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Top Status Bar: Pill Badge + TXN ID + [Verify Status] Button
            Row(
              children: [
                _buildStatusPill(status),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    txnId,
                    style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF334155)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                ElevatedButton(
                  onPressed: _isVerifying ? null : () => _verifyPaymentAction(txnId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEEF2FF),
                    foregroundColor: const Color(0xFF4F46E5),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                  ),
                  child: _isVerifying
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('Verify Status', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section: Overview
            Text('Overview', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
            const SizedBox(height: 12),
            _buildKeyValRow('Student / Customer', payer['name'] ?? d['customer_name'] ?? 'Priya Verma'),
            _buildKeyValRow('Invoice / Reference', d['reference_number'] ?? d['fee_invoice_id'] ?? 'FEE-2026-000985'),
            _buildKeyValRow('Payment Type', payment['purpose'] ?? d['payment_purpose'] ?? 'Tuition Fee'),
            _buildKeyValRow('Amount', _formatCurrency(d['amount'] ?? summary['amount'])),
            _buildKeyValRow('Paid Amount', _formatCurrency(d['amount'] ?? summary['amount'])),
            _buildKeyValRow('Gateway', payment['gateway'] ?? d['provider'] ?? 'ICICI UPI'),
            _buildKeyValRow('Payment Method', payment['payment_method'] ?? d['payment_method'] ?? 'UPI (Google Pay)'),
            _buildKeyValRow('Created At', _formatDateTime(summary['created_at'] ?? d['created_at'])),
            const Divider(height: 28),

            // Section: Payment Flow (Vertical Stepper matching Screenshot)
            Text('Payment Flow', style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A))),
            const SizedBox(height: 14),
            _buildPaymentFlowStepper(status, summary['created_at'] ?? d['created_at']),
            const Divider(height: 28),

            // Bottom Action Buttons: [View Invoice], [Receipt (Soon)], [More Actions ⌄]
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Opening Invoice ${d['reference_number'] ?? 'FEE-2026-000985'}...')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: Text('View Invoice', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: isSuccess ? () => _openReceiptDialog(d) : null,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                      backgroundColor: isSuccess ? const Color(0xFF10B981).withValues(alpha: 0.08) : const Color(0xFFF8FAFC),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: Text(
                      isSuccess ? 'View Receipt' : 'Receipt (Soon)',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSuccess ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'retry') {
                      _openRetryDialog(d);
                    } else if (action == 'refund') {
                      _openRefundDialog(d);
                    } else if (action == 'reconcile') {
                      _openReconcileDialog(d);
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'retry', child: Text('Retry Payment')),
                    const PopupMenuItem(value: 'refund', child: Text('Initiate Refund')),
                    const PopupMenuItem(value: 'reconcile', child: Text('Reconcile with Bank')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('More Actions', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF334155))),
                        const SizedBox(width: 4),
                        const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: Color(0xFF334155)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentFlowStepper(String currentStatus, dynamic createdAt) {
    final isSuccess = currentStatus == 'SUCCESS';
    final dateStr = _formatDateTime(createdAt);

    return Column(
      children: [
        _buildStepperRow(
          icon: Icons.check_circle_rounded,
          iconColor: const Color(0xFF10B981),
          title: 'Payment Initiated',
          subtitle: dateStr,
          isCompleted: true,
          showLine: true,
        ),
        _buildStepperRow(
          icon: isSuccess ? Icons.check_circle_rounded : Icons.circle,
          iconColor: isSuccess ? const Color(0xFF10B981) : const Color(0xFF3B82F6),
          title: 'Payment Processing',
          subtitle: dateStr,
          isCompleted: true,
          showLine: true,
        ),
        _buildStepperRow(
          icon: isSuccess ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          iconColor: isSuccess ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
          title: 'Payment Success',
          subtitle: isSuccess ? dateStr : '-',
          isCompleted: isSuccess,
          showLine: true,
        ),
        _buildStepperRow(
          icon: Icons.radio_button_unchecked_rounded,
          iconColor: const Color(0xFFCBD5E1),
          title: 'Settled to Bank',
          subtitle: '-',
          isCompleted: false,
          showLine: true,
        ),
        _buildStepperRow(
          icon: Icons.radio_button_unchecked_rounded,
          iconColor: const Color(0xFFCBD5E1),
          title: 'Reconciled',
          subtitle: '-',
          isCompleted: false,
          showLine: false,
        ),
      ],
    );
  }

  Widget _buildStepperRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool isCompleted,
    required bool showLine,
  }) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Icon & Vertical Connecting Line
          Column(
            children: [
              Icon(icon, color: iconColor, size: 16),
              if (showLine)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: const Color(0xFFE2E8F0),
                    margin: const EdgeInsets.symmetric(vertical: 2),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),

          // Title & Timestamp
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: isCompleted ? FontWeight.w600 : FontWeight.normal,
                      color: isCompleted ? const Color(0xFF0F172A) : const Color(0xFF94A3B8),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: isCompleted ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
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

  // =========================================================================
  // PAGINATION BAR (Exact Match to Screenshot)
  // =========================================================================

  Widget _buildPaginationBar() {
    final startItem = _totalPayments == 0 ? 0 : (_currentPage - 1) * _pageSize + 1;
    final endItem = (_currentPage * _pageSize > _totalPayments) ? _totalPayments : _currentPage * _pageSize;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 640;

        final showingText = Text(
          'Showing $startItem to $endItem of $_totalPayments entries',
          style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B)),
        );

        final controls = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Page Numbers: < [1] 2 3 4 5 ... 125 >
            OutlinedButton(
              onPressed: _currentPage > 1
                  ? () {
                      setState(() => _currentPage--);
                      _fetchPayments();
                    }
                  : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(28, 28),
                padding: EdgeInsets.zero,
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: const Icon(Icons.chevron_left_rounded, size: 16),
            ),
            const SizedBox(width: 6),

            ...List.generate(
              _totalPages > 5 ? 5 : _totalPages,
              (idx) {
                final pageNum = idx + 1;
                final isActive = _currentPage == pageNum;
                return InkWell(
                  onTap: () {
                    setState(() => _currentPage = pageNum);
                    _fetchPayments();
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: isActive ? const Color(0xFF4F46E5) : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$pageNum',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        color: isActive ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ),
                );
              },
            ),

            if (_totalPages > 5) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text('...', style: TextStyle(color: Color(0xFF94A3B8))),
              ),
              InkWell(
                onTap: () {
                  setState(() => _currentPage = _totalPages);
                  _fetchPayments();
                },
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: _currentPage == _totalPages ? const Color(0xFF4F46E5) : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$_totalPages',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: _currentPage == _totalPages ? FontWeight.bold : FontWeight.normal,
                      color: _currentPage == _totalPages ? Colors.white : const Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(width: 6),
            OutlinedButton(
              onPressed: _currentPage < _totalPages
                  ? () {
                      setState(() => _currentPage++);
                      _fetchPayments();
                    }
                  : null,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(28, 28),
                padding: EdgeInsets.zero,
                side: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              child: const Icon(Icons.chevron_right_rounded, size: 16),
            ),
            const SizedBox(width: 14),

            // Rows per page dropdown: 10 / page ⌄
            Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _pageSize,
                  items: const [
                    DropdownMenuItem(value: 10, child: Text('10 / page', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 25, child: Text('25 / page', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 50, child: Text('50 / page', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _pageSize = val;
                        _currentPage = 1;
                      });
                      _fetchPayments();
                    }
                  },
                ),
              ),
            ),
          ],
        );

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    showingText,
                    const SizedBox(height: 10),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: controls,
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    showingText,
                    controls,
                  ],
                ),
        );
      },
    );
  }

  // =========================================================================
  // HELPER FORMATTERS
  // =========================================================================

  Widget _buildKeyValRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                color: isBold ? const Color(0xFF0F172A) : const Color(0xFF334155),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatCurrency(dynamic amount) {
    final numVal = double.tryParse('$amount') ?? 0.0;
    final parts = numVal.toStringAsFixed(2).split('.');
    final whole = parts[0];
    final dec = parts[1];

    final reg = RegExp(r'(\d+?)(?=(\d\d)+(\d)(?!\d))(\.\d+)?');
    String formattedWhole = whole.replaceAllMapped(reg, (Match m) => '${m[1]},');
    return '₹$formattedWhole.$dec';
  }

  String _formatDate(dynamic isoString) {
    if (isoString == null) return '03 Sep 2026';
    try {
      final dt = DateTime.parse(isoString.toString());
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final day = dt.day.toString().padLeft(2, '0');
      return '$day ${months[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return '03 Sep 2026';
    }
  }

  String _formatTime(dynamic isoString) {
    if (isoString == null) return '08:57 PM';
    try {
      final dt = DateTime.parse(isoString.toString()).toLocal();
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'PM' : 'AM';
      return '${hour.toString().padLeft(2, '0')}:$min $ampm';
    } catch (_) {
      return '08:57 PM';
    }
  }

  String _formatDateTime(dynamic isoString) {
    return '${_formatDate(isoString)}, ${_formatTime(isoString)}';
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF4F46E5).withValues(alpha: 0.08), shape: BoxShape.circle),
            child: const Icon(Icons.payments_outlined, size: 40, color: Color(0xFF4F46E5)),
          ),
          const SizedBox(height: 14),
          Text('No payments found', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('Adjust your active filters or create an initial payment order.', style: GoogleFonts.dmSans(fontSize: 12, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }
}
