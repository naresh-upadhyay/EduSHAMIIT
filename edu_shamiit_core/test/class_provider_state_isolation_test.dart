import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/classes/providers/class_provider.dart';

void main() {
  group('ClassProvider Multi-Tab Filter & Pagination State Isolation Tests', () {
    test('Initial ClassState has clean, isolated filters for all 4 tabs', () {
      final state = ClassState();

      // Classes tab
      expect(state.classSearchQuery, '');
      expect(state.classStageFilter, 'ALL');
      expect(state.classStatusFilter, 'ALL');
      expect(state.classPage, 1);

      // Sections tab
      expect(state.sectionSearchQuery, '');
      expect(state.sectionClassIdFilter, isNull);
      expect(state.sectionBuildingFilter, 'ALL');
      expect(state.sectionFloorFilter, 'ALL');
      expect(state.sectionStatusFilter, 'ALL');
      expect(state.sectionPage, 1);

      // Subjects tab
      expect(state.subjectSearchQuery, '');
      expect(state.subjectTypeFilter, 'ALL');
      expect(state.subjectClassIdFilter, isNull);
      expect(state.subjectStatusFilter, 'ALL');
      expect(state.subjectPage, 1);

      // Rooms tab
      expect(state.roomSearchQuery, '');
      expect(state.roomTypeFilter, 'ALL');
      expect(state.roomBuildingFilter, 'ALL');
      expect(state.roomFloorFilter, 'ALL');
      expect(state.roomStatusFilter, 'ALL');
      expect(state.roomPage, 1);
    });

    test('Updating Classes tab filters does NOT alter Sections, Subjects, or Rooms filters', () {
      var state = ClassState();

      // Update Classes Tab filter
      state = state.copyWith(
        classSearchQuery: 'Class 10',
        classStageFilter: 'Secondary',
        classStatusFilter: 'ACTIVE',
        classPage: 2,
      );

      // Classes updated
      expect(state.classSearchQuery, 'Class 10');
      expect(state.classStageFilter, 'Secondary');
      expect(state.classStatusFilter, 'ACTIVE');
      expect(state.classPage, 2);

      // Sections remains unchanged
      expect(state.sectionSearchQuery, '');
      expect(state.sectionClassIdFilter, isNull);
      expect(state.sectionBuildingFilter, 'ALL');
      expect(state.sectionPage, 1);

      // Subjects remains unchanged
      expect(state.subjectSearchQuery, '');
      expect(state.subjectTypeFilter, 'ALL');
      expect(state.subjectPage, 1);

      // Rooms remains unchanged
      expect(state.roomSearchQuery, '');
      expect(state.roomTypeFilter, 'ALL');
      expect(state.roomBuildingFilter, 'ALL');
      expect(state.roomPage, 1);
    });

    test('Updating Rooms tab filters does NOT impact Classes or Sections filters', () {
      var state = ClassState();

      // Update Rooms Tab filter
      state = state.copyWith(
        roomSearchQuery: 'Bio Lab',
        roomTypeFilter: 'Laboratory',
        roomBuildingFilter: 'Science Block',
        roomFloorFilter: '2nd Floor',
        roomStatusFilter: 'AVAILABLE',
        roomPage: 3,
      );

      // Rooms updated
      expect(state.roomSearchQuery, 'Bio Lab');
      expect(state.roomTypeFilter, 'Laboratory');
      expect(state.roomBuildingFilter, 'Science Block');
      expect(state.roomFloorFilter, '2nd Floor');
      expect(state.roomStatusFilter, 'AVAILABLE');
      expect(state.roomPage, 3);

      // Classes unchanged
      expect(state.classSearchQuery, '');
      expect(state.classStageFilter, 'ALL');
      expect(state.classPage, 1);

      // Sections unchanged
      expect(state.sectionSearchQuery, '');
      expect(state.sectionClassIdFilter, isNull);
      expect(state.sectionPage, 1);
    });

    test('Updating Subjects tab filters does NOT impact other tabs', () {
      var state = ClassState();

      state = state.copyWith(
        subjectSearchQuery: 'Mathematics',
        subjectTypeFilter: 'Core',
        subjectClassIdFilter: 'c-10',
        subjectStatusFilter: 'ACTIVE',
        subjectPage: 2,
      );

      expect(state.subjectSearchQuery, 'Mathematics');
      expect(state.subjectTypeFilter, 'Core');
      expect(state.subjectClassIdFilter, 'c-10');
      expect(state.subjectPage, 2);

      expect(state.classSearchQuery, '');
      expect(state.sectionSearchQuery, '');
      expect(state.roomSearchQuery, '');
    });

    test('Pagination state is completely independent per tab', () {
      var state = ClassState();

      state = state.copyWith(classPage: 3);
      expect(state.classPage, 3);
      expect(state.sectionPage, 1);
      expect(state.subjectPage, 1);
      expect(state.roomPage, 1);

      state = state.copyWith(sectionPage: 4);
      expect(state.classPage, 3);
      expect(state.sectionPage, 4);
      expect(state.subjectPage, 1);
      expect(state.roomPage, 1);

      state = state.copyWith(roomPage: 2);
      expect(state.classPage, 3);
      expect(state.sectionPage, 4);
      expect(state.subjectPage, 1);
      expect(state.roomPage, 2);
    });
  });
}
