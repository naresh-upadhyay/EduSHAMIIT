import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_class_models.dart';
import '../services/live_class_api_service.dart';
import '../services/in_app_live_room_service.dart';
import '../utils/live_class_recorder_helper.dart';

final liveClassApiServiceProvider = Provider<LiveClassApiService>((ref) {
  return LiveClassApiService();
});

/// Single Source of Truth for active live meeting participants across KPI cards,
/// stage header, video tiles, and the right-hand Participants list.
List<LiveKitParticipantTrack> resolveUnifiedParticipants({
  required InAppLiveRoomService roomService,
  required String localUserId,
  required String localUserName,
  required String localUserRole,
  List<LiveParticipant>? dbParticipants,
}) {
  final tracks = roomService.participantTracks.where((t) => !t.isScreenShare).toList();
  final localTrack = tracks.where((t) => t.isLocal).firstOrNull;
  final assignedLocalRole = roomService.customRoles[localUserId];
  final resolvedLocalRole = assignedLocalRole ?? (localUserRole.isNotEmpty ? localUserRole : 'Host');
  final resolvedLocalName = localUserName.trim().isNotEmpty ? localUserName.trim() : 'Host';

  final result = <LiveKitParticipantTrack>[
    LiveKitParticipantTrack(
      userId: localUserId.isNotEmpty ? localUserId : (localTrack?.userId ?? 'host'),
      name: resolvedLocalName,
      role: resolvedLocalRole,
      videoTrack: !roomService.isCamOff ? localTrack?.videoTrack : null,
      isLocal: true,
      isMicMuted: roomService.isMicMuted,
      isCamOff: roomService.isCamOff,
      isHandRaised: localTrack?.isHandRaised ?? false,
      isScreenShare: false,
      isSpeaking: !roomService.isMicMuted,
    ),
  ];

  bool alreadyPresent(String id, String name) {
    final normId = id.trim().toLowerCase();
    final normName = name.trim().toLowerCase();
    return result.any((e) =>
        (normId.isNotEmpty && e.userId.trim().toLowerCase() == normId) ||
        (normName.isNotEmpty && e.name.trim().toLowerCase() == normName));
  }

  // Merge real-time remote WebRTC participants
  for (final rt in tracks.where((t) => !t.isLocal)) {
    if (!alreadyPresent(rt.userId, rt.name)) {
      final assignedRole = roomService.customRoles[rt.userId];
      result.add(LiveKitParticipantTrack(
        userId: rt.userId,
        name: rt.name,
        role: assignedRole ?? rt.role,
        videoTrack: rt.videoTrack,
        isLocal: false,
        isMicMuted: rt.isMicMuted,
        isCamOff: rt.isCamOff,
        isHandRaised: rt.isHandRaised,
        isScreenShare: false,
        isSpeaking: rt.isSpeaking,
      ));
    }
  }

  // Merge active DB participants not already present in LiveKit tracks
  for (final p in dbParticipants ?? const <LiveParticipant>[]) {
    final effectiveUserId = p.userId.trim().isNotEmpty ? p.userId.trim() : p.id;
    if (!alreadyPresent(effectiveUserId, p.name) && !alreadyPresent(p.id, p.name)) {
      final assignedRole = roomService.customRoles[effectiveUserId] ?? roomService.customRoles[p.id];
      result.add(LiveKitParticipantTrack(
        userId: effectiveUserId,
        name: p.name,
        role: assignedRole ?? p.role,
        videoTrack: null,
        isLocal: false,
        isMicMuted: p.micMuted,
        isCamOff: p.camOff,
        isHandRaised: false,
        isScreenShare: false,
        isSpeaking: p.isSpeaking,
      ));
    }
  }

  return result;
}

/// Resolves targeted maximum capacity from DB session/schedule records.
int resolveTargetedMaxCapacity({
  ActiveLiveSession? activeSession,
  MyClassItem? selectedClass,
  MyClassDetails? selectedDetails,
  int activeCount = 1,
}) {
  final cap = (activeSession?.maxParticipants != null && activeSession!.maxParticipants > 0)
      ? activeSession.maxParticipants
      : ((selectedDetails?.maxParticipants != null && selectedDetails!.maxParticipants > 0)
          ? selectedDetails.maxParticipants
          : (selectedClass?.maxParticipants ?? 0));
  return cap > 0 ? math.max(cap, activeCount) : math.max(activeCount, 1);
}

class LiveClassState {
  final int selectedTabIndex; // 0 = Join & Conduct, 1 = Recordings, 2 = Attendance
  final bool isLoading;
  final String? errorMessage;

  final JoinConductDashboardData? joinConductData;
  final RecordingsDashboardData? recordingsData;
  final AttendanceDashboardData? attendanceData;
  final MetaDropdownsData? dropdownsData;

  // Recordings Tab state
  final List<RecordingItem> recordingsList;
  final int recordingsPage;
  final int recordingsPageSize;
  final String recordingsSortBy;
  final String recordingsSortOrder;
  final int recordingsTotalPages;
  final int recordingsTotalCount;
  final String? recordingClassFilter;
  final String? recordingSubjectFilter;
  final String? recordingTeacherFilter;
  final String? recordingStatusFilter;
  final String recordingSearchQuery;
  final RecordingItem? selectedRecordingForPreview;
  final AutoRecordingRuleSet autoRecordingRules;

  // Attendance Tab state
  final List<AttendanceItem> attendanceList;
  final int attendancePage;
  final int attendanceTotalPages;
  final int attendanceTotalCount;
  final Map<String, dynamic> attendanceCounts;
  final String? attendanceSessionFilter;
  final String? attendanceStatusFilter; // 'All', 'Present', 'Absent', 'Late', 'Not Joined'
  final String attendanceSearchQuery;
  final AttendanceItem? selectedStudentForTimeline;

  // My Classes Tab state (Matching Image 4)
  final List<String> academicSessions;
  final MyClassesDashboardData? myClassesDashboard;
  final List<MyClassItem> myClassesList;
  final MyClassItem? selectedMyClass;
  final MyClassDetails? selectedMyClassDetails;
  final String myClassesDateFilter; // 'Today', 'This Week', 'This Month'
  final String myClassesSessionFilter; // e.g. '2026 - 2027'
  final String? myClassesClassFilter;
  final String? myClassesSectionFilter;
  final String? myClassesSubjectFilter;
  final String myClassesStatusFilter; // 'All', 'Live', 'Upcoming', 'Completed', 'Scheduled'
  final String myClassesSearchQuery;
  final String myClassesSortBy; // 'scheduled_at', 'class_name', 'subject_name', 'title', 'status', 'viewer_count'
  final String myClassesSortOrder; // 'ASC', 'DESC'
  final int myClassesPage;
  final int myClassesPageSize;
  final int myClassesTotalCount;
  final int myClassesTotalPages;
  final Set<String> selectedMyClassIds;
  final List<SubjectDropdownItem> cascadingSubjects;

  // Join via Code & Guest Join state
  final List<RecentMeetingCodeItem> recentCodes;
  final List<GuestSessionItem> upcomingGuestSessions;
  final ValidatedMeetingInfo? validatedMeetingInfo;
  final bool isJoinCodeLoading;
  final String? joinCodeErrorMessage;
  final GuestJoinResponse? guestJoinResponse;
  final bool isGuestJoinLoading;
  final String? guestJoinErrorMessage;

  // Join Options (shared across Join via Code & Guest Join)
  final bool joinOptionCamera;
  final bool joinOptionMic;
  final bool joinOptionScreenShare;
  final bool joinOptionHandRaised;

  // Conduct Class state (Matching Image 1 & 6)
  final ConductClassSessionData? conductSessionData;
  final String? currentConductSessionId;
  final bool isConductLoading;
  final String? conductErrorMessage;
  final bool isWhiteboardActive;
  final bool isPollDialogActive;
  final bool isScreenSharing;

  LiveClassState({
    this.selectedTabIndex = 0,
    this.isLoading = false,
    this.errorMessage,
    this.joinConductData,
    this.recordingsData,
    this.attendanceData,
    this.dropdownsData,
    this.recordingsList = const [],
    this.recordingsPage = 1,
    this.recordingsPageSize = 8,
    this.recordingsSortBy = 'created_at',
    this.recordingsSortOrder = 'DESC',
    this.recordingsTotalPages = 1,
    this.recordingsTotalCount = 0,
    this.recordingClassFilter,
    this.recordingSubjectFilter,
    this.recordingTeacherFilter,
    this.recordingStatusFilter = 'All',
    this.recordingSearchQuery = '',
    this.selectedRecordingForPreview,
    this.attendanceList = const [],
    this.attendancePage = 1,
    this.attendanceTotalPages = 1,
    this.attendanceTotalCount = 0,
    this.attendanceCounts = const {},
    this.attendanceSessionFilter,
    this.attendanceStatusFilter = 'All',
    this.attendanceSearchQuery = '',
    this.selectedStudentForTimeline,
    this.academicSessions = const [],
    this.myClassesDashboard,
    this.myClassesList = const [],
    this.selectedMyClass,
    this.selectedMyClassDetails,
    this.myClassesDateFilter = 'Today',
    this.myClassesSessionFilter = '2026 - 2027',
    this.myClassesClassFilter,
    this.myClassesSectionFilter,
    this.myClassesSubjectFilter,
    this.myClassesStatusFilter = 'All',
    this.myClassesSearchQuery = '',
    this.myClassesSortBy = 'scheduled_at',
    this.myClassesSortOrder = 'DESC',
    this.myClassesPage = 1,
    this.myClassesPageSize = 5,
    this.myClassesTotalCount = 0,
    this.myClassesTotalPages = 1,
    this.selectedMyClassIds = const {},
    this.cascadingSubjects = const [],
    this.recentCodes = const [],
    this.upcomingGuestSessions = const [],
    this.validatedMeetingInfo,
    this.isJoinCodeLoading = false,
    this.joinCodeErrorMessage,
    this.guestJoinResponse,
    this.isGuestJoinLoading = false,
    this.guestJoinErrorMessage,
    this.joinOptionCamera = false,
    this.joinOptionMic = false,
    this.joinOptionScreenShare = false,
    this.joinOptionHandRaised = false,
    this.conductSessionData,
    this.currentConductSessionId,
    this.isConductLoading = false,
    this.conductErrorMessage,
    this.isWhiteboardActive = false,
    this.isPollDialogActive = false,
    this.isScreenSharing = false,
    AutoRecordingRuleSet? autoRecordingRules,
  }) : autoRecordingRules = autoRecordingRules ?? AutoRecordingRuleSet();

