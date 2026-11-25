import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/live_classes/models/live_class_models.dart';
import 'package:edu_shamiit_core/screens/live_classes/providers/live_class_management_provider.dart';
import 'package:edu_shamiit_core/screens/live_classes/services/in_app_live_room_service.dart';
import 'package:edu_shamiit_core/screens/live_classes/services/live_class_api_service.dart';
import 'package:edu_shamiit_core/screens/live_classes/whiteboard/providers/whiteboard_provider.dart';
import 'package:edu_shamiit_core/screens/live_classes/widgets/live_classroom_stage.dart';

class _ScenarioFakeApiService extends LiveClassApiService {
  String serverRecordingStatus = 'IDLE';
  final List<String> toggleActions = [];
  bool uploadCalled = false;
  bool endCalled = false;
  bool leaveCalled = false;
  bool simulateOthersPresent = false;
  bool simulateSessionLive = true;

  _ScenarioFakeApiService({this.serverRecordingStatus = 'IDLE'});

  @override
  Future<void> endLiveClass(String sessionId) async {
    endCalled = true;
    simulateSessionLive = false;
  }

  @override
  Future<Map<String, dynamic>> leaveLiveClass(String sessionId) async {
    leaveCalled = true;
    if (!simulateOthersPresent) {
      simulateSessionLive = false;
      return {
        'success': true,
        'auto_ended': true,
        'remaining_participants': 0,
        'message': 'No other participants remained. Meeting ended automatically.',
      };
    }
    return {
      'success': true,
      'auto_ended': false,
      'remaining_participants': 1,
      'message': 'Left meeting. Class continues live with 1 participant(s).',
    };
  }

