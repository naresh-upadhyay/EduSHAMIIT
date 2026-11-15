import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

void main() {
  group('Campus & Buildings Management Models Tests', () {
    test('CampusKpis fromJson parses KPI metrics accurately', () {
      final json = {
        'total_buildings': 8,
        'total_floors': 38,
        'total_rooms': 156,
        'total_capacity': 7560,
        'occupied_rooms': 142,
        'occupied_capacity': 6842,
        'available_rooms': 14,
        'available_capacity': 718,
        'occupancy_rate': 90.5,
        'maintenance_rooms': 3,
        'total_equipment': 420,
        'equipment_not_working': 12,
      };

      final kpis = CampusKpis.fromJson(json);

      expect(kpis.totalBuildings, 8);
      expect(kpis.totalFloors, 38);
      expect(kpis.totalRooms, 156);
      expect(kpis.totalCapacity, 7560);
      expect(kpis.occupiedCapacity, 6842);
      expect(kpis.availableCapacity, 718);
      expect(kpis.occupancyRate, 90.5);
      expect(kpis.maintenanceRooms, 3);
      expect(kpis.totalEquipment, 420);
      expect(kpis.equipmentNotWorking, 12);
    });

    test('BuildingModel fromJson parses building details, hierarchy and status', () {
      final json = {
        'id': 'bld-001-uuid',
        'school_id': '11111111-1111-1111-1111-111111111111',
        'campus_id': 'campus-greenwood-uuid',
        'name': 'B1 - Academic Block',
        'code': 'B1',
        'building_type': 'Academic',
        'purpose': 'Classrooms, Laboratories and Staff Rooms',
        'status': 'Active',
        'total_floors': 5,
        'total_rooms': 42,
        'total_capacity': 2100,
        'current_occupancy': 1950,
        'occupancy_rate': 92.9,
        'manager_name': 'Dr. Robert Langdon',
        'manager_contact': '+1 555-0199',
        'description': 'Main academic facility for Senior & High School students',
      };

      final building = BuildingModel.fromJson(json);

      expect(building.id, 'bld-001-uuid');
      expect(building.name, 'B1 - Academic Block');
      expect(building.code, 'B1');
      expect(building.buildingType, 'Academic');
      expect(building.totalFloors, 5);
      expect(building.totalRooms, 42);
      expect(building.totalCapacity, 2100);
      expect(building.currentOccupancy, 1950);
      expect(building.occupancyRate, 92.9);
      expect(building.managerName, 'Dr. Robert Langdon');
      expect(building.managerContact, '+1 555-0199');
      expect(building.status, 'Active');
    });

    test('BuildingFloorModel fromJson parses floor levels, codes and room counts', () {
      final json = {
        'id': 'flr-001-uuid',
        'building_id': 'bld-001-uuid',
        'name': 'Ground Floor (G)',
        'floor_code': 'G',
        'floor_level': 0,
        'floor_order': 0,
        'floor_type': 'Standard',
        'total_rooms': 8,
        'capacity': 400,
        'occupancy': 368,
        'occupancy_percentage': 92.0,
        'status': 'Active',
        'room_types_summary': 'Classroom (4), Lab (2), Office (2)',
      };

      final floor = BuildingFloorModel.fromJson(json);

      expect(floor.id, 'flr-001-uuid');
      expect(floor.buildingId, 'bld-001-uuid');
      expect(floor.name, 'Ground Floor (G)');
      expect(floor.floorCode, 'G');
      expect(floor.floorLevel, 0);
      expect(floor.totalRooms, 8);
      expect(floor.capacity, 400);
      expect(floor.occupancy, 368);
      expect(floor.occupancyPercentage, 92.0);
      expect(floor.roomTypesSummary, 'Classroom (4), Lab (2), Office (2)');
    });

    test('RoomModel fromJson parses dynamic attributes and equipment summaries', () {
      final json = {
        'id': 'rm-101-uuid',
        'school_id': '11111111-1111-1111-1111-111111111111',
        'building_id': 'bld-001-uuid',
        'building_name': 'B1 - Academic Block',
        'floor_id': 'flr-001-uuid',
        'floor_name': 'First Floor (F1)',
        'name': 'Smart Physics Lab',
        'room_number': '101',
        'room_code': 'B1-F1-101',
        'room_type': 'Laboratory',
        'max_capacity': 40,
        'current_occupancy': 35,
        'operational_status': 'Operational',
        'area': 850.5,
        'equipment_summary': 'Projector, Digital Whiteboard, 20 Laptops',
        'equipment_count': 22,
        'equipment_not_working': 1,
      };

      final room = RoomModel.fromJson(json);

      expect(room.id, 'rm-101-uuid');
      expect(room.roomNumber, '101');
      expect(room.name, 'Smart Physics Lab');
      expect(room.roomType, 'Laboratory');
      expect(room.maxCapacity, 40);
      expect(room.currentOccupancy, 35);
      expect(room.operationalStatus, 'Operational');
      expect(room.area, 850.5);
      expect(room.equipmentCount, 22);
      expect(room.equipmentNotWorking, 1);
      expect(room.equipmentSummary, 'Projector, Digital Whiteboard, 20 Laptops');
    });

    test('RoomEquipmentModel parses individual operational status accurately', () {
      final json = {
        'id': 'eq-001-uuid',
        'room_id': 'rm-101-uuid',
        'equipment_name': 'Epson 4K Laser Projector',
        'equipment_category': 'Audio Visual',
        'asset_id': 'PRJ-4K-01',
        'quantity': 1,
        'condition': 'Good',
        'operational_status': 'Operational',
        'installation_date': '2025-01-15',
        'next_service_date': '2028-01-15',
      };

      final equipment = RoomEquipmentModel.fromJson(json);

      expect(equipment.id, 'eq-001-uuid');
      expect(equipment.equipmentName, 'Epson 4K Laser Projector');
      expect(equipment.equipmentCategory, 'Audio Visual');
      expect(equipment.assetId, 'PRJ-4K-01');
      expect(equipment.operationalStatus, 'Operational');
    });
  });

  group('Campus State Notifier & Filters Tests', () {
    test('CampusState defaults to Buildings & Rooms tab as active tab', () {
      const state = CampusState();

      expect(state.activeCampusTab, 0); // Buildings & Rooms must be tab 0
      expect(state.activeBuildingSubTab, 0); // Floors is default sub-tab
      expect(state.roomsViewMode, 0); // Data table by default
      expect(state.buildings, isEmpty);
      expect(state.selectedBuilding, isNull);
    });

    test('CampusState copyWith updates filter criteria correctly', () {
      const state = CampusState();
      final updated = state.copyWith(
        buildingSearchQuery: 'Academic',
        filterRoomType: 'Laboratory',
        filterRoomStatus: 'Operational',
        roomsViewMode: 1, // Grid view
      );

      expect(updated.buildingSearchQuery, 'Academic');
      expect(updated.filterRoomType, 'Laboratory');
      expect(updated.filterRoomStatus, 'Operational');
      expect(updated.roomsViewMode, 1);
    });
  });
}