  // Convenience aliases for UI tabs
  JoinConductDashboardData? get joinDashboard => joinConductData;
  RecordingsDashboardData? get recordingsDashboard => recordingsData;
  AttendanceDashboardData? get attendanceDashboard => attendanceData;
  MetaDropdownsData? get dropdownMeta => dropdownsData;

  /// Only returns a session if it is genuinely live right now (never ended/recorded sessions).
  ActiveLiveSession? get trulyLiveSession {
    final candidate = conductSessionData?.activeSession ?? joinConductData?.activeSession;
    if (candidate == null) return null;
    final st = candidate.status.toLowerCase().trim();
    if (candidate.isLive || st == 'live' || st == 'ongoing') {
      return candidate;
    }
    return null;
  }
  List<RecordingItem> get recordings => recordingsList;
  List<MyClassItem> get myClasses => myClassesList;
  MyClassesDashboardData? get myDashboard => myClassesDashboard;

  LiveClassState copyWith({
    int? selectedTabIndex,
    bool? isLoading,
    String? errorMessage,
    JoinConductDashboardData? joinConductData,
    RecordingsDashboardData? recordingsData,
    AttendanceDashboardData? attendanceData,
    MetaDropdownsData? dropdownsData,
    List<RecordingItem>? recordingsList,
    int? recordingsPage,
    int? recordingsPageSize,
    String? recordingsSortBy,
    String? recordingsSortOrder,
    int? recordingsTotalPages,
    int? recordingsTotalCount,
    String? recordingClassFilter,
    String? recordingSubjectFilter,
    String? recordingTeacherFilter,
    String? recordingStatusFilter,
    String? recordingSearchQuery,
    RecordingItem? selectedRecordingForPreview,
    bool clearRecordingClassFilter = false,
    bool clearRecordingSubjectFilter = false,
    bool clearRecordingTeacherFilter = false,
    bool clearSelectedRecording = false,
    AutoRecordingRuleSet? autoRecordingRules,
    List<AttendanceItem>? attendanceList,
    int? attendancePage,
    int? attendanceTotalPages,
    int? attendanceTotalCount,
    Map<String, dynamic>? attendanceCounts,
    String? attendanceSessionFilter,
    String? attendanceStatusFilter,
    String? attendanceSearchQuery,
    AttendanceItem? selectedStudentForTimeline,
    List<String>? academicSessions,
    MyClassesDashboardData? myClassesDashboard,
    List<MyClassItem>? myClassesList,
    MyClassItem? selectedMyClass,
    MyClassDetails? selectedMyClassDetails,
    String? myClassesDateFilter,
    String? myClassesSessionFilter,
    String? myClassesClassFilter,
    String? myClassesSectionFilter,
    String? myClassesSubjectFilter,
    String? myClassesStatusFilter,
    String? myClassesSearchQuery,
    String? myClassesSortBy,
    String? myClassesSortOrder,
    int? myClassesPage,
    int? myClassesPageSize,
    int? myClassesTotalCount,
    int? myClassesTotalPages,
    Set<String>? selectedMyClassIds,
    List<SubjectDropdownItem>? cascadingSubjects,
    bool clearMyClassesSelection = false,
    List<RecentMeetingCodeItem>? recentCodes,
    List<GuestSessionItem>? upcomingGuestSessions,
    ValidatedMeetingInfo? validatedMeetingInfo,
    bool? isJoinCodeLoading,
    String? joinCodeErrorMessage,
    GuestJoinResponse? guestJoinResponse,
    bool? isGuestJoinLoading,
    String? guestJoinErrorMessage,
    bool? joinOptionCamera,
    bool? joinOptionMic,
    bool? joinOptionScreenShare,
    bool? joinOptionHandRaised,
    ConductClassSessionData? conductSessionData,
    String? currentConductSessionId,
    bool? isConductLoading,
    String? conductErrorMessage,
    bool? isWhiteboardActive,
    bool? isPollDialogActive,
    bool? isScreenSharing,
    bool clearSelectedMyClass = false,
    bool clearConductSession = false,
    bool clearJoinActiveSession = false,
  }) {
    final nextJoinConduct = clearJoinActiveSession && (joinConductData != null || this.joinConductData != null)
        ? (() {
            final base = joinConductData ?? this.joinConductData!;
            return JoinConductDashboardData(
              liveNow: 0,
              todaysClasses: base.todaysClasses,
              totalParticipantsLive: 0,
              recordingInProgress: 0,
              avgClassDurationMin: base.avgClassDurationMin,
              classQuality: base.classQuality,
              systemStatus: base.systemStatus,
              activeSession: null,
              participants: const [],
              upcomingClasses: base.upcomingClasses,
              engagement: base.engagement,
            );
          })()
        : (joinConductData ?? this.joinConductData);
    return LiveClassState(
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      joinConductData: nextJoinConduct,
      recordingsData: recordingsData ?? this.recordingsData,
      attendanceData: attendanceData ?? this.attendanceData,
      dropdownsData: dropdownsData ?? this.dropdownsData,
      recordingsList: recordingsList ?? this.recordingsList,
      recordingsPage: recordingsPage ?? this.recordingsPage,
      recordingsPageSize: recordingsPageSize ?? this.recordingsPageSize,
      recordingsSortBy: recordingsSortBy ?? this.recordingsSortBy,
      recordingsSortOrder: recordingsSortOrder ?? this.recordingsSortOrder,
      recordingsTotalPages: recordingsTotalPages ?? this.recordingsTotalPages,
      recordingsTotalCount: recordingsTotalCount ?? this.recordingsTotalCount,
      recordingClassFilter: clearRecordingClassFilter ? null : (recordingClassFilter ?? this.recordingClassFilter),
      recordingSubjectFilter: clearRecordingSubjectFilter ? null : (recordingSubjectFilter ?? this.recordingSubjectFilter),
      recordingTeacherFilter: clearRecordingTeacherFilter ? null : (recordingTeacherFilter ?? this.recordingTeacherFilter),
      recordingStatusFilter: recordingStatusFilter ?? this.recordingStatusFilter,
      recordingSearchQuery: recordingSearchQuery ?? this.recordingSearchQuery,
      selectedRecordingForPreview: clearSelectedRecording ? null : (selectedRecordingForPreview ?? this.selectedRecordingForPreview),
      autoRecordingRules: autoRecordingRules ?? this.autoRecordingRules,
      attendanceList: attendanceList ?? this.attendanceList,
      attendancePage: attendancePage ?? this.attendancePage,
      attendanceTotalPages: attendanceTotalPages ?? this.attendanceTotalPages,
      attendanceTotalCount: attendanceTotalCount ?? this.attendanceTotalCount,
      attendanceCounts: attendanceCounts ?? this.attendanceCounts,
      attendanceSessionFilter: attendanceSessionFilter ?? this.attendanceSessionFilter,
      attendanceStatusFilter: attendanceStatusFilter ?? this.attendanceStatusFilter,
      attendanceSearchQuery: attendanceSearchQuery ?? this.attendanceSearchQuery,
      selectedStudentForTimeline: selectedStudentForTimeline ?? this.selectedStudentForTimeline,
      academicSessions: academicSessions ?? this.academicSessions,
      myClassesDashboard: myClassesDashboard ?? this.myClassesDashboard,
      myClassesList: myClassesList ?? this.myClassesList,
      selectedMyClass: clearSelectedMyClass ? null : (selectedMyClass ?? this.selectedMyClass),
      selectedMyClassDetails: clearSelectedMyClass ? null : (selectedMyClassDetails ?? this.selectedMyClassDetails),
      myClassesDateFilter: myClassesDateFilter ?? this.myClassesDateFilter,
      myClassesSessionFilter: myClassesSessionFilter ?? this.myClassesSessionFilter,
      myClassesClassFilter: myClassesClassFilter ?? this.myClassesClassFilter,
      myClassesSectionFilter: myClassesSectionFilter ?? this.myClassesSectionFilter,
      myClassesSubjectFilter: myClassesSubjectFilter ?? this.myClassesSubjectFilter,
      myClassesStatusFilter: myClassesStatusFilter ?? this.myClassesStatusFilter,
      myClassesSearchQuery: myClassesSearchQuery ?? this.myClassesSearchQuery,
      myClassesSortBy: myClassesSortBy ?? this.myClassesSortBy,
      myClassesSortOrder: myClassesSortOrder ?? this.myClassesSortOrder,
      myClassesPage: myClassesPage ?? this.myClassesPage,
      myClassesPageSize: myClassesPageSize ?? this.myClassesPageSize,
      myClassesTotalCount: myClassesTotalCount ?? this.myClassesTotalCount,
      myClassesTotalPages: myClassesTotalPages ?? this.myClassesTotalPages,
      selectedMyClassIds: clearMyClassesSelection ? const {} : (selectedMyClassIds ?? this.selectedMyClassIds),
      cascadingSubjects: cascadingSubjects ?? this.cascadingSubjects,
      recentCodes: recentCodes ?? this.recentCodes,
      upcomingGuestSessions: upcomingGuestSessions ?? this.upcomingGuestSessions,
      validatedMeetingInfo: validatedMeetingInfo ?? this.validatedMeetingInfo,
      isJoinCodeLoading: isJoinCodeLoading ?? this.isJoinCodeLoading,
      joinCodeErrorMessage: joinCodeErrorMessage,
      guestJoinResponse: guestJoinResponse ?? this.guestJoinResponse,
      isGuestJoinLoading: isGuestJoinLoading ?? this.isGuestJoinLoading,
      guestJoinErrorMessage: guestJoinErrorMessage,
      joinOptionCamera: joinOptionCamera ?? this.joinOptionCamera,
      joinOptionMic: joinOptionMic ?? this.joinOptionMic,
      joinOptionScreenShare: joinOptionScreenShare ?? this.joinOptionScreenShare,
      joinOptionHandRaised: joinOptionHandRaised ?? this.joinOptionHandRaised,
      conductSessionData: clearConductSession ? null : (conductSessionData ?? this.conductSessionData),
      currentConductSessionId: clearConductSession ? null : (currentConductSessionId ?? this.currentConductSessionId),
      isConductLoading: isConductLoading ?? this.isConductLoading,
      conductErrorMessage: conductErrorMessage,
      isWhiteboardActive: isWhiteboardActive ?? this.isWhiteboardActive,
      isPollDialogActive: isPollDialogActive ?? this.isPollDialogActive,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
    );
  }
}

