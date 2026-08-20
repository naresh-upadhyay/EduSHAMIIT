import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/classes/models/class_models.dart';

void main() {
  group('Class Subject Assignment & Selection Unit Tests', () {
    test('AcademicSubjectModel assignedClassIds and section mappings', () {
      final subject = AcademicSubjectModel(
        id: 'sub-physics',
        name: 'Physics',
        code: 'PHY',
        type: 'Core',
        periodsPerWeek: 5,
        isClassWide: false,
        sectionNames: 'Section A, Section B',
        assignedClassIds: ['c-11', 'c-12'],
        status: 'ACTIVE',
      );

      expect(subject.id, 'sub-physics');
      expect(subject.name, 'Physics');
      expect(subject.isClassWide, isFalse);
      expect(subject.sectionNames, 'Section A, Section B');
      expect(subject.assignedClassIds, ['c-11', 'c-12']);
      expect(subject.isActive, isTrue);
    });

    test('Class + Section subject assignment model state toggle', () {
      final assignment = {
        'id': 'assign-1',
        'class_id': 'c-10',
        'class_name': 'Class 10',
        'section_id': 'sec-10a',
        'section_name': 'Section A',
        'subject_id': 'sub-math',
        'subject_name': 'Mathematics',
        'teacher_id': 't-1',
        'teacher_name': 'Mr. Sharma',
        'status': 'ACTIVE',
        'periods_per_week': 6,
      };

      expect(assignment['status'], 'ACTIVE');

      // Toggle status to INACTIVE
      final toggledAssignment = Map<String, dynamic>.from(assignment);
      toggledAssignment['status'] = 'INACTIVE';

      expect(toggledAssignment['status'], 'INACTIVE');
      expect(toggledAssignment['class_id'], 'c-10');
      expect(toggledAssignment['section_id'], 'sec-10a');
      expect(toggledAssignment['subject_id'], 'sub-math');
    });

    test('Class-wide vs section-specific subject assignment rules', () {
      final classWideSubject = AcademicSubjectModel(
        id: 'sub-eng',
        name: 'English Language',
        code: 'ENG',
        type: 'Core',
        isClassWide: true,
        sectionNames: 'All Sections',
        assignedClassIds: ['c-9', 'c-10'],
      );

      expect(classWideSubject.isClassWide, isTrue);
      expect(classWideSubject.sectionNames, 'All Sections');

      final electiveSubject = AcademicSubjectModel(
        id: 'sub-cs',
        name: 'Computer Science Elective',
        code: 'CS',
        type: 'Elective',
        isClassWide: false,
        sectionNames: 'Section A',
        assignedClassIds: ['c-11'],
      );

      expect(electiveSubject.isClassWide, isFalse);
      expect(electiveSubject.sectionNames, 'Section A');
    });
  });
}
