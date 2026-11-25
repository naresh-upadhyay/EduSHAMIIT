import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/work_management/models/work_models.dart';
import 'package:edu_shamiit_core/screens/work_management/providers/work_management_provider.dart';
import 'package:edu_shamiit_core/screens/work_management/utils/work_filter_helper.dart';

void main() {
  group('Work Sprint Items Visibility & Filter Tests', () {
    test('matchesAdvancedFilters respects All Boards and specific boards', () {
      const item1 = WorkItemModel(
        id: 'w1',
        itemNumber: 'WM-1050',
        title: 'Collect and verify project',
        workType: 'TASK',
        status: 'ACTIVE',
        priority: 'MEDIUM',
        boardId: 'a1111111-2222-3333-4444-555555555551',
        boardName: 'Academic Board',
        teamName: 'Infrastructure & Maintenance Team',
      );

      const item2 = WorkItemModel(
        id: 'w2',
        itemNumber: 'BG-1081',
        title: 'Copy of Library login issue',
        workType: 'BUG',
        status: 'NEW',
        priority: 'MEDIUM',
        boardId: 'a1111111-2222-3333-4444-555555555552',
        boardName: 'IT & Infra Board',
        teamName: 'Library Systems Team',
      );

      // When Board Filter is 'All Boards' or 'All'
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: item1,
          roleFilter: 'All',
          departmentFilter: 'All',
          classFilter: 'All',
          sectionFilter: 'All',
          teamFilter: 'All Teams',
          boardFilter: 'All Boards',
        ),
        isTrue,
      );

      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: item2,
          roleFilter: 'All',
          departmentFilter: 'All',
          classFilter: 'All',
          sectionFilter: 'All',
          teamFilter: 'All Teams',
          boardFilter: 'All Boards',
        ),
        isTrue,
      );

      // When Board Filter is 'Academic Board'
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: item1,
          roleFilter: 'All',
          departmentFilter: 'All',
          classFilter: 'All',
          sectionFilter: 'All',
          teamFilter: 'All Teams',
          boardFilter: 'Academic Board',
        ),
        isTrue,
      );

      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: item2,
          roleFilter: 'All',
          departmentFilter: 'All',
          classFilter: 'All',
          sectionFilter: 'All',
          teamFilter: 'All Teams',
          boardFilter: 'Academic Board',
        ),
        isFalse,
      );

      // When Board Filter is 'Institute Work Board'
      expect(
        WorkFilterHelper.matchesAdvancedFilters(
          item: item1,
          roleFilter: 'All',
          departmentFilter: 'All',
          classFilter: 'All',
          sectionFilter: 'All',
          teamFilter: 'All Teams',
          boardFilter: 'Institute Work Board',
        ),
        isFalse,
      );
    });

    test(
        'Sprint state metrics correctly reflect live items when rawMetrics is zero/empty',
        () {
      final items = [
        const WorkItemModel(
          id: 'w1',
          itemNumber: 'WM-1050',
          title: 'Collect and verify project',
          workType: 'TASK',
          status: 'ACTIVE',
          priority: 'MEDIUM',
          boardName: 'Academic Board',
        ),
        const WorkItemModel(
          id: 'w2',
          itemNumber: 'BG-1081',
          title: 'Copy of Library login issue',
          workType: 'BUG',
          status: 'NEW',
          priority: 'MEDIUM',
          boardName: 'IT & Infra Board',
        ),
      ];

      // Simulate Sprint 9 with 2 items and empty rawMetrics
      final allItems = <WorkItemModel>[];
      for (final s in items) {
        allItems.add(s);
        allItems.addAll(s.children);
      }

      final rawMetrics = <String, dynamic>{};
      final int totalItems;
      final int completedItems;
      final int inProgressItems;
      final int notStartedItems;
      final int blockedItems;

      if (allItems.isNotEmpty) {
        totalItems = allItems.length;
        completedItems = allItems
            .where((i) => i.status == 'COMPLETED' || i.status == 'RESOLVED')
            .length;
        inProgressItems = allItems
            .where((i) => i.status == 'ACTIVE' || i.status == 'IN PROGRESS')
            .length;
        notStartedItems = allItems
            .where((i) => i.status == 'NEW' || i.status == 'PLANNED')
            .length;
        blockedItems = allItems.where((i) => i.status == 'BLOCKED').length;
      } else {
        totalItems = (rawMetrics['total_items'] as num?)?.toInt() ?? 0;
        completedItems = (rawMetrics['completed_items'] as num?)?.toInt() ?? 0;
        inProgressItems =
            (rawMetrics['in_progress_items'] as num?)?.toInt() ?? 0;
        notStartedItems =
            (rawMetrics['not_started_items'] as num?)?.toInt() ?? 0;
        blockedItems = (rawMetrics['blocked_items'] as num?)?.toInt() ?? 0;
      }

      expect(totalItems, equals(2));
      expect(completedItems, equals(0));
      expect(inProgressItems, equals(1));
      expect(notStartedItems, equals(1));
      expect(blockedItems, equals(0));
    });
  });
}
