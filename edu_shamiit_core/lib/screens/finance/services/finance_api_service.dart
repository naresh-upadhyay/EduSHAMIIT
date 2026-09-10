import '../../../../services/api_service.dart';
import '../models/finance_models.dart';

class FinanceApiService {
  final ApiService _api = ApiService();

  /// Safely converts a JSON value to Map<String, dynamic>.
  /// Handles Flutter Web's LinkedHashMap<dynamic, dynamic> from jsonDecode.
  static Map<String, dynamic> _safeMap(dynamic raw) {
    if (raw == null) return {};
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  /// Safely converts a JSON value to List<dynamic>.
  static List<dynamic> _safeList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw;
    return [];
  }

  /// Fetch Finance Overview Data
  Future<FinanceOverviewData?> getOverview({String? academicYear}) async {
    try {
      final query = <String, String>{};
      if (academicYear != null && academicYear.isNotEmpty) {
        query['academic_year'] = academicYear;
      }
      final res = await _api.get('/finance/overview', query: query);
      if (res['success'] == true && res['data'] != null) {
        return FinanceOverviewData.fromJson(_safeMap(res['data']));
      }
    } catch (e) {
      print('Error fetching finance overview: $e');
    }
    return null;
  }

  /// Fetch Paginated Fees Ledger
  Future<Map<String, dynamic>> getFeesLedger({
    int page = 1,
    int limit = 10,
    String? academicYear,
    String? classId,
    String? feeHead,
    String? status,
    String? search,
  }) async {
    try {
      final query = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (academicYear != null && academicYear.isNotEmpty) query['academic_year'] = academicYear;
      if (classId != null && classId.isNotEmpty) query['class_id'] = classId;
      if (feeHead != null && feeHead.isNotEmpty) query['fee_head'] = feeHead;
      if (status != null && status.isNotEmpty) query['status'] = status;
      if (search != null && search.isNotEmpty) query['search'] = search;

      final res = await _api.get('/finance/fees/ledger', query: query);
      if (res['success'] == true && res['data'] != null) {
        final data = _safeMap(res['data']);
        final itemsRaw = _safeList(data['items']);
        final items = itemsRaw.map((e) => FeeLedgerItem.fromJson(_safeMap(e))).toList();
        return {
          'items': items,
          'total': data['total'] ?? 0,
          'page': data['page'] ?? 1,
          'total_pages': data['total_pages'] ?? 1,
        };
      }
    } catch (e) {
      print('Error fetching fee ledger: $e');
    }
    return {'items': <FeeLedgerItem>[], 'total': 0, 'page': 1, 'total_pages': 1};
  }

  /// Fetch Student Fee Account Profile
  Future<StudentFeeAccountData?> getStudentAccount(String studentId) async {
    try {
      final res = await _api.get('/finance/students/$studentId/account');
      if (res['success'] == true && res['data'] != null) {
        return StudentFeeAccountData.fromJson(_safeMap(res['data']));
      }
    } catch (e) {
      print('Error fetching student fee account: $e');
    }
    return null;
  }

  /// Fetch Fee Structures
  Future<List<FeeStructureModel>> getFeeStructures({String? academicYear}) async {
    try {
      final query = <String, String>{};
      if (academicYear != null && academicYear.isNotEmpty) query['academic_year'] = academicYear;
      final res = await _api.get('/finance/fee-structures', query: query);
      if (res['success'] == true && res['data'] is List) {
        return _safeList(res['data']).map((e) => FeeStructureModel.fromJson(_safeMap(e))).toList();
      }
    } catch (e) {
      print('Error fetching fee structures: $e');
    }
    return [];
  }

