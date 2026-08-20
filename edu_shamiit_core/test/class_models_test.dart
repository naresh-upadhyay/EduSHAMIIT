import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/classes/models/class_models.dart';

void main() {
  group('Class Management Models Unit Tests', () {
    // ------------------------------------------------------------------------
    // 1. AcademicClassModel Tests & Edge Cases
    // ------------------------------------------------------------------------
    test('AcademicClassModel JSON parsing and standard properties', () {
      final json = {
        'id': 'c-101',
        'name': 'Class 10',
        'code': 'C10',
        'stage': 'Secondary',
        'academic_year': '2026-27',
        'display_order': 10,
        'status': 'ACTIVE',
        'sections_count': 3,
        'subjects_count': 5,
        'students_count': 45,
        'class_teachers_count': 2,
        'created_at': '2026-08-01T10:00:00Z',
        'updated_at': '2026-08-01T12:00:00Z',
      };

      final model = AcademicClassModel.fromJson(json);
      expect(model.id, 'c-101');
      expect(model.name, 'Class 10');
      expect(model.code, 'C10');
      expect(model.stage, 'Secondary');
      expect(model.displayOrder, 10);
      expect(model.isActive, isTrue);
      expect(model.sectionsCount, 3);
      expect(model.subjectsCount, 5);
      expect(model.studentsCount, 45);
      expect(model.classTeachersCount, 2);
      expect(model.badgeColor, isA<Color>());
    });

    test('AcademicClassModel edge cases: null/missing fields and fallback defaults', () {
      final json = {
        'id': 'c-empty',
        'name': '',
        'status': 'inactive',
      };

      final model = AcademicClassModel.fromJson(json);
      expect(model.id, 'c-empty');
      expect(model.name, '');
      expect(model.code, '');
      expect(model.stage, 'Secondary'); // default
      expect(model.displayOrder, 1); // default
      expect(model.isActive, isFalse);
      expect(model.sectionsCount, 0);
      expect(model.subjectsCount, 0);
      expect(model.studentsCount, 0);
      expect(model.classTeachersCount, 0);
      expect(model.badgeColor, isA<Color>());
    });

    test('AcademicClassModel badgeColor distribution for various class names', () {
      final class1 = AcademicClassModel(id: '1', name: 'Class 1', code: 'C1', stage: 'Primary');
      final class5 = AcademicClassModel(id: '5', name: 'Class 5', code: 'C5', stage: 'Primary');
      final class10 = AcademicClassModel(id: '10', name: 'Class 10', code: 'C10', stage: 'Secondary');
      final classSpecial = AcademicClassModel(id: 's', name: 'Nursery Blue', code: 'NUR', stage: 'Pre-Primary');

      expect(class1.badgeColor, isNotNull);
      expect(class5.badgeColor, isNotNull);
      expect(class10.badgeColor, isNotNull);
      expect(classSpecial.badgeColor, isNotNull);
    });

    // ------------------------------------------------------------------------
    // 2. AcademicSectionModel Tests & Edge Cases
    // ------------------------------------------------------------------------
    test('AcademicSectionModel JSON parsing and properties', () {
      final json = {
        'id': 'sec-101',
        'class_id': 'c-101',
        'class_name': 'Class 10',
        'class_code': 'C10',
        'class_stage': 'Secondary',
        'name': 'Section A',
        'code': '10A',
        'capacity': 40,
        'room_number': 'Room 101',
        'academic_year': '2026-27',
        'status': 'ACTIVE',
        'students_count': 35,
        'subjects_count': 4,
        'assigned_subject_ids': ['sub-1', 'sub-2'],
        'class_teacher': {
          'id': 't-1',
          'full_name': 'Dr. Sarah Jenkins',
          'email': 'sarah@school.edu',
        },
      };

      final model = AcademicSectionModel.fromJson(json);
      expect(model.id, 'sec-101');
      expect(model.classId, 'c-101');
      expect(model.className, 'Class 10');
      expect(model.name, 'Section A');
      expect(model.roomNumber, 'Room 101');
      expect(model.capacity, 40);
      expect(model.studentsCount, 35);
      expect(model.subjectsCount, 4);
      expect(model.assignedSubjectIds, ['sub-1', 'sub-2']);
      expect(model.classTeacher?.fullName, 'Dr. Sarah Jenkins');
      expect(model.isActive, isTrue);
    });

    test('AcademicSectionModel edge cases: zero capacity and null teacher', () {
      final json = {
        'id': 'sec-empty',
        'name': 'B',
        'capacity': 0,
        'status': 'INACTIVE',
      };

      final model = AcademicSectionModel.fromJson(json);
      expect(model.id, 'sec-empty');
      expect(model.capacity, 0);
      expect(model.studentsCount, 0);
      expect(model.classTeacher, isNull);
      expect(model.isActive, isFalse);
      expect(model.assignedSubjectIds, isEmpty);
    });

    // ------------------------------------------------------------------------
    // 3. AcademicSubjectModel Tests & Edge Cases
    // ------------------------------------------------------------------------
    test('AcademicSubjectModel JSON parsing and color helper', () {
      final json = {
        'id': 'sub-101',
        'name': 'Advanced Mathematics',
        'code': 'MATH10',
        'type': 'Core',
        'periods_per_week': 6,
        'color': '#4F46E5',
        'icon': 'calculate',
        'status': 'ACTIVE',
        'is_class_wide': true,
        'section_names': 'All Sections',
        'assigned_class_ids': ['c-101', 'c-102'],
      };

      final model = AcademicSubjectModel.fromJson(json);
      expect(model.id, 'sub-101');
      expect(model.name, 'Advanced Mathematics');
      expect(model.type, 'Core');
      expect(model.periodsPerWeek, 6);
      expect(model.subjectColor, const Color(0xFF4F46E5));
      expect(model.isClassWide, isTrue);
      expect(model.sectionNames, 'All Sections');
      expect(model.assignedClassIds, ['c-101', 'c-102']);
      expect(model.isActive, isTrue);
    });

    test('AcademicSubjectModel color parsing edge cases (short hex, invalid hex)', () {
      final subShortHex = AcademicSubjectModel(id: 's1', name: 'Art', code: 'ART', color: '#FFF');
      expect(subShortHex.subjectColor, isA<Color>());

      final subNoHash = AcademicSubjectModel(id: 's2', name: 'Music', code: 'MUS', color: '10B981');
      expect(subNoHash.subjectColor, const Color(0xFF10B981));

      final subInvalidHex = AcademicSubjectModel(id: 's3', name: 'Drama', code: 'DRM', color: 'invalid-color');
      expect(subInvalidHex.subjectColor, const Color(0xFF4F46E5)); // Fallback color
    });

    // ------------------------------------------------------------------------
    // 4. AcademicStudentModel & Conflict Helpers
    // ------------------------------------------------------------------------
    test('AcademicStudentModel assignment summary helper', () {
      final unassigned = AcademicStudentModel(
        id: 's-1',
        fullName: 'Aarav Kumar',
        isAssigned: false,
      );
      expect(unassigned.assignmentSummary, 'Unassigned');

      final assignedClassOnly = AcademicStudentModel(
        id: 's-2',
        fullName: 'Priya Patel',
        currentClassId: 'c-5',
        currentClassName: 'Class 5',
        isAssigned: true,
      );
      expect(assignedClassOnly.assignmentSummary, 'Class 5');

      final assignedSection = AcademicStudentModel(
        id: 's-3',
        fullName: 'Rohan Gupta',
        currentClassId: 'c-10',
        currentClassName: 'Class 10',
        currentSectionId: 'sec-10a',
        currentSectionName: '10-A',
        isAssigned: true,
      );
      expect(assignedSection.assignmentSummary, 'Class 10 • Section 10-A');
    });

    test('StudentConflictModel location string', () {
      final conflictWithSection = StudentConflictModel(
        studentId: 's-1',
        studentName: 'Aarav Kumar',
        admissionNumber: 'ADM-901',
        currentClassId: 'c-10',
        currentClassName: 'Class 10',
        currentSectionId: 'sec-10a',
        currentSectionName: '10-A',
      );
      expect(conflictWithSection.locationString, 'Class 10-10-A');

      final conflictClassOnly = StudentConflictModel(
        studentId: 's-2',
        studentName: 'Priya Patel',
        admissionNumber: 'ADM-902',
        currentClassId: 'c-5',
        currentClassName: 'Class 5',
      );
      expect(conflictClassOnly.locationString, 'Class 5');
    });

    // ------------------------------------------------------------------------
    // 5. AcademicStatsModel Tests
    // ------------------------------------------------------------------------
    test('AcademicStatsModel JSON parsing and edge cases', () {
      final json = {
        'total_classes': 12,
        'active_classes': 10,
        'total_sections': 24,
        'total_subjects': 18,
        'total_students': 450,
        'total_teachers': 32,
        'total_rooms': 15,
        'available_rooms': 12,
        'in_use_rooms': 2,
        'maintenance_rooms': 1,
        'total_room_capacity': 600,
        'academic_year': '2026-27',
      };

      final stats = AcademicStatsModel.fromJson(json);
      expect(stats.totalClasses, 12);
      expect(stats.activeClasses, 10);
      expect(stats.totalSections, 24);
      expect(stats.totalSubjects, 18);
      expect(stats.totalStudents, 450);
      expect(stats.totalTeachers, 32);
      expect(stats.totalRooms, 15);
      expect(stats.availableRooms, 12);
      expect(stats.inUseRooms, 2);
      expect(stats.maintenanceRooms, 1);
      expect(stats.totalRoomCapacity, 600);
      expect(stats.academicYear, '2026-27');
    });
  });
}