  @override
  Future<JoinConductDashboardData> fetchJoinConductDashboard() async {
    return JoinConductDashboardData(
      liveNow: simulateSessionLive ? 1 : 0,
      todaysClasses: 1,
      totalParticipantsLive: simulateSessionLive ? (simulateOthersPresent ? 2 : 1) : 0,
      recordingInProgress: 0,
      avgClassDurationMin: 45,
      classQuality: 'Excellent',
      systemStatus: 'Online',
      activeSession: simulateSessionLive
          ? _buildConductData('sess-live-rec').activeSession
          : null,
      engagement: ClassEngagement(
        overallPercentage: 0,
        activeParticipantsPct: 0,
        interactionPct: 0,
        pollResponsePct: 0,
        contentViewPct: 0,
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> toggleRecording(String sessionId, {String? action}) async {
    toggleActions.add(action ?? 'toggle');
    if (action == 'start') {
      serverRecordingStatus = 'RECORDING';
    } else if (action == 'stop') {
      serverRecordingStatus = 'COMPLETED';
    } else {
      serverRecordingStatus = serverRecordingStatus == 'RECORDING' ? 'COMPLETED' : 'RECORDING';
    }
    return {
      'success': true,
      'recording_status': serverRecordingStatus,
      'data': {
        'recording_status': serverRecordingStatus,
        'is_recording': serverRecordingStatus == 'RECORDING',
      },
    };
  }

  @override
  Future<ConductClassSessionData?> fetchConductSessionData([String? sessionId]) async {
    return _buildConductData(sessionId ?? 'sess-live-rec', recordingStatus: serverRecordingStatus);
  }

  @override
  Future<Map<String, dynamic>> uploadRecordingFile({
    String? classId,
    String? description,
    int durationMinutes = 0,
    int? durationSeconds,
    String? externalUrl,
    List<int>? fileBytes,
    String? fileName,
    String? liveClassId,
    String recordingType = 'Uploaded Recording',
    String? sectionId,
    String? subjectId,
    String? teacherId,
    String? teacherName,
    required String title,
    String visibility = 'CLASS',
  }) async {
    uploadCalled = true;
    return {
      'success': true,
      'data': {'id': 'rec-uploaded-1', 'title': title},
    };
  }

  @override
  Future<RecordingsDashboardData> fetchRecordingsDashboard() async {
    return RecordingsDashboardData(
      totalRecordings: 1,
      thisWeek: 1,
      totalDurationDisplay: '0 h 05 min',
      storageUsedGb: 0.01,
      storageTotalTb: 1.0,
      storageUsedPercentage: 1,
      totalDownloads: 0,
      avgViews: 1,
      retentionRatePct: 100,
      storageBreakdown: StorageBreakdown(
        recordingsGb: 0.01,
        recordingsPct: 0.01,
        classResourcesGb: 0.0,
        classResourcesPct: 0.0,
        othersGb: 0.0,
        othersPct: 0.0,
        freeSpaceGb: 1023.99,
        freeSpacePct: 99.99,
      ),
      settings: RecordingSettings(
        autoRecording: false,
        cloudStorage: true,
        defaultRetentionDays: 180,
        recordingQuality: 'Full HD (1080p)',
        allowStudentDownload: true,
      ),
      analytics30Days: [
        AnalyticsDataPoint(date: '25 Nov', views: 1, downloads: 0),
      ],
    );
  }

  @override
  Future<Map<String, dynamic>> fetchRecordingsList({
    String? classId,
    String? subjectId,
    String? teacherId,
    String? search,
    String? status,
    int page = 1,
    int pageSize = 8,
    String sortBy = 'recorded_at',
    String sortOrder = 'desc',
  }) async {
    return {'items': <RecordingItem>[], 'total_count': 0, 'total_pages': 1};
  }

  @override
  Future<MyClassesDashboardData> fetchMyClassesDashboard(String dateFilter) async {
    return MyClassesDashboardData.fromJson({
      'my_classes_today': 0,
      'ongoing_live': simulateSessionLive ? 1 : 0,
      'upcoming': 0,
      'completed': 1,
      'total_students': 0,
      'teaching_duration_today': '0 h 0 min',
    });
  }

  @override
  Future<Map<String, dynamic>> fetchMyClassesList({
    String dateFilter = 'today',
    String? sessionName,
    String? classId,
    String? sectionId,
    String? subjectId,
    String? status,
    String? search,
    int page = 1,
    int pageSize = 5,
    String? sortBy,
    String? sortOrder,
  }) async {
    return {'items': <MyClassItem>[], 'total_count': 0, 'total_pages': 1};
  }
}

ConductClassSessionData _buildConductData(String id, {String recordingStatus = 'IDLE'}) {
  return ConductClassSessionData.fromJson({
    'active_session': {
      'id': id,
      'title': 'Organic Compounds – Live Class',
      'description': '',
      'class_name': 'Class 10',
      'section_name': '10-B',
      'class_section': 'Class 10 - 10-B',
      'subject': 'Mathematics',
      'subject_icon': 'calculate',
      'teacher_name': 'King Doe',
      'teacher_role': 'Super Admin',
      'duration_minutes': 45,
      'status': 'live',
      'is_live': true,
      'recording_status': recordingStatus,
      'recording_enabled': recordingStatus == 'RECORDING',
      'room_code': '10B-MATH',
      'meeting_link': '',
      'viewer_count': 1,
      'max_participants': 37,
      'date_str': '25 Nov 2026',
      'time_str': '02:00 PM',
      'recording_elapsed_str': '00:00:00',
    },
    'participants': <dynamic>[],
    'upcoming_classes': <dynamic>[],
    'questions': <dynamic>[],
    'breakout_rooms': <dynamic>[],
  });
}

class _ScenarioLiveClassNotifier extends LiveClassNotifier {
  _ScenarioLiveClassNotifier(super.api, LiveClassState init) {
    state = init;
  }

  @override
  Future<void> loadInitialData() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Live Recording All Scenarios Test Suite', () {
    setUp(() {
      InAppLiveRoomService.instance.setIsRecording(false);
    });

    test('ActiveLiveSession and MyClassDetails default to IDLE / not recording', () {
      final session = ActiveLiveSession.fromJson({'id': 's-1', 'title': 'Physics'});
      final details = MyClassDetails.fromJson({'id': 's-1', 'title': 'Physics'});

      expect(session.recordingStatus, equals('IDLE'));
      expect(session.recordingEnabled, isFalse);
      expect(details.recordingStatus, equals('IDLE'));
      expect(details.isRecording, isFalse);
    });

    test('startRecordingWithCapture sends explicit action=start even when DB had stale RECORDING', () async {
      final api = _ScenarioFakeApiService(serverRecordingStatus: 'RECORDING');
      final initState = LiveClassState(
        currentConductSessionId: 'sess-stale',
        conductSessionData: _buildConductData('sess-stale', recordingStatus: 'RECORDING'),
      );
      final notifier = _ScenarioLiveClassNotifier(api, initState);

      final res = await notifier.startRecordingWithCapture();

      expect(res['success'], isTrue);
      expect(res['is_recording'], isTrue);
      expect(api.toggleActions, equals(['start']));
      expect(InAppLiveRoomService.instance.isRecording, isTrue);

      final stopRes = await notifier.stopRecordingWithCapture(recordedDurationSeconds: 12);
      expect(stopRes['success'], isTrue);
      expect(stopRes['is_recording'], isFalse);
      expect(api.toggleActions, equals(['start', 'stop']));
      expect(InAppLiveRoomService.instance.isRecording, isFalse);
    });

    testWidgets(
      'Start Rec turns recording ON immediately and stays ON across Mic, Camera, and Whiteboard toggles',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final api = _ScenarioFakeApiService(serverRecordingStatus: 'IDLE');
        final initState = LiveClassState(
          currentConductSessionId: 'sess-live-rec',
          conductSessionData: _buildConductData('sess-live-rec', recordingStatus: 'IDLE'),
        );
        final wbNotifier = WhiteboardNotifier();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              liveClassApiServiceProvider.overrideWithValue(api),
              liveClassManagementProvider.overrideWith((ref) => _ScenarioLiveClassNotifier(api, initState)),
              whiteboardProvider.overrideWith((ref) => wbNotifier),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SizedBox(
                  width: 1100,
                  height: 700,
                  child: LiveClassroomStage(
                    session: initState.conductSessionData!.activeSession,
                    participants: const [],
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(seconds: 5));

        expect(find.text('Start Rec'), findsOneWidget);

        // 1. Tap Start Rec -> must start immediately and remain active (not immediately toggle back OFF)
        await tester.tap(find.text('Start Rec'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.textContaining('Rec 00:00:'), findsOneWidget);
        expect(api.toggleActions, equals(['start']));
        expect(InAppLiveRoomService.instance.isRecording, isTrue);

        // 2. Simulate Mic / Cam / Room updates firing during recording (must NOT stop recording)
        InAppLiveRoomService.instance.notifyListeners();
        await tester.pump(const Duration(seconds: 2));
        expect(find.textContaining('Rec 00:00:'), findsOneWidget);
        expect(InAppLiveRoomService.instance.isRecording, isTrue);

        // 3. Open Whiteboard mid-recording -> timer keeps ticking and recording remains active
        await tester.tap(find.text('Whiteboard'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.textContaining('Rec 00:00:'), findsOneWidget);
        expect(InAppLiveRoomService.instance.isRecording, isTrue);

        // 4. Open Recording Controls dialog & click Stop & Finalize Recording -> immediately resets to Start Rec
        await tester.tap(find.textContaining('Rec 00:00:'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Stop & Finalize Recording'), findsOneWidget);

        await tester.tap(find.text('Stop & Finalize Recording'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Start Rec'), findsOneWidget);
        expect(api.toggleActions, equals(['start', 'stop']));
        expect(InAppLiveRoomService.instance.isRecording, isFalse);

        // 5. Clicking End Class shows BOTH Leave Meeting (or Auto-End) AND End Meeting for All options
        await tester.tap(find.text('End Class'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Leave or End Live Class?'), findsOneWidget);
        expect(find.text('End Meeting for All'), findsOneWidget);
        expect(find.textContaining('Leave'), findsAtLeastNWidgets(1));
      },
    );

    test('trulyLiveSession ignores ended/recorded sessions, and leaveClass keeps live iff others remain', () async {
      final api = _ScenarioFakeApiService()..simulateOthersPresent = true..simulateSessionLive = true;
      final recordedDash = JoinConductDashboardData(
        liveNow: 0,
        todaysClasses: 1,
        totalParticipantsLive: 0,
        recordingInProgress: 0,
        avgClassDurationMin: 45,
        classQuality: 'Good',
        systemStatus: 'Online',
        activeSession: _buildConductData('sess-ended', recordingStatus: 'COMPLETED').activeSession,
        engagement: ClassEngagement(
          overallPercentage: 0,
          activeParticipantsPct: 0,
          interactionPct: 0,
          pollResponsePct: 0,
          contentViewPct: 0,
        ),
      );
      // Force status='recorded', isLive=false via ActiveLiveSession.fromJson
      final deadSess = ActiveLiveSession.fromJson({
        'id': 'sess-dead',
        'title': 'Old Ended Class',
        'status': 'recorded',
        'is_live': false,
      });
      final deadState = LiveClassState(
        joinConductData: JoinConductDashboardData(
          liveNow: 0,
          todaysClasses: 1,
          totalParticipantsLive: 0,
          recordingInProgress: 0,
          avgClassDurationMin: 45,
          classQuality: 'Good',
          systemStatus: 'Online',
          activeSession: deadSess,
          engagement: recordedDash.engagement,
        ),
      );
      expect(deadState.trulyLiveSession, isNull);

      // Host leaves while 1 student still in room -> auto_ended == false, session remains live
      final liveInit = LiveClassState(
        currentConductSessionId: 'sess-live-rec',
        conductSessionData: _buildConductData('sess-live-rec'),
        joinConductData: await api.fetchJoinConductDashboard(),
      );
      final notifier = _ScenarioLiveClassNotifier(api, liveInit);
      final leaveWithOthers = await notifier.leaveClass('sess-live-rec');
      expect(leaveWithOthers['auto_ended'], isFalse);
      expect(notifier.state.trulyLiveSession, isNotNull);

      // Last person leaves -> auto_ended == true, trulyLiveSession cleared cleanly
      api.simulateOthersPresent = false;
      final leaveEmpty = await notifier.leaveClass('sess-live-rec');
      expect(leaveEmpty['auto_ended'], isTrue);
      expect(notifier.state.trulyLiveSession, isNull);
    });
  });
}
