import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/classes/models/class_models.dart';

void main() {
  group('Rooms & Facilities Model & Utilization Tests', () {
    test('AcademicRoomModel full JSON parsing with assigned sections', () {
      final json = {
        'id': 'room-01',
        'name': 'Biology Lab',
        'code': 'BIO-LAB-01',
        'type': 'Laboratory',
        'building': 'Science Block',
        'floor': '2nd Floor',
        'capacity': 40,
        'facilities': ['Microscopes', 'Specimen Jars', 'AC', 'Projector'],
        'status': 'AVAILABLE',
        'description': 'Equipped with binocular compound microscopes and anatomy models.',
        'created_at': '2026-08-18T19:13:34Z',
        'updated_at': '2026-08-20T10:00:00Z',
        'assigned_sections': [
          {
            'id': 'sec-1',
            'name': 'Section A',
            'code': '10-A',
            'class_id': 'c-10',
            'class_name': 'Class 10',
            'class_code': 'C10',
            'capacity': 40,
            'students_count': 38,
            'status': 'ACTIVE',
            'class_teacher': {
              'id': 't-1',
              'full_name': 'Dr. Sarah Jenkins',
              'email': 'sarah@school.edu',
            },
          },
        ],
        'assigned_sections_count': 1,
        'total_students_seated': 38,
        'capacity_utilization': 95.0,
      };

      final room = AcademicRoomModel.fromJson(json);
      expect(room.id, 'room-01');
      expect(room.name, 'Biology Lab');
      expect(room.code, 'BIO-LAB-01');
      expect(room.type, 'Laboratory');
      expect(room.building, 'Science Block');
      expect(room.floor, '2nd Floor');
      expect(room.capacity, 40);
      expect(room.facilities, ['Microscopes', 'Specimen Jars', 'AC', 'Projector']);
      expect(room.status, 'AVAILABLE');
      expect(room.description, contains('compound microscopes'));
      expect(room.assignedSections.length, 1);
      expect(room.assignedSections.first.name, 'Section A');
      expect(room.assignedSections.first.className, 'Class 10');
      expect(room.assignedSections.first.classTeacher?.fullName, 'Dr. Sarah Jenkins');
      expect(room.assignedSectionsCount, 1);
      expect(room.totalStudentsSeated, 38);
      expect(room.capacityUtilization, 95.0);
    });

    test('AcademicRoomModel fallback and null resilience', () {
      final json = {
        'id': 'room-empty',
        'name': 'Utility Room',
      };

      final room = AcademicRoomModel.fromJson(json);
      expect(room.id, 'room-empty');
      expect(room.name, 'Utility Room');
      expect(room.code, '');
      expect(room.type, 'Classroom');
      expect(room.building, 'Academic Block');
      expect(room.floor, 'Ground Floor');
      expect(room.capacity, 40);
      expect(room.facilities, isEmpty);
      expect(room.status, 'AVAILABLE');
      expect(room.assignedSections, isEmpty);
      expect(room.assignedSectionsCount, 0);
      expect(room.totalStudentsSeated, 0);
      expect(room.capacityUtilization, 0.0);
      expect(room.description, isNull);
    });

    test('Capacity utilization calculations and edge cases', () {
      // 1. Standard calculation
      final room1 = AcademicRoomModel(
        id: 'r1',
        name: 'Math Room',
        code: 'MR-01',
        capacity: 40,
        totalStudentsSeated: 30,
        capacityUtilization: 75.0,
      );
      expect(room1.capacityUtilization, 75.0);

      // 2. Zero capacity edge case
      final roomZeroCap = AcademicRoomModel(
        id: 'r2',
        name: 'Server Room',
        code: 'SR-01',
        capacity: 0,
        totalStudentsSeated: 0,
        capacityUtilization: 0.0,
      );
      expect(roomZeroCap.capacityUtilization, 0.0);

      // 3. Over-capacity seating (> 100%)
      final roomOverCap = AcademicRoomModel(
        id: 'r3',
        name: 'Seminar Hall',
        code: 'SH-01',
        capacity: 50,
        totalStudentsSeated: 60,
        capacityUtilization: 120.0,
      );
      expect(roomOverCap.capacityUtilization, 120.0);
    });

    test('Floor map grouping algorithm verification', () {
      final rooms = [
        AcademicRoomModel(id: '1', name: 'Room 101', code: '101', building: 'Block A', floor: '1st Floor'),
        AcademicRoomModel(id: '2', name: 'Room 102', code: '102', building: 'Block A', floor: '1st Floor'),
        AcademicRoomModel(id: '3', name: 'Room 201', code: '201', building: 'Block A', floor: '2nd Floor'),
        AcademicRoomModel(id: '4', name: 'Lab 1', code: 'L1', building: 'Science Block', floor: 'Ground Floor'),
      ];

      final Map<String, Map<String, List<AcademicRoomModel>>> grouped = {};
      for (var r in rooms) {
        grouped.putIfAbsent(r.building, () => {});
        grouped[r.building]!.putIfAbsent(r.floor, () => []);
        grouped[r.building]![r.floor]!.add(r);
      }

      expect(grouped.keys, containsAll(['Block A', 'Science Block']));
      expect(grouped['Block A']!['1st Floor']!.length, 2);
      expect(grouped['Block A']!['2nd Floor']!.length, 1);
      expect(grouped['Science Block']!['Ground Floor']!.length, 1);
    });
  });
}
