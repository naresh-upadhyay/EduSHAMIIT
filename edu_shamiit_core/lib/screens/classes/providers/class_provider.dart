import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/class_models.dart';
import '../services/class_api_service.dart';

class ClassState {
  final int activeTab; // 0: Classes, 1: Sections, 2: Subjects, 3: Rooms
  final String academicYear;

  // 1. Classes Tab Filters & Pagination
  final String classSearchQuery;
  final String classStatusFilter;
  final String classStageFilter;
  final int classPage;
  final int classPageSize;
  final int classTotalCount;
  final int classTotalPages;

  // 2. Sections Tab Filters & Pagination
  final String sectionSearchQuery;
  final String sectionStatusFilter;
  final String? sectionClassIdFilter;
  final String sectionBuildingFilter;
  final String sectionFloorFilter;
  final int sectionPage;
  final int sectionPageSize;
  final int sectionTotalCount;
  final int sectionTotalPages;

  // 3. Subjects Tab Filters & Pagination
  final String subjectSearchQuery;
  final String subjectStatusFilter;
  final String subjectTypeFilter;
  final String? subjectClassIdFilter;
  final int subjectPage;
  final int subjectPageSize;
  final int subjectTotalCount;
  final int subjectTotalPages;

  // 4. Rooms Tab Filters & Pagination
  final String roomSearchQuery;
  final String roomStatusFilter;
  final String roomTypeFilter;
  final String roomBuildingFilter;
  final String roomFloorFilter;
  final String roomViewMode; // TABLE, FLOOR
  final int roomPage;
  final int roomPageSize;
  final int roomTotalCount;
  final int roomTotalPages;

  // Generic Compatibility Getters
  int get page {
    if (activeTab == 0) return classPage;
    if (activeTab == 1) return sectionPage;
    if (activeTab == 2) return subjectPage;
    return roomPage;
  }

  int get pageSize {
    if (activeTab == 0) return classPageSize;
    if (activeTab == 1) return sectionPageSize;
    if (activeTab == 2) return subjectPageSize;
    return roomPageSize;
  }

  int get totalCount {
    if (activeTab == 0) return classTotalCount;
    if (activeTab == 1) return sectionTotalCount;
    if (activeTab == 2) return subjectTotalCount;
    return roomTotalCount;
  }

  int get totalPages {
    if (activeTab == 0) return classTotalPages;
    if (activeTab == 1) return sectionTotalPages;
    if (activeTab == 2) return subjectTotalPages;
    return roomTotalPages;
  }

  String get searchQuery {
    if (activeTab == 0) return classSearchQuery;
    if (activeTab == 1) return sectionSearchQuery;
    if (activeTab == 2) return subjectSearchQuery;
    return roomSearchQuery;
  }

  String get statusFilter {
    if (activeTab == 0) return classStatusFilter;
    if (activeTab == 1) return sectionStatusFilter;
    if (activeTab == 2) return subjectStatusFilter;
    return roomStatusFilter;
  }

  String? get selectedClassIdFilter {
    if (activeTab == 1) return sectionClassIdFilter;
    if (activeTab == 2) return subjectClassIdFilter;
    return null;
  }

  final List<AcademicClassModel> classes;
  final List<AcademicClassModel> allClasses;
  final AcademicClassModel? selectedClass;

  List<AcademicClassModel> get availableClasses => allClasses.isNotEmpty ? allClasses : classes;
  final AcademicClassDetailModel? selectedClassDetail;
  final List<AcademicSectionModel> sections;
  final SectionsOverviewStatsModel? sectionsOverviewStats;
  final List<AcademicSubjectModel> subjects;
  final AcademicSubjectModel? selectedSubject;
  final List<AcademicRoomModel> rooms;
  final AcademicRoomModel? selectedRoom;
  final AcademicRoomModel? selectedRoomDetail;
  final List<SubjectSectionMappingModel> subjectMappings;
  final List<String> availableBuildings;
  final List<String> availableFloors;
  final AcademicStatsModel stats;
  final bool isLoading;
  final bool isDetailLoading;
  final bool isMutating;
  final String? errorMessage;

  ClassState({
    this.activeTab = 0,
    this.academicYear = '2026-27',
    this.classSearchQuery = '',
    this.classStatusFilter = 'ALL',
    this.classStageFilter = 'ALL',
    this.classPage = 1,
    this.classPageSize = 10,
    this.classTotalCount = 0,
    this.classTotalPages = 1,
    this.sectionSearchQuery = '',
    this.sectionStatusFilter = 'ALL',
    this.sectionClassIdFilter,
    this.sectionBuildingFilter = 'ALL',
    this.sectionFloorFilter = 'ALL',
    this.sectionPage = 1,
    this.sectionPageSize = 10,
    this.sectionTotalCount = 0,
    this.sectionTotalPages = 1,
    this.subjectSearchQuery = '',
    this.subjectStatusFilter = 'ALL',
    this.subjectTypeFilter = 'ALL',
    this.subjectClassIdFilter,
    this.subjectPage = 1,
    this.subjectPageSize = 10,
    this.subjectTotalCount = 0,
    this.subjectTotalPages = 1,
    this.roomSearchQuery = '',
    this.roomStatusFilter = 'ALL',
    this.roomTypeFilter = 'ALL',
    this.roomBuildingFilter = 'ALL',
    this.roomFloorFilter = 'ALL',
    this.roomViewMode = 'TABLE',
    this.roomPage = 1,
    this.roomPageSize = 10,
    this.roomTotalCount = 0,
    this.roomTotalPages = 1,
    this.classes = const [],
    this.allClasses = const [],
    this.selectedClass,
    this.selectedClassDetail,
    this.sections = const [],
    this.sectionsOverviewStats,
    this.subjects = const [],
    this.selectedSubject,
    this.rooms = const [],
    this.selectedRoom,
    this.selectedRoomDetail,
    this.subjectMappings = const [],
    this.availableBuildings = const [],
    this.availableFloors = const [],
    AcademicStatsModel? stats,
    this.isLoading = false,
    this.isDetailLoading = false,
    this.isMutating = false,
    this.errorMessage,
  }) : stats = stats ?? AcademicStatsModel();

