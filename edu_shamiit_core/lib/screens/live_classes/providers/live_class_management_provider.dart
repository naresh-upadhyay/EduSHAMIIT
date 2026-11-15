import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_class_models.dart';
import '../services/live_class_api_service.dart';

final liveClassApiServiceProvider = Provider<LiveClassApiService>((ref) {
  return LiveClassApiService();
});

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
  final int recordingsTotalPages;
  final int recordingsTotalCount;
  final String? recordingClassFilter;
  final String? recordingSubjectFilter;
  final String? recordingTeacherFilter;
  final String? recordingStatusFilter;
  final String recordingSearchQuery;
  final RecordingItem? selectedRecordingForPreview;

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
  final int myClassesPage;
  final int myClassesPageSize;
  final int myClassesTotalCount;

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
    this.myClassesPage = 1,
    this.myClassesPageSize = 5,
    this.myClassesTotalCount = 0,
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
  });

  // Convenience aliases for UI tabs
  JoinConductDashboardData? get joinDashboard => joinConductData;
  RecordingsDashboardData? get recordingsDashboard => recordingsData;
  AttendanceDashboardData? get attendanceDashboard => attendanceData;
  MetaDropdownsData? get dropdownMeta => dropdownsData;
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
    int? recordingsTotalPages,
    int? recordingsTotalCount,
    String? recordingClassFilter,
    String? recordingSubjectFilter,
    String? recordingTeacherFilter,
    String? recordingStatusFilter,
    String? recordingSearchQuery,
    RecordingItem? selectedRecordingForPreview,
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
    int? myClassesPage,
    int? myClassesPageSize,
    int? myClassesTotalCount,
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
  }) {
    return LiveClassState(
      selectedTabIndex: selectedTabIndex ?? this.selectedTabIndex,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      joinConductData: joinConductData ?? this.joinConductData,
      recordingsData: recordingsData ?? this.recordingsData,
      attendanceData: attendanceData ?? this.attendanceData,
      dropdownsData: dropdownsData ?? this.dropdownsData,
      recordingsList: recordingsList ?? this.recordingsList,
      recordingsPage: recordingsPage ?? this.recordingsPage,
      recordingsTotalPages: recordingsTotalPages ?? this.recordingsTotalPages,
      recordingsTotalCount: recordingsTotalCount ?? this.recordingsTotalCount,
      recordingClassFilter: recordingClassFilter ?? this.recordingClassFilter,
      recordingSubjectFilter: recordingSubjectFilter ?? this.recordingSubjectFilter,
      recordingTeacherFilter: recordingTeacherFilter ?? this.recordingTeacherFilter,
      recordingStatusFilter: recordingStatusFilter ?? this.recordingStatusFilter,
      recordingSearchQuery: recordingSearchQuery ?? this.recordingSearchQuery,
      selectedRecordingForPreview: selectedRecordingForPreview ?? this.selectedRecordingForPreview,
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
      myClassesPage: myClassesPage ?? this.myClassesPage,
      myClassesPageSize: myClassesPageSize ?? this.myClassesPageSize,
      myClassesTotalCount: myClassesTotalCount ?? this.myClassesTotalCount,
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
      conductSessionData: conductSessionData ?? this.conductSessionData,
      currentConductSessionId: currentConductSessionId ?? this.currentConductSessionId,
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
      final attendanceDash = await _api.fetchAttendanceDashboard();

      final recsListRes = await _api.fetchRecordingsList(page: 1, pageSize: 8);
      final attListRes = await _api.fetchAttendanceList(page: 1, pageSize: 10);
      final myClassesDash = await _api.fetchMyClassesDashboard('today');
      final myClassesRes = await _api.fetchMyClassesList(dateFilter: 'today', sessionName: currentFY, page: 1, pageSize: 5);
      final recentCodes = await _api.fetchRecentMeetingCodes();
      final upcomingGuestSessions = await _api.fetchUpcomingGuestSessions();

      final recs = (recsListRes['items'] as List<RecordingItem>?) ?? [];
      final atts = (attListRes['items'] as List<AttendanceItem>?) ?? [];
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
        attendanceData: attendanceDash,
        recordingsList: recs,
        recordingsTotalCount: recsListRes['total_count'] ?? recs.length,
        recordingsTotalPages: recsListRes['total_pages'] ?? 1,
        selectedRecordingForPreview: recs.isNotEmpty ? recs.first : null,
        attendanceList: atts,
        attendanceTotalCount: attListRes['total_count'] ?? atts.length,
        attendanceTotalPages: attListRes['total_pages'] ?? 1,
        attendanceCounts: attListRes['counts'] ?? {},
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
    } else if (index == 2) {
      refreshAttendance();
    }
  }

  Future<void> refreshJoinConduct() async {
    try {
      final data = await _api.fetchJoinConductDashboard();
      state = state.copyWith(joinConductData: data);
    } catch (_) {}
  }

  Future<void> refreshRecordings() async {
    try {
      final dash = await _api.fetchRecordingsDashboard();
      final recsRes = await _api.fetchRecordingsList(
        classId: state.recordingClassFilter,
        subjectId: state.recordingSubjectFilter,
        teacherId: state.recordingTeacherFilter,
        status: state.recordingStatusFilter,
        search: state.recordingSearchQuery,
        page: state.recordingsPage,
        pageSize: 8,
      );
      final recs = (recsRes['items'] as List<RecordingItem>?) ?? [];
      state = state.copyWith(
        recordingsData: dash,
        recordingsList: recs,
        recordingsTotalCount: recsRes['total_count'] ?? recs.length,
        recordingsTotalPages: recsRes['total_pages'] ?? 1,
        selectedRecordingForPreview: recs.isNotEmpty ? recs.first : state.selectedRecordingForPreview,
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
    state = state.copyWith(recordingClassFilter: classId, recordingsPage: 1);
    refreshRecordings();
  }

  void setRecordingsSubjectFilter(String? subjectId) {
    state = state.copyWith(recordingSubjectFilter: subjectId, recordingsPage: 1);
    refreshRecordings();
  }

  void setRecordingsTeacherFilter(String? teacherId) {
    state = state.copyWith(recordingTeacherFilter: teacherId, recordingsPage: 1);
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
    await _api.endLiveClass(sessionId);
    await refreshJoinConduct();
    await refreshRecordings();
    await refreshAttendance();
  }

  Future<void> overrideAttendance(String attendanceId, String newStatus, String reason) async {
    await _api.overrideAttendance(attendanceId, newStatus, reason);
    await refreshAttendance();
  }

  Future<void> recalculateAttendance(String sessionId) async {
    await _api.recalculateAttendance(sessionId);
    await refreshAttendance();
  }

  Future<void> shareRecording(String sessionId, String sharedToId) async {
    await _api.shareRecording(sessionId, sharedToId);
    await refreshRecordings();
  }

  Future<void> deleteRecording(String recordingId) async {
    await _api.deleteRecording(recordingId);
    await refreshRecordings();
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

  void setMyClassesClassFilter(String? classId) {
    // When class changes, clear section filter so stale sections are not retained
    state = state.copyWith(
      myClassesClassFilter: classId,
      myClassesSectionFilter: null,
      myClassesPage: 1,
    );
    refreshMyClasses();
  }

  void setMyClassesSectionFilter(String? sectionId) {
    state = state.copyWith(myClassesSectionFilter: sectionId, myClassesPage: 1);
    refreshMyClasses();
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

  void setMyClassesPage(int page) {
    state = state.copyWith(myClassesPage: page);
    refreshMyClasses();
  }

  void setMyClassesPageSize(int pageSize) {
    state = state.copyWith(myClassesPageSize: pageSize, myClassesPage: 1);
    refreshMyClasses();
  }

  Future<void> selectMyClass(MyClassItem item) async {
    state = state.copyWith(selectedMyClass: item);
    final details = await _api.fetchSessionDetails(item.id);
    if (details != null) {
      state = state.copyWith(selectedMyClassDetails: details);
    }
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
        state = state.copyWith(
          isConductLoading: false,
          conductErrorMessage: 'Failed to load conduct session',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isConductLoading: false,
        conductErrorMessage: e.toString(),
      );
    }
  }

  Future<bool> submitQuestion(String question, {bool isAnonymous = false}) async {
    final sessId = state.currentConductSessionId ?? state.conductSessionData?.activeSession.id;
    if (sessId == null) return false;
    final item = await _api.submitQuestion(sessId, question, isAnonymous: isAnonymous);
    if (item != null && state.conductSessionData != null) {
      final updatedList = List<LiveClassQuestionItem>.from(state.conductSessionData!.questions)..insert(0, item);
      final updatedData = ConductClassSessionData(
        activeSession: state.conductSessionData!.activeSession,
        stats: state.conductSessionData!.stats,
        participants: state.conductSessionData!.participants,
        upcomingClasses: state.conductSessionData!.upcomingClasses,
        questions: updatedList,
        activePoll: state.conductSessionData!.activePoll,
        whiteboard: state.conductSessionData!.whiteboard,
        breakoutRooms: state.conductSessionData!.breakoutRooms,
        engagement: state.conductSessionData!.engagement,
      );
      state = state.copyWith(conductSessionData: updatedData);
      return true;
    }
    return false;
  }

  Future<bool> answerQuestion(String questionId, String answer) async {
    final ok = await _api.answerQuestion(questionId, answer);
    if (ok && state.conductSessionData != null) {
      final updatedList = state.conductSessionData!.questions.map((q) {
        if (q.id == questionId) {
          return LiveClassQuestionItem(
            id: q.id,
            author: q.author,
            authorRole: q.authorRole,
            question: q.question,
            upvotes: q.upvotes,
            status: 'ANSWERED',
            answered: true,
            answer: answer,
            isPinned: q.isPinned,
            createdAt: q.createdAt,
          );
        }
        return q;
      }).toList();
      final updatedData = ConductClassSessionData(
        activeSession: state.conductSessionData!.activeSession,
        stats: state.conductSessionData!.stats,
        participants: state.conductSessionData!.participants,
        upcomingClasses: state.conductSessionData!.upcomingClasses,
        questions: updatedList,
        activePoll: state.conductSessionData!.activePoll,
        whiteboard: state.conductSessionData!.whiteboard,
        breakoutRooms: state.conductSessionData!.breakoutRooms,
        engagement: state.conductSessionData!.engagement,
      );
      state = state.copyWith(conductSessionData: updatedData);
    }
    return ok;
  }

  Future<bool> upvoteQuestion(String questionId) async {
    final ok = await _api.upvoteQuestion(questionId);
    if (ok && state.conductSessionData != null) {
      final updatedList = state.conductSessionData!.questions.map((q) {
        if (q.id == questionId) {
          return LiveClassQuestionItem(
            id: q.id,
            author: q.author,
            authorRole: q.authorRole,
            question: q.question,
            upvotes: q.upvotes + 1,
            status: q.status,
            answered: q.answered,
            answer: q.answer,
            isPinned: q.isPinned,
            createdAt: q.createdAt,
          );
        }
        return q;
      }).toList();
      final updatedData = ConductClassSessionData(
        activeSession: state.conductSessionData!.activeSession,
        stats: state.conductSessionData!.stats,
        participants: state.conductSessionData!.participants,
        upcomingClasses: state.conductSessionData!.upcomingClasses,
        questions: updatedList,
        activePoll: state.conductSessionData!.activePoll,
        whiteboard: state.conductSessionData!.whiteboard,
        breakoutRooms: state.conductSessionData!.breakoutRooms,
        engagement: state.conductSessionData!.engagement,
      );
      state = state.copyWith(conductSessionData: updatedData);
    }
    return ok;
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

  Future<bool> createPoll(Map<String, dynamic> pollData) async {
    final sessId = state.currentConductSessionId ?? state.conductSessionData?.activeSession.id;
    final questionText = (pollData['question'] as String? ?? 'Live Poll').trim();
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
        await loadConductSession(sessId);
      }
    }
    return true;
  }

  Future<bool> saveWhiteboard(Map<String, dynamic> canvasData, {bool teacherOnlyMode = true}) async {
    final sessId = state.currentConductSessionId ?? state.conductSessionData?.activeSession.id;
    if (sessId == null) return false;
    return await _api.saveWhiteboard(sessId, canvasData, teacherOnlyMode: teacherOnlyMode);
  }

  Future<bool> toggleRecording() async {
    final sessId = state.currentConductSessionId ?? state.conductSessionData?.activeSession.id;
    if (sessId == null) return false;
    final res = await _api.toggleRecording(sessId);
    if (res['success'] == true) {
      await loadConductSession(sessId);
      return true;
    }
    return false;
  }

  Future<bool> muteParticipant(String participantId, bool isMuted) async {
    final sessId = state.currentConductSessionId ?? state.conductSessionData?.activeSession.id;
    if (sessId == null) return false;
    final ok = await _api.muteParticipant(sessId, participantId, isMuted);
    if (ok) {
      await loadConductSession(sessId);
    }
    return ok;
  }

  Future<bool> removeParticipant(String participantId) async {
    final sessId = state.currentConductSessionId ?? state.conductSessionData?.activeSession.id;
    if (sessId == null) return false;
    final ok = await _api.removeParticipant(sessId, participantId);
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

  Future<bool> updateSessionSettings(String sessionId, Map<String, dynamic> settings) async {
    return await _api.updateSessionSettings(sessionId, settings);
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
