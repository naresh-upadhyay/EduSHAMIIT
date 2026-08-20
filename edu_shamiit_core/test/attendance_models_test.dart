import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

void main() {
  group('Attendance Models & Enums Tests', () {
    test('AttendanceStatus enum codes and parsing', () {
      expect(AttendanceStatusExtension.fromString('PRESENT'), AttendanceStatus.present);
      expect(AttendanceStatusExtension.fromString('P'), AttendanceStatus.present);
      expect(AttendanceStatusExtension.fromString('ABSENT'), AttendanceStatus.absent);
      expect(AttendanceStatusExtension.fromString('A'), AttendanceStatus.absent);
      expect(AttendanceStatusExtension.fromString('LATE'), AttendanceStatus.late);
      expect(AttendanceStatusExtension.fromString('L'), AttendanceStatus.late);
      expect(AttendanceStatusExtension.fromString('ON_LEAVE'), AttendanceStatus.onLeave);
      expect(AttendanceStatusExtension.fromString('O'), AttendanceStatus.onLeave);
      expect(AttendanceStatusExtension.fromString('HALF_DAY'), AttendanceStatus.halfDay);
      expect(AttendanceStatusExtension.fromString('H'), AttendanceStatus.halfDay);
      expect(AttendanceStatusExtension.fromString('WORK_FROM_HOME'), AttendanceStatus.workFromHome);
      expect(AttendanceStatusExtension.fromString('WFH'), AttendanceStatus.workFromHome);
      expect(AttendanceStatusExtension.fromString('HOLIDAY'), AttendanceStatus.holiday);
      expect(AttendanceStatusExtension.fromString('UNKNOWN'), AttendanceStatus.notMarked);
      expect(AttendanceStatusExtension.fromString(null), AttendanceStatus.notMarked);

      expect(AttendanceStatus.present.code, 'P');
      expect(AttendanceStatus.absent.code, 'A');
      expect(AttendanceStatus.late.code, 'L');
      expect(AttendanceStatus.onLeave.code, 'O');
      expect(AttendanceStatus.halfDay.code, 'H');
      expect(AttendanceStatus.workFromHome.code, 'W');
      expect(AttendanceStatus.notMarked.code, '-');
    });

    test('AttendanceMode enum API keys and labels', () {
      expect(AttendanceMode.allDay.apiKey, 'ALL_DAY');
      expect(AttendanceMode.byPeriod.apiKey, 'PERIOD');
      expect(AttendanceMode.customSelection.apiKey, 'MULTI_SCHEDULE');

      expect(AttendanceMode.allDay.label, 'By Schedule (All Day)');
      expect(AttendanceMode.byPeriod.label, 'By Period');
      expect(AttendanceMode.customSelection.label, 'Custom Selection');
    });

    test('AttendanceStatsModel fromJson parses correctly', () {
      final json = {
        'overall_attendance_pct': 85.5,
        'total_students': 40,
        'students_present': 32,
        'students_absent': 5,
        'late_entries': 2,
        'on_leave': 1,
        'half_day': 0,
        'not_marked': 0,
        'day_summary': {'marked_students': 40},
      };

      final stats = AttendanceStatsModel.fromJson(json);
      expect(stats.overallAttendancePct, 85.5);
      expect(stats.totalStudents, 40);
      expect(stats.studentsPresent, 32);
      expect(stats.studentsAbsent, 5);
      expect(stats.lateEntries, 2);
      expect(stats.onLeave, 1);
    });

    test('AttendanceStudentRowModel fromJson and copyWith', () {
      final json = {
        'id': 'rec-123',
        'student_id': 'stud-456',
        'full_name': 'Aarav Sharma',
        'avatar_url': 'https://example.com/avatar.png',
        'roll_number': '1',
        'admission_number': 'ADM2026001',
        'class_name': 'Class 10',
        'section_name': 'Section A',
        'status': 'PRESENT',
        'remarks': 'Active participant',
        'is_locked': true,
        'locked_by_all_day': true,
        'is_overridden': false,
        'has_approved_leave': false,
      };

      final student = AttendanceStudentRowModel.fromJson(json);
      expect(student.id, 'rec-123');
      expect(student.studentId, 'stud-456');
      expect(student.fullName, 'Aarav Sharma');
      expect(student.status, AttendanceStatus.present);
      expect(student.isLocked, true);
      expect(student.lockedByAllDay, true);

      final updated = student.copyWith(
        status: AttendanceStatus.absent,
        remarks: 'Sick leave',
        isOverridden: true,
        overrideReason: 'Doctor note provided',
      );

      expect(updated.status, AttendanceStatus.absent);
      expect(updated.remarks, 'Sick leave');
      expect(updated.isOverridden, true);
      expect(updated.overrideReason, 'Doctor note provided');
      expect(updated.fullName, 'Aarav Sharma'); // Unchanged
    });

    test('AttendanceSettingsModel serialization', () {
      final settings = AttendanceSettingsModel(
        allowLate: true,
        lateCutoffMinutes: 20,
        requireAbsentRemark: true,
        requireLateRemark: true,
        autoMarkApprovedLeave: true,
        lockAfterHours: 48,
        allowTeacherOverrideLocked: true,
        enableNotifications: true,
      );

      final json = settings.toJson();
      expect(json['allow_late'], true);
      expect(json['late_cutoff_minutes'], 20);
      expect(json['require_absent_remark'], true);
      expect(json['lock_after_hours'], 48);

      final parsed = AttendanceSettingsModel.fromJson(json);
      expect(parsed.allowLate, true);
      expect(parsed.lateCutoffMinutes, 20);
      expect(parsed.lockAfterHours, 48);
    });
  });
}
