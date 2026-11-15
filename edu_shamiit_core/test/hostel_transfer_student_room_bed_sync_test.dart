import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/hostel/models/hostel_models.dart';

void main() {
  group('Hostel Transfer Room & Bed Synchronization Test', () {
    final currentStudent = HostelStudentRosterItem(
      id: 'adm-001',
      admissionId: 'adm-001',
      allocationId: 'alloc-001',
      studentId: 'stu-001',
      studentName: 'Aarav Sharma',
      guardianName: 'Father',
      guardianRelation: 'Father',
      rollNo: '0101',
      className: 'Class 10 A',
      hostelId: 'bld-001',
      hostelName: 'Boys Hostel A',
      roomId: 'room-101',
      roomNumber: 'A-101',
      bedId: 'bed-1',
      bedNo: '1',
      status: 'Active',
      rawStatus: 'ACTIVE',
      feeStatus: 'Paid',
      admissionDate: '2026-10-30',
      gender: 'Male',
      bloodGroup: 'B+',
      emergencyContact: '+91 98765 43210',
    );

    final allRooms = [
      HostelRoomItem(
        id: 'room-101',
        buildingId: 'bld-001',
        buildingName: 'Boys Hostel A',
        floorId: 'flr-001',
        floorName: 'Ground Floor',
        roomNumber: 'A-101',
        roomCode: 'A101',
        roomType: 'Standard',
        capacity: 3,
        occupied: 3, // 0 free beds! Current room!
        monthlyFee: 6000.0,
      ),
      HostelRoomItem(
        id: 'room-102',
        buildingId: 'bld-001',
        buildingName: 'Boys Hostel A',
        floorId: 'flr-001',
        floorName: 'Ground Floor',
        roomNumber: 'A-102',
        roomCode: 'A102',
        roomType: 'Standard',
        capacity: 3,
        occupied: 3, // 0 free beds!
        monthlyFee: 6000.0,
      ),
      HostelRoomItem(
        id: 'room-104',
        buildingId: 'bld-001',
        buildingName: 'Boys Hostel A',
        floorId: 'flr-001',
        floorName: 'Ground Floor',
        roomNumber: 'A-104',
        roomCode: 'A104',
        roomType: 'Standard',
        capacity: 3,
        occupied: 2, // 1 free bed!
        monthlyFee: 6000.0,
      ),
      HostelRoomItem(
        id: 'room-201',
        buildingId: 'bld-001',
        buildingName: 'Boys Hostel A',
        floorId: 'flr-002',
        floorName: 'First Floor',
        roomNumber: 'A-201',
        roomCode: 'A201',
        roomType: 'Deluxe',
        capacity: 2,
        occupied: 0, // 2 free beds!
        monthlyFee: 8500.0,
      ),
    ];

    test('Rooms with 0 available beds and student current room are strictly excluded', () {
      final filtered = allRooms.where((r) {
        final hasVacant = r.availableBeds > 0;
        final isNotCurrent = r.id != currentStudent.roomId &&
            r.roomNumber.trim().toLowerCase() != currentStudent.roomNumber.trim().toLowerCase();
        return hasVacant && isNotCurrent;
      }).toList();

      expect(filtered.length, equals(2));
      expect(filtered.any((r) => r.roomNumber == 'A-101'), isFalse, reason: 'Current room must be excluded');
      expect(filtered.any((r) => r.roomNumber == 'A-102'), isFalse, reason: 'Room with 0 free beds must be excluded');
      expect(filtered.any((r) => r.roomNumber == 'A-104'), isTrue);
      expect(filtered.any((r) => r.roomNumber == 'A-201'), isTrue);
    });

    test('Room Type filter strictly isolates matching room types with vacant beds', () {
      const selectedType = 'Deluxe';
      final filtered = allRooms.where((r) {
        final matchesType = r.roomType.trim().toLowerCase() == selectedType.toLowerCase();
        final hasVacant = r.availableBeds > 0;
        final isNotCurrent = r.id != currentStudent.roomId &&
            r.roomNumber.trim().toLowerCase() != currentStudent.roomNumber.trim().toLowerCase();
        return matchesType && hasVacant && isNotCurrent;
      }).toList();

      expect(filtered.length, equals(1));
      expect(filtered.first.roomNumber, equals('A-201'));
      expect(filtered.first.roomType, equals('Deluxe'));
    });

    test('Bed dropdown shows only vacant beds and excludes occupied beds', () {
      final allBedsInRoom = [
        HostelBed(
          id: 'b-1',
          bedCode: 'Bed 1',
          bedType: 'Single',
          status: 'OCCUPIED',
        ),
        HostelBed(
          id: 'b-2',
          bedCode: 'Bed 2',
          bedType: 'Single',
          status: 'OCCUPIED',
        ),
        HostelBed(
          id: 'b-3',
          bedCode: 'Bed 3',
          bedType: 'Single',
          status: 'AVAILABLE',
        ),
      ];

      final vacantBeds = allBedsInRoom
          .where((b) => b.isAvailable || b.status.toUpperCase() == 'AVAILABLE')
          .toList();

      expect(vacantBeds.length, equals(1));
      expect(vacantBeds.first.bedCode, equals('Bed 3'));
      expect(vacantBeds.first.status, equals('AVAILABLE'));
    });
  });
}
