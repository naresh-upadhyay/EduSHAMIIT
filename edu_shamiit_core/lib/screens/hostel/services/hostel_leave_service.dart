import 'package:edu_shamiit_core/services/api_service.dart';
import '../models/hostel_leave_outing_models.dart';

class HostelLeaveService {
  final ApiService _api = ApiService();

  /// Retrieve high-level KPI cards data
  Future<LeaveOutingKpiData> getKpis({String academicYear = '2026 - 2027'}) async {
    try {
      final res = await _api.get(
        '/hostel/leave-outing/kpis',
        query: {'academic_year': academicYear},
        useCache: false,
      );
      if (res['success'] == true && res['data'] != null) {
        return LeaveOutingKpiData.fromJson(res['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return const LeaveOutingKpiData();
  }

  /// Paginated list of Leave & Outing requests
  Future<Map<String, dynamic>> getRequests({
    String? search,
    String? hostelId,
    String? requestType,
    String? status,
    String? fromDate,
    String? toDate,
    String? studentId,
    bool? currentlyOut,
    bool? overdueOnly,
    bool? isEmergency,
    String academicYear = '2026 - 2027',
    int page = 1,
    int pageSize = 10,
    String sortBy = 'request_number',
    String sortOrder = 'asc',
  }) async {
    try {
      final query = <String, dynamic>{
        'academic_year': academicYear,
        'page': page,
        'page_size': pageSize,
        'sort_by': sortBy,
        'sort_order': sortOrder,
      };
      if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();
      if (hostelId != null && hostelId.trim().isNotEmpty && hostelId != 'All Hostels') query['hostel_id'] = hostelId.trim();
      if (requestType != null && requestType.trim().isNotEmpty && requestType != 'All Types') query['request_type'] = requestType.trim().toUpperCase();
      if (status != null && status.trim().isNotEmpty && status != 'All Status') query['status'] = status.trim().toUpperCase();
      if (fromDate != null) query['from_date'] = fromDate;
      if (toDate != null) query['to_date'] = toDate;
      if (studentId != null) query['student_id'] = studentId;
      if (currentlyOut == true) query['currently_out'] = true;
      if (overdueOnly == true) query['overdue_only'] = true;
      if (isEmergency == true) query['is_emergency'] = true;

      final res = await _api.get('/hostel/leave-outing', query: query, useCache: false);
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        final items = (data['items'] as List? ?? [])
            .map((item) => LeaveOutingRequestItem.fromJson(item as Map<String, dynamic>))
            .toList();
        final total = (data['total'] as num?)?.toInt() ?? 0;
        final totalPages = (data['total_pages'] as num?)?.toInt() ?? 1;
        final currentPage = (data['page'] as num?)?.toInt() ?? page;

        return {
          'items': items,
          'total': total,
          'total_pages': totalPages,
          'page': currentPage,
          'page_size': pageSize,
        };
      }
    } catch (_) {}
    return {
      'items': <LeaveOutingRequestItem>[],
      'total': 0,
      'total_pages': 1,
      'page': page,
      'page_size': pageSize,
    };
  }

  /// Top pending requests for right sidebar "Awaiting Approval" card
  Future<List<AwaitingApprovalItem>> getAwaitingApproval({int limit = 8}) async {
    try {
      final res = await _api.get(
        '/hostel/leave-outing/awaiting-approval',
        query: {'limit': limit},
        useCache: false,
      );
      if (res['success'] == true && res['data'] != null) {
        return (res['data'] as List)
            .map((item) => AwaitingApprovalItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return <AwaitingApprovalItem>[];
  }

  /// Retrieve currently out students
  Future<Map<String, dynamic>> getCurrentlyOut({int page = 1, int pageSize = 20}) async {
    try {
      final res = await _api.get(
        '/hostel/leave-outing/currently-out',
        query: {'page': page, 'page_size': pageSize},
        useCache: false,
      );
      if (res['success'] == true && res['data'] != null) {
        List rawList = [];
        int total = 0;
        if (res['data'] is List) {
          rawList = res['data'] as List;
          total = rawList.length;
        } else if (res['data'] is Map<String, dynamic>) {
          final data = res['data'] as Map<String, dynamic>;
          rawList = data['items'] as List? ?? [];
          total = (data['total'] as num?)?.toInt() ?? rawList.length;
        }
        final items = rawList
            .map((item) => LeaveOutingRequestItem.fromJson(item as Map<String, dynamic>))
            .toList();
        return {
          'items': items,
          'total': total,
        };
      }
    } catch (_) {}
    return {'items': <LeaveOutingRequestItem>[], 'total': 0};
  }

  /// Retrieve full details of a specific request
  Future<Map<String, dynamic>?> getRequestById(String id) async {
    try {
      final res = await _api.get('/hostel/leave-outing/$id', useCache: false);
      if (res['success'] == true && res['data'] != null) {
        return res['data'] as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Create new Leave / Outing request
  Future<Map<String, dynamic>> createRequest(Map<String, dynamic> payload) async {
    try {
      final res = await _api.post('/hostel/leave-outing', payload);
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Approve request
  Future<Map<String, dynamic>> approveRequest(
    String id, {
    String? notes,
    String? conditions,
    int version = 1,
  }) async {
    try {
      final res = await _api.post(
        '/hostel/leave-outing/$id/approve',
        {
          if (notes != null) 'remarks': notes,
          if (conditions != null) 'conditions': conditions,
          'version': version,
        },
      );
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Reject request
  Future<Map<String, dynamic>> rejectRequest(
    String id, {
    required String reason,
    String? internalNotes,
    int version = 1,
  }) async {
    try {
      final res = await _api.post(
        '/hostel/leave-outing/$id/reject',
        {
          'reason': reason,
          if (internalNotes != null) 'internal_note': internalNotes,
          'version': version,
        },
      );
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Cancel request
  Future<Map<String, dynamic>> cancelRequest(
    String id, {
    required String reason,
    int version = 1,
  }) async {
    try {
      final res = await _api.post(
        '/hostel/leave-outing/$id/cancel',
        {
          'reason': reason,
          'version': version,
        },
      );
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Generate Digital Gate Pass
  Future<Map<String, dynamic>> generateGatePass(String requestId) async {
    try {
      final res = await _api.post('/hostel/leave-outing/$requestId/gate-pass', {});
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get Gate Pass details by ID
  Future<GatePassData?> getGatePass(String gatePassId) async {
    try {
      final res = await _api.get('/hostel/gate-pass/$gatePassId', useCache: false);
      if (res['success'] == true && res['data'] != null) {
        return GatePassData.fromJson(res['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  /// Verify Gate Pass QR or Token
  Future<Map<String, dynamic>> verifyGatePass(String token) async {
    try {
      final res = await _api.post('/hostel/gate-pass/verify', {'identifier': token});
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Computer vision image scan for gate pass QR
  Future<Map<String, dynamic>> scanGatePassImage(String base64Image) async {
    try {
      final res = await _api.post('/hostel/gate-pass/scan-image', {'image_base64': base64Image});
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Execute Gate Pass Clearance Action (Departure Exit or Arrival Return)
  Future<Map<String, dynamic>> executeGatePassScanAction(
    String identifier, {
    required String action,
    String gate = 'Main Gate',
    String? remarks,
  }) async {
    try {
      final res = await _api.post(
        '/hostel/gate-pass/$identifier/scan-action',
        {
          'action': action,
          'gate': gate,
          if (remarks != null && remarks.trim().isNotEmpty) 'remarks': remarks.trim(),
        },
      );
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Record Actual Exit
  Future<Map<String, dynamic>> markExit(String requestId, {String gate = 'Main Gate', String? remarks}) async {
    try {
      final res = await _api.post(
        '/hostel/leave-outing/$requestId/exit',
        {'gate': gate, if (remarks != null) 'remarks': remarks},
      );
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Record Actual Return
  Future<Map<String, dynamic>> markReturn(String requestId, {String gate = 'Main Gate', String? remarks}) async {
    try {
      final res = await _api.post(
        '/hostel/leave-outing/$requestId/return',
        {'gate': gate, if (remarks != null) 'remarks': remarks},
      );
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Get Rules & Settings
  Future<LeaveOutingSettingsData> getSettings() async {
    try {
      final res = await _api.get('/hostel/leave-outing/settings', useCache: false);
      if (res['success'] == true && res['data'] != null) {
        return LeaveOutingSettingsData.fromJson(res['data'] as Map<String, dynamic>);
      }
    } catch (_) {}
    return const LeaveOutingSettingsData();
  }

  /// Save Rules & Settings
  Future<Map<String, dynamic>> saveSettings(LeaveOutingSettingsData settings) async {
    try {
      final res = await _api.put('/hostel/leave-outing/settings', settings.toJson());
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Calendar events
  Future<List<Map<String, dynamic>>> getCalendarEvents({
    String academicYear = '2026 - 2027',
    int? month,
    int? year,
  }) async {
    try {
      final query = <String, dynamic>{'academic_year': academicYear};
      if (month != null) query['month'] = month;
      if (year != null) query['year'] = year;
      final res = await _api.get('/hostel/leave-outing/calendar', query: query, useCache: false);
      if (res['success'] == true && res['data'] != null) {
        if (res['data'] is List) {
          return (res['data'] as List).map((e) => e as Map<String, dynamic>).toList();
        } else if (res['data'] is Map && res['data']['events'] is List) {
          return (res['data']['events'] as List).map((e) => e as Map<String, dynamic>).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  /// Export Leave & Outing requests to CSV bytes
  Future<List<int>?> exportLeaveOutingCsv({String academicYear = '2026 - 2027'}) async {
    final queryStr = Uri.encodeComponent(academicYear);
    return await _api.getRawBytes('/hostel/leave-outing/export/csv?academic_year=$queryStr');
  }

  /// List of digital gate passes with live movement details
  Future<Map<String, dynamic>> getGatePasses({
    String? search,
    String? status,
    String? hostelName,
    String? requestType,
    String? fromDate,
    String? toDate,
    String? academicYear,
    int page = 1,
    int pageSize = 10,
    String sortBy = 'generated_at',
    String sortOrder = 'DESC',
  }) async {
    try {
      final query = <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        'sort_by': sortBy,
        'sort_order': sortOrder,
      };
      if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();
      if (status != null && status.trim().isNotEmpty && status != 'All Status') query['status'] = status.trim().toUpperCase();
      if (hostelName != null && hostelName.trim().isNotEmpty && hostelName != 'All Hostels') query['hostel_name'] = hostelName.trim();
      if (requestType != null && requestType.trim().isNotEmpty && requestType != 'All Types') query['request_type'] = requestType.trim().toUpperCase();
      if (fromDate != null && fromDate.trim().isNotEmpty) query['from_date'] = fromDate.trim();
      if (toDate != null && toDate.trim().isNotEmpty) query['to_date'] = toDate.trim();
      if (academicYear != null && academicYear.trim().isNotEmpty) query['academic_year'] = academicYear.trim();

      final res = await _api.get('/hostel/leave-outing/gate-passes', query: query, useCache: false);
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        final items = (data['items'] as List? ?? [])
            .map((item) => GatePassData.fromJson(item as Map<String, dynamic>))
            .toList();
        final total = (data['total'] as num?)?.toInt() ?? 0;
        final totalPages = (data['total_pages'] as num?)?.toInt() ?? 1;

        return {
          'items': items,
          'total': total,
          'total_pages': totalPages,
          'page': page,
          'page_size': pageSize,
        };
      }
    } catch (_) {}
    return {
      'items': <GatePassData>[],
      'total': 0,
      'total_pages': 1,
      'page': page,
      'page_size': pageSize,
    };
  }

  /// Add / Upload supporting document
  Future<Map<String, dynamic>> addDocument(String requestId, Map<String, dynamic> docPayload) async {
    try {
      if (docPayload['file_bytes'] != null && docPayload['file_bytes'] is List<int>) {
        final bytes = docPayload['file_bytes'] as List<int>;
        return await uploadDocumentBytes(
          requestId,
          fileBytes: bytes,
          fileName: docPayload['document_name'] ?? 'document.pdf',
          documentType: docPayload['document_type'] ?? 'Parent Consent',
          notes: docPayload['notes']?.toString(),
        );
      }
      final res = await _api.post('/hostel/leave-outing/$requestId/documents', docPayload);
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Upload physical document file with raw bytes via multipart
  Future<Map<String, dynamic>> uploadDocumentBytes(
    String requestId, {
    required List<int> fileBytes,
    required String fileName,
    required String documentType,
    String? notes,
  }) async {
    try {
      final fields = <String, String>{
        'document_name': fileName,
        'document_type': documentType,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      };
      return await _api.multipartPostBytes(
        '/hostel/leave-outing/$requestId/documents/upload',
        fileBytes,
        fileName,
        'file',
        fields: fields,
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Delete supporting document
  Future<Map<String, dynamic>> deleteDocument(String requestId, String docId) async {
    try {
      final res = await _api.delete('/hostel/leave-outing/$requestId/documents/$docId');
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Download supporting document raw bytes
  Future<List<int>?> downloadDocumentBytes(String requestId, String docId) async {
    try {
      return await _api.getRawBytes('/hostel/leave-outing/$requestId/documents/$docId/download');
    } catch (_) {
      return null;
    }
  }

  /// Add internal note / remark
  Future<Map<String, dynamic>> addNote(String requestId, {required String note, String category = 'General'}) async {
    try {
      final res = await _api.post(
        '/hostel/leave-outing/$requestId/notes',
        {'note': note, 'category': category},
      );
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Delete internal note
  Future<Map<String, dynamic>> deleteNote(String requestId, String noteId) async {
    try {
      final res = await _api.delete('/hostel/leave-outing/$requestId/notes/$noteId');
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Update existing request
  Future<Map<String, dynamic>> updateRequest(String requestId, Map<String, dynamic> payload) async {
    try {
      final res = await _api.patch('/hostel/leave-outing/$requestId', payload);
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Delete / Cancel request
  Future<Map<String, dynamic>> deleteRequest(String requestId) async {
    try {
      final res = await _api.delete('/hostel/leave-outing/$requestId');
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Confirm guardian
  Future<Map<String, dynamic>> confirmGuardian(String requestId, bool confirmed) async {
    try {
      final res = await _api.post(
        '/hostel/leave-outing/$requestId/confirm-guardian',
        {'confirmed': confirmed},
      );
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Revoke approval
  Future<Map<String, dynamic>> revokeApproval(String requestId, {String? reason}) async {
    try {
      final res = await _api.post(
        '/hostel/leave-outing/$requestId/revoke-approval',
        {'reason': reason ?? 'Approval revoked by administrative staff'},
      );
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Reset movement
  Future<Map<String, dynamic>> resetMovement(String requestId) async {
    try {
      final res = await _api.post('/hostel/leave-outing/$requestId/reset-movement', {});
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  /// Update movement
  Future<Map<String, dynamic>> updateMovement(String requestId, Map<String, dynamic> movementData) async {
    try {
      final res = await _api.put('/hostel/leave-outing/$requestId/movement', movementData);
      return res;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}

