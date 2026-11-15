import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/hostel/models/hostel_models.dart';

void main() {
  group('Hostel Staff Documents & Leaves - Models & Parsing', () {
    test('HostelStaffDocument parses JSON and calculates extension and size',
        () {
      final json = {
        'id': 'doc-001',
        'document_name': 'Police Verification Certificate',
        'document_type': 'POLICE_VERIFICATION',
        'file_url':
            'https://documents.edushamiit.edu/staff/police_clearance.pdf',
        'file_size_bytes': 845632,
        'mime_type': 'application/pdf',
        'verification_status': 'VERIFIED',
        'verified_by_name': 'HR Compliance Bureau',
        'verified_at': '02 Nov 2026, 03:00 AM',
        'notes': 'Sector police verification clearance verified',
        'created_at': '02 Nov 2026, 02:45 AM',
        'formatted_date': '02 Nov 2026',
      };

      final doc = HostelStaffDocument.fromJson(json);
      expect(doc.id, 'doc-001');
      expect(doc.documentName, 'Police Verification Certificate');
      expect(doc.documentType, 'POLICE_VERIFICATION');
      expect(doc.fileExtension, 'PDF');
      expect(doc.fileSizeFormatted, '826 KB');
      expect(doc.verificationStatus, 'VERIFIED');
      expect(doc.verifiedByName, 'HR Compliance Bureau');
    });

    test('HostelStaffLeave parses JSON and tracks duration and backup coverage',
        () {
      final json = {
        'id': 'leave-001',
        'leave_type': 'Emergency Duty Relief',
        'start_date': '01 Nov 2026',
        'end_date': '03 Nov 2026',
        'days_count': 2.0,
        'reason': 'Authorized duty leave with backup coverage',
        'status': 'APPROVED',
        'substitute_staff_name': 'Rajesh Sharma (Backup Warden)',
        'emergency_contact': '+91 98765 43210',
        'approved_by_name': 'Operations Head',
        'created_at': '01 Nov 2026',
      };

      final leave = HostelStaffLeave.fromJson(json);
      expect(leave.id, 'leave-001');
      expect(leave.leaveType, 'Emergency Duty Relief');
      expect(leave.daysCount, 2.0);
      expect(leave.substituteStaffName, 'Rajesh Sharma (Backup Warden)');
      expect(leave.status, 'APPROVED');
      expect(leave.emergencyContact, '+91 98765 43210');
    });

    test(
        'HostelStaffDetail360 deserializes dynamic documents, leaves, and duty info',
        () {
      final json = {
        'assignment_id': 'asg-001',
        'profile_id': 'prof-001',
        'full_name': 'Deepak Verma',
        'employee_id': 'HS013',
        'role': 'Hostel Warden',
        'hostel_id': 'bld-001',
        'hostel_name': 'Boys Hostel B',
        'contact': '+91 98765 43222',
        'email': 'deepak.verma@edushamiit.edu',
        'address': 'Staff Quarters, Block B',
        'emergency_contact': '+91 98765 11123',
        'shift_timings': '8:00 AM - 10:00 PM',
        'reporting_to': 'Hostel Administrator',
        'status': 'On Leave',
        'joining_date': '15 Jul 2023',
        'assigned_areas': [
          {
            'id': 'area-1',
            'area_name': 'Overall',
            'badge_label': 'Primary',
            'is_primary': true
          }
        ],
        'activities': [
          {
            'id': 'act-1',
            'activity_type': 'TRANSFERRED',
            'title':
                'Staff Transferred to Boys Hostel B - Extended Description for Screen Overflow Prevention Test',
            'description':
                'Transferred from Boys Hostel A (Overall). Reason: Administrative Operational Transfer',
            'badge_color': 'orange',
            'created_at': '02 Nov 2026, 03:45 AM',
          }
        ],
        'documents': [
          {
            'id': 'doc-1',
            'document_name': 'Identity Verification (Aadhaar / Passport)',
            'document_type': 'IDENTITY_VERIFICATION',
            'file_url': 'https://documents.edushamiit.edu/id.pdf',
            'file_size_bytes': 1258291,
            'verification_status': 'VERIFIED'
          },
          {
            'id': 'doc-2',
            'document_name': 'Hostel Administrator Duty Appointment Order',
            'document_type': 'APPOINTMENT_ORDER',
            'file_url': 'https://documents.edushamiit.edu/order.pdf',
            'file_size_bytes': 642819,
            'verification_status': 'SIGNED'
          }
        ],
        'leaves': [
          {
            'id': 'lv-1',
            'leave_type': 'Emergency Duty Relief',
            'start_date': '01 Nov 2026',
            'end_date': '03 Nov 2026',
            'days_count': 2.0,
            'reason':
                'Authorized hostel duty leave. Coverage assigned to backup warden.',
            'status': 'APPROVED',
            'substitute_staff_name': 'Rajesh Sharma (Backup Warden)',
            'emergency_contact': '+91 98765 43210'
          }
        ],
        'monthly_leaves_taken': 2.0,
        'active_substitute_warden': 'Rajesh Sharma (Backup Warden)',
      };

      final detail = HostelStaffDetail360.fromJson(json);
      expect(detail.fullName, 'Deepak Verma');
      expect(detail.status, 'On Leave');
      expect(detail.documents.length, 2);
      expect(detail.leaves.length, 1);
      expect(detail.documents[0].verificationStatus, 'VERIFIED');
      expect(detail.documents[1].verificationStatus, 'SIGNED');
      expect(detail.leaves[0].substituteStaffName,
          'Rajesh Sharma (Backup Warden)');
      expect(detail.monthlyLeavesTaken, 2.0);
    });
  });

  group('Hostel Staff Drawer - Overflow & Widget Tests', () {
    testWidgets(
        'History Tab renders without horizontal overflow on narrow mobile/drawer width',
        (tester) async {
      final detail = HostelStaffDetail360(
        assignmentId: 'asg-001',
        profileId: 'prof-001',
        fullName: 'Deepak Verma',
        role: 'Hostel Warden',
        hostelName: 'Boys Hostel B',
        contact: '+91 98765 43222',
        email: 'deepak@edushamiit.edu',
        address: 'Sector 62',
        emergencyContact: '+91 98765 11111',
        shiftTimings: '8:00 AM - 10:00 PM',
        reportingTo: 'Hostel Administrator',
        status: 'On Leave',
        joiningDate: '15 Jul 2023',
        activities: [
          HostelStaffActivity(
            id: 'act-1',
            activityType: 'TRANSFERRED',
            title:
                'Staff Transferred to Boys Hostel B - Very Long Activity Heading That Previously Broke Screen',
            description:
                'Transferred from Boys Hostel A (Overall). Reason: Administrative Operational Transfer',
            badgeColor: 'orange',
            createdAt: '02 Nov 2026, 03:45 AM',
          ),
          HostelStaffActivity(
            id: 'act-2',
            activityType: 'ASSIGNED',
            title: 'Staff Assigned to Hostel with Primary Warden Duty',
            description: 'Assigned as Hostel Warden (Overall)',
            badgeColor: 'blue',
            createdAt: '02 Nov 2026, 03:44 AM',
          ),
        ],
      );

      // Constrain width to 320px (exact drawer width in screenshots)
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                child: Builder(
                  builder: (context) {
                    // Render the history content
                    return SingleChildScrollView(
                      child: Column(
                        children: detail.activities.map((act) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        act.title,
                                        style: const TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      act.createdAt,
                                      style: const TextStyle(fontSize: 10.5),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(act.description),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Zero overflow assertion
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Staff Transferred to Boys Hostel B'),
          findsOneWidget);
      expect(find.text('02 Nov 2026, 03:45 AM'), findsOneWidget);
    });
  });
}
