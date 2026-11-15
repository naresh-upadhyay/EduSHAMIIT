import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/hostel/models/hostel_models.dart';
import 'package:edu_shamiit_core/screens/hostel/providers/hostel_provider.dart';

void main() {
  group('Hostel Staff Models & Parsing Tests', () {
    test('HostelStaffKPIs parses correctly from JSON matching screenshot figures', () {
      final json = {
        'total_staff': 28,
        'wardens_count': 4,
        'wardens_boys': 2,
        'wardens_girls': 2,
        'caretakers_count': 12,
        'support_count': 10,
        'on_leave_count': 3,
        'pending_assignments_count': 2,
      };

      final kpis = HostelStaffKPIs.fromJson(json);

      expect(kpis.totalStaff, 28);
      expect(kpis.wardensCount, 4);
      expect(kpis.wardensBoys, 2);
      expect(kpis.wardensGirls, 2);
      expect(kpis.caretakersCount, 12);
      expect(kpis.supportCount, 10);
      expect(kpis.onLeaveCount, 3);
      expect(kpis.pendingAssignmentsCount, 2);
    });

    test('HostelStaffKPIs correctly unrolls nested backend payload with exact live counts (30 staff, 5 wardens)', () {
      final nestedBackendJson = {
        'success': true,
        'data': {
          'total_staff': 30,
          'wardens_count': 5,
          'wardens_boys': 3,
          'wardens_girls': 2,
          'caretakers_count': 12,
          'support_count': 11,
          'on_leave_count': 3,
          'pending_count': 2,
          'academic_year': '2026 - 2027',
        }
      };

      final kpis = HostelStaffKPIs.fromJson(nestedBackendJson);

      expect(kpis.totalStaff, 30);
      expect(kpis.wardensCount, 5);
      expect(kpis.wardensBoys, 3);
      expect(kpis.wardensGirls, 2);
      expect(kpis.caretakersCount, 12);
      expect(kpis.supportCount, 11);
      expect(kpis.onLeaveCount, 3);
      expect(kpis.pendingAssignmentsCount, 2);
      expect(kpis.academicYear, '2026 - 2027');
    });

    test('HostelStaffRosterPagination supports page getter and sequential numbering across pages', () {
      final p1 = HostelStaffRosterPagination(currentPage: 1, pageSize: 10, totalRecords: 30, totalPages: 3);
      expect(p1.page, 1);
      final p1RowNumbers = List.generate(10, (i) => ((p1.currentPage - 1) * p1.pageSize) + i + 1);
      expect(p1RowNumbers, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);

      final p2 = HostelStaffRosterPagination(currentPage: 2, pageSize: 10, totalRecords: 30, totalPages: 3);
      expect(p2.page, 2);
      final p2RowNumbers = List.generate(10, (i) => ((p2.currentPage - 1) * p2.pageSize) + i + 1);
      expect(p2RowNumbers, [11, 12, 13, 14, 15, 16, 17, 18, 19, 20]);

      final p3 = HostelStaffRosterPagination(currentPage: 3, pageSize: 10, totalRecords: 30, totalPages: 3);
      expect(p3.page, 3);
      final p3RowNumbers = List.generate(10, (i) => ((p3.currentPage - 1) * p3.pageSize) + i + 1);
      expect(p3RowNumbers, [21, 22, 23, 24, 25, 26, 27, 28, 29, 30]);
    });

    test('HostelStaffRosterItem parses correctly with assigned areas and badges', () {
      final json = {
        'assignment_id': '6b8a2119-9f44-48ee-a63e-4b2a8d111001',
        'profile_id': 'e1111111-0001-4000-8000-000000000001',
        'row_num': 1,
        'name': 'Mr. Suresh Kumar',
        'employee_id': 'HS001',
        'role': 'Warden',
        'hostel_id': '11111111-1111-1111-1111-111111111101',
        'hostel_name': 'Boys Hostel A',
        'assigned_area': 'Overall Hostel Supervision',
        'contact': '+91 98765 43210',
        'email': 'suresh.kumar@school.edu',
        'status': 'Active',
        'shift_timings': '6:00 AM - 10:00 PM',
        'joining_date': '12 Apr 2023',
      };

      final item = HostelStaffRosterItem.fromJson(json);

      expect(item.assignmentId, '6b8a2119-9f44-48ee-a63e-4b2a8d111001');
      expect(item.employeeId, 'HS001');
      expect(item.name, 'Mr. Suresh Kumar');
      expect(item.role, 'Warden');
      expect(item.hostelName, 'Boys Hostel A');
      expect(item.assignedArea, 'Overall Hostel Supervision');
      expect(item.contact, '+91 98765 43210');
      expect(item.status, 'Active');
      expect(item.shiftTimings, '6:00 AM - 10:00 PM');
      expect(item.joiningDate, '12 Apr 2023');
    });

    test('HostelStaffDetail360 parses full 360 inspector details', () {
      final json = {
        'assignment_id': '6b8a2119-9f44-48ee-a63e-4b2a8d111001',
        'profile_id': 'e1111111-0001-4000-8000-000000000001',
        'full_name': 'Mr. Suresh Kumar',
        'employee_id': 'HS001',
        'role': 'Warden',
        'hostel_id': '11111111-1111-1111-1111-111111111101',
        'hostel_name': 'Boys Hostel A',
        'contact': '+91 98765 43210',
        'email': 'suresh.kumar@school.edu',
        'address': 'A-123, Sector 62, Noida, UP',
        'emergency_contact': '+91 98765 11111 (Spouse)',
        'shift_timings': '6:00 AM - 10:00 PM',
        'reporting_to': 'Hostel Administrator',
        'status': 'Active',
        'joining_date': '12 Apr 2023',
        'assigned_areas': [
          {'id': 'a1', 'area_name': 'Overall Hostel Supervision', 'badge_label': 'Primary', 'is_primary': true},
          {'id': 'a2', 'area_name': 'Discipline & Safety', 'badge_label': 'Assigned'},
          {'id': 'a3', 'area_name': 'Student Welfare', 'badge_label': 'Assigned'},
          {'id': 'a4', 'area_name': 'Mess Coordination', 'badge_label': 'Assigned'},
        ],
        'activities': [
          {
            'id': 'act1',
            'activity_type': 'Assigned',
            'title': 'Appointed as Chief Warden',
            'description': 'Assigned to Boys Hostel A',
            'performed_by_name': 'Admin',
            'created_at': '12 Apr 2023',
          }
        ],
      };

      final detail = HostelStaffDetail360.fromJson(json);

      expect(detail.fullName, 'Mr. Suresh Kumar');
      expect(detail.role, 'Warden');
      expect(detail.address, 'A-123, Sector 62, Noida, UP');
      expect(detail.emergencyContact, '+91 98765 11111 (Spouse)');
      expect(detail.reportingTo, 'Hostel Administrator');
      expect(detail.assignedAreas.length, 4);
      expect(detail.assignedAreas.first.areaName, 'Overall Hostel Supervision');
      expect(detail.assignedAreas.first.badgeLabel, 'Primary');
      expect(detail.assignedAreas.first.isPrimary, isTrue);
      expect(detail.activities.length, 1);
      expect(detail.activities.first.title, 'Appointed as Chief Warden');
    });

    test('EligibleStaffProfileItem parses search results', () {
      final json = {
        'id': 'p-1',
        'full_name': 'Rajesh Sharma',
        'role': 'Staff',
        'employee_id': 'EMP099',
        'phone': '+91 99999 88888',
        'email': 'rajesh@school.edu',
        'status': 'Active',
      };

      final profile = EligibleStaffProfileItem.fromJson(json);

      expect(profile.id, 'p-1');
      expect(profile.fullName, 'Rajesh Sharma');
      expect(profile.phone, '+91 99999 88888');
      expect(profile.employeeId, 'EMP099');
      expect(profile.status, 'Active');
    });
  });

  group('HostelState Staff Management Tests', () {
    test('HostelState initial tab and staff properties', () {
      final state = HostelState.initial();
      expect(state.activeTab, isNonNegative);
      expect(state.copyWith(activeTab: 3).activeTab, 3);
      expect(state.staffRoster, isEmpty);
      expect(state.selectedStaffAssignmentIds, isEmpty);
      expect(state.selectedStaffAssignmentId, isNull);
    });

    test('HostelState copyWith updates staff filters and selection properly', () {
      var state = HostelState.initial();

      state = state.copyWith(
        staffHostelFilter: 'hostel-123',
        staffRoleFilter: 'Warden',
        staffStatusFilter: 'Active',
        staffSearch: 'Suresh',
        selectedStaffAssignmentId: 'assign-1',
        selectedStaffAssignmentIds: {'assign-1', 'assign-2'},
      );

      expect(state.staffHostelFilter, 'hostel-123');
      expect(state.staffRoleFilter, 'Warden');
      expect(state.staffStatusFilter, 'Active');
      expect(state.staffSearch, 'Suresh');
      expect(state.selectedStaffAssignmentId, 'assign-1');
      expect(state.selectedStaffAssignmentIds.contains('assign-1'), isTrue);
      expect(state.selectedStaffAssignmentIds.contains('assign-2'), isTrue);
    });
  });
}
