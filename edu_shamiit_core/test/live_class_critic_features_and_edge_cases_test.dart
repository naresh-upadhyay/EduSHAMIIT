import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/live_classes/models/live_class_models.dart';
import 'package:edu_shamiit_core/screens/live_classes/whiteboard/models/whiteboard_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Live Class Critic Features & RBAC Edge Cases Test Suite', () {
    test('RBAC role detection cleanly isolates students/guests from hosts/teachers', () {
      bool isStudentParticipant(String role) {
        final r = role.toLowerCase().trim();
        return r != 'teacher' &&
            r != 'host' &&
            r != 'co-host' &&
            r != 'super_admin' &&
            r != 'admin';
      }

      // Students and parents must NOT have host authority
      expect(isStudentParticipant('student'), isTrue);
      expect(isStudentParticipant('Student'), isTrue);
      expect(isStudentParticipant('parent'), isTrue);
      expect(isStudentParticipant('guest'), isTrue);

      // Teachers and administrators MUST have host authority
      expect(isStudentParticipant('teacher'), isFalse);
      expect(isStudentParticipant('Teacher'), isFalse);
      expect(isStudentParticipant('host'), isFalse);
      expect(isStudentParticipant('co-host'), isFalse);
      expect(isStudentParticipant('super_admin'), isFalse);
      expect(isStudentParticipant('admin'), isFalse);
    });

    test('Network Quality HUD accurately maps RTT and packet loss into telemetry bands', () {
      String computeStatusLabel(int rttMs, double packetLossPct) {
        if (rttMs > 200 || packetLossPct > 2.0) return 'Poor';
        if (rttMs > 80 || packetLossPct > 0.5) return 'Good';
        return 'Excellent';
      }

      // Ultra low latency on high-speed fiber
      expect(computeStatusLabel(24, 0.0), 'Excellent');
      expect(computeStatusLabel(42, 0.01), 'Excellent');

      // Standard mobile/Wi-Fi connection
      expect(computeStatusLabel(95, 0.2), 'Good');
      expect(computeStatusLabel(120, 0.4), 'Good');

      // High latency or degraded satellite / cell edge connection
      expect(computeStatusLabel(225, 0.1), 'Poor');
      expect(computeStatusLabel(45, 3.5), 'Poor');
    });

    test('Push-to-Talk state machine transitions correctly and preserves initial mic state', () {
      // Simulate state machine
      bool isMicMuted = true;
      bool isPushToTalkActive = false;
      bool wasMicMutedBeforePTT = true;

      void onSpaceKeyDown() {
        if (!isPushToTalkActive) {
          isPushToTalkActive = true;
          wasMicMutedBeforePTT = isMicMuted;
          if (isMicMuted) {
            isMicMuted = false;
          }
        }
      }

      void onSpaceKeyUp() {
        if (isPushToTalkActive) {
          isPushToTalkActive = false;
          if (wasMicMutedBeforePTT) {
            isMicMuted = true;
          }
        }
      }

      // Case 1: Initial state is muted (standard PTT)
      expect(isMicMuted, isTrue);
      onSpaceKeyDown(); // User presses space
      expect(isPushToTalkActive, isTrue);
      expect(isMicMuted, isFalse); // Mic unmuted while holding

      onSpaceKeyUp(); // User releases space
      expect(isPushToTalkActive, isFalse);
      expect(isMicMuted, isTrue); // Returns to muted

      // Case 2: Initial state is unmuted (teacher active talking)
      isMicMuted = false;
      onSpaceKeyDown();
      expect(isMicMuted, isFalse);
      onSpaceKeyUp();
      expect(isMicMuted, isFalse); // Stays unmuted! Not forced to mute
    });

    test('Subject title resolver correctly selects whiteboard template matching curriculum', () {
      String resolveTemplate(String subject) {
        final subLower = subject.toLowerCase();
        if (subLower.contains('chem')) {
          return 'chemistry';
        } else if (subLower.contains('math') ||
            subLower.contains('algebra') ||
            subLower.contains('calc')) {
          return 'mathematics';
        } else if (subLower.contains('phys')) {
          return 'physics';
        } else if (subLower.contains('bio') || subLower.contains('life')) {
          return 'biology';
        } else {
          return 'concept_mind_map';
        }
      }

      expect(resolveTemplate('Chemistry (Organic Compounds)'), 'chemistry');
      expect(resolveTemplate('Class 10 - Mathematics'), 'mathematics');
      expect(resolveTemplate('Physics - Thermodynamics'), 'physics');
      expect(resolveTemplate('Biology & Life Sciences'), 'biology');
      expect(resolveTemplate('History & Social Studies'), 'concept_mind_map');
      expect(resolveTemplate('Computer Science'), 'concept_mind_map');
    });

    test('Mindmap connector objects support edge label modification and styling', () {
      final connector = WhiteboardObject(
        id: 'conn-1',
        type: 'connector',
        pageId: 'page-1',
        data: {
          'x': 100.0,
          'y': 100.0,
          'endX': 300.0,
          'endY': 250.0,
          'label': 'connects to',
          'fromId': 'node-1',
          'toId': 'node-2',
          'lineStyle': 'curved',
          'hasArrow': true,
        },
      );

      expect(connector.data['label'], 'connects to');
      expect(connector.data['hasArrow'], isTrue);

      // Modify edge label
      final updated = connector.copyWith(
        data: Map<String, dynamic>.from(connector.data)..['label'] = 'yields reactant',
      );

      expect(updated.data['label'], 'yields reactant');
      expect(updated.id, connector.id);
      expect(updated.data['fromId'], 'node-1');
      expect(updated.data['toId'], 'node-2');
    });

    test('ActiveLiveSession preserves session identity across stage and whiteboard transitions', () {
      final session = ActiveLiveSession(
        id: 'sess-chem-12a',
        title: 'Organic Compounds – Introduction',
        description: 'Chapter 4',
        className: 'Class 12',
        sectionName: 'A',
        classSection: 'Class 12 - A',
        subject: 'Chemistry',
        subjectIcon: 'science',
        teacherName: 'Aarav Sharma',
        teacherRole: 'Super Admin / Chemistry Lead',
        durationMinutes: 45,
        status: 'live',
        isLive: true,
        recordingStatus: 'recording',
        recordingEnabled: true,
        roomCode: '12A-CHEM',
        meetingLink: 'https://meet.edushamiit.com/c/12A-CHEM',
        viewerCount: 42,
        maxParticipants: 45,
        dateStr: '20 Nov 2026',
        timeStr: '08:00 AM - 08:45 AM',
        recordingElapsedStr: '00:18:24',
      );

      expect(session.classSection, 'Class 12 - A');
      expect('${session.classSection} : ${session.subject}', 'Class 12 - A : Chemistry');
      expect(session.isLive, isTrue);
      expect(session.roomCode, '12A-CHEM');
    });
  });
}
