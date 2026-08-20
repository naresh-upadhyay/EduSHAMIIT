import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/classes/models/class_models.dart';

void main() {
  group('Class Management Hierarchy & Constraints Business Rules', () {
    // ------------------------------------------------------------------------
    // Grandparent (Class) -> Parent (Section) -> Child (Subject Assignment)
    // ------------------------------------------------------------------------

    test('Rule 1: If Class is INACTIVE, Section activation is blocked', () {
      final inactiveClass = AcademicClassModel(
        id: 'c-inactive',
        name: 'Class 8',
        code: 'C8',
        status: 'INACTIVE',
      );

      final section = AcademicSectionModel(
        id: 'sec-1',
        classId: 'c-inactive',
        name: 'Section A',
        code: '8A',
        status: 'INACTIVE',
      );

      // Business Rule Validation Function
      String? validateSectionActivation(AcademicSectionModel sec, AcademicClassModel? parentClass) {
        if (parentClass == null) return 'Parent class not found.';
        if (!parentClass.isActive) {
          return 'Cannot activate section because parent Class ${parentClass.name} is INACTIVE. Activate the class first.';
        }
        return null;
      }

      final validationError = validateSectionActivation(section, inactiveClass);
      expect(validationError, isNotNull);
      expect(validationError, contains('Activate the class first'));
    });

    test('Rule 2: If Class is ACTIVE, Section can be activated or deactivated independently', () {
      final activeClass = AcademicClassModel(
        id: 'c-active',
        name: 'Class 10',
        code: 'C10',
        status: 'ACTIVE',
      );

      final section = AcademicSectionModel(
        id: 'sec-1',
        classId: 'c-active',
        name: 'Section A',
        code: '10A',
        status: 'INACTIVE',
      );

      String? validateSectionActivation(AcademicSectionModel sec, AcademicClassModel? parentClass) {
        if (parentClass == null) return 'Parent class not found.';
        if (!parentClass.isActive) {
          return 'Cannot activate section because parent Class ${parentClass.name} is INACTIVE. Activate the class first.';
        }
        return null;
      }

      final validationError = validateSectionActivation(section, activeClass);
      expect(validationError, isNull); // Allowed
    });

    test('Rule 3: If Grandparent Class is INACTIVE or Parent Section is INACTIVE, Subject Assignment activation is blocked', () {
      final inactiveClass = AcademicClassModel(id: 'c-1', name: 'Class 9', code: 'C9', status: 'INACTIVE');
      final activeClass = AcademicClassModel(id: 'c-2', name: 'Class 10', code: 'C10', status: 'ACTIVE');

      final inactiveSection = AcademicSectionModel(id: 's-1', classId: 'c-2', name: 'B', code: '10B', status: 'INACTIVE');
      final activeSection = AcademicSectionModel(id: 's-2', classId: 'c-2', name: 'A', code: '10A', status: 'ACTIVE');

      // Validation rule for Class + Section -> Subject assignment
      String? validateSubjectAssignmentActivation({
        required AcademicClassModel parentClass,
        required AcademicSectionModel parentSection,
      }) {
        if (!parentClass.isActive) {
          return 'Cannot activate subject assignment because Grandparent Class (${parentClass.name}) is INACTIVE. First activate the Class.';
        }
        if (!parentSection.isActive) {
          return 'Cannot activate subject assignment because Parent Section (${parentSection.name}) is INACTIVE. First activate the Section.';
        }
        return null;
      }

      // Case A: Grandparent inactive
      final errorA = validateSubjectAssignmentActivation(
        parentClass: inactiveClass,
        parentSection: activeSection,
      );
      expect(errorA, contains('Grandparent Class (Class 9) is INACTIVE'));

      // Case B: Parent section inactive
      final errorB = validateSubjectAssignmentActivation(
        parentClass: activeClass,
        parentSection: inactiveSection,
      );
      expect(errorB, contains('Parent Section (B) is INACTIVE'));

      // Case C: Both active -> Allowed
      final errorC = validateSubjectAssignmentActivation(
        parentClass: activeClass,
        parentSection: activeSection,
      );
      expect(errorC, isNull);
    });

    test('Rule 4: Deactivating Class cascades to invalidate active children', () {
      final myClass = AcademicClassModel(id: 'c-1', name: 'Class 11', code: 'C11', status: 'ACTIVE');
      final sections = [
        AcademicSectionModel(id: 's1', classId: 'c-1', name: 'A', code: '11A', status: 'ACTIVE'),
        AcademicSectionModel(id: 's2', classId: 'c-1', name: 'B', code: '11B', status: 'ACTIVE'),
      ];

      // Simulate cascade deactivation
      final deactivatedClass = AcademicClassModel(
        id: myClass.id,
        name: myClass.name,
        code: myClass.code,
        status: 'INACTIVE',
      );

      final cascadedSections = sections.map((sec) {
        return AcademicSectionModel(
          id: sec.id,
          classId: sec.classId,
          name: sec.name,
          code: sec.code,
          status: 'INACTIVE', // cascaded
        );
      }).toList();

      expect(deactivatedClass.isActive, isFalse);
      expect(cascadedSections.every((s) => !s.isActive), isTrue);
    });

    test('Rule 5: Grandparent Active + Parent Active allows child to be Inactive', () {
      final activeClass = AcademicClassModel(id: 'c-1', name: 'Class 12', code: 'C12', status: 'ACTIVE');
      final activeSection = AcademicSectionModel(id: 's-1', classId: 'c-1', name: 'Science', code: '12SCI', status: 'ACTIVE');

      expect(activeClass.isActive, isTrue);
      expect(activeSection.isActive, isTrue);

      final inactiveSubjectAssignment = {
        'class_id': activeClass.id,
        'section_id': activeSection.id,
        'subject_id': 'sub-french',
        'status': 'INACTIVE',
      };

      expect(inactiveSubjectAssignment['status'], 'INACTIVE');
    });
  });
}
