import 'package:edu_shamiit_core/services/api_service.dart';
import '../models/hostel_models.dart';

class HostelApiService {
  final ApiService _api = ApiService();

  Future<HostelKPIs> getKPIs({String academicYear = '2026 - 2027'}) async {
    final res = await _api.get(
      '/hostel/kpis',
      query: {'academic_year': academicYear},
      useCache: false,
    );
    if (res['success'] == true && res['data'] != null) {
      return HostelKPIs.fromJson(res['data'] as Map<String, dynamic>);
    }
    return HostelKPIs();
  }

  Future<Map<String, dynamic>> getOverviewAnalytics({String academicYear = '2026 - 2027'}) async {
    final res = await _api.get(
      '/hostel/overview',
      query: {'academic_year': academicYear},
      useCache: false,
    );
    if (res['success'] == true && res['data'] != null) {
      return Map<String, dynamic>.from(res['data'] as Map);
    }
    return {};
  }

  Future<Map<String, dynamic>> getReportsData({
    required String reportType,
    String academicYear = '2026 - 2027',
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final query = <String, dynamic>{
      'report_type': reportType,
      'academic_year': academicYear,
    };
    if (startDate != null) {
      query['start_date'] = startDate.toIso8601String().split('T')[0];
    }
    if (endDate != null) {
      query['end_date'] = endDate.toIso8601String().split('T')[0];
    }
    final res = await _api.get(
      '/hostel/reports',
      query: query,
      useCache: false,
    );
    if (res['success'] == true && res['data'] != null) {
      return Map<String, dynamic>.from(res['data'] as Map);
    } else if (res['records'] != null) {
      return Map<String, dynamic>.from(res);
    }
    return {'records': [], 'record_count': 0, 'report_type': reportType};
  }

  Future<List<HostelBuilding>> getStructureTree({String search = ''}) async {
    final res = await _api.get(
      '/hostel/structure-tree',
      query: {'search': search},
      useCache: false,
    );
    if (res['success'] == true && res['data'] is List) {
      return (res['data'] as List)
          .map((b) => HostelBuilding.fromJson(b as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getRooms({
    String search = '',
    String? buildingId,
    String? floorId,
    String roomType = 'ALL',
    String status = 'ALL',
    int page = 1,
    int pageSize = 10,
    String sortBy = 'room_number',
    String sortOrder = 'ASC',
  }) async {
    final query = <String, dynamic>{
      'search': search,
      'room_type': roomType,
      'status': status,
      'page': page,
      'page_size': pageSize,
      'sort_by': sortBy,
      'sort_order': sortOrder,
    };
    if (buildingId != null && buildingId.isNotEmpty) {
      query['building_id'] = buildingId;
    }
    if (floorId != null && floorId.isNotEmpty) {
      query['floor_id'] = floorId;
    }

    final res = await _api.get('/hostel/rooms', query: query, useCache: false);
    if (res['success'] == true) {
      final list = (res['data'] as List? ?? [])
          .map((r) => HostelRoomItem.fromJson(r as Map<String, dynamic>))
          .toList();
      return {
        'rooms': list,
        'context_title': res['context_title'] ?? 'Rooms',
        'pagination': res['pagination'] ?? {},
      };
    }
    return {'rooms': <HostelRoomItem>[], 'context_title': 'Rooms', 'pagination': {}};
  }

  Future<HostelRoomDetail?> getRoomDetail(String roomId) async {
    final res = await _api.get('/hostel/rooms/$roomId', useCache: false);
    if (res['success'] == true && res['data'] != null) {
      return HostelRoomDetail.fromJson(res['data'] as Map<String, dynamic>);
    }
    return null;
  }

  Future<HostelFilterOptions> getFilterOptions() async {
    final res = await _api.get('/hostel/filter-options', useCache: false);
    if (res['success'] == true && res['data'] != null) {
      return HostelFilterOptions.fromJson(res['data'] as Map<String, dynamic>);
    }
    return HostelFilterOptions();
  }

  Future<Map<String, dynamic>> saveBuilding(Map<String, dynamic> data) async {
    final id = data['id'];
    return id != null
        ? await _api.patch('/hostel/buildings/$id', data)
        : await _api.post('/hostel/buildings', data);
  }

  Future<bool> deleteBuilding(String buildingId) async {
    final res = await _api.delete('/hostel/buildings/$buildingId');
    return res['success'] == true;
  }

  Future<Map<String, dynamic>> saveFloor(Map<String, dynamic> data) async {
    final id = data['id'];
    return id != null
        ? await _api.patch('/hostel/floors/$id', data)
        : await _api.post('/hostel/floors', data);
  }

  Future<bool> deleteFloor(String floorId) async {
    final res = await _api.delete('/hostel/floors/$floorId');
    return res['success'] == true;
  }

  Future<Map<String, dynamic>> saveRoom(Map<String, dynamic> data) async {
    final id = data['id'];
    return id != null
        ? await _api.patch('/hostel/rooms/$id', data)
        : await _api.post('/hostel/rooms', data);
  }

  Future<bool> deleteRoom(String roomId) async {
    final res = await _api.delete('/hostel/rooms/$roomId');
    return res['success'] == true;
  }

  Future<Map<String, dynamic>> bulkGenerateRooms(Map<String, dynamic> data) async {
    return await _api.post('/hostel/rooms/bulk-generate', data);
  }

  Future<Map<String, dynamic>> saveBed(Map<String, dynamic> data) async {
    final id = data['id'];
    return id != null
        ? await _api.patch('/hostel/beds/$id', data)
        : await _api.post('/hostel/beds', data);
  }

  Future<bool> deleteBed(String bedId) async {
    final res = await _api.delete('/hostel/beds/$bedId');
    return res['success'] == true;
  }

  Future<Map<String, dynamic>> saveEquipment(Map<String, dynamic> data) async {
    final id = data['id'];
    return id != null
        ? await _api.patch('/hostel/equipment/$id', data)
        : await _api.post('/hostel/equipment', data);
  }

  Future<bool> deleteEquipment(String equipmentId) async {
    final res = await _api.delete('/hostel/equipment/$equipmentId');
    return res['success'] == true;
  }

  Future<List<Map<String, dynamic>>> searchStudents(String query) async {
    final res = await _api.get(
      '/hostel/students/search',
      query: {'query': query},
      useCache: false,
    );
    if (res['success'] == true && res['data'] is List) {
      return (res['data'] as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> assignStudent(Map<String, dynamic> data) async {
    return await _api.post('/hostel/allocations/assign', data);
  }

  Future<Map<String, dynamic>> checkOutStudent(String allocationId, {String? reason}) async {
    return await _api.post('/hostel/allocations/check-out', {
      'allocation_id': allocationId,
      'reason': reason ?? 'Regular Check-Out',
    });
  }

  Future<Map<String, dynamic>> transferStudent(Map<String, dynamic> data) async {
    return await _api.post('/hostel/allocations/transfer', data);
  }

  Future<String> uploadRoomPhoto({
    required List<int> bytes,
    required String filename,
    String? roomId,
  }) async {
    final endpoint = roomId != null && roomId.isNotEmpty
        ? '/hostel/rooms/$roomId/photos'
        : '/hostel/upload-photo';
    final res = await _api.multipartPostBytes(
      endpoint,
      bytes,
      filename,
      'file',
    );
    if (res['success'] == true && res['data']?['url'] != null) {
      return res['data']['url'] as String;
    }
    throw res['detail'] ?? res['message'] ?? 'Failed to upload photo';
  }

  Future<bool> deleteRoomPhoto({
    required String roomId,
    required String photoUrl,
  }) async {
    final res = await _api.delete(
      '/hostel/rooms/$roomId/photos?photo_url=${Uri.encodeComponent(photoUrl)}',
    );
    return res['success'] == true;
  }

  // ==========================================================================
  // HOSTEL STUDENTS MANAGEMENT API METHODS
  // ==========================================================================

  Future<HostelStudentsKPIs> getStudentsKPIs({String academicYear = '2026 - 2027'}) async {
    try {
      final res = await _api.get(
        '/hostel/students/kpis',
        query: {'academic_year': academicYear},
        useCache: false,
      );
      if (res['success'] == true && res['data'] != null) {
        return HostelStudentsKPIs.fromJson(res['data'] as Map<String, dynamic>);
      }
    } catch (e) {
      // Fallback default
    }
    return HostelStudentsKPIs();
  }

  Future<Map<String, dynamic>> getStudentsRoster({
    String academicYear = '2026 - 2027',
    String search = '',
    String? hostelId,
    String? classId,
    String status = 'ALL',
    String feeStatus = 'ALL',
    int page = 1,
    int pageSize = 10,
    String sortBy = 'student_name',
    String sortOrder = 'ASC',
  }) async {
    final query = <String, dynamic>{
      'academic_year': academicYear,
      'search': search,
      'status': status,
      'fee_status': feeStatus,
      'page': page,
      'page_size': pageSize,
      'sort_by': sortBy,
      'sort_order': sortOrder,
    };
    if (hostelId != null && hostelId.isNotEmpty) {
      query['hostel_id'] = hostelId;
    }
    if (classId != null && classId.isNotEmpty) {
      query['class_id'] = classId;
    }

    try {
      final res = await _api.get('/hostel/students', query: query, useCache: false);
      if (res['success'] == true) {
        final list = (res['data'] as List? ?? [])
            .map((item) => HostelStudentRosterItem.fromJson(item as Map<String, dynamic>))
            .toList();
        final pagination = HostelStudentRosterPagination.fromJson(
            (res['pagination'] as Map<String, dynamic>?) ?? {});
        return {
          'data': list,
          'pagination': pagination,
        };
      }
    } catch (e) {
      // Return empty list on failure
    }
    return {
      'data': <HostelStudentRosterItem>[],
      'pagination': HostelStudentRosterPagination(),
    };
  }

  Future<HostelStudentDetail360?> getStudentDetail(String admissionOrStudentId) async {
    try {
      final res = await _api.get('/hostel/students/$admissionOrStudentId', useCache: false);
      if (res['success'] == true && res['data'] != null) {
        return HostelStudentDetail360.fromJson(res['data'] as Map<String, dynamic>);
      }
    } catch (e) {
      // Return null on failure
    }
    return null;
  }

  Future<List<EligibleStudentItem>> getEligibleStudents({
    String academicYear = '2026 - 2027',
    String search = '',
    int limit = 20,
  }) async {
    try {
      final res = await _api.get(
        '/hostel/eligible-students',
        query: {
          'academic_year': academicYear,
          'search': search,
          'limit': limit,
        },
        useCache: false,
      );
      if (res['success'] == true && res['data'] is List) {
        return (res['data'] as List)
            .map((e) => EligibleStudentItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Empty
    }
    return [];
  }

  Future<Map<String, dynamic>> admitStudent(Map<String, dynamic> payload) async {
    return await _api.post('/hostel/students/admit', payload);
  }

  Future<Map<String, dynamic>> transferStudentBed(Map<String, dynamic> payload) async {
    return await _api.post('/hostel/students/transfer', payload);
  }

  Future<Map<String, dynamic>> releaseBed(Map<String, dynamic> payload) async {
    return await _api.post('/hostel/students/release-bed', payload);
  }

  Future<Map<String, dynamic>> checkoutHostelStudent(Map<String, dynamic> payload) async {
    return await _api.post('/hostel/students/checkout', payload);
  }

  Future<List<int>?> exportStudentsCsv({
    required String academicYear,
    String? search,
    String? hostelId,
    String? status,
    String? feeStatus,
  }) async {
    final query = <String, String>{
      'academic_year': academicYear,
      if (search != null && search.isNotEmpty) 'search': search,
      if (hostelId != null && hostelId.isNotEmpty) 'hostel_id': hostelId,
      if (status != null && status != 'ALL') 'status': status,
      if (feeStatus != null && feeStatus != 'ALL') 'fee_status': feeStatus,
    };
    final uri = Uri(path: '/hostel/students/export', queryParameters: query);
    return await _api.getRawBytes(uri.toString());
  }

  Future<List<HostelStudentDocument>> getStudentDocuments(String studentId) async {
    try {
      final res = await _api.get('/hostel/students/$studentId/documents', useCache: false);
      if (res['success'] == true && res['data'] is List) {
        return (res['data'] as List)
            .map((d) => HostelStudentDocument.fromJson(d as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  Future<Map<String, dynamic>> uploadStudentDocument({
    required String studentId,
    required String documentName,
    required String documentType,
    required String fileUrl,
    int fileSizeBytes = 0,
    String mimeType = 'application/pdf',
    String? admissionId,
  }) async {
    return await _api.post('/hostel/students/$studentId/documents', {
      'document_name': documentName,
      'document_type': documentType,
      'file_url': fileUrl,
      'file_size_bytes': fileSizeBytes,
      'mime_type': mimeType,
      if (admissionId != null) 'admission_id': admissionId,
    });
  }

  Future<Map<String, dynamic>> uploadStudentDocumentMultipart({
    required String studentId,
    required List<int> fileBytes,
    required String fileName,
    required String documentName,
    required String documentType,
    String? admissionId,
  }) async {
    return await _api.multipartPostBytes(
      '/hostel/students/$studentId/documents/upload',
      fileBytes,
      fileName,
      'file',
      fields: {
        'document_name': documentName,
        'document_type': documentType,
        if (admissionId != null && admissionId.isNotEmpty) 'admission_id': admissionId,
      },
    );
  }

  Future<bool> deleteStudentDocument(String documentId) async {
    final res = await _api.delete('/hostel/students/documents/$documentId');
    return res['success'] == true;
  }

  Future<List<int>?> downloadStudentDocumentBytes(String documentId) async {
    try {
      return await _api.getRawBytes('/hostel/students/documents/$documentId/download');
    } catch (_) {
      return null;
    }
  }

  // ============================================================================
  // HOSTEL STAFF MANAGEMENT API METHODS
  // ============================================================================

  Future<HostelStaffKPIs?> getStaffKPIs(String academicYear) async {
    try {
      final res = await _api.get(
        '/hostel/staff/kpis',
        query: {'academic_year': academicYear},
        useCache: false,
      );
      if (res['success'] == true && res['data'] != null) {
        final payload = res['data'];
        if (payload is Map<String, dynamic>) {
          final actualData = (payload['data'] is Map<String, dynamic>)
              ? payload['data'] as Map<String, dynamic>
              : payload;
          return HostelStaffKPIs.fromJson(actualData);
        }
      }
    } catch (e) {
      // Return null on failure
    }
    return null;
  }

  Future<Map<String, dynamic>> getStaffRoster({
    String academicYear = '2026 - 2027',
    String search = '',
    String? hostelId,
    String role = 'ALL',
    String status = 'ALL',
    int page = 1,
    int pageSize = 10,
    String sortBy = 'default',
    String sortOrder = 'ASC',
  }) async {
    try {
      final query = <String, dynamic>{
        'academic_year': academicYear,
        'page': page,
        'page_size': pageSize,
        'sort_by': sortBy,
        'sort_order': sortOrder,
      };
      if (search.trim().isNotEmpty) query['search'] = search.trim();
      if (hostelId != null && hostelId.trim().isNotEmpty) query['hostel_id'] = hostelId;
      if (role != 'ALL') query['role'] = role;
      if (status != 'ALL') query['status'] = status;

      final res = await _api.get('/hostel/staff', query: query, useCache: false);
      if (res['success'] == true) {
        final list = (res['data'] as List<dynamic>? ?? [])
            .map((e) => HostelStaffRosterItem.fromJson(e as Map<String, dynamic>))
            .toList();
        final pagination = HostelStaffRosterPagination.fromJson(
          res['pagination'] as Map<String, dynamic>? ?? {},
        );
        return {
          'data': list,
          'pagination': pagination,
        };
      }
    } catch (e) {
      // Fallback
    }
    return {
      'data': <HostelStaffRosterItem>[],
      'pagination': HostelStaffRosterPagination(),
    };
  }

  Future<HostelStaffDetail360?> getStaffDetail(String assignmentId) async {
    try {
      final res = await _api.get('/hostel/staff/$assignmentId', useCache: false);
      if (res['success'] == true && res['data'] != null) {
        return HostelStaffDetail360.fromJson(res['data'] as Map<String, dynamic>);
      }
    } catch (e) {
      // Return null on failure
    }
    return null;
  }

  Future<List<EligibleStaffProfileItem>> getEligibleStaffProfiles({
    String search = '',
    int limit = 25,
  }) async {
    try {
      final res = await _api.get(
        '/hostel/staff/eligible-profiles',
        query: {
          'search': search,
          'limit': limit,
        },
        useCache: false,
      );
      if (res['success'] == true && res['data'] is List) {
        return (res['data'] as List)
            .map((e) => EligibleStaffProfileItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (e) {
      // Fallback
    }
    return [];
  }

  Future<Map<String, dynamic>> assignStaff(Map<String, dynamic> payload) async {
    return await _api.post('/hostel/staff/assignments', payload);
  }

  Future<Map<String, dynamic>> updateStaffAssignment(String assignmentId, Map<String, dynamic> payload) async {
    return await _api.patch('/hostel/staff/assignments/$assignmentId', payload);
  }

  Future<Map<String, dynamic>> transferStaff(String assignmentId, Map<String, dynamic> payload) async {
    return await _api.post('/hostel/staff/assignments/$assignmentId/transfer', payload);
  }

  Future<Map<String, dynamic>> endStaffAssignment(String assignmentId, Map<String, dynamic> payload) async {
    return await _api.post('/hostel/staff/assignments/$assignmentId/end', payload);
  }

  Future<Map<String, dynamic>> bulkStaffActions(Map<String, dynamic> payload) async {
    return await _api.post('/hostel/staff/bulk-actions', payload);
  }

  Future<Map<String, dynamic>> uploadStaffDocument({
    required String staffId,
    required String documentName,
    required String documentType,
    required String fileUrl,
    int fileSizeBytes = 0,
    String mimeType = 'application/pdf',
    String verificationStatus = 'VERIFIED',
    String? notes,
  }) async {
    return await _api.post('/hostel/staff/$staffId/documents', {
      'document_name': documentName,
      'document_type': documentType,
      'file_url': fileUrl,
      'file_size_bytes': fileSizeBytes,
      'mime_type': mimeType,
      'verification_status': verificationStatus,
      'notes': notes,
    });
  }

  Future<Map<String, dynamic>> uploadStaffDocumentMultipart({
    required String staffId,
    required List<int> fileBytes,
    required String fileName,
    required String documentName,
    required String documentType,
    String verificationStatus = 'VERIFIED',
    String? notes,
  }) async {
    return await _api.multipartPostBytes(
      '/hostel/staff/$staffId/documents/upload',
      fileBytes,
      fileName,
      'file',
      fields: {
        'document_name': documentName,
        'document_type': documentType,
        'verification_status': verificationStatus,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
  }

  Future<bool> verifyStaffDocument({
    required String documentId,
    required String verificationStatus,
    String? notes,
  }) async {
    final res = await _api.patch('/hostel/staff/documents/$documentId/verify', {
      'verification_status': verificationStatus,
      'notes': notes,
    });
    return res['success'] == true;
  }

  Future<bool> deleteStaffDocument(String documentId) async {
    final res = await _api.delete('/hostel/staff/documents/$documentId');
    return res['success'] == true;
  }

  Future<List<int>?> downloadStaffDocumentBytes(String documentId) async {
    try {
      return await _api.getRawBytes('/hostel/staff/documents/$documentId/download');
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> recordStaffLeave({
    required String staffId,
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
    String substituteStaffName = 'Backup Warden',
    String emergencyContact = '',
  }) async {
    return await _api.post('/hostel/staff/$staffId/leaves', {
      'leave_type': leaveType,
      'start_date': startDate,
      'end_date': endDate,
      'reason': reason,
      'substitute_staff_name': substituteStaffName,
      'emergency_contact': emergencyContact,
    });
  }

  Future<bool> returnStaffToDuty(String staffId) async {
    final res = await _api.post('/hostel/staff/$staffId/return-duty', {});
    return res['success'] == true;
  }

  // ==========================================================================
  // COMPREHENSIVE RESIDENTIAL MANAGEMENT SUBSYSTEMS
  // 1. Night Curfew & Roll-Call Attendance
  // 2. Mess & Dining Hall Management
  // 3. Room & Bed Asset Handover Audit
  // 4. Visitor Logbook & Guest Room Management
  // ==========================================================================

  // --- 1. Night Curfew Roll-Call ---
  Future<List<Map<String, dynamic>>> getNightAttendanceSessions({
    String? buildingId,
    String? attendanceDate,
    String academicYear = '2026 - 2027',
  }) async {
    final query = <String, dynamic>{'academic_year': academicYear};
    if (buildingId != null) query['building_id'] = buildingId;
    if (attendanceDate != null) query['attendance_date'] = attendanceDate;
    final res = await _api.get('/hostel/night-attendance/sessions', query: query, useCache: false);
    if (res['success'] == true && res['data'] is List) {
      return List<Map<String, dynamic>>.from(res['data'] as List);
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getStudentsForNightRoster({
    String? buildingId,
    String? floorId,
    String academicYear = '2026 - 2027',
  }) async {
    final query = <String, dynamic>{'academic_year': academicYear};
    if (buildingId != null) query['building_id'] = buildingId;
    if (floorId != null) query['floor_id'] = floorId;
    final res = await _api.get('/hostel/night-attendance/students-for-roster', query: query, useCache: false);
    if (res['success'] == true && res['data'] is List) {
      return List<Map<String, dynamic>>.from(res['data'] as List);
    }
    return [];
  }

  Future<Map<String, dynamic>> submitNightAttendance(Map<String, dynamic> payload) async {
    return await _api.post('/hostel/night-attendance/submit', payload);
  }

  // --- 2. Mess & Dining Hall ---
  Future<List<Map<String, dynamic>>> getMessMenus({
    String? buildingId,
    String? dayOfWeek,
  }) async {
    final query = <String, dynamic>{};
    if (buildingId != null) query['building_id'] = buildingId;
    if (dayOfWeek != null) query['day_of_week'] = dayOfWeek;
    final res = await _api.get('/hostel/mess/menus', query: query, useCache: false);
    if (res['success'] == true && res['data'] is List) {
      return List<Map<String, dynamic>>.from(res['data'] as List);
    }
    return [];
  }

  Future<Map<String, dynamic>> upsertMessMenu(Map<String, dynamic> payload) async {
    return await _api.post('/hostel/mess/menus', payload);
  }

  Future<List<Map<String, dynamic>>> getDietaryProfiles({String? studentId}) async {
    final query = <String, dynamic>{};
    if (studentId != null) query['student_id'] = studentId;
    final res = await _api.get('/hostel/mess/dietary-profiles', query: query, useCache: false);
    if (res['success'] == true && res['data'] is List) {
      return List<Map<String, dynamic>>.from(res['data'] as List);
    }
    return [];
  }

  Future<Map<String, dynamic>> scanMealAttendance(Map<String, dynamic> payload) async {
    return await _api.post('/hostel/mess/attendance/scan', payload);
  }

  Future<List<Map<String, dynamic>>> getMessRebates({String academicYear = '2026 - 2027'}) async {
    final res = await _api.get('/hostel/mess/rebates', query: {'academic_year': academicYear}, useCache: false);
    if (res['success'] == true && res['data'] is List) {
      return List<Map<String, dynamic>>.from(res['data'] as List);
    }
    return [];
  }

  Future<Map<String, dynamic>> processLeaveMessRebate(Map<String, dynamic> payload) async {
    return await _api.post('/hostel/mess/rebates/process-leave', payload);
  }

  // --- 3. Room & Bed Asset Inventory Audit ---
  Future<List<Map<String, dynamic>>> getAssetAudits({
    String? studentId,
    String? auditType,
  }) async {
    final query = <String, dynamic>{};
    if (studentId != null) query['student_id'] = studentId;
    if (auditType != null) query['audit_type'] = auditType;
    final res = await _api.get('/hostel/asset-audits', query: query, useCache: false);
    if (res['success'] == true && res['data'] is List) {
      return List<Map<String, dynamic>>.from(res['data'] as List);
    }
    return [];
  }

  Future<Map<String, dynamic>> recordAssetAudit(Map<String, dynamic> payload) async {
    return await _api.post('/hostel/asset-audits', payload);
  }

  // --- 4. Visitor Logbook & Guest Rooms ---
  Future<List<Map<String, dynamic>>> getHostelVisitors({
    String? status,
    String? studentId,
  }) async {
    final query = <String, dynamic>{};
    if (status != null) query['status'] = status;
    if (studentId != null) query['student_id'] = studentId;
    final res = await _api.get('/hostel/visitors', query: query, useCache: false);
    if (res['success'] == true && res['data'] is List) {
      return List<Map<String, dynamic>>.from(res['data'] as List);
    }
    return [];
  }

  Future<Map<String, dynamic>> logHostelVisitor(Map<String, dynamic> payload) async {
    return await _api.post('/hostel/visitors', payload);
  }

  Future<Map<String, dynamic>> checkoutHostelVisitor(String visitorId) async {
    return await _api.patch('/hostel/visitors/$visitorId/checkout', {});
  }

  Future<List<Map<String, dynamic>>> getGuestRoomBookings() async {
    final res = await _api.get('/hostel/visitors/guest-rooms/bookings', useCache: false);
    if (res['success'] == true && res['data'] is List) {
      return List<Map<String, dynamic>>.from(res['data'] as List);
    }
    return [];
  }

  Future<Map<String, dynamic>> bookGuestRoom(Map<String, dynamic> payload) async {
    return await _api.post('/hostel/visitors/guest-rooms/bookings', payload);
  }

  // --- 5. Turnover Forecasting, Bulk Room Status & School Classes ---
  Future<Map<String, dynamic>> getTurnoverForecast({String? academicYear}) async {
    final query = <String, dynamic>{};
    if (academicYear != null) query['academic_year'] = academicYear;
    final dynamic res = await _api.get('/hostel/turnover-forecast', query: query, useCache: false);
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return {};
  }

  Future<Map<String, dynamic>> bulkUpdateRoomStatus({
    required List<String> roomIds,
    required String status,
  }) async {
    final dynamic res = await _api.post('/hostel/rooms/bulk-status', {
      'room_ids': roomIds,
      'status': status,
    });
    if (res is Map) {
      return Map<String, dynamic>.from(res);
    }
    return {'success': false};
  }

  Future<List<String>> getSchoolClasses() async {
    final dynamic res = await _api.get('/hostel/classes', useCache: false);
    if (res is List) {
      return res.map((e) => e.toString()).toList();
    }
    if (res is Map && res['data'] is List) {
      return (res['data'] as List).map((e) => e.toString()).toList();
    }
    return [];
  }
}