  ClassState copyWith({
    int? activeTab,
    String? academicYear,
    String? classSearchQuery,
    String? classStatusFilter,
    String? classStageFilter,
    int? classPage,
    int? classPageSize,
    int? classTotalCount,
    int? classTotalPages,
    String? sectionSearchQuery,
    String? sectionStatusFilter,
    String? sectionClassIdFilter,
    bool clearSectionClassFilter = false,
    String? sectionBuildingFilter,
    String? sectionFloorFilter,
    int? sectionPage,
    int? sectionPageSize,
    int? sectionTotalCount,
    int? sectionTotalPages,
    String? subjectSearchQuery,
    String? subjectStatusFilter,
    String? subjectTypeFilter,
    String? subjectClassIdFilter,
    bool clearSubjectClassFilter = false,
    int? subjectPage,
    int? subjectPageSize,
    int? subjectTotalCount,
    int? subjectTotalPages,
    String? roomSearchQuery,
    String? roomStatusFilter,
    String? roomTypeFilter,
    String? roomBuildingFilter,
    String? roomFloorFilter,
    String? roomViewMode,
    int? roomPage,
    int? roomPageSize,
    int? roomTotalCount,
    int? roomTotalPages,
    List<AcademicClassModel>? classes,
    List<AcademicClassModel>? allClasses,
    AcademicClassModel? selectedClass,
    AcademicClassDetailModel? selectedClassDetail,
    bool clearSelectedClass = false,
    List<AcademicSectionModel>? sections,
    SectionsOverviewStatsModel? sectionsOverviewStats,
    List<AcademicSubjectModel>? subjects,
    AcademicSubjectModel? selectedSubject,
    bool clearSelectedSubject = false,
    List<AcademicRoomModel>? rooms,
    AcademicRoomModel? selectedRoom,
    AcademicRoomModel? selectedRoomDetail,
    bool clearSelectedRoom = false,
    List<SubjectSectionMappingModel>? subjectMappings,
    List<String>? availableBuildings,
    List<String>? availableFloors,
    AcademicStatsModel? stats,
    bool? isLoading,
    bool? isDetailLoading,
    bool? isMutating,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ClassState(
      activeTab: activeTab ?? this.activeTab,
      academicYear: academicYear ?? this.academicYear,
      classSearchQuery: classSearchQuery ?? this.classSearchQuery,
      classStatusFilter: classStatusFilter ?? this.classStatusFilter,
      classStageFilter: classStageFilter ?? this.classStageFilter,
      classPage: classPage ?? this.classPage,
      classPageSize: classPageSize ?? this.classPageSize,
      classTotalCount: classTotalCount ?? this.classTotalCount,
      classTotalPages: classTotalPages ?? this.classTotalPages,
      sectionSearchQuery: sectionSearchQuery ?? this.sectionSearchQuery,
      sectionStatusFilter: sectionStatusFilter ?? this.sectionStatusFilter,
      sectionClassIdFilter: clearSectionClassFilter ? null : (sectionClassIdFilter ?? this.sectionClassIdFilter),
      sectionBuildingFilter: sectionBuildingFilter ?? this.sectionBuildingFilter,
      sectionFloorFilter: sectionFloorFilter ?? this.sectionFloorFilter,
      sectionPage: sectionPage ?? this.sectionPage,
      sectionPageSize: sectionPageSize ?? this.sectionPageSize,
      sectionTotalCount: sectionTotalCount ?? this.sectionTotalCount,
      sectionTotalPages: sectionTotalPages ?? this.sectionTotalPages,
      subjectSearchQuery: subjectSearchQuery ?? this.subjectSearchQuery,
      subjectStatusFilter: subjectStatusFilter ?? this.subjectStatusFilter,
      subjectTypeFilter: subjectTypeFilter ?? this.subjectTypeFilter,
      subjectClassIdFilter: clearSubjectClassFilter ? null : (subjectClassIdFilter ?? this.subjectClassIdFilter),
      subjectPage: subjectPage ?? this.subjectPage,
      subjectPageSize: subjectPageSize ?? this.subjectPageSize,
      subjectTotalCount: subjectTotalCount ?? this.subjectTotalCount,
      subjectTotalPages: subjectTotalPages ?? this.subjectTotalPages,
      roomSearchQuery: roomSearchQuery ?? this.roomSearchQuery,
      roomStatusFilter: roomStatusFilter ?? this.roomStatusFilter,
      roomTypeFilter: roomTypeFilter ?? this.roomTypeFilter,
      roomBuildingFilter: roomBuildingFilter ?? this.roomBuildingFilter,
      roomFloorFilter: roomFloorFilter ?? this.roomFloorFilter,
      roomViewMode: roomViewMode ?? this.roomViewMode,
      roomPage: roomPage ?? this.roomPage,
      roomPageSize: roomPageSize ?? this.roomPageSize,
      roomTotalCount: roomTotalCount ?? this.roomTotalCount,
      roomTotalPages: roomTotalPages ?? this.roomTotalPages,
      classes: classes ?? this.classes,
      allClasses: allClasses ?? this.allClasses,
      selectedClass: clearSelectedClass ? null : (selectedClass ?? this.selectedClass),
      selectedClassDetail: clearSelectedClass ? null : (selectedClassDetail ?? this.selectedClassDetail),
      sections: sections ?? this.sections,
      sectionsOverviewStats: sectionsOverviewStats ?? this.sectionsOverviewStats,
      subjects: subjects ?? this.subjects,
      selectedSubject: clearSelectedSubject ? null : (selectedSubject ?? this.selectedSubject),
      rooms: rooms ?? this.rooms,
      selectedRoom: clearSelectedRoom ? null : (selectedRoom ?? this.selectedRoom),
      selectedRoomDetail: clearSelectedRoom ? null : (selectedRoomDetail ?? this.selectedRoomDetail),
      subjectMappings: subjectMappings ?? this.subjectMappings,
      availableBuildings: availableBuildings ?? this.availableBuildings,
      availableFloors: availableFloors ?? this.availableFloors,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      isDetailLoading: isDetailLoading ?? this.isDetailLoading,
      isMutating: isMutating ?? this.isMutating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ClassNotifier extends StateNotifier<ClassState> {
  final ClassApiService _api = ClassApiService();

  ClassNotifier() : super(ClassState()) {
    init();
  }

  Future<void> init() async {
    await Future.wait([
      fetchStats(),
      fetchClasses(),
      fetchAllClasses(),
      fetchRooms(),
      fetchBuildingsAndFloors(),
    ]);
  }

  void setActiveTab(int index) {
    if (state.activeTab == index) return;
    state = state.copyWith(activeTab: index, clearError: true);
    if (index == 0) {
      fetchClasses();
      if (state.rooms.isEmpty) fetchRooms();
    } else if (index == 1) {
      fetchStats();
      fetchSectionsOverviewStats();
      fetchSections();
      if (state.allClasses.isEmpty) fetchAllClasses();
      if (state.rooms.isEmpty) fetchRooms();
    } else if (index == 2) {
      fetchStats();
      fetchSubjects();
      if (state.allClasses.isEmpty) fetchAllClasses();
    } else if (index == 3) {
      fetchStats();
      fetchRooms();
    }
  }

  void setAcademicYear(String year) {
    if (state.academicYear == year) return;
    state = state.copyWith(
      academicYear: year,
      classPage: 1,
      sectionPage: 1,
      subjectPage: 1,
      roomPage: 1,
      clearSelectedClass: true,
      clearSelectedSubject: true,
      clearSelectedRoom: true,
    );
    fetchStats();
    _refetchCurrentTab();
  }

  void _refetchCurrentTab() {
    switch (state.activeTab) {
      case 0:
        fetchClasses();
        fetchAllClasses();
        break;
      case 1:
        fetchSectionsOverviewStats();
        fetchSections();
        fetchAllClasses();
        break;
      case 2:
        fetchSubjects();
        fetchAllClasses();
        break;
      case 3:
        fetchRooms();
        break;
    }
  }

  // =========================================================================
  // TAB-SPECIFIC FILTER & SEARCH HANDLERS
  // =========================================================================

  // Classes Tab Handlers
  void searchClasses(String query) {
    state = state.copyWith(classSearchQuery: query, classPage: 1);
    fetchClasses();
  }

  void setClassStatusFilter(String status) {
    state = state.copyWith(classStatusFilter: status, classPage: 1);
    fetchClasses();
  }

  void setClassStageFilter(String stage) {
    state = state.copyWith(classStageFilter: stage, classPage: 1);
    fetchClasses();
  }

  // Sections Tab Handlers
  void applySectionFilters({
    required String search,
    required String? classId,
    required String building,
    required String floor,
    required String status,
  }) {
    final cleanClassId = (classId == null || classId == 'ALL' || classId.isEmpty) ? null : classId;
    state = state.copyWith(
      sectionSearchQuery: search,
      sectionClassIdFilter: cleanClassId,
      clearSectionClassFilter: cleanClassId == null,
      sectionBuildingFilter: building,
      sectionFloorFilter: floor,
      sectionStatusFilter: status,
      sectionPage: 1,
    );
    fetchSections();
  }

  void clearSectionFilters() {
    state = state.copyWith(
      sectionSearchQuery: '',
      clearSectionClassFilter: true,
      sectionBuildingFilter: 'ALL',
      sectionFloorFilter: 'ALL',
      sectionStatusFilter: 'ALL',
      sectionPage: 1,
    );
    fetchSections();
  }

  // Subjects Tab Handlers
  void applySubjectFilters({
    required String search,
    required String type,
    required String status,
    required String? classId,
  }) {
    final cleanClassId = (classId == null || classId == 'ALL' || classId.isEmpty) ? null : classId;
    state = state.copyWith(
      subjectSearchQuery: search,
      subjectTypeFilter: type,
      subjectStatusFilter: status,
      subjectClassIdFilter: cleanClassId,
      clearSubjectClassFilter: cleanClassId == null,
      subjectPage: 1,
    );
    fetchSubjects();
  }

  void clearSubjectFilters() {
    state = state.copyWith(
      subjectSearchQuery: '',
      subjectTypeFilter: 'ALL',
      subjectStatusFilter: 'ALL',
      clearSubjectClassFilter: true,
      subjectPage: 1,
    );
    fetchSubjects();
  }

  // Rooms Tab Handlers
  void setRoomSearchQuery(String query) {
    state = state.copyWith(roomSearchQuery: query, roomPage: 1);
    fetchRooms();
  }

  void setRoomTypeFilter(String type) {
    state = state.copyWith(roomTypeFilter: type, roomPage: 1);
    fetchRooms();
  }

  void setRoomBuildingFilter(String building) {
    state = state.copyWith(roomBuildingFilter: building, roomPage: 1);
    fetchRooms();
  }

  void setRoomFloorFilter(String floor) {
    state = state.copyWith(roomFloorFilter: floor, roomPage: 1);
    fetchRooms();
  }

  void setRoomStatusFilter(String status) {
    state = state.copyWith(roomStatusFilter: status, roomPage: 1);
    fetchRooms();
  }

  void setRoomViewMode(String mode) {
    state = state.copyWith(roomViewMode: mode);
  }

  // Generic Compatibility Handlers
  void setSearchQuery(String query) {
    if (state.activeTab == 0) {
      searchClasses(query);
    } else if (state.activeTab == 1) {
      state = state.copyWith(sectionSearchQuery: query, sectionPage: 1);
      fetchSections();
    } else if (state.activeTab == 2) {
      state = state.copyWith(subjectSearchQuery: query, subjectPage: 1);
      fetchSubjects();
    } else if (state.activeTab == 3) {
      setRoomSearchQuery(query);
    }
  }

  void setStatusFilter(String status) {
    if (state.activeTab == 0) {
      setClassStatusFilter(status);
    } else if (state.activeTab == 1) {
      state = state.copyWith(sectionStatusFilter: status, sectionPage: 1);
      fetchSections();
    } else if (state.activeTab == 2) {
      state = state.copyWith(subjectStatusFilter: status, subjectPage: 1);
      fetchSubjects();
    } else if (state.activeTab == 3) {
      setRoomStatusFilter(status);
    }
  }

  void setClassFilter(String? classId) {
    final cleanId = (classId == null || classId == 'ALL' || classId.isEmpty) ? null : classId;
    if (state.activeTab == 1) {
      state = state.copyWith(sectionClassIdFilter: cleanId, clearSectionClassFilter: cleanId == null, sectionPage: 1);
      fetchSections();
    } else if (state.activeTab == 2) {
      state = state.copyWith(subjectClassIdFilter: cleanId, clearSubjectClassFilter: cleanId == null, subjectPage: 1);
      fetchSubjects();
    }
  }

  void setSubjectTypeFilter(String type) {
    state = state.copyWith(subjectTypeFilter: type, subjectPage: 1);
    fetchSubjects();
  }

  void setPage(int page) {
    if (state.activeTab == 0) {
      if (page < 1 || (state.classTotalPages > 0 && page > state.classTotalPages)) return;
      state = state.copyWith(classPage: page);
      fetchClasses();
    } else if (state.activeTab == 1) {
      if (page < 1 || (state.sectionTotalPages > 0 && page > state.sectionTotalPages)) return;
      state = state.copyWith(sectionPage: page);
      fetchSections();
    } else if (state.activeTab == 2) {
      if (page < 1 || (state.subjectTotalPages > 0 && page > state.subjectTotalPages)) return;
      state = state.copyWith(subjectPage: page);
      fetchSubjects();
    } else if (state.activeTab == 3) {
      if (page < 1 || (state.roomTotalPages > 0 && page > state.roomTotalPages)) return;
      state = state.copyWith(roomPage: page);
      fetchRooms();
    }
  }

  void setPageSize(int pageSize) {
    if (state.activeTab == 0) {
      if (pageSize == state.classPageSize) return;
      state = state.copyWith(classPageSize: pageSize, classPage: 1);
      fetchClasses();
    } else if (state.activeTab == 1) {
      if (pageSize == state.sectionPageSize) return;
      state = state.copyWith(sectionPageSize: pageSize, sectionPage: 1);
      fetchSections();
    } else if (state.activeTab == 2) {
      if (pageSize == state.subjectPageSize) return;
      state = state.copyWith(subjectPageSize: pageSize, subjectPage: 1);
      fetchSubjects();
    } else if (state.activeTab == 3) {
      if (pageSize == state.roomPageSize) return;
      state = state.copyWith(roomPageSize: pageSize, roomPage: 1);
      fetchRooms();
    }
  }

  void clearSelectedRoom() {
    state = state.copyWith(clearSelectedRoom: true);
  }

  Future<void> fetchStats() async {
    final stats = await _api.getStats(academicYear: state.academicYear);
    state = state.copyWith(stats: stats);
  }

  Future<void> fetchBuildingsAndFloors() async {
    final res = await _api.getBuildingsAndFloors();
    state = state.copyWith(
      availableBuildings: res['buildings'] ?? [],
      availableFloors: res['floors'] ?? [],
    );
  }

  // =========================================================================
  // CLASSES
  // =========================================================================

  Future<void> fetchClasses() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _api.getClasses(
        search: state.classSearchQuery,
        stage: state.classStageFilter,
        academicYear: state.academicYear,
        status: state.classStatusFilter,
        page: state.classPage,
        pageSize: state.classPageSize,
      );

      final List<AcademicClassModel> classList = res['classes'] ?? [];
      AcademicClassModel? currentSelected = state.selectedClass;

      if (classList.isNotEmpty) {
        if (currentSelected == null || !classList.any((c) => c.id == currentSelected?.id)) {
          currentSelected = classList.first;
        } else {
          currentSelected = classList.firstWhere((c) => c.id == currentSelected?.id);
        }
      } else {
        currentSelected = null;
      }

      state = state.copyWith(
        classes: classList,
        selectedClass: currentSelected,
        classTotalCount: res['totalCount'] ?? 0,
        classTotalPages: res['totalPages'] ?? 1,
        classPage: res['page'] ?? state.classPage,
        isLoading: false,
      );

      if (currentSelected != null) {
        fetchClassDetail(currentSelected.id);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> fetchAllClasses() async {
    try {
      final res = await _api.getClasses(
        academicYear: state.academicYear,
        status: 'ALL',
        page: 1,
        pageSize: 100,
        sortBy: 'display_order',
        sortOrder: 'ASC',
      );
      final List<AcademicClassModel> list = res['classes'] ?? [];
      if (list.isNotEmpty) {
        state = state.copyWith(allClasses: list);
      }
    } catch (_) {}
  }

  Future<void> selectClass(AcademicClassModel cls) async {
    state = state.copyWith(selectedClass: cls);
    await fetchClassDetail(cls.id);
  }

  Future<void> selectClassById(String classId) async {
    final match = state.classes.where((c) => c.id == classId).firstOrNull;
    if (match != null) {
      state = state.copyWith(selectedClass: match);
    }
    await fetchClassDetail(classId);
  }

  Future<void> fetchClassDetail(String classId) async {
    state = state.copyWith(isDetailLoading: true);
    try {
      final detail = await _api.getClassDetail(classId);
      state = state.copyWith(selectedClassDetail: detail, isDetailLoading: false);
    } catch (_) {
      state = state.copyWith(isDetailLoading: false);
    }
  }

  Future<bool> createClass({
    required String name,
    required String code,
    String stage = 'Secondary',
    String academicYear = '2026-27',
    int displayOrder = 1,
    String status = 'ACTIVE',
    List<Map<String, dynamic>> sections = const [],
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.createClass(
        name: name,
        code: code,
        stage: stage,
        academicYear: academicYear,
        displayOrder: displayOrder,
        status: status,
        sections: sections,
      );
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([fetchStats(), fetchClasses(), fetchAllClasses()]);
        return true;
      } else {
        state = state.copyWith(errorMessage: res['error']?.toString() ?? 'Failed to create class');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateClass(
    String classId, {
    String? name,
    String? code,
    String? stage,
    String? academicYear,
    int? displayOrder,
    String? status,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.updateClass(
        classId,
        name: name,
        code: code,
        stage: stage,
        academicYear: academicYear,
        displayOrder: displayOrder,
        status: status,
      );
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([fetchStats(), fetchClasses(), fetchAllClasses()]);
        return true;
      } else {
        state = state.copyWith(errorMessage: res['error']?.toString() ?? 'Failed to update class');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<Map<String, dynamic>> archiveClass(String classId, {bool force = false}) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.archiveClass(classId, force: force);
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([fetchStats(), fetchClasses(), fetchAllClasses()]);
      }
      return res;
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> restoreClass(String classId) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.restoreClass(classId);
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([fetchStats(), fetchClasses(), fetchAllClasses()]);
        return true;
      } else {
        state = state.copyWith(errorMessage: res['error']?.toString() ?? 'Failed to restore class');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  // =========================================================================
  // SECTIONS
  // =========================================================================

  Future<void> fetchSections() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _api.getSections(
        search: state.sectionSearchQuery,
        classId: state.sectionClassIdFilter,
        academicYear: state.academicYear,
        status: state.sectionStatusFilter,
        building: state.sectionBuildingFilter,
        floor: state.sectionFloorFilter,
        page: state.sectionPage,
        pageSize: state.sectionPageSize,
      );

      state = state.copyWith(
        sections: res['sections'] ?? [],
        sectionTotalCount: res['totalCount'] ?? 0,
        sectionTotalPages: res['totalPages'] ?? 1,
        sectionPage: res['page'] ?? state.sectionPage,
        isLoading: false,
      );

      fetchSectionsOverviewStats();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> fetchSectionsOverviewStats() async {
    try {
      final stats = await _api.getSectionsOverviewStats(academicYear: state.academicYear);
      state = state.copyWith(sectionsOverviewStats: stats);
    } catch (_) {}
  }

  Future<bool> createSection({
    required String classId,
    required String name,
    required String code,
    int capacity = 40,
    String? roomNumber,
    String? roomId,
    String academicYear = '2026-27',
    String status = 'ACTIVE',
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.createSection(
        classId: classId,
        name: name,
        code: code,
        capacity: capacity,
        roomNumber: roomNumber,
        roomId: roomId,
        academicYear: academicYear,
        status: status,
      );
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([
          fetchStats(),
          state.activeTab == 0 && state.selectedClass != null
              ? fetchClassDetail(state.selectedClass!.id)
              : fetchSections(),
        ]);
        return true;
      } else {
        state = state.copyWith(errorMessage: res['error']?.toString() ?? 'Failed to create section');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateSection(
    String sectionId, {
    String? name,
    String? code,
    int? capacity,
    String? roomNumber,
    String? roomId,
    String? status,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.updateSection(
        sectionId,
        name: name,
        code: code,
        capacity: capacity,
        roomNumber: roomNumber,
        roomId: roomId,
        status: status,
      );
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([
          fetchStats(),
          state.activeTab == 0 && state.selectedClass != null
              ? fetchClassDetail(state.selectedClass!.id)
              : fetchSections(),
        ]);
        return true;
      } else {
        state = state.copyWith(errorMessage: res['error']?.toString() ?? 'Failed to update section');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<Map<String, dynamic>> archiveSection(String sectionId, {bool force = false}) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.archiveSection(sectionId, force: force);
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([
          fetchStats(),
          state.activeTab == 0 && state.selectedClass != null
              ? fetchClassDetail(state.selectedClass!.id)
              : fetchSections(),
        ]);
      }
      return res;
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> restoreSection(String sectionId) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.restoreSection(sectionId);
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([
          fetchStats(),
          state.activeTab == 0 && state.selectedClass != null
              ? fetchClassDetail(state.selectedClass!.id)
              : fetchSections(),
        ]);
        return true;
      } else {
        state = state.copyWith(errorMessage: res['error']?.toString() ?? 'Failed to restore section');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  // =========================================================================
  // SUBJECTS
  // =========================================================================

  Future<void> fetchSubjects() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _api.getSubjects(
        search: state.subjectSearchQuery,
        type: state.subjectTypeFilter,
        status: state.subjectStatusFilter,
        classId: state.subjectClassIdFilter,
        academicYear: state.academicYear,
        page: state.subjectPage,
        pageSize: state.subjectPageSize,
      );

      final List<AcademicSubjectModel> subList = res['subjects'] ?? [];
      AcademicSubjectModel? currentSelected = state.selectedSubject;

      if (subList.isNotEmpty) {
        if (currentSelected == null || !subList.any((s) => s.id == currentSelected?.id)) {
          currentSelected = subList.first;
        } else {
          currentSelected = subList.firstWhere((s) => s.id == currentSelected?.id);
        }
      } else {
        currentSelected = null;
      }

      state = state.copyWith(
        subjects: subList,
        selectedSubject: currentSelected,
        subjectTotalCount: res['totalCount'] ?? 0,
        subjectTotalPages: res['totalPages'] ?? 1,
        subjectPage: res['page'] ?? state.subjectPage,
        isLoading: false,
      );

      if (currentSelected != null) {
        loadSubjectMappings(currentSelected.id);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  void selectSubject(AcademicSubjectModel subject) {
    state = state.copyWith(selectedSubject: subject);
    loadSubjectMappings(subject.id);
  }

  void selectSubjectById(String subjectId) {
    final match = state.subjects.where((s) => s.id == subjectId).firstOrNull;
    if (match != null) {
      selectSubject(match);
    } else {
      loadSubjectMappings(subjectId);
    }
  }

  Future<bool> createSubject({
    required String name,
    required String code,
    String type = 'Core',
    String? description,
    int periodsPerWeek = 5,
    String color = '#4F46E5',
    String icon = 'book',
    String status = 'ACTIVE',
    bool isOptional = false,
    List<String> classIds = const [],
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.createSubject(
        name: name,
        code: code,
        type: type,
        description: description,
        periodsPerWeek: periodsPerWeek,
        color: color,
        icon: icon,
        status: status,
        isOptional: isOptional,
        classIds: classIds,
      );
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([fetchStats(), fetchSubjects()]);
        return true;
      } else {
        state = state.copyWith(errorMessage: res['error']?.toString() ?? 'Failed to create subject');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateSubject(
    String subjectId, {
    String? name,
    String? code,
    String? type,
    String? description,
    int? periodsPerWeek,
    String? color,
    String? icon,
    String? status,
    bool? isOptional,
    List<String>? classIds,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.updateSubject(
        subjectId,
        name: name,
        code: code,
        type: type,
        description: description,
        periodsPerWeek: periodsPerWeek,
        color: color,
        icon: icon,
        status: status,
        isOptional: isOptional,
        classIds: classIds,
      );
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([fetchStats(), fetchSubjects()]);
        return true;
      } else {
        state = state.copyWith(errorMessage: res['error']?.toString() ?? 'Failed to update subject');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<Map<String, dynamic>> archiveSubject(String subjectId, {bool force = false}) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.archiveSubject(subjectId, force: force);
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([fetchStats(), fetchSubjects()]);
      }
      return res;
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> restoreSubject(String subjectId) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.restoreSubject(subjectId);
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([fetchStats(), fetchSubjects()]);
        return true;
      } else {
        state = state.copyWith(errorMessage: res['error']?.toString() ?? 'Failed to restore subject');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<void> loadSubjectMappings(String subjectId) async {
    try {
      final list = await _api.getSubjectSectionMappings(
        subjectId: subjectId,
        academicYear: state.academicYear,
      );
      state = state.copyWith(subjectMappings: list);
    } catch (_) {}
  }

  Future<bool> assignSubjectToSections({
    required String classId,
    required List<String> sectionIds,
    required String subjectId,
    String? teacherId,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.assignSubjectToSections(
        classId: classId,
        sectionIds: sectionIds,
        subjectId: subjectId,
        teacherId: teacherId,
        academicYear: state.academicYear,
      );
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([
          loadSubjectMappings(subjectId),
          fetchSubjects(),
          fetchClasses(),
          fetchStats(),
        ]);
        return true;
      } else {
        state = state.copyWith(errorMessage: res['error']?.toString() ?? 'Failed to assign subject');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> unassignSubjectFromSection({
    required String classId,
    String? sectionId,
    required String subjectId,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.unassignSubjectFromSection(
        classId: classId,
        sectionId: sectionId,
        subjectId: subjectId,
        academicYear: state.academicYear,
      );
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([
          loadSubjectMappings(subjectId),
          fetchSubjects(),
          fetchClasses(),
          fetchStats(),
        ]);
        return true;
      } else {
        state = state.copyWith(errorMessage: res['error']?.toString() ?? 'Failed to unassign subject');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> toggleClassSubjectStatus({
    required String classId,
    String? sectionId,
    required String subjectId,
    required String status,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.toggleClassSubjectStatus(
        classId: classId,
        sectionId: sectionId,
        subjectId: subjectId,
        status: status,
        academicYear: state.academicYear,
      );
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([
          loadSubjectMappings(subjectId),
          fetchSubjects(),
          fetchClasses(),
        ]);
        return true;
      } else {
        state = state.copyWith(errorMessage: res['error']?.toString() ?? 'Failed to update status');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> assignSectionSubjectTeacher({
    required String classId,
    required List<String> sectionIds,
    required String subjectId,
    String? teacherId,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.assignSectionSubjectTeacher(
        classId: classId,
        sectionIds: sectionIds,
        subjectId: subjectId,
        teacherId: teacherId,
        academicYear: state.academicYear,
      );
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([
          loadSubjectMappings(subjectId),
          fetchSubjects(),
          fetchClasses(),
          fetchStats(),
        ]);
        return true;
      } else {
        state = state.copyWith(errorMessage: res['error']?.toString() ?? 'Failed to assign teacher');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> manageOptionalEnrollments({
    required String classId,
    required String sectionId,
    required String subjectId,
    required List<String> studentIds,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.manageOptionalEnrollments(
        classId: classId,
        sectionId: sectionId,
        subjectId: subjectId,
        studentIds: studentIds,
        academicYear: state.academicYear,
      );
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await loadSubjectMappings(subjectId);
        return true;
      } else {
        state = state.copyWith(errorMessage: res['error']?.toString() ?? 'Failed to update enrollments');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  // =========================================================================
  // ROOMS
  // =========================================================================

  Future<void> fetchRooms() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _api.getRooms(
        search: state.roomSearchQuery,
        type: state.roomTypeFilter,
        building: state.roomBuildingFilter,
        floor: state.roomFloorFilter,
        status: state.roomStatusFilter,
        academicYear: state.academicYear,
        page: state.roomPage,
        pageSize: state.roomPageSize,
      );

      final List<AcademicRoomModel> roomList = res['rooms'] ?? [];
      AcademicRoomModel? currentSelected = state.selectedRoom;

      if (roomList.isNotEmpty) {
        if (currentSelected == null || !roomList.any((r) => r.id == currentSelected?.id)) {
          currentSelected = roomList.first;
        } else {
          currentSelected = roomList.firstWhere((r) => r.id == currentSelected?.id);
        }
      } else {
        currentSelected = null;
      }

      state = state.copyWith(
        rooms: roomList,
        selectedRoom: currentSelected,
        roomTotalCount: res['totalCount'] ?? 0,
        roomTotalPages: res['totalPages'] ?? 1,
        roomPage: res['page'] ?? state.roomPage,
        isLoading: false,
      );

      if (currentSelected != null) {
        fetchRoomDetail(currentSelected.id);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> selectRoom(AcademicRoomModel room) async {
    state = state.copyWith(selectedRoom: room);
    await fetchRoomDetail(room.id);
  }

  Future<void> fetchRoomDetail(String roomId) async {
    state = state.copyWith(isDetailLoading: true);
    try {
      final detail = await _api.getRoomDetail(roomId, academicYear: state.academicYear);
      state = state.copyWith(selectedRoomDetail: detail, isDetailLoading: false);
    } catch (_) {
      state = state.copyWith(isDetailLoading: false);
    }
  }

  Future<bool> createRoom({
    required String name,
    required String code,
    String type = 'Classroom',
    String building = 'Academic Block',
    String floor = 'Ground Floor',
    int capacity = 40,
    List<String> facilities = const [],
    String status = 'AVAILABLE',
    String? description,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.createRoom(
        name: name,
        code: code,
        type: type,
        building: building,
        floor: floor,
        capacity: capacity,
        facilities: facilities,
        status: status,
        description: description,
      );
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([fetchStats(), fetchRooms(), fetchBuildingsAndFloors()]);
        return true;
      } else {
        state = state.copyWith(errorMessage: res['error']?.toString() ?? 'Failed to create room');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> updateRoom(
    String roomId, {
    String? name,
    String? code,
    String? type,
    String? building,
    String? floor,
    int? capacity,
    List<String>? facilities,
    String? status,
    String? description,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.updateRoom(
        roomId,
        name: name,
        code: code,
        type: type,
        building: building,
        floor: floor,
        capacity: capacity,
        facilities: facilities,
        status: status,
        description: description,
      );
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([
          fetchStats(),
          fetchRooms(),
          fetchBuildingsAndFloors(),
          fetchRoomDetail(roomId),
        ]);
        return true;
      } else {
        state = state.copyWith(errorMessage: res['error']?.toString() ?? 'Failed to update room');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<Map<String, dynamic>> archiveRoom(String roomId, {bool force = false}) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.archiveRoom(roomId, force: force);
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([fetchStats(), fetchRooms()]);
      }
      return res;
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> restoreRoom(String roomId) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.restoreRoom(roomId);
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([fetchStats(), fetchRooms()]);
        return true;
      } else {
        state = state.copyWith(errorMessage: res['error']?.toString() ?? 'Failed to restore room');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> bulkUpdateRoomStatus({
    required List<String> roomIds,
    required String status,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.bulkUpdateRoomStatus(roomIds: roomIds, status: status);
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([fetchStats(), fetchRooms()]);
        return true;
      } else {
        state = state.copyWith(errorMessage: res['error']?.toString() ?? 'Failed to update rooms');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  // =========================================================================
  // ASSIGNMENTS
  // =========================================================================

  Future<bool> assignClassTeachers({
    required String classId,
    String? sectionId,
    required List<String> teacherIds,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.assignTeachers(
        classId: classId,
        sectionId: sectionId,
        teacherIds: teacherIds,
        academicYear: state.academicYear,
      );
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([
          fetchStats(),
          state.selectedClass != null ? fetchClassDetail(state.selectedClass!.id) : fetchClasses(),
          if (state.activeTab == 1) fetchSections(),
        ]);
        return true;
      } else {
        state = state.copyWith(errorMessage: res['error']?.toString() ?? 'Failed to assign teachers');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<Map<String, dynamic>> assignClassStudents({
    required String classId,
    String? sectionId,
    required List<String> studentIds,
    bool confirmMove = false,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.assignStudents(
        classId: classId,
        sectionId: sectionId,
        studentIds: studentIds,
        academicYear: state.academicYear,
        confirmMove: confirmMove,
      );
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([
          fetchStats(),
          state.selectedClass != null ? fetchClassDetail(state.selectedClass!.id) : fetchClasses(),
          if (state.activeTab == 1) fetchSections(),
        ]);
      }
      return res;
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> manageClassSubjects({
    required String classId,
    String? sectionId,
    required List<String> subjectIds,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.manageSubjects(
        classId: classId,
        sectionId: sectionId,
        subjectIds: subjectIds,
        academicYear: state.academicYear,
      );
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([
          fetchStats(),
          state.selectedClass != null ? fetchClassDetail(state.selectedClass!.id) : fetchClasses(),
          if (state.activeTab == 1) fetchSections(),
        ]);
        return true;
      } else {
        state = state.copyWith(errorMessage: res['error']?.toString() ?? 'Failed to assign subjects');
        return false;
      }
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> assignTeachers({
    required String classId,
    String? sectionId,
    required List<String> teacherIds,
  }) => assignClassTeachers(classId: classId, sectionId: sectionId, teacherIds: teacherIds);

  Future<bool> assignClassTeacher({
    required String classId,
    required String teacherId,
    String? sectionId,
  }) => assignClassTeachers(classId: classId, sectionId: sectionId, teacherIds: [teacherId]);

  Future<bool> assignSectionTeacher({
    required String sectionId,
    required String teacherId,
    String? classId,
  }) => assignClassTeachers(classId: classId ?? '', sectionId: sectionId, teacherIds: [teacherId]);

  Future<Map<String, dynamic>> assignStudents({
    required String classId,
    String? sectionId,
    required List<String> studentIds,
    bool confirmMove = false,
  }) => assignClassStudents(classId: classId, sectionId: sectionId, studentIds: studentIds, confirmMove: confirmMove);

  Future<Map<String, dynamic>> assignStudentsToSection({
    required String classId,
    required String sectionId,
    required List<String> studentIds,
    bool confirmMove = false,
  }) => assignClassStudents(classId: classId, sectionId: sectionId, studentIds: studentIds, confirmMove: confirmMove);

  Future<bool> manageSubjects({
    required String classId,
    String? sectionId,
    required List<String> subjectIds,
  }) => manageClassSubjects(classId: classId, sectionId: sectionId, subjectIds: subjectIds);
}

final classProvider = StateNotifierProvider<ClassNotifier, ClassState>((ref) {
  return ClassNotifier();
});