class LiveClassNotifier extends StateNotifier<LiveClassState> {
  final LiveClassApiService _api;
  bool _isCreatingPoll = false;
  DateTime? _lastPollLaunchTime;
  String? _lastPollQuestion;

  LiveClassNotifier(this._api) : super(LiveClassState(isLoading: true)) {
    loadInitialData();
  }

    Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final dropdowns = await _api.fetchMetaDropdowns();
      final academicSessions = await _api.fetchAcademicSessions();
      final currentFY = LiveClassApiService.resolveCurrentFinancialYear(academicSessions);

      final joinConduct = await _api.fetchJoinConductDashboard();
      final recordingsDash = await _api.fetchRecordingsDashboard();

      final recsListRes = await _api.fetchRecordingsList(page: 1, pageSize: 8);
      final myClassesDash = await _api.fetchMyClassesDashboard('today');
      final myClassesRes = await _api.fetchMyClassesList(dateFilter: 'today', sessionName: currentFY, page: 1, pageSize: 5);
      final recentCodes = await _api.fetchRecentMeetingCodes();
      final upcomingGuestSessions = await _api.fetchUpcomingGuestSessions();

      final recs = (recsListRes['items'] as List<RecordingItem>?) ?? [];
      final myClasses = (myClassesRes['items'] as List<MyClassItem>?) ?? [];
      final firstMyClass = myClasses.isNotEmpty ? myClasses.first : null;
      MyClassDetails? initialDetails;
      if (firstMyClass != null) {
        initialDetails = await _api.fetchSessionDetails(firstMyClass.id);
      }
      final conductData = await _api.fetchConductSessionData(firstMyClass?.id);

