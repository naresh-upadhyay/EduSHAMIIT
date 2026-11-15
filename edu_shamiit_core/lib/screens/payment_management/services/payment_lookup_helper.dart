import '../../../services/api_service.dart';
import '../../../services/lookup_event_bus.dart';

class PaymentLookupItem {
  final String id;
  final String code;
  final String label;
  final String description;
  final String status;
  final int sortOrder;

  const PaymentLookupItem({
    required this.id,
    required this.code,
    required this.label,
    this.description = '',
    this.status = 'ACTIVE',
    this.sortOrder = 0,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  factory PaymentLookupItem.fromJson(Map<String, dynamic> json) {
    return PaymentLookupItem(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? json['value_code']?.toString() ?? '',
      label: json['label']?.toString() ?? json['value_name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class PaymentLookupHelper {
  static final PaymentLookupHelper instance = PaymentLookupHelper._internal();
  PaymentLookupHelper._internal() {
    LookupEventBus.instance.addListener(() {
      final event = LookupEventBus.instance.lastEvent;
      if (event?.keyCode != null && event!.keyCode!.isNotEmpty) {
        clearCache(event.keyCode);
      } else {
        clearCache();
      }
    });
  }

  final ApiService _api = ApiService();
  final Map<String, List<PaymentLookupItem>> _cache = {};

  Future<List<PaymentLookupItem>> getActiveLookup(
    String keyCode, {
    List<PaymentLookupItem>? fallbacks,
    bool forceRefresh = false,
  }) async {
    final upperKey = keyCode.toUpperCase().trim();
    if (!forceRefresh && _cache.containsKey(upperKey) && _cache[upperKey]!.isNotEmpty) {
      return _cache[upperKey]!;
    }

    try {
      final res = await _api.get(
        '/lookups/code/$upperKey',
        query: {'include_inactive': false},
        useCache: false,
      );

      if (res['success'] == true && res['values'] is List) {
        final list = (res['values'] as List)
            .map((e) => PaymentLookupItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((item) => item.isActive)
            .toList();

        if (list.isNotEmpty) {
          _cache[upperKey] = list;
          return list;
        }
      }
    } catch (_) {}

    if (fallbacks != null && fallbacks.isNotEmpty) {
      _cache[upperKey] = fallbacks;
      return fallbacks;
    }

    return _getDefaultFallbacks(upperKey);
  }

  void clearCache([String? keyCode]) {
    if (keyCode != null) {
      _cache.remove(keyCode.toUpperCase().trim());
    } else {
      _cache.clear();
    }
  }

  List<PaymentLookupItem> _getDefaultFallbacks(String keyCode) {
    switch (keyCode) {
      case 'STUDENT_FEE_TYPE':
        return const [
          PaymentLookupItem(id: '1', code: 'TUITION', label: 'Tuition Fee'),
          PaymentLookupItem(id: '2', code: 'ADMISSION', label: 'Admission Fee'),
          PaymentLookupItem(id: '3', code: 'EXAM', label: 'Examination Fee'),
          PaymentLookupItem(id: '4', code: 'LAB', label: 'Science & Computer Lab Fee'),
          PaymentLookupItem(id: '5', code: 'LIBRARY', label: 'Library & Digital Resources Fee'),
          PaymentLookupItem(id: '6', code: 'SPORTS', label: 'Sports & Fitness Fee'),
          PaymentLookupItem(id: '7', code: 'DEVELOPMENT', label: 'Annual Campus Development Fee'),
          PaymentLookupItem(id: '8', code: 'TRANSPORT', label: 'Transportation Fee'),
        ];
      case 'STUDENT_FEE_BILLING_CYCLE':
        return const [
          PaymentLookupItem(id: '1', code: 'MONTHLY', label: 'Monthly'),
          PaymentLookupItem(id: '2', code: 'QUARTERLY', label: 'Quarterly'),
          PaymentLookupItem(id: '3', code: 'TERM_WISE', label: 'Term-Wise'),
          PaymentLookupItem(id: '4', code: 'ANNUAL', label: 'Annual'),
          PaymentLookupItem(id: '5', code: 'ONE_TIME', label: 'One-Time'),
        ];
      case 'STUDENT_FEE_PAYMENT_STATUS':
        return const [
          PaymentLookupItem(id: '1', code: 'PAID', label: 'Paid'),
          PaymentLookupItem(id: '2', code: 'PARTIAL', label: 'Partial'),
          PaymentLookupItem(id: '3', code: 'PENDING', label: 'Pending'),
          PaymentLookupItem(id: '4', code: 'OVERDUE', label: 'Overdue'),
        ];
      case 'STUDENT_FEE_PAYMENT_MODE':
      case 'STAFF_SALARY_PAYMENT_MODE':
        return const [
          PaymentLookupItem(id: '1', code: 'UPI', label: 'UPI'),
          PaymentLookupItem(id: '2', code: 'CASH', label: 'Cash'),
          PaymentLookupItem(id: '3', code: 'BANK_TRANSFER', label: 'Direct Bank Transfer (NEFT/RTGS)'),
          PaymentLookupItem(id: '4', code: 'CARD', label: 'Credit / Debit Card'),
          PaymentLookupItem(id: '5', code: 'CHEQUE', label: 'Cheque'),
        ];
      case 'STUDENT_FEE_CONCESSION_TYPE':
        return const [
          PaymentLookupItem(id: '1', code: 'MERIT_SCHOLARSHIP', label: 'Academic Merit Scholarship'),
          PaymentLookupItem(id: '2', code: 'SIBLING_DISCOUNT', label: 'Sibling Concession'),
          PaymentLookupItem(id: '3', code: 'STAFF_CHILD', label: 'Staff Ward Concession'),
          PaymentLookupItem(id: '4', code: 'SPORTS_QUOTA', label: 'Sports Excellence Quota'),
        ];
      case 'STAFF_SALARY_PAYMENT_STATUS':
        return const [
          PaymentLookupItem(id: '1', code: 'PAID', label: 'Paid'),
          PaymentLookupItem(id: '2', code: 'PROCESSED', label: 'Processed'),
          PaymentLookupItem(id: '3', code: 'PENDING', label: 'Pending'),
          PaymentLookupItem(id: '4', code: 'ON_HOLD', label: 'On Hold'),
        ];
      default:
        return const [];
    }
  }
}
