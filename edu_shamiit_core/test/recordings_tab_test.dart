import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_shamiit_core/screens/classes/models/class_models.dart';
import 'package:edu_shamiit_core/screens/classes/providers/class_provider.dart';
import 'package:edu_shamiit_core/screens/live_classes/models/live_class_models.dart';
import 'package:edu_shamiit_core/screens/live_classes/providers/live_class_management_provider.dart';
import 'package:edu_shamiit_core/screens/live_classes/services/live_class_api_service.dart';
import 'package:edu_shamiit_core/screens/live_classes/tabs/recordings_tab.dart';
import 'package:edu_shamiit_core/screens/live_classes/widgets/recording_edit_dialog.dart';
import 'package:edu_shamiit_core/screens/live_classes/widgets/recording_player_widget.dart';
import 'package:edu_shamiit_core/screens/live_classes/widgets/recording_share_dialog.dart';
import 'package:edu_shamiit_core/screens/live_classes/widgets/upload_recording_dialog.dart';

class _FakeLiveClassApiService extends LiveClassApiService {
  List<RecordingItem> storedRecordings;
  RecordingsDashboardData dashboard;
  bool deleteCalled = false;
  bool updateCalled = false;
  bool viewTracked = false;
  bool settingsSaved = false;

  _FakeLiveClassApiService({
    required this.storedRecordings,
    required this.dashboard,
  });

  @override
  Future<MetaDropdownsData> fetchMetaDropdowns() async {
    return MetaDropdownsData(
      classes: [ClassDropdownItem(id: 'cls-10', name: 'Class 10')],
      sections: [SectionDropdownItem(id: 'sec-10a', classId: 'cls-10', name: '10-A')],
      subjects: [SubjectDropdownItem(id: 'sub-math', name: 'Mathematics')],
      teachers: [TeacherDropdownItem(id: 't-1', fullName: 'King Doe')],
      sessions: [],
    );
  }

  @override
  Future<RecordingsDashboardData> fetchRecordingsDashboard() async => dashboard;