      state = state.copyWith(
        isLoading: false,
        dropdownsData: dropdowns,
        academicSessions: academicSessions,
        myClassesSessionFilter: currentFY,
        joinConductData: joinConduct,
        recordingsData: recordingsDash,
        recordingsList: recs,
        recordingsTotalCount: recsListRes['total_count'] ?? recs.length,
        recordingsTotalPages: recsListRes['total_pages'] ?? 1,
        selectedRecordingForPreview: recs.isNotEmpty ? recs.first : null,
        myClassesDashboard: myClassesDash,
        myClassesList: myClasses,
        selectedMyClass: firstMyClass,
        selectedMyClassDetails: initialDetails,
        clearSelectedMyClass: firstMyClass == null,
        myClassesTotalCount: myClassesRes['total_count'] ?? myClasses.length,
        recentCodes: recentCodes,
        upcomingGuestSessions: upcomingGuestSessions,
        conductSessionData: conductData,
        currentConductSessionId: conductData?.activeSession.id ?? firstMyClass?.id,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void switchTab(int index) {
    if (index == state.selectedTabIndex) return;
    state = state.copyWith(selectedTabIndex: index);
    if (index == 0) {
      refreshJoinConduct();
    } else if (index == 1) {
      refreshRecordings();
    }
  }

  Future<void> refreshJoinConduct() async {
    try {
      final data = await _api.fetchJoinConductDashboard();
      state = state.copyWith(joinConductData: data);
    } catch (_) {}
  }

  Future<void> refreshRecordings({String? selectRecordingId}) async {
    try {
      final dash = await _api.fetchRecordingsDashboard();
      final recsRes = await _api.fetchRecordingsList(
        classId: state.recordingClassFilter,
        subjectId: state.recordingSubjectFilter,
        teacherId: state.recordingTeacherFilter,
        status: state.recordingStatusFilter,
        search: state.recordingSearchQuery,
        page: state.recordingsPage,
        pageSize: state.recordingsPageSize,
        sortBy: state.recordingsSortBy,
        sortOrder: state.recordingsSortOrder,
      );
      final recs = (recsRes['items'] as List<RecordingItem>?) ?? [];
      RecordingItem? nextSelected;
      if (selectRecordingId != null && selectRecordingId.isNotEmpty) {
        nextSelected = recs.where((r) => r.id == selectRecordingId).firstOrNull;
      }
      nextSelected ??= state.selectedRecordingForPreview != null
          ? recs.where((r) => r.id == state.selectedRecordingForPreview!.id).firstOrNull
          : null;
      nextSelected ??= recs.isNotEmpty ? recs.first : null;

      state = state.copyWith(
        recordingsData: dash,
        recordingsList: recs,
        recordingsTotalCount: recsRes['total_count'] ?? recs.length,
        recordingsTotalPages: recsRes['total_pages'] ?? 1,
        selectedRecordingForPreview: nextSelected,
        clearSelectedRecording: nextSelected == null,
      );
    } catch (_) {}
  }

  Future<void> refreshAttendance() async {
    try {
      final dash = await _api.fetchAttendanceDashboard(sessionId: state.attendanceSessionFilter);
      final attRes = await _api.fetchAttendanceList(
        sessionId: state.attendanceSessionFilter,
        statusFilter: state.attendanceStatusFilter,
        search: state.attendanceSearchQuery,
        page: state.attendancePage,
        pageSize: 10,
      );
      final atts = (attRes['items'] as List<AttendanceItem>?) ?? [];
      state = state.copyWith(
        attendanceData: dash,
        attendanceList: atts,
        attendanceTotalCount: attRes['total_count'] ?? atts.length,
        attendanceTotalPages: attRes['total_pages'] ?? 1,
        attendanceCounts: attRes['counts'] ?? {},
      );
    } catch (_) {}
  }

  // Recordings filter & pagination setters
  void setRecordingsClassFilter(String? classId) {
    state = state.copyWith(
      recordingClassFilter: classId,
      clearRecordingClassFilter: classId == null,
      recordingsPage: 1,
    );
    refreshRecordings();
  }

  void setRecordingsSubjectFilter(String? subjectId) {
    state = state.copyWith(
      recordingSubjectFilter: subjectId,
      clearRecordingSubjectFilter: subjectId == null,
      recordingsPage: 1,
    );
    refreshRecordings();
  }

  void setRecordingsTeacherFilter(String? teacherId) {
    state = state.copyWith(
      recordingTeacherFilter: teacherId,
      clearRecordingTeacherFilter: teacherId == null,
      recordingsPage: 1,
    );
    refreshRecordings();
  }

  void setRecordingsSearch(String query) {
    state = state.copyWith(recordingSearchQuery: query, recordingsPage: 1);
    refreshRecordings();
  }

  void setRecordingsPage(int page) {
    state = state.copyWith(recordingsPage: page);
    refreshRecordings();
  }

  void setRecordingsPageSize(int pageSize) {
    state = state.copyWith(recordingsPageSize: pageSize, recordingsPage: 1);
    refreshRecordings();
  }

  void toggleRecordingsSort(String columnKey) {
    final isSame = state.recordingsSortBy == columnKey;
    final nextOrder = isSame ? (state.recordingsSortOrder == 'ASC' ? 'DESC' : 'ASC') : 'ASC';
    state = state.copyWith(
      recordingsSortBy: columnKey,
      recordingsSortOrder: nextOrder,
      recordingsPage: 1,
    );
    refreshRecordings();
  }

  void selectRecordingForPreview(RecordingItem item) {
    state = state.copyWith(selectedRecordingForPreview: item);
  }

  // Attendance filter & pagination setters
  void setAttendanceSessionFilter(String? sessionId) {
    state = state.copyWith(attendanceSessionFilter: sessionId, attendancePage: 1);
    refreshAttendance();
  }

  void setAttendanceStatusFilter(String? statusFilter) {
    state = state.copyWith(attendanceStatusFilter: statusFilter, attendancePage: 1);
    refreshAttendance();
  }

  void setAttendanceSearch(String query) {
    state = state.copyWith(attendanceSearchQuery: query, attendancePage: 1);
    refreshAttendance();
  }

  void setAttendancePage(int page) {
    state = state.copyWith(attendancePage: page);
    refreshAttendance();
  }

  // Action methods
  Future<void> createInstantClass(Map<String, dynamic> payload) async {
    await _api.createInstantClass(payload);
    await refreshJoinConduct();
  }

  Future<void> startClass(String sessionId) async {
    await _api.startLiveClass(sessionId);
    await refreshJoinConduct();
  }

  Future<void> endClass(String sessionId) async {
    if (LiveClassBrowserRecorder.instance.isRecording) {
      try {
        final capture = await LiveClassBrowserRecorder.instance.stopAndCollect();
        if (capture.bytes != null && capture.bytes!.isNotEmpty) {
          await uploadRecordedLiveClassBytes(
            sessionId: sessionId,
            bytes: capture.bytes!,
            fileName: capture.fileName,
            durationSeconds: capture.durationSeconds,
          );
        }
      } catch (e) {
        debugPrint('[LiveClassNotifier] endClass finalize recording error: $e');
      }
    }
    InAppLiveRoomService.instance.setIsRecording(false);
    try {
      await InAppLiveRoomService.instance.leaveRoom();
    } catch (_) {}
    // Clear live stage & active banner immediately before awaiting backend refresh
    state = state.copyWith(
      clearConductSession: true,
      clearSelectedMyClass: true,
      clearJoinActiveSession: true,
    );
    await _api.endLiveClass(sessionId);
    await refreshJoinConduct();
    await refreshRecordings();
    await refreshAttendance();
    await refreshMyClasses();
  }

  void addLiveMeetingRecording({
    required String sessionId,
    required String title,
    required String classSection,
    required String subject,
    required String teacherName,
    int durationSeconds = 1800,
  }) {
    final now = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final mName = (now.month >= 1 && now.month <= 12) ? months[now.month - 1] : 'Nov';
    final hourStr = now.hour > 12 ? (now.hour - 12).toString().padLeft(2, '0') : (now.hour == 0 ? '12' : now.hour.toString().padLeft(2, '0'));
    final amPm = now.hour >= 12 ? 'PM' : 'AM';
    final dateStr = '${now.day} $mName ${now.year}, $hourStr:${now.minute.toString().padLeft(2, '0')} $amPm';

    final durationMins = math.max(1, (durationSeconds / 60).round());
    final sizeMb = (durationMins * 6.2).clamp(45, 1200).toInt();

    final newRec = RecordingItem(
      id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
      liveClassId: sessionId,
      title: title.isNotEmpty ? '$title Recording' : 'Live Class Recording',
      description: 'Captured & finalized live meeting recording with interactive whiteboard & slides sync.',
      recordingUrl: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
      classSection: classSection.isNotEmpty ? classSection : 'Class 10 - 10-A',
      subjectName: subject.isNotEmpty ? subject : 'Computer Science',
      teacherName: teacherName.isNotEmpty ? teacherName : 'Teacher',
      dateTimeStr: dateStr,
      durationStr: '$durationMins min',
      durationSeconds: durationSeconds,
      views: 0,
      sizeStr: '$sizeMb MB',
      status: 'Processed',
      visibility: 'CLASS',
    );

    final updated = [newRec, ...state.recordingsList];
    state = state.copyWith(
      recordingsList: updated,
      selectedRecordingForPreview: newRec,
      recordingsTotalCount: state.recordingsTotalCount + 1,
    );
  }

  Future<Map<String, dynamic>> leaveClass(String sessionId) async {
    if (LiveClassBrowserRecorder.instance.isRecording) {
      try {
        final capture = await LiveClassBrowserRecorder.instance.stopAndCollect();
        if (capture.bytes != null && capture.bytes!.isNotEmpty) {
          await uploadRecordedLiveClassBytes(
            sessionId: sessionId,
            bytes: capture.bytes!,
            fileName: capture.fileName,
            durationSeconds: capture.durationSeconds,
          );
        }
      } catch (e) {
        debugPrint('[LiveClassNotifier] leaveClass recording finalize notice: $e');
      }
    }
    InAppLiveRoomService.instance.setIsRecording(false);
    try {
      await InAppLiveRoomService.instance.leaveRoom();
    } catch (_) {}
    final res = await _api.leaveLiveClass(sessionId);
    final autoEnded = res['auto_ended'] == true;
    state = state.copyWith(
      clearConductSession: true,
      clearSelectedMyClass: true,
      clearJoinActiveSession: autoEnded,
    );
    await refreshJoinConduct();
    await refreshMyClasses();
    return res;
  }

  void clearActiveSession() {
    state = state.copyWith(clearConductSession: true, clearSelectedMyClass: true);
  }

  Future<void> overrideAttendance(String attendanceId, String newStatus, String reason) async {
    await _api.overrideAttendance(attendanceId, newStatus, reason);
    await refreshAttendance();
  }

  Future<void> recalculateAttendance(String sessionId) async {
    await _api.recalculateAttendance(sessionId);
    await refreshAttendance();
  }

  Future<void> shareRecording(String recordingId, String sharedToId) async {
    await _api.shareRecording(recordingId, sharedToId);
    await refreshRecordings(selectRecordingId: recordingId);
  }

  Future<bool> updateRecording(
    String recordingId,
    Map<String, dynamic> payload,
  ) async {
    try {
      await _api.updateRecording(recordingId, payload);
      await refreshRecordings(selectRecordingId: recordingId);
      return true;
    } catch (e) {
      debugPrint('[LiveClassProvider] updateRecording error: $e');
      return false;
    }
  }

  Future<bool> deleteRecording(String recordingId) async {
    try {
      await _api.deleteRecording(recordingId);
      final remaining = state.recordingsList.where((r) => r.id != recordingId).toList();
      final wasSelected = state.selectedRecordingForPreview?.id == recordingId;
      state = state.copyWith(
        recordingsList: remaining,
        selectedRecordingForPreview: wasSelected ? (remaining.isNotEmpty ? remaining.first : null) : state.selectedRecordingForPreview,
        clearSelectedRecording: wasSelected && remaining.isEmpty,
      );
      await refreshRecordings();
      return true;
    } catch (e) {
      debugPrint('[LiveClassProvider] deleteRecording error: $e');
      return false;
    }
  }

  Future<int> bulkDeleteRecordings(List<String> recordingIds) async {
    if (recordingIds.isEmpty) return 0;
    try {
      final res = await _api.bulkDeleteRecordings(recordingIds);
      await refreshRecordings();
      return (res['deleted_count'] as num?)?.toInt() ?? recordingIds.length;
    } catch (e) {
      debugPrint('[LiveClassProvider] bulkDeleteRecordings error: $e');
      return 0;
    }
  }

  Future<void> trackRecordingView(String recordingId) async {
    final nextViews = await _api.recordRecordingView(recordingId);
    if (nextViews != null) {
      final updatedList = state.recordingsList.map((r) {
        if (r.id == recordingId) {
          return r.copyWith(views: nextViews);
        }
        return r;
      }).toList();
      final sel = state.selectedRecordingForPreview;
      state = state.copyWith(
        recordingsList: updatedList,
        selectedRecordingForPreview: sel != null && sel.id == recordingId ? sel.copyWith(views: nextViews) : sel,
      );
    }
    try {
      final dash = await _api.fetchRecordingsDashboard();
      state = state.copyWith(recordingsData: dash);
    } catch (_) {}
  }

  Future<bool> saveRecordingSettings({
    required bool autoRecording,
    required bool cloudStorage,
    required int defaultRetentionDays,
    required String recordingQuality,
    required bool allowStudentDownload,
  }) async {
    final ok = await _api.saveRecordingSettings({
      'auto_recording': autoRecording,
      'cloud_storage': cloudStorage,
      'default_retention_days': defaultRetentionDays,
      'recording_quality': recordingQuality,
      'allow_student_download': allowStudentDownload,
    });
    if (ok) {
      await refreshRecordings();
    }
    return ok;
  }

  void updateAutoRecordingRules(AutoRecordingRuleSet newRules) {
    state = state.copyWith(autoRecordingRules: newRules);
  }

  Future<bool> uploadRecording({
    required String title,
    required String classId,
    String? sectionId,
    required String classSection,
    required String subjectId,
    required String subjectName,
    String? teacherId,
    required String teacherName,
    required int durationMinutes,
    int? durationSeconds,
    required double fileSizeMb,
    List<int>? fileBytes,
    String? fileName,
    String? videoUrl,
    String? description,
    String visibility = 'CLASS',
  }) async {
    try {
      final res = await _api.uploadRecordingFile(
        fileBytes: fileBytes,
        fileName: fileName,
        title: title,
        description: description,
        classId: classId,
        sectionId: sectionId,
        subjectId: subjectId,
        teacherId: teacherId,
        teacherName: teacherName,
        durationMinutes: durationMinutes,
        durationSeconds: durationSeconds,
        visibility: visibility,
        externalUrl: videoUrl,
      );
      final data = res['data'];
      final newId = data is Map ? data['id']?.toString() : null;
      await refreshRecordings(selectRecordingId: newId);
      return res['success'] == true || newId != null;
    } catch (e) {
      debugPrint('[LiveClassProvider] uploadRecording error: $e');
      return false;
    }
  }

  // ============================================================================
  // MY CLASSES ACTIONS & SETTERS
  // ============================================================================

  Future<void> refreshMyClasses() async {
    try {
      final dash = await _api.fetchMyClassesDashboard(state.myClassesDateFilter);
      final listRes = await _api.fetchMyClassesList(
        dateFilter: state.myClassesDateFilter.toLowerCase(),
        sessionName: state.myClassesSessionFilter,
        classId: state.myClassesClassFilter,
        sectionId: state.myClassesSectionFilter,
        subjectId: state.myClassesSubjectFilter,
        status: state.myClassesStatusFilter,
        search: state.myClassesSearchQuery,
        sortBy: state.myClassesSortBy,
        sortOrder: state.myClassesSortOrder,
        page: state.myClassesPage,
        pageSize: state.myClassesPageSize,
      );
      final items = (listRes['items'] as List<MyClassItem>?) ?? [];
      final firstItem = items.isNotEmpty
          ? (state.selectedMyClass != null && items.any((e) => e.id == state.selectedMyClass!.id)
              ? items.firstWhere((e) => e.id == state.selectedMyClass!.id)
              : items.first)
          : null;
      MyClassDetails? details;
      if (firstItem != null) {
        details = await _api.fetchSessionDetails(firstItem.id);
      }

      state = state.copyWith(
        myClassesDashboard: dash,
        myClassesList: items,
        selectedMyClass: firstItem,
        selectedMyClassDetails: details,
        clearSelectedMyClass: firstItem == null,
        myClassesTotalCount: listRes['total_count'] ?? items.length,
        myClassesTotalPages: listRes['total_pages'] ?? 1,
      );
    } catch (e) {
      debugPrint('[LiveClassNotifier] Error refreshing my classes: $e');
    }
  }

  void setMyClassesDateFilter(String filter) {
    state = state.copyWith(myClassesDateFilter: filter, myClassesPage: 1);
    refreshMyClasses();
  }

  void setMyClassesSessionFilter(String session) {
    state = state.copyWith(myClassesSessionFilter: session, myClassesPage: 1);
    refreshMyClasses();
  }

  Future<void> setMyClassesClassFilter(String? classId) async {
    // When class changes, clear section & subject filters to prevent stale mismatch
    state = state.copyWith(
      myClassesClassFilter: classId,
      myClassesSectionFilter: null,
      myClassesSubjectFilter: null,
      myClassesPage: 1,
    );
    if (classId != null && classId.isNotEmpty && classId != 'All Classes') {
      await loadCascadingSubjects(classId);
    } else {
      state = state.copyWith(cascadingSubjects: const []);
    }
    refreshMyClasses();
  }

  Future<void> setMyClassesSectionFilter(String? sectionId) async {
    // When section changes, clear subject filter
    state = state.copyWith(
      myClassesSectionFilter: sectionId,
      myClassesSubjectFilter: null,
      myClassesPage: 1,
    );
    if (state.myClassesClassFilter != null && state.myClassesClassFilter!.isNotEmpty) {
      await loadCascadingSubjects(state.myClassesClassFilter!, sectionId: sectionId);
    }
    refreshMyClasses();
  }

  Future<void> loadCascadingSubjects(String classId, {String? sectionId}) async {
    try {
      final subs = await _api.fetchCascadingSubjects(classId, sectionId: sectionId);
      state = state.copyWith(cascadingSubjects: subs);
    } catch (e) {
      debugPrint('[LiveClassNotifier] Error loading cascading subjects: $e');
    }
  }

  void setMyClassesSubjectFilter(String? subjectId) {
    state = state.copyWith(myClassesSubjectFilter: subjectId, myClassesPage: 1);
    refreshMyClasses();
  }

  void setMyClassesStatusFilter(String status) {
    state = state.copyWith(myClassesStatusFilter: status, myClassesPage: 1);
    refreshMyClasses();
  }

  void searchMyClasses(String query) {
    state = state.copyWith(myClassesSearchQuery: query, myClassesPage: 1);
    refreshMyClasses();
  }

  void setMyClassesSort(String sortBy, {String? sortOrder}) {
    String order = sortOrder ?? 'ASC';
    if (sortOrder == null && state.myClassesSortBy == sortBy) {
      order = state.myClassesSortOrder == 'ASC' ? 'DESC' : 'ASC';
    } else if (sortOrder == null) {
      order = (sortBy == 'scheduled_at' ? 'DESC' : 'ASC');
    }
    state = state.copyWith(
      myClassesSortBy: sortBy,
      myClassesSortOrder: order,
      myClassesPage: 1,
    );
    refreshMyClasses();
  }

  void setMyClassesPage(int page) {
    if (page < 1) page = 1;
    if (page > state.myClassesTotalPages && state.myClassesTotalPages > 0) {
      page = state.myClassesTotalPages;
    }
    state = state.copyWith(myClassesPage: page);
    refreshMyClasses();
  }

  void setMyClassesPageSize(int pageSize) {
    state = state.copyWith(myClassesPageSize: pageSize, myClassesPage: 1);
    refreshMyClasses();
  }

  void toggleSelectMyClassId(String id) {
    final updated = Set<String>.from(state.selectedMyClassIds);
    if (updated.contains(id)) {
      updated.remove(id);
    } else {
      updated.add(id);
    }
    state = state.copyWith(selectedMyClassIds: updated);
  }

  void selectAllMyClasses(bool selectAll) {
    if (selectAll) {
      final allIds = state.myClassesList.map((e) => e.id).toSet();
      state = state.copyWith(selectedMyClassIds: allIds);
    } else {
      state = state.copyWith(clearMyClassesSelection: true);
    }
  }

  void clearSelectedMyClassIds() {
    state = state.copyWith(clearMyClassesSelection: true);
  }

  Future<void> selectMyClass(MyClassItem item) async {
    state = state.copyWith(selectedMyClass: item);
    final details = await _api.fetchSessionDetails(item.id);
    if (details != null) {
      state = state.copyWith(selectedMyClassDetails: details);
    }
  }

  /// Instantly activate and prepare a live class session so classroom stage reflects the chosen class immediately.
  Future<void> selectAndActivateLiveClass(MyClassItem item, [MyClassDetails? details]) async {
    final active = ActiveLiveSession.fromMyClassItem(item, details);
    final fallbackStats = JoinConductKPIs(
      liveNow: 1,
      todaysClasses: state.myClassesTotalCount > 0 ? state.myClassesTotalCount : (state.myClassesList.isNotEmpty ? state.myClassesList.length : 1),
      totalParticipantsLive: item.viewerCount > 0 ? item.viewerCount : 1,
      recordingInProgress: item.recordingEnabled ? 1 : 0,
      avgClassDurationMin: item.durationMinutes > 0 ? item.durationMinutes : 45,
      classQuality: 'Excellent (98%)',
      systemStatus: 'Online',
    );
    final conductData = ConductClassSessionData(
      activeSession: active,
      stats: fallbackStats,
      participants: const [],
      upcomingClasses: const [],
      questions: const [],
      breakoutRooms: const [],
      engagement: LiveClassEngagementMetrics(
        overallScore: 92,
        activeParticipantsPct: 92,
        interactionPct: 88,
        pollResponsePct: 95,
        contentFocusPct: 95,
      ),
    );
    state = state.copyWith(
      selectedMyClass: item,
      selectedMyClassDetails: details,
      currentConductSessionId: item.id,
      conductSessionData: conductData,
    );
    // Enrich with server-side Q&A, active polls, and participants
    loadConductSession(item.id);
  }

  Future<bool> duplicateMyClass(String sessionId) async {
    final success = await _api.duplicateSession(sessionId);
    if (success) {
      await refreshMyClasses();
    }
    return success;
  }

  Future<bool> cancelMyClass(String sessionId, String reason) async {
    final success = await _api.cancelSession(sessionId, reason);
    if (success) {
      await refreshMyClasses();
    }
    return success;
  }

  Future<bool> updateMyClass(String sessionId, Map<String, dynamic> payload) async {
    final success = await _api.updateSession(sessionId, payload);
    if (success) {
      await refreshMyClasses();
    }
    return success;
  }

  Future<bool> deleteMyClass(String sessionId) async {
    final success = await _api.deleteSession(sessionId);
    if (success) {
      if (state.selectedMyClass?.id == sessionId) {
        state = state.copyWith(clearSelectedMyClass: true);
      }
      await refreshMyClasses();
    }
    return success;
  }

  Future<bool> bulkCancelSelectedMyClasses(String reason) async {
    if (state.selectedMyClassIds.isEmpty) return false;
    final success = await _api.bulkCancelSessions(state.selectedMyClassIds.toList(), reason: reason);
    if (success) {
      clearSelectedMyClassIds();
      await refreshMyClasses();
    }
    return success;
  }

  Future<bool> bulkDeleteSelectedMyClasses() async {
    if (state.selectedMyClassIds.isEmpty) return false;
    final success = await _api.bulkDeleteSessions(state.selectedMyClassIds.toList());
    if (success) {
      clearSelectedMyClassIds();
      await refreshMyClasses();
    }
    return success;
  }

  // ============================================================================
  // JOIN VIA CODE & GUEST JOIN ACTIONS
  // ============================================================================

  Future<void> loadJoinViaCodeData() async {
    try {
      final codes = await _api.fetchRecentMeetingCodes();
      state = state.copyWith(recentCodes: codes);
    } catch (_) {}
  }

  Future<void> loadGuestJoinData() async {
    try {
      final sessions = await _api.fetchUpcomingGuestSessions();
      state = state.copyWith(upcomingGuestSessions: sessions);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> validateAndPreviewCode(String code) async {
    state = state.copyWith(isJoinCodeLoading: true, joinCodeErrorMessage: null);
    final res = await _api.validateJoinCode(code);
    state = state.copyWith(
      isJoinCodeLoading: false,
      validatedMeetingInfo: res['session'] as ValidatedMeetingInfo?,
      joinCodeErrorMessage: res['success'] == true ? null : (res['message'] as String? ?? 'Invalid meeting code'),
    );
    return res;
  }

  Future<void> toggleStarMeetingCode(String code, bool isStarred) async {
    final updated = state.recentCodes.map<RecentMeetingCodeItem>((item) {
      if (item.meetingCode == code) {
        return item.copyWith(isStarred: isStarred);
      }
      return item;
    }).toList();
    state = state.copyWith(recentCodes: updated);
    await _api.toggleStarredMeetingCode(code, isStarred);
    await loadJoinViaCodeData();
  }

  Future<void> clearRecentCodes() async {
    state = state.copyWith(recentCodes: []);
    await _api.clearRecentMeetingCodes();
  }

  Future<GuestJoinResponse> submitGuestJoinRequest({
    required String code,
    required String displayName,
    String? email,
    required String purpose,
    String? organization,
  }) async {
    state = state.copyWith(isGuestJoinLoading: true, guestJoinErrorMessage: null);
    final response = await _api.requestGuestJoin(
      code: code,
      displayName: displayName,
      email: email,
      purpose: purpose,
      organization: organization,
      options: {
        'camera': state.joinOptionCamera,
        'microphone': state.joinOptionMic,
        'screen_share': state.joinOptionScreenShare,
        'hand_raised': state.joinOptionHandRaised,
      },
    );
    state = state.copyWith(
      isGuestJoinLoading: false,
      guestJoinResponse: response,
      guestJoinErrorMessage: response.success ? null : response.message,
    );
    return response;
  }

  void setJoinOptionCamera(bool val) => state = state.copyWith(joinOptionCamera: val);
  void setJoinOptionMic(bool val) => state = state.copyWith(joinOptionMic: val);
  void setJoinOptionScreenShare(bool val) => state = state.copyWith(joinOptionScreenShare: val);
  void setJoinOptionHandRaised(bool val) => state = state.copyWith(joinOptionHandRaised: val);

  // ==========================================================================
  // CONDUCT CLASS DYNAMIC CONTROLS & INTERACTIONS
  // ==========================================================================

  Future<void> loadConductSession([String? sessionId]) async {
    state = state.copyWith(isConductLoading: true, conductErrorMessage: null);
    try {
      final data = await _api.fetchConductSessionData(sessionId);
      if (data != null) {
        state = state.copyWith(
          conductSessionData: data,
          currentConductSessionId: data.activeSession.id,
          isConductLoading: false,
        );
      } else {
        // Fallback to local session data if available rather than nullifying
        ConductClassSessionData? fallbackData = state.conductSessionData;
        if (fallbackData == null) {
          final targetItem = (sessionId != null && state.myClassesList.isNotEmpty)
              ? state.myClassesList.where((c) => c.id == sessionId).firstOrNull
              : (state.selectedMyClass ?? state.myClassesList.where((c) => c.status.toLowerCase() == 'live').firstOrNull);
          if (targetItem != null) {
            fallbackData = ConductClassSessionData(
              activeSession: ActiveLiveSession.fromMyClassItem(targetItem, state.selectedMyClassDetails),
              stats: JoinConductKPIs(
                liveNow: 1,
                todaysClasses: state.myClassesTotalCount > 0 ? state.myClassesTotalCount : (state.myClassesList.isNotEmpty ? state.myClassesList.length : 1),
                totalParticipantsLive: targetItem.viewerCount > 0 ? targetItem.viewerCount : 1,
                recordingInProgress: targetItem.recordingEnabled ? 1 : 0,
                avgClassDurationMin: targetItem.durationMinutes > 0 ? targetItem.durationMinutes : 45,
                classQuality: 'Excellent (98%)',
                systemStatus: 'Online',
              ),
              participants: const [],
              upcomingClasses: const [],
              questions: const [],
              breakoutRooms: const [],
              engagement: LiveClassEngagementMetrics(
                overallScore: 92,
                activeParticipantsPct: 92,
                interactionPct: 88,
                pollResponsePct: 95,
                contentFocusPct: 95,
              ),
            );
          }
        }
        state = state.copyWith(
          conductSessionData: fallbackData,
          currentConductSessionId: fallbackData?.activeSession.id ?? sessionId,
          isConductLoading: false,
          conductErrorMessage: 'Notice: Using offline active session cache',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isConductLoading: false,
        conductErrorMessage: e.toString(),
      );
    }
  }

  Future<bool> submitQuestion(
    String question, {
    String? authorName,
    String? authorRole,
    bool isAnonymous = false,
  }) async {
    final sessId = state.currentConductSessionId ?? state.conductSessionData?.activeSession.id;
    if (sessId == null) return false;
    final item = await _api.submitQuestion(
      sessId,
      question,
      authorName: authorName,
      authorRole: authorRole,
      isAnonymous: isAnonymous,
    );
    if (item != null && state.conductSessionData != null) {
      final exists = state.conductSessionData!.questions.any((q) => q.id == item.id);
      if (!exists) {
        final updatedList = List<LiveClassQuestionItem>.from(state.conductSessionData!.questions)..insert(0, item);
        final updatedData = state.conductSessionData!.copyWith(questions: updatedList);
        state = state.copyWith(conductSessionData: updatedData);
      }
      return true;
    }
    return false;
  }

  Future<bool> answerQuestion(
    String questionId,
    String answer, {
    String? authorName,
    String? authorRole,
    String? authorEmail,
    String? authorPhone,
  }) async {
    final sessId = state.currentConductSessionId ?? state.conductSessionData?.activeSession.id;
    final res = await _api.answerQuestion(
      questionId,
      answer,
      authorName: authorName,
      authorRole: authorRole,
      sessionId: sessId,
    );
    if (res != null && state.conductSessionData != null) {
      final newReply = (res['reply'] is Map<String, dynamic>)
          ? LiveClassQuestionReply.fromJson(res['reply'])
          : LiveClassQuestionReply(
              id: 'reply_${DateTime.now().millisecondsSinceEpoch}',
              authorId: '',
              authorName: authorName ?? 'Instructor',
              authorRole: authorRole ?? 'Teacher',
              authorEmail: authorEmail,
              authorPhone: authorPhone,
              answer: answer,
              createdAt: DateTime.now().toIso8601String(),
            );

      final updatedList = state.conductSessionData!.questions.map((q) {
        if (q.id == questionId) {
          final updatedReplies = List<LiveClassQuestionReply>.from(q.answers)..add(newReply);
          return q.copyWith(
            status: 'ANSWERED',
            answered: true,
            answer: answer,
            answers: updatedReplies,
          );
        }
        return q;
      }).toList();

      final updatedData = state.conductSessionData!.copyWith(questions: updatedList);
      state = state.copyWith(conductSessionData: updatedData);
      return true;
    }
    return false;
  }

  Future<bool> upvoteQuestion(String questionId) async {
    // 1. Optimistic toggle
    if (state.conductSessionData != null) {
      final updatedList = state.conductSessionData!.questions.map((q) {
        if (q.id == questionId) {
          final nextUpvoted = !q.hasUpvoted;
          final nextCount = nextUpvoted ? (q.upvotes + 1) : (q.upvotes > 0 ? q.upvotes - 1 : 0);
          return q.copyWith(
            hasUpvoted: nextUpvoted,
            upvotes: nextCount,
          );
        }
        return q;
      }).toList();
      state = state.copyWith(
        conductSessionData: state.conductSessionData!.copyWith(questions: updatedList),
      );
    }

    // 2. Synchronize with server toggle response
    final res = await _api.upvoteQuestion(questionId);
    if (res != null && res['upvotes'] != null && state.conductSessionData != null) {
      final serverUpvotes = res['upvotes'] as int;
      final serverHasUpvoted = res['has_upvoted'] == true;
      final syncedList = state.conductSessionData!.questions.map((q) {
        if (q.id == questionId) {
          return q.copyWith(
            upvotes: serverUpvotes,
            hasUpvoted: serverHasUpvoted,
          );
        }
        return q;
      }).toList();
      state = state.copyWith(
        conductSessionData: state.conductSessionData!.copyWith(questions: syncedList),
      );
      return true;
    }
    return res != null;
  }

  void setLocalActivePoll(LiveClassPollItem newPoll) {
    if (state.conductSessionData != null) {
      final currentHistory = List<LiveClassPollItem>.from(state.conductSessionData!.pollHistory);
      final existingIndex = currentHistory.indexWhere((p) => p.id == newPoll.id);
      if (existingIndex >= 0) {
        currentHistory[existingIndex] = newPoll;
      } else {
        currentHistory.insert(0, newPoll);
      }

      final updatedData = state.conductSessionData!.copyWith(
        activePoll: newPoll,
        pollHistory: currentHistory,
      );
      state = state.copyWith(conductSessionData: updatedData);
    } else {
      final sess = state.joinDashboard?.activeSession ??
          (state.selectedMyClass != null
              ? ActiveLiveSession.fromMyClassItem(state.selectedMyClass!, state.selectedMyClassDetails)
              : ActiveLiveSession.fromJson({
                  'id': state.currentConductSessionId ?? 'c1000000-0000-0000-0000-000000000014',
                  'title': 'Class 12 - A : Chemistry',
                  'class_section': 'Class 12 - A',
                  'class_name': 'Class 12',
                  'section_name': 'A',
                  'subject': 'Chemistry',
                  'teacher_name': 'Aarav Sharma',
                  'status': 'LIVE',
                  'is_live': true,
                }));
      state = state.copyWith(
        conductSessionData: ConductClassSessionData(
          activeSession: sess,
          stats: JoinConductKPIs.fromJson({}),
          participants: state.joinDashboard?.participants ?? [],
          upcomingClasses: [],
          questions: [],
          activePoll: newPoll,
          pollHistory: [newPoll],
          breakoutRooms: [],
          engagement: LiveClassEngagementMetrics.fromJson({}),
          waitingRoom: [],
        ),
      );
    }
  }

  void recordLocalVote(String optionId, {String? pollId}) {
    if (state.conductSessionData == null) return;
    final currentHistory = List<LiveClassPollItem>.from(state.conductSessionData!.pollHistory);
    final targetPollId = pollId ?? state.conductSessionData?.activePoll?.id;
    if (targetPollId == null) return;

    final pollIndex = currentHistory.indexWhere((p) => p.id == targetPollId);
    LiveClassPollItem? targetPoll;
    if (pollIndex >= 0) {
      targetPoll = currentHistory[pollIndex];
    } else if (state.conductSessionData?.activePoll?.id == targetPollId) {
      targetPoll = state.conductSessionData!.activePoll;
    }
    if (targetPoll == null) return;

    final updatedOptions = targetPoll.options.map((opt) {
      final isVoted = opt.id == optionId;
      final newVotes = isVoted ? opt.votes + 1 : opt.votes;
      return LiveClassPollOption(
        id: opt.id,
        text: opt.text,
        votes: newVotes,
        percentage: 0.0,
      );
    }).toList();

    final totalVotes = updatedOptions.fold<int>(0, (sum, o) => sum + o.votes);
    final recomputedOptions = updatedOptions.map((opt) {
      final pct = totalVotes > 0 ? ((opt.votes / totalVotes) * 100.0) : 0.0;
      return LiveClassPollOption(
        id: opt.id,
        text: opt.text,
        votes: opt.votes,
        percentage: pct,
      );
    }).toList();

    final updatedPoll = targetPoll.copyWith(
      options: recomputedOptions,
      totalVotes: totalVotes,
    );

    if (pollIndex >= 0) {
      currentHistory[pollIndex] = updatedPoll;
    } else {
      currentHistory.insert(0, updatedPoll);
    }

    final isAlsoActive = state.conductSessionData?.activePoll?.id == targetPollId;
    final updatedData = state.conductSessionData!.copyWith(
      activePoll: isAlsoActive ? updatedPoll : state.conductSessionData?.activePoll,
      pollHistory: currentHistory,
    );
    state = state.copyWith(conductSessionData: updatedData);
  }

  Future<bool> respondToPoll(String optionId, {String? pollId}) async {
    final targetPollId = pollId ?? state.conductSessionData?.activePoll?.id;
    if (targetPollId == null) return false;
    recordLocalVote(optionId, pollId: targetPollId);
    final sessId = state.currentConductSessionId ?? state.conductSessionData?.activeSession.id;
    if (sessId == null) return true;
    final ok = await _api.respondToPoll(targetPollId, sessId, optionId);
    if (ok) {
      await loadConductSession(sessId);
    }
    return true;
  }

  Future<bool> createPoll(Map<String, dynamic> pollData, [String? targetSessionId]) async {
    final sessId = targetSessionId ??
        state.currentConductSessionId ??
        state.conductSessionData?.activeSession.id ??
        state.joinDashboard?.activeSession?.id;
    final questionText = (pollData['question'] as String? ?? 'Live Poll').trim();

    // Multi-click & Concurrency Lock
    if (_isCreatingPoll) {
      debugPrint('[Poll] Concurrency lock: createPoll is already executing. Suppressing extra clicks.');
      return false;
    }

    // Rapid duplicate suppression within 4 seconds for identical question
    final now = DateTime.now();
    if (_lastPollQuestion == questionText &&
        _lastPollLaunchTime != null &&
        now.difference(_lastPollLaunchTime!) < const Duration(seconds: 4)) {
      debugPrint('[Poll] Duplicate poll suppressed: "$questionText" was launched within 4 seconds.');
      return false;
    }

    _isCreatingPoll = true;
    _lastPollLaunchTime = now;
    _lastPollQuestion = questionText;

    try {
      final rawOptions = (pollData['options'] as List? ?? []);

      final localOptions = rawOptions.asMap().entries.map((entry) {
        final opt = entry.value;
        final id = (opt is Map) ? (opt['id'] ?? 'opt_${entry.key + 1}') : 'opt_${entry.key + 1}';
        final text = (opt is Map) ? (opt['text'] ?? '') : opt.toString();
        return LiveClassPollOption(
          id: id.toString(),
          text: text.toString(),
          votes: 0,
          percentage: 0.0,
        );
      }).toList();

      final newPoll = LiveClassPollItem(
        id: 'poll_${DateTime.now().millisecondsSinceEpoch}',
        title: (pollData['title'] as String? ?? questionText).trim(),
        question: questionText,
        pollType: 'single_choice',
        status: 'ACTIVE',
        options: localOptions,
        totalVotes: 0,
      );

      setLocalActivePoll(newPoll);

      if (sessId != null) {
        final created = await _api.createPoll(sessId, pollData);
        if (created != null) {
          setLocalActivePoll(created);
        }
        await loadConductSession(sessId);
      }
      return true;
    } finally {
      _isCreatingPoll = false;
    }
  }

  Future<bool> saveWhiteboard(Map<String, dynamic> canvasData, {bool teacherOnlyMode = true}) async {
    final sessId = state.currentConductSessionId ?? state.conductSessionData?.activeSession.id;
    if (sessId == null) return false;
    return await _api.saveWhiteboard(sessId, canvasData, teacherOnlyMode: teacherOnlyMode);
  }

  Future<bool> uploadRecordedLiveClassBytes({
    required String sessionId,
    required List<int> bytes,
    required String fileName,
    required int durationSeconds,
  }) async {
    try {
      final activeSess = state.conductSessionData?.activeSession;
      final meta = state.dropdownMeta;
      final classSection = activeSess != null
          ? [activeSess.className, activeSess.sectionName].where((s) => s.trim().isNotEmpty).join(' - ')
          : '';
      final rawTitle = (activeSess?.title ?? '').trim();
      String resolvedTitle;
      if (rawTitle.isNotEmpty &&
          rawTitle.toLowerCase() != 'live class' &&
          rawTitle.toLowerCase() != 'live class recording') {
        resolvedTitle = (classSection.isNotEmpty && !rawTitle.toLowerCase().contains(classSection.toLowerCase()))
            ? '$rawTitle ($classSection)'
            : rawTitle;
      } else if (classSection.isNotEmpty && (activeSess?.subject ?? '').isNotEmpty) {
        resolvedTitle = '$classSection • ${activeSess!.subject} Lecture';
      } else {
        resolvedTitle = classSection.isNotEmpty ? '$classSection Lecture' : 'Recorded Class Session';
      }

      String? classId;
      String? sectionId;
      String? subjectId;
      if (meta != null && activeSess != null) {
        classId = meta.classes.where((c) => c.name.toLowerCase() == activeSess.className.toLowerCase()).firstOrNull?.id;
        sectionId = meta.sections.where((s) => s.name.toLowerCase() == activeSess.sectionName.toLowerCase() && (classId == null || s.classId == classId)).firstOrNull?.id;
        subjectId = meta.subjects.where((s) => s.name.toLowerCase() == activeSess.subject.toLowerCase()).firstOrNull?.id;
      }

      final res = await _api.uploadRecordingFile(
        fileBytes: bytes,
        fileName: fileName,
        title: resolvedTitle,
        description: 'Recorded live class lecture (${activeSess?.subject ?? 'General'}) with whiteboard & video sync.',
        classId: classId,
        sectionId: sectionId,
        subjectId: subjectId,
        teacherName: activeSess?.teacherName ?? 'Teacher',
        liveClassId: sessionId,
        recordingType: 'Live Class',
        durationMinutes: math.max(1, (durationSeconds / 60).round()),
        durationSeconds: math.max(1, durationSeconds),
        visibility: 'CLASS',
      );
      final newId = (res['data'] is Map) ? res['data']['id']?.toString() : null;
      await refreshRecordings(selectRecordingId: newId);
      return res['success'] == true || newId != null;
    } catch (e) {
      debugPrint('[LiveClassNotifier] uploadRecordedLiveClassBytes error: $e');
      return false;
    }
  }

  /// Explicitly start recording (idempotent; never toggles OFF if backend row was stale).
  Future<Map<String, dynamic>> startRecordingWithCapture() async {
    final sessId = state.currentConductSessionId ?? state.conductSessionData?.activeSession.id;
    if (sessId == null) {
      return {'success': false, 'is_recording': false, 'message': 'No active class session'};
    }

    final recorder = LiveClassBrowserRecorder.instance;
    if (kIsWeb && recorder.isRecording) {
      InAppLiveRoomService.instance.setIsRecording(true);
      return {
        'success': true,
        'is_recording': true,
        'source': recorder.sourceLabel,
        'message': 'Recording is already running (${recorder.sourceLabel}).',
      };
    }

    LiveClassCaptureStartResult captureStart = const LiveClassCaptureStartResult(started: false);
    if (kIsWeb) {
      captureStart = await recorder.startCapture();
    }
    if (!kIsWeb || captureStart.started) {
      InAppLiveRoomService.instance.setIsRecording(true);
    }

    final res = await _api.toggleRecording(sessId, action: 'start');
    final serverStarted = res['success'] == true &&
        (res['recording_status'] == 'RECORDING' || res['data']?['is_recording'] == true);

    if (!captureStart.started && !kIsWeb && !serverStarted) {
      InAppLiveRoomService.instance.setIsRecording(false);
      return {
        'success': false,
        'is_recording': false,
        'message': 'Could not start recording.',
      };
    }
    if (kIsWeb && !captureStart.started) {
      InAppLiveRoomService.instance.setIsRecording(false);
      if (serverStarted) {
        unawaited(_api.toggleRecording(sessId, action: 'stop'));
      }
      return {
        'success': false,
        'is_recording': false,
        'message': captureStart.errorMessage ?? 'Capture initialization failed.',
      };
    }

    unawaited(loadConductSession(sessId));
    return {
      'success': true,
      'is_recording': true,
      'source': captureStart.sourceLabel,
      'message': captureStart.sourceLabel.isNotEmpty
          ? 'Recording started (${captureStart.sourceLabel}). Click Rec badge to Pause or Stop.'
          : 'Live recording started.',
    };
  }

  /// Explicitly stop recording, upload captured WebM, and sync Recordings tab.
  Future<Map<String, dynamic>> stopRecordingWithCapture({int? recordedDurationSeconds}) async {
    final sessId = state.currentConductSessionId ?? state.conductSessionData?.activeSession.id;
    if (sessId == null) {
      return {'success': false, 'is_recording': false, 'message': 'No active class session'};
    }

    final recorder = LiveClassBrowserRecorder.instance;
    InAppLiveRoomService.instance.setIsRecording(false);

    LiveClassCaptureStopResult? captureStop;
    if (recorder.isRecording) {
      captureStop = await recorder.stopAndCollect();
    }

    await _api.toggleRecording(sessId, action: 'stop');

    bool uploaded = false;
    if (captureStop?.bytes != null && captureStop!.bytes!.isNotEmpty) {
      uploaded = await uploadRecordedLiveClassBytes(
        sessionId: sessId,
        bytes: captureStop.bytes!,
        fileName: captureStop.fileName,
        durationSeconds: recordedDurationSeconds ?? captureStop.durationSeconds,
      );
    }

    unawaited(loadConductSession(sessId));
    unawaited(refreshRecordings());
    return {
      'success': true,
      'is_recording': false,
      'uploaded': uploaded,
      'message': uploaded
          ? 'Live class recording captured and saved to Recordings tab!'
          : 'Recording stopped.',
    };
  }

  Future<Map<String, dynamic>> toggleRecordingWithCapture({
    bool? forceStart,
    int? recordedDurationSeconds,
  }) async {
    if (forceStart == true) {
      return startRecordingWithCapture();
    }
    if (forceStart == false) {
      return stopRecordingWithCapture(recordedDurationSeconds: recordedDurationSeconds);
    }
    final recorder = LiveClassBrowserRecorder.instance;
    // Never infer active recording from stale DB field; check live recorder / room state only
    final isCurrentlyActive = kIsWeb
        ? recorder.isRecording
        : InAppLiveRoomService.instance.isRecording;
    return isCurrentlyActive
        ? stopRecordingWithCapture(recordedDurationSeconds: recordedDurationSeconds)
        : startRecordingWithCapture();
  }

  Future<bool> toggleRecording({int? recordedDurationSeconds}) async {
    final out = await toggleRecordingWithCapture(recordedDurationSeconds: recordedDurationSeconds);
    return out['success'] == true;
  }

  Future<bool> muteParticipant(String participantId, bool isMuted) async {
    final sessId = state.currentConductSessionId ?? state.conductSessionData?.activeSession.id;
    if (sessId == null) return false;

    // Optimistic UI state update
    if (state.conductSessionData != null) {
      final updatedParts = state.conductSessionData!.participants.map((p) {
        if (p.id == participantId || p.userId == participantId) {
          return p.copyWith(micMuted: isMuted);
        }
        return p;
      }).toList();
      state = state.copyWith(
        conductSessionData: state.conductSessionData!.copyWith(participants: updatedParts),
      );
    }

    final ok = await _api.muteParticipant(sessId, participantId, isMuted);
    if (ok) {
      await loadConductSession(sessId);
    }
    return ok;
  }

  Future<bool> removeParticipant(String participantId) async {
    final sessId = state.currentConductSessionId ?? state.conductSessionData?.activeSession.id;
    if (sessId == null) return false;

    // Optimistic UI state update
    if (state.conductSessionData != null) {
      final updatedParts = state.conductSessionData!.participants
          .where((p) => p.id != participantId && p.userId != participantId)
          .toList();
      state = state.copyWith(
        conductSessionData: state.conductSessionData!.copyWith(participants: updatedParts),
      );
    }

    final ok = await _api.removeParticipant(sessId, participantId);
    if (ok) {
      await loadConductSession(sessId);
    }
    return ok;
  }

  Future<bool> reviewGuestRequest(String requestId, String decision, {String? reason}) async {
    final sessId = state.currentConductSessionId ?? state.conductSessionData?.activeSession.id;
    if (sessId == null) return false;

    // Optimistically remove from waitingRoom in state
    if (state.conductSessionData != null) {
      final updatedWaiting = state.conductSessionData!.waitingRoom
          .where((g) => g.requestId != requestId)
          .toList();
      state = state.copyWith(
        conductSessionData: state.conductSessionData!.copyWith(waitingRoom: updatedWaiting),
      );
    }

    final ok = await _api.reviewGuestRequest(sessId, requestId, decision: decision, reason: reason);
    if (ok) {
      await loadConductSession(sessId);
    }
    return ok;
  }

  // ============================================================================
  // ENROLLED STUDENTS, BREAKOUT ROOMS, HOST & SETTINGS MANAGEMENT
  // ============================================================================

  Future<List<Map<String, dynamic>>> fetchEnrolledStudents({String? classId, String? sectionId}) async {
    return await _api.fetchEnrolledStudents(classId: classId, sectionId: sectionId);
  }

  Future<List<Map<String, dynamic>>> fetchBreakoutRooms(String sessionId) async {
    return await _api.fetchBreakoutRooms(sessionId);
  }

  Future<bool> createBreakoutRoom(String sessionId, String name, int capacity) async {
    final room = await _api.createBreakoutRoom(sessionId, name, capacity);
    return room != null;
  }

  Future<bool> closeBreakoutRoom(String sessionId, String roomId) async {
    return await _api.closeBreakoutRoom(sessionId, roomId);
  }

  Future<Map<String, dynamic>?> fetchSessionSettings(String sessionId) async {
    return await _api.fetchSessionSettings(sessionId);
  }

  Future<bool> updateSessionSettings(String sessionId, Map<String, dynamic> settings) async {
    final success = await _api.updateSessionSettings(sessionId, settings);
    if (success && state.conductSessionData != null && state.conductSessionData!.activeSession.id == sessionId) {
      final curActive = state.conductSessionData!.activeSession;
      final updatedActive = curActive.copyWith(
        allowStudentMic: settings['allow_mic'] ?? settings['allow_student_mic'] ?? curActive.allowStudentMic,
        allowStudentCam: settings['allow_cam'] ?? settings['allow_student_cam'] ?? curActive.allowStudentCam,
        allowStudentShare: settings['allow_screen_share'] ?? settings['allow_student_share'] ?? curActive.allowStudentShare,
        allowChat: settings['allow_chat'] ?? curActive.allowChat,
        allowReactions: settings['allow_reactions'] ?? curActive.allowReactions,
        waitingRoomEnabled: settings['waiting_room_enabled'] ?? curActive.waitingRoomEnabled,
        recordingEnabled: settings['auto_record'] ?? settings['recording_enabled'] ?? curActive.recordingEnabled,
        maxParticipants: settings['max_participants'] ?? curActive.maxParticipants,
      );
      state = state.copyWith(
        conductSessionData: state.conductSessionData!.copyWith(activeSession: updatedActive),
      );
    }
    return success;
  }

  Future<bool> reassignHost(String sessionId, String targetUserId, {String role = 'host'}) async {
    return await _api.reassignHost(sessionId, targetUserId, role: role);
  }

  void toggleScreenShare() => state = state.copyWith(isScreenSharing: !state.isScreenSharing);
  void toggleWhiteboard() => state = state.copyWith(isWhiteboardActive: !state.isWhiteboardActive);
  void togglePollDialog() => state = state.copyWith(isPollDialogActive: !state.isPollDialogActive);

  // Convenience aliases for UI actions
  void setTab(int index) => switchTab(index);
  Future<void> fetchInitialData() => loadInitialData();
  Future<void> autoCalculateAttendance(String sessionId) => recalculateAttendance(sessionId);
  void searchRecordings(String query) => setRecordingsSearch(query);
  void searchAttendance(String query) => setAttendanceSearch(query);
}

final liveClassManagementProvider =
    StateNotifierProvider<LiveClassNotifier, LiveClassState>((ref) {
  final api = ref.watch(liveClassApiServiceProvider);
  return LiveClassNotifier(api);
});
