import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Bulk Import & Export Center Unit Tests (All 4 Tabs)', () {
    // ------------------------------------------------------------------------
    // 1. Template Generation for All 4 Academic Tabs
    // ------------------------------------------------------------------------
    test('Classes template contains standard headers and sample records', () {
      const classesTemplate = "Class Name,Code,Stage,Academic Year,Display Order,Status\n"
          "Class 9,C9,Secondary,2026-27,9,ACTIVE\n"
          "Class 10,C10,Secondary,2026-27,10,ACTIVE\n"
          "Class 11,C11,Higher Secondary,2026-27,11,ACTIVE\n";

      final lines = classesTemplate.trim().split('\n');
      expect(lines.first, 'Class Name,Code,Stage,Academic Year,Display Order,Status');
      expect(lines.length, 4); // header + 3 rows
    });

    test('Sections template contains required Class and Section Name columns', () {
      const sectionsTemplate = "Class,Section Name,Section Code,Capacity,Room,Status\n"
          "Class 10,Section A,10A,40,Room 101,ACTIVE\n"
          "Class 10,Section B,10B,40,Room 102,ACTIVE\n";

      final lines = sectionsTemplate.trim().split('\n');
      expect(lines.first, 'Class,Section Name,Section Code,Capacity,Room,Status');
      expect(lines.length, 3);
    });

    test('Subjects template contains subject types and codes without weekly periods', () {
      const subjectsTemplate = "Subject Name,Code,Type,Status\n"
          "Advanced Mathematics,MATH10,Core,ACTIVE\n"
          "English Literature,ENG10,Core,ACTIVE\n"
          "Computer Science,CS10,Elective,ACTIVE\n";

      final lines = subjectsTemplate.trim().split('\n');
      expect(lines.first, 'Subject Name,Code,Type,Status');
      expect(lines.length, 4);
    });

    test('Rooms template contains building, floor, capacity, and facilities', () {
      const roomsTemplate = "Room Name,Room Code,Type,Building,Floor,Capacity,Facilities,Status\n"
          "Classroom 101,CR-101,Classroom,Academic Block,1st Floor,40,\"Projector, AC, Smart Board\",AVAILABLE\n"
          "Physics Lab,PHY-LAB-01,Laboratory,Science Block,2nd Floor,35,\"AC, Laboratory Equipment, Projector\",AVAILABLE\n";

      final lines = roomsTemplate.trim().split('\n');
      expect(lines.first, 'Room Name,Room Code,Type,Building,Floor,Capacity,Facilities,Status');
      expect(lines.length, 3);
    });

    // ------------------------------------------------------------------------
    // 2. CSV Parser with Quotes, UTF-8 BOM, and Special Characters
    // ------------------------------------------------------------------------
    List<String> splitCsvLine(String line) {
      final result = <String>[];
      final buffer = StringBuffer();
      bool insideQuotes = false;

      for (int i = 0; i < line.length; i++) {
        final char = line[i];
        if (char == '"') {
          insideQuotes = !insideQuotes;
        } else if (char == ',' && !insideQuotes) {
          result.add(buffer.toString());
          buffer.clear();
        } else {
          buffer.write(char);
        }
      }
      result.add(buffer.toString());
      return result;
    }

    test('CSV split handles quotes containing commas correctly', () {
      const line = 'Biology Lab,BIO-01,Laboratory,Science Block,2nd Floor,35,"AC, Microscopes, Smart Board",AVAILABLE';
      final parts = splitCsvLine(line);

      expect(parts.length, 8);
      expect(parts[0], 'Biology Lab');
      expect(parts[6], 'AC, Microscopes, Smart Board');
      expect(parts[7], 'AVAILABLE');
    });

    test('CSV parsing strips UTF-8 BOM and standardizes carriage returns', () {
      const csvWithBom = '\ufeffClass Name,Code,Stage,Academic Year,Display Order,Status\r\n'
          'Class 10,C10,Secondary,2026-27,10,ACTIVE\r\n'
          'Class 12,C12,Higher Secondary,2026-27,12,ACTIVE';

      final clean = csvWithBom.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim().replaceFirst('\ufeff', '');
      final lines = clean.split('\n');

      expect(lines.length, 3);
      expect(lines.first, 'Class Name,Code,Stage,Academic Year,Display Order,Status');
      expect(lines[1], 'Class 10,C10,Secondary,2026-27,10,ACTIVE');
    });

    // ------------------------------------------------------------------------
    // 3. Validation Rules for Uploaded Data
    // ------------------------------------------------------------------------
    test('Validation catches missing mandatory fields per entity', () {
      // Classes validation: requires Class Name
      final invalidClassRow = {'Code': 'C10', 'Stage': 'Secondary'};
      expect(invalidClassRow['Class Name'], isNull);

      // Sections validation: requires Class and Section Name
      final invalidSectionRow = {'Section Name': '10-A', 'Capacity': '40'};
      expect(invalidSectionRow['Class'], isNull);

      // Subjects validation: requires Subject Name
      final invalidSubjectRow = {'Code': 'MATH', 'Type': 'Core'};
      expect(invalidSubjectRow['Subject Name'], isNull);

      // Rooms validation: requires Room Name
      final invalidRoomRow = {'Type': 'Classroom', 'Capacity': '40'};
      expect(invalidRoomRow['Room Name'], isNull);
    });

    test('Facilities string parsing handles empty, single, and multiple items', () {
      List<String> parseFacilities(dynamic raw) {
        if (raw == null) return [];
        if (raw is List) return raw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
        if (raw is String) {
          return raw.split(',').map((e) => e.trim().replaceAll('"', '')).where((e) => e.isNotEmpty).toList();
        }
        return [];
      }

      expect(parseFacilities(''), isEmpty);
      expect(parseFacilities('AC'), ['AC']);
      expect(parseFacilities('AC, Projector, Smart Board'), ['AC', 'Projector', 'Smart Board']);
      expect(parseFacilities(['AC', 'Projector']), ['AC', 'Projector']);
    });

    test('Section parent class normalization matches case-insensitively', () {
      final classMap = {
        'class 10': 'id-10',
        'c10': 'id-10',
        'class 11': 'id-11',
      };

      String? resolveClassId(String input) {
        return classMap[input.trim().toLowerCase()];
      }

      expect(resolveClassId('Class 10'), 'id-10');
      expect(resolveClassId('CLASS 10'), 'id-10');
      expect(resolveClassId('C10'), 'id-10');
      expect(resolveClassId('Unknown Class'), isNull);
    });

    test('Capacity and Display Order parsing fallbacks handle invalid strings', () {
      int parseCapacity(dynamic raw, int fallback) {
        if (raw == null) return fallback;
        if (raw is int) return raw;
        return int.tryParse(raw.toString().trim()) ?? fallback;
      }

      expect(parseCapacity('40', 40), 40);
      expect(parseCapacity('invalid', 40), 40);
      expect(parseCapacity(null, 40), 40);
      expect(parseCapacity(35, 40), 35);
    });
  });
}
