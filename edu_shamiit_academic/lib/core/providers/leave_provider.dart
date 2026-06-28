import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_core/providers/api_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────

class LeaveApplication {
  final String id;
  final String leaveType;
  final String startDate;
  final String endDate;
  final String reason;
  final String status;
  final int? durationDays;
  final String? attachmentUrl;
  final String? rejectionReason;
  final DateTime createdAt;

  LeaveApplication({
    required this.id,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.status,
    this.durationDays,
    this.attachmentUrl,
    this.rejectionReason,
    required this.createdAt,
  });

  factory LeaveApplication.fromJson(Map<String, dynamic> json) {
    return LeaveApplication(
      id: json['id'] as String,
      leaveType: (json['leave_type'] as String? ?? 'Other').trim(),
      startDate: json['start_date'] as String,
      endDate: json['end_date'] as String,
      reason: json['reason'] as String? ?? '',
      status: (json['status'] as String? ?? 'pending').toLowerCase(),
      durationDays: json['duration_days'] as int?,
      attachmentUrl: json['attachment_url'] as String?,
      rejectionReason:
          (json['rejection_reason'] as String?) ?? (json['remarks'] as String?),
      createdAt: _parseDateTime(json['created_at']),
    );
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value == null) return DateTime.now();
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return DateTime.now();
    }
  }

  /// True if the leave start date is in the future (upcoming).
  bool get isUpcoming {
    try {
      final start = DateTime.parse(startDate);
      return start.isAfter(DateTime.now().subtract(const Duration(days: 1)));
    } catch (_) {
      return false;
    }
  }

  LeaveApplication copyWith({
    String? id,
    String? leaveType,
    String? startDate,
    String? endDate,
    String? reason,
    String? status,
    int? durationDays,
    String? attachmentUrl,
    String? rejectionReason,
    DateTime? createdAt,
  }) {
    return LeaveApplication(
      id: id ?? this.id,
      leaveType: leaveType ?? this.leaveType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      durationDays: durationDays ?? this.durationDays,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATE
// ─────────────────────────────────────────────────────────────────────────────

class LeaveState {
  final bool isLoading;
  final String? error;
  final List<LeaveApplication> applications;
  final Map<String, dynamic> stats;

  LeaveState({
    this.isLoading = false,
    this.error,
    this.applications = const [],
    this.stats = const {},
  });

  LeaveState copyWith({
    bool? isLoading,
    String? error,
    List<LeaveApplication>? applications,
    Map<String, dynamic>? stats,
  }) {
    return LeaveState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      applications: applications ?? this.applications,
      stats: stats ?? this.stats,
    );
  }

  // Computed helpers
  List<LeaveApplication> get upcomingLeaves => applications
      .where((a) =>
          a.isUpcoming &&
          (a.status == 'pending' || a.status == 'approved'))
      .toList();

  List<LeaveApplication> get pastLeaves => applications
      .where((a) =>
          !a.isUpcoming ||
          a.status == 'rejected' ||
          a.status == 'cancelled')
      .toList();

  int get totalQuota => (stats['total_quota'] as int?) ?? 15;
  int get usedDays   => (stats['used']        as int?) ?? 0;
  int get pendingCount => (stats['pending']   as int?) ?? 0;
  int get balanceDays  => (stats['balance']   as int?) ?? totalQuota;
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFIER
// ─────────────────────────────────────────────────────────────────────────────

class LeaveNotifier extends StateNotifier<LeaveState> {
  final ApiService _api;

  LeaveNotifier(this._api) : super(LeaveState());

  /// Fetch all leave applications for the current user.
  Future<void> fetchLeaves({bool forceRefresh = false}) async {
    if (!forceRefresh && state.applications.isNotEmpty) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await _api.get('/leave', useCache: !forceRefresh);
      final data = response['data'] ?? response;
      final apps = (data['applications'] as List? ?? [])
          .map((a) => LeaveApplication.fromJson(a as Map<String, dynamic>))
          .toList();
      final statsRaw = data['stats'] as Map<String, dynamic>? ?? {};
      state = state.copyWith(
        isLoading: false,
        applications: apps,
        stats: statsRaw,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Submit a new leave application.
  Future<bool> submitLeave({
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
    String? attachmentUrl,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.post('/leave', {
        'leave_type': leaveType,
        'start_date': startDate,
        'end_date':   endDate,
        'reason':     reason,
        if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      });
      await fetchLeaves(forceRefresh: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Edit a pending leave application.
  Future<bool> editLeave({
    required String leaveId,
    String? leaveType,
    String? startDate,
    String? endDate,
    String? reason,
    String? attachmentUrl,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.patch('/leave/$leaveId', {
        if (leaveType  != null) 'leave_type':  leaveType,
        if (startDate  != null) 'start_date':  startDate,
        if (endDate    != null) 'end_date':    endDate,
        if (reason     != null) 'reason':      reason,
        if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      });
      await fetchLeaves(forceRefresh: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Cancel a pending leave or delete a past leave.
  Future<bool> cancelOrDeleteLeave(String leaveId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _api.delete('/leave/$leaveId');
      await fetchLeaves(forceRefresh: true);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  /// Upload an attachment to the backend
  Future<String?> uploadAttachment(List<int> bytes, String filename) async {
    try {
      final response = await _api.multipartPostBytes(
        '/leave/upload',
        bytes,
        filename,
        'file',
      );
      final data = response['data'] as Map<String, dynamic>?;
      return data?['file_url'] as String?;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

final leaveProvider =
    StateNotifierProvider<LeaveNotifier, LeaveState>((ref) {
  return LeaveNotifier(ref.watch(apiServiceProvider));
});