  @override
  Future<Map<String, dynamic>> fetchRecordingsList({
    String? classId,
    String? subjectId,
    String? teacherId,
    String? search,
    String? status,
    int page = 1,
    int pageSize = 8,
    String sortBy = 'created_at',
    String sortOrder = 'desc',
  }) async {
    var list = storedRecordings;
    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      list = list.where((r) => r.title.toLowerCase().contains(q)).toList();
    }
    return {
      'items': list,
      'total_count': list.length,
      'total_pages': 1,
      'page': page,
    };
  }

  @override
  Future<void> deleteRecording(String recordingId) async {
    deleteCalled = true;
    storedRecordings = storedRecordings.where((r) => r.id != recordingId).toList();
  }

  @override
  Future<Map<String, dynamic>> updateRecording(
    String recordingId,
    Map<String, dynamic> payload,
  ) async {
    updateCalled = true;
    storedRecordings = storedRecordings.map((r) {
      if (r.id == recordingId) {
        return r.copyWith(
          title: payload['title']?.toString(),
          visibility: payload['visibility']?.toString(),
          description: payload['description']?.toString(),
        );
      }
      return r;
    }).toList();
    return {'success': true};
  }

  @override
  Future<int?> recordRecordingView(String recordingId) async {
    viewTracked = true;
    return 42;
  }

  @override
  Future<bool> saveRecordingSettings(Map<String, dynamic> payload) async {
    settingsSaved = true;
    return true;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchShareDirectoryClasses() async {
    return [
      {
        'id': 'cls-10',
        'name': 'Class 10',
        'sections': [
          {'id': 'sec-10a', 'name': '10-A'},
          {'id': 'sec-10b', 'name': '10-B'},
        ],
      }
    ];
  }

  @override
  Future<Map<String, List<Map<String, dynamic>>>> fetchShareClassMembers({
    required String classId,
    List<String> sectionIds = const [],
  }) async {
    return {
      'students': [
        {'id': 'stu-1', 'full_name': 'Aarav Sharma', 'role': 'student', 'section_name': '10-A'},
      ],
      'teachers': [
        {'id': 'tea-1', 'full_name': 'King Doe', 'role': 'teacher', 'section_name': '10-A'},
      ],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> searchShareUsers({String query = '', String? role}) async {
    return [
      {'id': 'stu-1', 'full_name': 'Aarav Sharma', 'role': 'student', 'email': 'aarav@school.edu'},
      {'id': 'tea-1', 'full_name': 'King Doe', 'role': 'teacher', 'email': 'king@school.edu'},
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRecordingShares(String recordingId) async => [];

  @override
  Future<Map<String, dynamic>> shareRecordingBatch(String recordingId, Map<String, dynamic> payload) async {
    return {
      'success': true,
      'message': 'Shared successfully with class sections',
      'data': {'shared_count': 1, 'granted_member_count': 2},
    };
  }

  @override
  Future<String> resolveAuthenticatedMediaUrl(
    RecordingItem item, {
    bool isDownload = false,
  }) async {
    return 'http://localhost:8082/api/live-classes/recordings/${item.id}/${isDownload ? 'download' : 'stream'}?token=test-token';
  }
}

class _SeededLiveClassNotifier extends LiveClassNotifier {
  _SeededLiveClassNotifier(super.api, LiveClassState initial) {
    state = initial;
  }

  @override
  Future<void> loadInitialData() async {}
}

class _SeededClassNotifier extends ClassNotifier {
  _SeededClassNotifier(List<AcademicClassModel> classes) : super() {
    state = ClassState(classes: classes, allClasses: classes);
  }

  @override
  Future<void> fetchClasses({String? academicYear, int? page}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({'auth_token': 'test-token'});

  RecordingItem sampleRec({
    String id = 'rec-1',
    String title = 'Wave Optics Lecture 1',
    String visibility = 'CLASS',
    int views = 14,
  }) {
    return RecordingItem(
      id: id,
      liveClassId: 'lc-1',
      title: title,
      description: 'Complete physics lecture recording.',
      recordingUrl: '/api/live-classes/recordings/$id/stream',
      classId: 'cls-10',
      sectionId: 'sec-10a',
      subjectId: 'sub-math',
      classSection: 'Class 10 - 10-A',
      subjectName: 'Physics',
      teacherName: 'King Doe',
      dateTimeStr: '25 Nov 2026, 02:15 AM',
      durationStr: '15 min',
      durationSeconds: 900,
      views: views,
      downloadsCount: 4,
      fileSizeBytes: 24326963,
      sharedCount: 1,
      sizeStr: '23.2 MB',
      status: 'Processed',
      visibility: visibility,
      type: 'Uploaded Recording',
      tags: const ['upload', 'shared'],
    );
  }

  RecordingsDashboardData sampleDash() {
    return RecordingsDashboardData(
      totalRecordings: 3,
      thisWeek: 2,
      totalDurationDisplay: '1 h 25 min',
      storageUsedGb: 0.48,
      storageTotalTb: 1.0,
      storageUsedPercentage: 1,
      totalDownloads: 7,
      avgViews: 12,
      retentionRatePct: 100,
      storageBreakdown: StorageBreakdown(
        recordingsGb: 0.42,
        recordingsPct: 0.04,
        classResourcesGb: 0.05,
        classResourcesPct: 0.01,
        othersGb: 0.01,
        othersPct: 0.0,
        freeSpaceGb: 1023.52,
        freeSpacePct: 99.95,
      ),
      settings: RecordingSettings(
        autoRecording: true,
        cloudStorage: true,
        defaultRetentionDays: 180,
        recordingQuality: 'HD (720p)',
        allowStudentDownload: true,
      ),
      analytics30Days: [
        AnalyticsDataPoint(date: '20 Nov', views: 5, downloads: 2),
        AnalyticsDataPoint(date: '25 Nov', views: 12, downloads: 7),
      ],
    );
  }

  Widget wrapTab(_FakeLiveClassApiService fakeApi, LiveClassState initialState) {
    return ProviderScope(
      overrides: [
        liveClassApiServiceProvider.overrideWithValue(fakeApi),
        liveClassManagementProvider.overrideWith((ref) => _SeededLiveClassNotifier(fakeApi, initialState)),
      ],
      child: const MaterialApp(
        home: Scaffold(body: RecordingsTab()),
      ),
    );
  }

  group('Recordings Tab Full End-to-End Widget & Responsive Suite', () {
    testWidgets('Renders real DB KPIs instead of hardcoded placeholders and shows uploaded video player', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final rec = sampleRec();
      final fakeApi = _FakeLiveClassApiService(storedRecordings: [rec], dashboard: sampleDash());
      final initState = LiveClassState(
        recordingsData: sampleDash(),
        recordingsList: [rec],
        recordingsTotalCount: 1,
        recordingsTotalPages: 1,
        selectedRecordingForPreview: rec,
        dropdownsData: MetaDropdownsData(
          classes: [ClassDropdownItem(id: 'cls-10', name: 'Class 10')],
          sections: [SectionDropdownItem(id: 'sec-10a', classId: 'cls-10', name: '10-A')],
          subjects: [SubjectDropdownItem(id: 'sub-math', name: 'Physics')],
          teachers: [TeacherDropdownItem(id: 't-1', fullName: 'King Doe')],
          sessions: [],
        ),
      );

      await tester.pumpWidget(wrapTab(fakeApi, initState));
      await tester.pumpAndSettle();

      // Dynamic KPI values are displayed, NEVER legacy hardcoded values
      expect(find.text('1 h 25 min'), findsOneWidget);
      expect(find.text('0.48 GB'), findsAtLeastNWidgets(1));
      expect(find.text('362 h 14 min'), findsNothing);
      expect(find.text('728.4 GB'), findsNothing);

      // Real Player & Recording Actions present
      expect(find.byType(RecordingPlayerWidget), findsOneWidget);
      expect(find.text('Wave Optics Lecture 1'), findsAtLeastNWidgets(1));
      expect(find.text('Download'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('Responsive across Tablet (820px) and Mobile (390px) without overflow', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final rec = sampleRec();
      final fakeApi = _FakeLiveClassApiService(storedRecordings: [rec], dashboard: sampleDash());
      final initState = LiveClassState(
        recordingsData: sampleDash(),
        recordingsList: [rec],
        recordingsTotalCount: 1,
        recordingsTotalPages: 1,
        selectedRecordingForPreview: rec,
      );

      for (final size in [const Size(820, 1024), const Size(390, 844)]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(wrapTab(fakeApi, initState));
        await tester.pumpAndSettle();
        expect(find.byType(RecordingsTab), findsOneWidget);
      }
    });

    testWidgets('Edit button opens RecordingEditDialog and saves via API', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final rec = sampleRec();
      final fakeApi = _FakeLiveClassApiService(storedRecordings: [rec], dashboard: sampleDash());
      final initState = LiveClassState(
        recordingsData: sampleDash(),
        recordingsList: [rec],
        recordingsTotalCount: 1,
        recordingsTotalPages: 1,
        selectedRecordingForPreview: rec,
        dropdownsData: MetaDropdownsData(
          classes: [ClassDropdownItem(id: 'cls-10', name: 'Class 10')],
          sections: [SectionDropdownItem(id: 'sec-10a', classId: 'cls-10', name: '10-A')],
          subjects: [SubjectDropdownItem(id: 'sub-math', name: 'Physics')],
          teachers: [TeacherDropdownItem(id: 't-1', fullName: 'King Doe')],
          sessions: [],
        ),
      );

      await tester.pumpWidget(wrapTab(fakeApi, initState));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Edit'));
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      expect(find.byType(RecordingEditDialog), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, 'Wave Optics Updated Title');
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      expect(fakeApi.updateCalled, isTrue);
      expect(fakeApi.storedRecordings.first.title, 'Wave Optics Updated Title');
    });

    testWidgets('Share button opens RecordingShareDialog with Class & Sections + Search Individuals', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final rec = sampleRec();
      final fakeApi = _FakeLiveClassApiService(storedRecordings: [rec], dashboard: sampleDash());
      final initState = LiveClassState(
        recordingsData: sampleDash(),
        recordingsList: [rec],
        recordingsTotalCount: 1,
        recordingsTotalPages: 1,
        selectedRecordingForPreview: rec,
      );

      await tester.pumpWidget(wrapTab(fakeApi, initState));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.textContaining('Share ('));
      await tester.tap(find.textContaining('Share ('));
      await tester.pumpAndSettle();

      expect(find.byType(RecordingShareDialog), findsOneWidget);
      expect(find.text('Class & Sections'), findsOneWidget);
      expect(find.text('Search Individuals'), findsOneWidget);
      expect(find.text('Share Recording'), findsAtLeastNWidgets(1));
    });

    testWidgets('Delete button confirms and invokes real deleteRecording API', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final rec = sampleRec();
      final fakeApi = _FakeLiveClassApiService(storedRecordings: [rec], dashboard: sampleDash());
      final initState = LiveClassState(
        recordingsData: sampleDash(),
        recordingsList: [rec],
        recordingsTotalCount: 1,
        recordingsTotalPages: 1,
        selectedRecordingForPreview: rec,
      );

      await tester.pumpWidget(wrapTab(fakeApi, initState));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Delete'));
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Recording?'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      expect(fakeApi.deleteCalled, isTrue);
      expect(fakeApi.storedRecordings, isEmpty);
    });

    testWidgets('Upload Recording opens cleanly when Class Management classes merge with meta sections/classSubjects', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 960));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final rec = sampleRec();
      final fakeApi = _FakeLiveClassApiService(storedRecordings: [rec], dashboard: sampleDash());
      final cls10 = AcademicClassModel(
        id: 'cls-10',
        name: 'Class 10',
        code: 'C10',
        sections: [
          AcademicSectionModel.fromJson({'id': 'sec-10a', 'name': '10-A', 'class_id': 'cls-10'}),
        ],
        subjects: [
          AcademicSubjectModel.fromJson({'id': 'sub-math', 'name': 'Mathematics', 'code': 'MATH'}),
        ],
      );
      final initState = LiveClassState(
        recordingsData: sampleDash(),
        recordingsList: [rec],
        recordingsTotalCount: 1,
        recordingsTotalPages: 1,
        selectedRecordingForPreview: rec,
        dropdownsData: MetaDropdownsData(
          classes: [ClassDropdownItem(id: 'cls-10', name: 'Class 10')],
          sections: [
            SectionDropdownItem(id: 'sec-10a', classId: 'cls-10', name: '10-A'),
            SectionDropdownItem(id: 'sec-10b', classId: 'cls-10', name: '10-B'),
          ],
          subjects: [SubjectDropdownItem(id: 'sub-math', name: 'Mathematics')],
          teachers: [TeacherDropdownItem(id: 't-1', fullName: 'King Doe')],
          sessions: [],
          classSubjects: [
            ClassSubjectMapItem(
              classId: 'cls-10',
              subjectId: 'sub-phy',
              subjectName: 'Physics',
              subjectIcon: 'science',
            ),
          ],
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            liveClassApiServiceProvider.overrideWithValue(fakeApi),
            liveClassManagementProvider.overrideWith((ref) => _SeededLiveClassNotifier(fakeApi, initState)),
            classProvider.overrideWith((ref) => _SeededClassNotifier([cls10])),
          ],
          child: const MaterialApp(home: Scaffold(body: RecordingsTab())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Upload Recording'));
      await tester.pumpAndSettle();

      expect(find.byType(UploadRecordingDialog), findsOneWidget);
      expect(find.text('Upload Video Recording'), findsOneWidget);
      expect(find.text('Save & Publish Recording'), findsOneWidget);
      // Both merged sections & subjects must be present without TypeError
      expect(find.text('10-A'), findsAtLeastNWidgets(1));
      expect(find.text('Mathematics'), findsAtLeastNWidgets(1));
    });
  });
}
