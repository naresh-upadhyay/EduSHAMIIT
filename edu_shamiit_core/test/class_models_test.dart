import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/classes/models/class_models.dart';

void main() {
  group('Class Management Models Unit Tests', () {
    test('AcademicClassModel JSON parsing and properties', () {
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

    test('AcademicSectionModel JSON parsing and properties', () {
      final json = {
        'id': 'sec-101',
        'class_id': 'c-101',
        'class_name': 'Class 10',
        'class_code': 'C10',
        'name': 'Section A',
        'code': '10A',
        'capacity': 40,
        'room_number': 'Room 101',
        'academic_year': '2026-27',
        'status': 'ACTIVE',
        'students_count': 35,
        'subjects_count': 4,
        'assigned_subject_ids': ['sub-1', 'sub-2'],
      };

      final model = AcademicSectionModel.fromJson(json);
      expect(model.id, 'sec-101');
      expect(model.classId, 'c-101');
      expect(model.name, 'Section A');
      expect(model.roomNumber, 'Room 101');
      expect(model.capacity, 40);
      expect(model.studentsCount, 35);
      expect(model.subjectsCount, 4);
      expect(model.assignedSubjectIds, ['sub-1', 'sub-2']);
      expect(model.isActive, isTrue);
    });

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

    test('AcademicStatsModel JSON parsing', () {
      final json = {
        'total_classes': 12,
        'active_classes': 10,
        'total_sections': 24,
        'total_subjects': 18,
        'total_students': 450,
        'total_teachers': 32,
        'academic_year': '2026-27',
      };

      final stats = AcademicStatsModel.fromJson(json);
      expect(stats.totalClasses, 12);
      expect(stats.activeClasses, 10);
      expect(stats.totalSections, 24);
      expect(stats.totalSubjects, 18);
      expect(stats.totalStudents, 450);
      expect(stats.totalTeachers, 32);
      expect(stats.academicYear, '2026-27');
    });
  });
}
