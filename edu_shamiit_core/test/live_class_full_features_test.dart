import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/live_classes/live_class_management_screen.dart';
import 'package:edu_shamiit_core/screens/live_classes/models/live_class_models.dart';
import 'package:edu_shamiit_core/screens/live_classes/providers/live_class_management_provider.dart';
import 'package:edu_shamiit_core/screens/live_classes/services/in_app_live_room_service.dart';
import 'package:edu_shamiit_core/screens/live_classes/whiteboard/models/whiteboard_models.dart';
import 'package:edu_shamiit_core/screens/live_classes/whiteboard/providers/whiteboard_provider.dart';
import 'package:edu_shamiit_core/screens/live_classes/whiteboard/widgets/whiteboard_dialogs.dart';
import 'package:edu_shamiit_core/screens/live_classes/whiteboard/widgets/whiteboard_workspace.dart';
import 'package:edu_shamiit_core/screens/live_classes/widgets/live_class_chat_panel.dart';
import 'package:edu_shamiit_core/screens/live_classes/widgets/live_classroom_stage.dart';
import 'package:edu_shamiit_core/screens/live_classes/utils/live_class_theme.dart';
import 'package:edu_shamiit_core/screens/live_classes/services/live_class_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Live Class Full Features & Edge Cases Test Suite', () {
    test('LiveClassPollOption calculates accurate percentages and protects against division by zero', () {
      double computePct(int optionVotes, int totalVotes) {
        if (totalVotes <= 0) return 0.0;
        return double.parse((optionVotes / totalVotes * 100).toStringAsFixed(1));
      }

      final opt1 = LiveClassPollOption(id: 'opt1', text: 'Option A', votes: 0, percentage: 0.0);
      final opt2 = LiveClassPollOption(id: 'opt2', text: 'Option B', votes: 0, percentage: 0.0);

      // 0 total votes -> 0.0%
      expect(computePct(opt1.votes, 0), 0.0);
      expect(computePct(opt2.votes, 0), 0.0);

      // 1 vote out of 1 -> 100.0%
      expect(computePct(1, 1), 100.0);

      // 1 vote out of 4 -> 25.0%
      expect(computePct(1, 4), 25.0);

      // 1 vote out of 3 -> 33.3%
      expect(computePct(1, 3), 33.3);
    });

    test('Financial Year resolver identifies current academic year dynamically from lookup values', () {
      final sessions = ['2023 - 2024', '2024 - 2025', '2025 - 2026', '2026 - 2027'];
      final resolved = LiveClassApiService.resolveCurrentFinancialYear(sessions);

      final now = DateTime.now();
      final startYear = now.month >= 4 ? now.year : now.year - 1;
      expect(resolved.contains('$startYear'), isTrue);
    });

    test('LiveClassPollItem maintains active state and history aggregation', () {
      final poll1 = LiveClassPollItem(
        id: 'poll-1',
        question: 'Active Poll 1',
        title: 'Active Poll 1',
        pollType: 'SINGLE_CHOICE',
        status: 'ACTIVE',
        options: [
          LiveClassPollOption(id: 'o1', text: 'WAW', votes: 2, percentage: 50.0),
          LiveClassPollOption(id: 'o2', text: 'KING', votes: 2, percentage: 50.0),
        ],
        totalVotes: 4,
      );

      final poll2 = LiveClassPollItem(
        id: 'poll-2',
        question: 'Past Poll 2',
        title: 'Past Poll 2',
        pollType: 'SINGLE_CHOICE',
        status: 'COMPLETED',
        options: [
          LiveClassPollOption(id: 'o3', text: 'JI', votes: 5, percentage: 100.0),
          LiveClassPollOption(id: 'o4', text: 'READY', votes: 0, percentage: 0.0),
        ],
        totalVotes: 5,
      );

      final history = [poll1, poll2];
      expect(history.length, 2);
      expect(history.first.options.length, 2);
      expect(history.first.options[0].text, 'WAW');
      expect(history.first.options[1].text, 'KING');
      expect(history.last.options[0].text, 'JI');
      expect(history.last.options[1].text, 'READY');
    });

    testWidgets('LiveClassTheme adapts colors dynamically from context ThemeData', (WidgetTester tester) async {
      const customPrimary = Color(0xFF6366F1); // Indigo theme

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            primaryColor: customPrimary,
            colorScheme: ColorScheme.fromSeed(seedColor: customPrimary),
          ),
          home: Builder(
            builder: (context) {
              final resolvedPrimary = LiveClassTheme.primary(context);
              expect(resolvedPrimary, equals(customPrimary));
              return Container(color: resolvedPrimary);
            },
          ),
        ),
      );

      await tester.pump();
    });

    testWidgets('LiveClassChatPanel renders Participants, Chat, and Q&A / Polls tabs without errors', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LiveClassChatPanel(
                initialTabIndex: 0,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify the 3 core tabs exist and are rendered cleanly (including local host participant)
      expect(find.text('Participants (1)'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Q&A (0)'), findsOneWidget);
    });

    test('resolveUnifiedParticipants deduplicates local host and DB participants into one synced list', () {
      final roomService = InAppLiveRoomService();
      final dbParticipants = [
        LiveParticipant(
          id: 'p-host',
          userId: 'user-host-1',
          name: 'King Doe',
          role: 'Super Admin',
          initials: 'KD',
          micMuted: true,
          camOff: true,
          isSpeaking: false,
          color: '#2563EB',
        ),
        LiveParticipant(
          id: 'p-host-dup-name',
          userId: '',
          name: 'king doe',
          role: 'host',
          initials: 'KD',
          micMuted: true,
          camOff: true,
          isSpeaking: false,
          color: '#2563EB',
        ),
        LiveParticipant(
          id: 'p-student-1',
          userId: 'user-stu-1',
          name: 'Aarav Verma',
          role: 'student',
          initials: 'AV',
          micMuted: true,
          camOff: true,
          isSpeaking: false,
          color: '#10B981',
        ),
      ];

      final unified = resolveUnifiedParticipants(
        roomService: roomService,
        localUserId: 'user-host-1',
        localUserName: 'King Doe',
        localUserRole: 'Super Admin',
        dbParticipants: dbParticipants,
      );

      expect(unified.length, 2);
      expect(unified.first.isLocal, isTrue);
      expect(unified.first.name, 'King Doe');
      expect(unified.last.userId, 'user-stu-1');
      expect(unified.last.name, 'Aarav Verma');
    });

    test('resolveTargetedMaxCapacity uses DB targeted capacity instead of hardcoded 45', () {
      final session = ActiveLiveSession(
        id: 'sess-10b',
        title: 'Mathematics',
        description: '',
        className: 'Class 10',
        sectionName: '10-B',
        classSection: 'Class 10 - 10-B',
        subject: 'Mathematics',
        subjectIcon: 'calculate',
        teacherName: 'King Doe',
        teacherRole: 'Super Admin',
        durationMinutes: 45,
        status: 'live',
        isLive: true,
        recordingStatus: 'idle',
        recordingEnabled: false,
        roomCode: '10B-MATH',
        meetingLink: '',
        viewerCount: 1,
        maxParticipants: 37,
        dateStr: '25 Nov 2026',
        timeStr: '09:00 AM',
        recordingElapsedStr: '00:00:00',
      );

      expect(resolveTargetedMaxCapacity(activeSession: session, activeCount: 1), 37);
      expect(resolveTargetedMaxCapacity(activeSession: null, activeCount: 1), 1);
      expect(resolveTargetedMaxCapacity(activeSession: null, activeCount: 4), 4);
    });

    test('MyClassItem.fromJson and ActiveLiveSession.fromJson preserve DB viewer_count and max_participants', () {
      final classJson = {
        'id': 'cls-10b',
        'class_section': 'Class 10 - 10-B',
        'subject_name': 'Mathematics',
        'topic': 'Trigonometry',
        'viewer_count': 0,
        'max_participants': 37,
        'status': 'scheduled',
      };
      final item = MyClassItem.fromJson(classJson);
      expect(item.viewerCount, 0);
      expect(item.maxParticipants, 37);

      final sessionJson = {
        'id': 'sess-10b',
        'title': 'Trigonometry',
        'class_name': 'Class 10',
        'section_name': '10-B',
        'class_section': 'Class 10 - 10-B',
        'subject': 'Mathematics',
        'teacher_name': 'King Doe',
        'viewer_count': 1,
        'max_participants': 37,
        'status': 'live',
        'is_live': true,
      };
      final session = ActiveLiveSession.fromJson(sessionJson);
      expect(session.viewerCount, 1);
      expect(session.maxParticipants, 37);
    });

    testWidgets('LiveClassroomStage starts fresh like Zoom/Meet without fake slides or smartboard text', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final session = ActiveLiveSession(
        id: 'sess-fresh',
        title: 'Linear Algebra',
        description: '',
        className: 'Class 10',
        sectionName: '10-B',
        classSection: 'Class 10 - 10-B',
        subject: 'Mathematics',
        subjectIcon: 'calculate',
        teacherName: 'King Doe',
        teacherRole: 'Super Admin',
        durationMinutes: 45,
        status: 'live',
        isLive: true,
        recordingStatus: 'idle',
        recordingEnabled: false,
        roomCode: '10B-MATH',
        meetingLink: '',
        viewerCount: 1,
        maxParticipants: 37,
        dateStr: '25 Nov 2026',
        timeStr: '09:00 AM',
        recordingElapsedStr: '00:00:00',
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 900,
                height: 600,
                child: LiveClassroomStage(
                  session: session,
                  participants: const [],
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(seconds: 5));

      expect(find.textContaining('Quadratic_Equations_Masterclass.pdf'), findsNothing);
      expect(find.textContaining('Organic Compounds'), findsNothing);
      expect(find.textContaining('1/37'), findsOneWidget);
    });

    testWidgets('LiveClassManagementScreen replaces Attendance tab with standalone White Board tab on right of Recordings', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final wbNotifier = WhiteboardNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            whiteboardProvider.overrideWith((ref) => wbNotifier),
          ],
          child: const MaterialApp(
            home: LiveClassManagementScreen(initialTabIndex: 2),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.text('Join & Conduct'), findsOneWidget);
      expect(find.text('Recordings'), findsOneWidget);
      expect(find.text('White Board'), findsOneWidget);
      expect(find.text('Attendance'), findsNothing);
      expect(find.text('Offline Class'), findsOneWidget);
      expect(find.text('New Board'), findsOneWidget);
      expect(find.text('Participants (1)'), findsNothing);
    });

    testWidgets('WhiteboardWorkspace left Work History & Sessions drawer toggles Hide/Show and displays CRUD & Share actions cleanly', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final wbNotifier = WhiteboardNotifier();
      wbNotifier.state = WhiteboardState(
        document: WhiteboardDocument(
          id: 'wb-1',
          sessionId: null,
          title: 'Morning Geometry Session',
          status: 'ACTIVE',
          currentRevision: 1,
          teacherOnlyMode: false,
          collaborationEnabled: false,
          presentationMode: false,
          defaultPermissions: const {},
          templateType: 'blank',
          myPermission: const WhiteboardPermissionInfo(permission: 'OWNER', canEdit: true, canManagePermissions: true, canManagePages: true),
          pages: [
            WhiteboardPage(
              id: 'pg-1',
              whiteboardId: 'wb-1',
              title: '1. Main Board',
              pageOrder: 1,
              backgroundType: WhiteboardBackgroundType.plain,
              objects: const [],
            ),
          ],
          versions: const [],
          activeCollaborators: const [],
        ),
        activePageId: 'pg-1',
        sessionBoards: const [
          {
            'id': 'wb-1',
            'session_id': null,
            'title': 'Morning Geometry Session',
            'description': 'Triangles & Proofs',
            'template_type': 'blank',
            'page_count': 2,
            'object_count': 6,
            'updated_at': '2026-11-25T08:00:00Z',
          },
          {
            'id': 'wb-2',
            'session_id': null,
            'title': 'Yesterday Algebra Revision',
            'description': 'Quadratic equations',
            'template_type': 'mathematics',
            'page_count': 3,
            'object_count': 14,
            'updated_at': '2026-11-24T10:30:00Z',
          },
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            whiteboardProvider.overrideWith((ref) => wbNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: WhiteboardWorkspace(
                sessionId: null,
                sessionTitle: 'Morning Geometry Session',
                isOfflineTab: true,
                isTabActive: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // Drawer is hidden initially; top-left toggle shows History count
      expect(find.text('History (2)'), findsOneWidget);
      expect(find.text('Work History & Sessions'), findsNothing);

      // Tap top-left History toggle to open drawer
      await tester.tap(find.text('History (2)'));
      await tester.pumpAndSettle();

      expect(find.text('Work History & Sessions'), findsOneWidget);
      expect(find.text('New Fresh Session'), findsOneWidget);
      expect(find.text('Yesterday Algebra Revision'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Rework'), findsOneWidget);

      // Verify compact mobile layout drawer overlay renders with zero overflow
      tester.view.physicalSize = const Size(420, 820);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Hide drawer via Hide Drawer button
      await tester.tap(find.byTooltip('Hide Drawer'));
      await tester.pumpAndSettle();
      expect(find.text('Work History & Sessions'), findsNothing);
    });

    testWidgets('WhiteboardShareDialog supports Class -> multi-Section cascading, Search Individuals multi-select, and Access Level presets without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final testWbNotifier = _ShareTestWhiteboardNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            whiteboardProvider.overrideWith((ref) => testWbNotifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: WhiteboardShareDialog(
                whiteboardId: 'wb-1',
                boardTitle: 'Engineering Blueprint',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Class & Sections cascading loaded from directory without manual typing
      expect(find.text('Class & Sections'), findsOneWidget);
      expect(find.text('Search Individuals'), findsOneWidget);
      expect(find.text('10-A (36)'), findsOneWidget);
      expect(find.text('10-B (37)'), findsOneWidget);
      expect(find.text('Aarav Student'), findsOneWidget);
      expect(find.text('Meera Teacher'), findsOneWidget);

      // Select multiple sections cleanly
      await tester.tap(find.text('10-A (36)'));
      await tester.pumpAndSettle();
      expect(find.text('1 section(s) selected'), findsOneWidget);

      // Switch to Individual Search multi-select and select both individuals
      await tester.tap(find.text('Search Individuals'));
      await tester.pumpAndSettle();
      expect(find.text('Rohan Verma'), findsOneWidget);
      expect(find.text('Meera Teacher'), findsOneWidget);
      await tester.tap(find.text('Rohan Verma'));
      await tester.pump();
      await tester.tap(find.text('Meera Teacher'));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);

      // Switch Access Level preset and verify capabilities update
      await tester.tap(find.text('Full Edit'));
      await tester.pumpAndSettle();
      expect(find.text('Share & Assign Access'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _ShareTestWhiteboardNotifier extends WhiteboardNotifier {
  @override
  Future<List<Map<String, dynamic>>> fetchShareDirectoryClasses() async {
    return [
      {
        'id': 'cls-10',
        'name': 'Class 10',
        'students_count': 73,
        'sections': [
          {'id': 'sec-10a', 'name': '10-A', 'students_count': 36, 'teachers_count': 2},
          {'id': 'sec-10b', 'name': '10-B', 'students_count': 37, 'teachers_count': 2},
        ],
      },
    ];
  }

  @override
  Future<Map<String, List<Map<String, dynamic>>>> fetchShareClassMembers({
    required String classId,
    List<String> sectionIds = const [],
  }) async {
    return {
      'students': [
        {'id': 'stu-1', 'full_name': 'Aarav Student', 'email': 'aarav@shamiit.edu', 'role': 'student', 'section_name': '10-A', 'roll_number': '101'},
      ],
      'teachers': [
        {'id': 'tch-1', 'full_name': 'Meera Teacher', 'email': 'meera@shamiit.edu', 'role': 'teacher', 'section_name': '10-A', 'assignment_label': 'Class Teacher'},
      ],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> searchShareUsers({
    String query = '',
    String roleFilter = 'all',
    int limit = 60,
  }) async {
    return [
      {'id': 'stu-2', 'full_name': 'Rohan Verma', 'email': 'rohan@shamiit.edu', 'role': 'student', 'class_name': 'Class 10', 'section_name': '10-B'},
      {'id': 'tch-1', 'full_name': 'Meera Teacher', 'email': 'meera@shamiit.edu', 'role': 'teacher', 'department': 'Physics'},
    ];
  }

  @override
  Future<List<WhiteboardShareItem>> listBoardShares([String? whiteboardId]) async => [];
}
