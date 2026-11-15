import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/hostel/models/hostel_models.dart';
import 'package:edu_shamiit_core/screens/hostel/models/hostel_leave_outing_models.dart';

void main() {
  group('Hostel Student Documents & Gate Passes Dynamic Flow', () {
    test('HostelStudentDocument parses JSON and calculates size & extension accurately', () {
      final doc = HostelStudentDocument.fromJson({
        'id': 'doc-123',
        'document_name': 'Hostel Admission Form (Signed).pdf',
        'document_type': 'ADMISSION_FORM',
        'file_url': 'https://documents.edushamiit.edu/form.pdf',
        'file_size_bytes': 1572864, // 1.5 MB
        'mime_type': 'application/pdf',
        'verification_status': 'VERIFIED',
      });

      expect(doc.id, equals('doc-123'));
      expect(doc.documentName, equals('Hostel Admission Form (Signed).pdf'));
      expect(doc.fileExtension, equals('PDF'));
      expect(doc.extensionBadge, equals('PDF'));
      expect(doc.formattedSize, equals('1.5 MB'));
      expect(doc.fileSizeFormatted, equals('1.5 MB'));
    });

    test('HostelStudentLeaveHistoryItem parses movements correctly', () {
      final item = HostelStudentLeaveHistoryItem.fromJson({
        'id': 'req-999',
        'leave_type': 'OUTING',
        'request_subtype': 'Market Outing',
        'reason': 'Purchasing study materials',
        'destination': 'Central City Market',
        'start_date': '02 Nov 2026, 04:00 PM',
        'end_date': '02 Nov 2026, 07:30 PM',
        'status': 'APPROVED',
        'pass_number': 'GP-2026-0042',
      });

      expect(item.id, equals('req-999'));
      expect(item.leaveType, equals('OUTING'));
      expect(item.passNumber, equals('GP-2026-0042'));
      expect(item.status, equals('APPROVED'));
    });

    test('HostelStudentDetail360 deserializes dynamic documents and leave history items', () {
      final detail = HostelStudentDetail360.fromJson({
        'admission_id': 'adm-101',
        'student_id': 'stu-101',
        'student_name': 'Aarav Sharma',
        'status': 'Active',
        'admission_status': 'ACTIVE',
        'roll_no': '0101',
        'class_name': 'Class 10 A',
        'hostel_name': 'Boys Hostel A',
        'room_number': 'A-101',
        'bed_no': '1',
        'admission_date': '30 Oct 2026',
        'room_and_bed': 'A-101 (Bed 1)',
        'hostel_type': 'Non-AC Room',
        'fee_plan': 'Monthly',
        'blood_group': 'B+',
        'emergency_contact': '+91 98765 43210',
        'emergency_contact_label': 'Father',
        'address': 'Noida, UP',
        'documents': [
          {
            'id': 'doc-1',
            'document_name': 'Hostel Admission Form (Signed)',
            'document_type': 'ADMISSION_FORM',
            'file_url': 'https://documents.edushamiit.edu/doc1.pdf',
            'file_size_bytes': 1200000,
            'mime_type': 'application/pdf',
          },
          {
            'id': 'doc-2',
            'document_name': 'Medical Fitness Certificate',
            'document_type': 'MEDICAL_CERTIFICATE',
            'file_url': 'https://documents.edushamiit.edu/doc2.pdf',
            'file_size_bytes': 850000,
            'mime_type': 'application/pdf',
          }
        ],
        'leaves': [
          {
            'id': 'leave-1',
            'leave_type': 'LEAVE',
            'request_subtype': 'Home Visit',
            'reason': 'Diwali festival celebrations',
            'destination': 'Jaipur',
            'start_date': '01 Nov 2026, 09:00 AM',
            'end_date': '05 Nov 2026, 06:00 PM',
            'status': 'APPROVED',
            'pass_number': 'GP-2026-0001',
          }
        ],
      });

      expect(detail.documents.length, equals(2));
      expect(detail.documents.first.documentName, equals('Hostel Admission Form (Signed)'));
      expect(detail.leaves.length, equals(1));
      expect(detail.leaves.first.passNumber, equals('GP-2026-0001'));
      expect(detail.leaves.first.destination, equals('Jaipur'));
    });

    test('LeaveOutingKpiData parses non-string rates gracefully and prevents NaN / type errors', () {
      final kpi = LeaveOutingKpiData.fromJson({
        'total_requests': 48,
        'approved_count': 32,
        'pending_count': 8,
        'rejected_count': 4,
        'currently_out': 15,
        'due_today': 5,
        'approval_rate': 67, // integer from database
        'rejected_rate': 8, // integer from database
      });

      expect(kpi.totalRequests, equals(48));
      expect(kpi.approved, equals(32));
      expect(kpi.approvalRate, equals('67% approval rate'));
      expect(kpi.rejectedRate, equals('8% of requests'));
    });

    test('HostelStudentDetail360.copyWith allows instant dynamic document deletion and upload updates', () {
      final detail = HostelStudentDetail360.fromJson({
        'admission_id': 'adm-101',
        'student_id': 'stu-101',
        'student_name': 'Aarav Sharma',
        'status': 'Active',
        'admission_status': 'ACTIVE',
        'roll_no': '0101',
        'class_name': 'Class 10 A',
        'hostel_name': 'Boys Hostel A',
        'room_number': 'A-101',
        'bed_no': '1',
        'admission_date': '30 Oct 2026',
        'room_and_bed': 'A-101 (Bed 1)',
        'hostel_type': 'Non-AC Room',
        'fee_plan': 'Monthly',
        'blood_group': 'B+',
        'emergency_contact': '+91 98765 43210',
        'emergency_contact_label': 'Father',
        'address': 'Noida, UP',
        'documents': [
          {
            'id': 'doc-1',
            'document_name': 'Hostel Admission Form (Signed)',
            'document_type': 'ADMISSION_FORM',
            'file_url': 'https://documents.edushamiit.edu/doc1.pdf',
            'file_size_bytes': 1200000,
          },
          {
            'id': 'doc-2',
            'document_name': 'Medical Fitness Certificate',
            'document_type': 'MEDICAL_CERTIFICATE',
            'file_url': 'https://documents.edushamiit.edu/doc2.pdf',
            'file_size_bytes': 850000,
          }
        ],
      });

      expect(detail.documents.length, equals(2));

      // Simulate deleting doc-2
      final updatedAfterDelete = detail.copyWith(
        documents: detail.documents.where((d) => d.id != 'doc-2').toList(),
      );
      expect(updatedAfterDelete.documents.length, equals(1));
      expect(updatedAfterDelete.documents.first.id, equals('doc-1'));

      // Simulate uploading a new document doc-3
      const newDoc = HostelStudentDocument(
        id: 'doc-3',
        documentName: 'Aadhaar Card',
        documentType: 'ID_PROOF',
        fileUrl: 'https://documents.edushamiit.edu/doc3.jpg',
      );
      final updatedAfterUpload = updatedAfterDelete.copyWith(
        documents: [newDoc, ...updatedAfterDelete.documents],
      );
      expect(updatedAfterUpload.documents.length, equals(2));
      expect(updatedAfterUpload.documents.first.id, equals('doc-3'));
      expect(updatedAfterUpload.documents[1].id, equals('doc-1'));
    });

    test('HostelStaffDocument parses extensions cleanly and suppresses OCTET-STREAM badge', () {
      final docxDoc = HostelStaffDocument.fromJson({
        'id': 'sdoc-1',
        'document_name': 'Police Verification Certificate.docx',
        'document_type': 'POLICE_VERIFICATION',
        'file_url': 'data:application/octet-stream;base64,UEsDBBQ...',
        'file_size_bytes': 49728,
        'mime_type': 'application/octet-stream',
        'verification_status': 'SIGNED',
      });
      expect(docxDoc.fileExtension, equals('DOCX'));

      final pngDoc = HostelStaffDocument.fromJson({
        'id': 'sdoc-2',
        'document_name': 'Staff ID Photo.png',
        'document_type': 'STAFF_ID',
        'file_url': 'data:application/octet-stream;base64,iVBORw...',
        'file_size_bytes': 1500000,
        'mime_type': 'application/octet-stream',
        'verification_status': 'VERIFIED',
      });
      expect(pngDoc.fileExtension, equals('PNG'));

      final fallbackDoc = HostelStaffDocument.fromJson({
        'id': 'sdoc-3',
        'document_name': 'Official Order',
        'document_type': 'APPOINTMENT_ORDER',
        'file_url': 'data:application/octet-stream;base64,AA==',
        'file_size_bytes': 2048,
        'mime_type': 'application/octet-stream',
        'verification_status': 'PENDING',
      });
      expect(fallbackDoc.fileExtension, equals('PDF'));
      expect(fallbackDoc.fileExtension, isNot(equals('OCTET-STREAM')));
    });

    test('HostelStaffDetail360.copyWith updates documents state seamlessly', () {
      final staff = HostelStaffDetail360.fromJson({
        'assignment_id': 'asg-1',
        'profile_id': 'prof-1',
        'full_name': 'Deepak Verma',
        'role': 'Hostel Warden',
        'hostel_name': 'Boys Hostel A',
        'contact': '+91 98765 43210',
        'email': 'deepak@school.edu',
        'address': 'Campus Staff Quarter',
        'emergency_contact': '+91 98765 00000',
        'shift_timings': '08:00 AM - 04:00 PM',
        'reporting_to': 'Chief Warden',
        'status': 'Active',
        'joining_date': '15 Jul 2023',
        'documents': [
          {
            'id': 'sdoc-1',
            'document_name': 'Police Verification Certificate',
            'document_type': 'POLICE_VERIFICATION',
            'file_url': 'https://storage/avatars/pv.pdf',
          },
        ],
      });

      final updated = staff.copyWith(
        documents: [
          const HostelStaffDocument(
            id: 'sdoc-2',
            documentName: 'New Document.pdf',
            documentType: 'OTHER',
            fileUrl: 'https://storage/avatars/new.pdf',
          ),
          ...staff.documents,
        ],
      );

      expect(updated.documents.length, equals(2));
      expect(updated.documents.first.id, equals('sdoc-2'));
      expect(updated.documents[1].id, equals('sdoc-1'));
    });
  });
}