  /// Create Fee Structure
  Future<bool> createFeeStructure(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/finance/fee-structures', payload);
      return res['success'] == true;
    } catch (e) {
      print('Error creating fee structure: $e');
      return false;
    }
  }

  /// Assign Fee Structure
  Future<bool> assignFeeStructure(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/finance/fee-assignments', payload);
      return res['success'] == true;
    } catch (e) {
      print('Error assigning fee structure: $e');
      return false;
    }
  }

  /// Collect Payment
  Future<Map<String, dynamic>?> collectPayment(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/finance/payments/collect', payload);
      if (res['success'] == true && res['data'] != null) {
        return _safeMap(res['data']);
      }
    } catch (e) {
      print('Error collecting payment: $e');
    }
    return null;
  }

  /// Apply Concession
  Future<bool> applyConcession(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/finance/concessions', payload);
      return res['success'] == true;
    } catch (e) {
      print('Error applying concession: $e');
      return false;
    }
  }

  /// Request Refund
  Future<bool> requestRefund(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/finance/refunds', payload);
      return res['success'] == true;
    } catch (e) {
      print('Error requesting refund: $e');
      return false;
    }
  }

  /// Send Reminders
  Future<bool> sendReminders(List<String> studentIds, {String reminderType = 'overdue', String channel = 'sms'}) async {
    try {
      final res = await _api.post('/finance/reminders/send', {
        'student_ids': studentIds,
        'reminder_type': reminderType,
        'channel': channel,
      });
      return res['success'] == true;
    } catch (e) {
      print('Error sending reminders: $e');
      return false;
    }
  }

  /// Global Search
  Future<Map<String, dynamic>> globalSearch(String query) async {
    try {
      final res = await _api.get('/finance/search', query: {'q': query});
      if (res['success'] == true && res['data'] != null) {
        return _safeMap(res['data']);
      }
    } catch (e) {
      print('Error performing global finance search: $e');
    }
    return {'students': [], 'invoices': [], 'payments': []};
  }

  /// Get Chart of Accounts
  Future<List<ChartOfAccount>> getChartOfAccounts() async {
    try {
      final res = await _api.get('/finance/accounts');
      if (res['success'] == true && res['data'] != null) {
        return _safeList(res['data']).map((e) => ChartOfAccount.fromJson(_safeMap(e))).toList();
      }
    } catch (e) {
      print('Error loading chart of accounts: $e');
    }
    return [];
  }

  /// Create Account
  Future<bool> createAccount(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/finance/accounts', payload);
      return res['success'] == true;
    } catch (e) {
      print('Error creating account: $e');
      return false;
    }
  }

  /// Post Double-Entry Journal Entry
  Future<bool> postJournalEntry(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/finance/ledger', payload);
      return res['success'] == true;
    } catch (e) {
      print('Error posting journal entry: $e');
      return false;
    }
  }

  /// Process Monthly Staff Payroll
  Future<bool> processPayroll(String month) async {
    try {
      final res = await _api.post('/finance/payroll/process', {'payroll_month': month});
      return res['success'] == true;
    } catch (e) {
      print('Error processing payroll: $e');
      return false;
    }
  }

  /// Get Payslips
  Future<List<StaffPayslip>> getPayslips() async {
    try {
      final res = await _api.get('/finance/payroll/payslips');
      if (res['success'] == true && res['data'] != null) {
        return _safeList(res['data']).map((e) => StaffPayslip.fromJson(_safeMap(e))).toList();
      }
    } catch (e) {
      print('Error loading payslips: $e');
    }
    return [];
  }

  /// Get Expenses
  Future<List<ExpenseModel>> getExpenses() async {
    try {
      final res = await _api.get('/finance/expenses');
      if (res['success'] == true && res['data'] != null) {
        return _safeList(res['data']).map((e) => ExpenseModel.fromJson(_safeMap(e))).toList();
      }
    } catch (e) {
      print('Error loading expenses: $e');
    }
    return [];
  }

  /// Create Expense
  Future<bool> createExpense(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/finance/expenses', payload);
      return res['success'] == true;
    } catch (e) {
      print('Error creating expense: $e');
      return false;
    }
  }

  /// Get Vendors
  Future<List<VendorModel>> getVendors() async {
    try {
      final res = await _api.get('/finance/vendors');
      if (res['success'] == true && res['data'] != null) {
        return _safeList(res['data']).map((e) => VendorModel.fromJson(_safeMap(e))).toList();
      }
    } catch (e) {
      print('Error loading vendors: $e');
    }
    return [];
  }

  /// Get Bank Accounts
  Future<List<BankAccountModel>> getBankAccounts() async {
    try {
      final res = await _api.get('/finance/banks');
      if (res['success'] == true && res['data'] != null) {
        return _safeList(res['data']).map((e) => BankAccountModel.fromJson(_safeMap(e))).toList();
      }
    } catch (e) {
      print('Error loading bank accounts: $e');
    }
    return [];
  }

  /// Bank Fund Transfer
  Future<bool> transferBankFunds(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/finance/banks/transfer', payload);
      return res['success'] == true;
    } catch (e) {
      print('Error transferring funds: $e');
      return false;
    }
  }

  /// Get Profit & Loss Report
  Future<Map<String, dynamic>> getProfitLossReport(String year) async {
    try {
      final res = await _api.get('/finance/reports/profit-loss', query: {'financial_year': year});
      if (res['success'] == true && res['data'] != null) {
        return _safeMap(res['data']);
      }
    } catch (e) {
      print('Error generating P&L report: $e');
    }
    return {};
  }
}
