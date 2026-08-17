import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/class_models.dart';
import '../services/class_api_service.dart';

class ClassState {
  final int activeTab; // 0: Classes, 1: Sections, 2: Subjects
  final String academicYear;
  final String searchQuery;
  final String statusFilter;
  final String? selectedClassIdFilter;
  final String subjectTypeFilter;
  final int page;
  final int pageSize;
  final int totalCount;
  final int totalPages;
  final List<AcademicClassModel> classes;
  final AcademicClassModel? selectedClass;
  final AcademicClassModel? selectedClassDetail;
  final List<AcademicSectionModel> sections;
  final List<AcademicSubjectModel> subjects;
  final AcademicStatsModel stats;
  final bool isLoading;
  final bool isDetailLoading;
  final bool isMutating;
  final String? errorMessage;

  ClassState({
    this.activeTab = 0,
    this.academicYear = '2026-27',
    this.searchQuery = '',
    this.statusFilter = 'ALL',
    this.selectedClassIdFilter,
    this.subjectTypeFilter = 'ALL',
    this.page = 1,
    this.pageSize = 10,
    this.totalCount = 0,
    this.totalPages = 1,
    this.classes = const [],
    this.selectedClass,
    this.selectedClassDetail,
    this.sections = const [],
    this.subjects = const [],
    AcademicStatsModel? stats,
    this.isLoading = false,
    this.isDetailLoading = false,
    this.isMutating = false,
    this.errorMessage,
  }) : stats = stats ?? AcademicStatsModel();

  ClassState copyWith({
    int? activeTab,
    String? academicYear,
    String? searchQuery,
    String? statusFilter,
    String? selectedClassIdFilter,
    bool clearClassFilter = false,
    String? subjectTypeFilter,
    int? page,
    int? pageSize,
    int? totalCount,
    int? totalPages,
    List<AcademicClassModel>? classes,
    AcademicClassModel? selectedClass,
    AcademicClassModel? selectedClassDetail,
    List<AcademicSectionModel>? sections,
    List<AcademicSubjectModel>? subjects,
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
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter ?? this.statusFilter,
      selectedClassIdFilter: clearClassFilter ? null : (selectedClassIdFilter ?? this.selectedClassIdFilter),
      subjectTypeFilter: subjectTypeFilter ?? this.subjectTypeFilter,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      totalCount: totalCount ?? this.totalCount,
      totalPages: totalPages ?? this.totalPages,
      classes: classes ?? this.classes,
      selectedClass: selectedClass ?? this.selectedClass,
      selectedClassDetail: selectedClassDetail ?? this.selectedClassDetail,
      sections: sections ?? this.sections,
      subjects: subjects ?? this.subjects,
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
    ]);
  }

  void setActiveTab(int index) {
    if (state.activeTab == index) return;
    state = state.copyWith(activeTab: index, page: 1, searchQuery: '', clearError: true);
    if (index == 0) {
      fetchClasses();
    } else if (index == 1) {
      fetchSections();
    } else if (index == 2) {
      fetchSubjects();
    }
  }

  void setAcademicYear(String year) {
    if (state.academicYear == year) return;
    state = state.copyWith(academicYear: year, page: 1);
    fetchStats();
    if (state.activeTab == 0) {
      fetchClasses();
    } else if (state.activeTab == 1) {
      fetchSections();
    } else {
      fetchSubjects();
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query, page: 1);
    _refetchCurrentTab();
  }

  void setStatusFilter(String status) {
    state = state.copyWith(statusFilter: status, page: 1);
    _refetchCurrentTab();
  }

  void setClassFilter(String? classId) {
    state = state.copyWith(selectedClassIdFilter: classId, clearClassFilter: classId == null, page: 1);
    if (state.activeTab == 1) {
      fetchSections();
    }
  }

  void setSubjectTypeFilter(String type) {
    state = state.copyWith(subjectTypeFilter: type, page: 1);
    if (state.activeTab == 2) {
      fetchSubjects();
    }
  }

  void setPage(int page) {
    if (page < 1 || (state.totalPages > 0 && page > state.totalPages)) return;
    state = state.copyWith(page: page);
    _refetchCurrentTab();
  }

  void _refetchCurrentTab() {
    if (state.activeTab == 0) {
      fetchClasses();
    } else if (state.activeTab == 1) {
      fetchSections();
    } else {
      fetchSubjects();
    }
  }

  Future<void> fetchStats() async {
    final stats = await _api.getStats(academicYear: state.academicYear);
    state = state.copyWith(stats: stats);
  }

  Future<void> fetchClasses() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _api.getClasses(
        search: state.searchQuery,
        academicYear: state.academicYear,
        status: state.statusFilter,
        page: state.page,
        pageSize: state.pageSize,
      );

      final List<AcademicClassModel> classList = res['classes'] ?? [];
      AcademicClassModel? currentSelected = state.selectedClass;

      if (classList.isNotEmpty) {
        if (currentSelected == null || !classList.any((c) => c.id == currentSelected?.id)) {
          currentSelected = classList.first;
        }
      } else {
        currentSelected = null;
      }

      state = state.copyWith(
        classes: classList,
        selectedClass: currentSelected,
        totalCount: res['totalCount'] ?? 0,
        totalPages: res['totalPages'] ?? 1,
        page: res['page'] ?? state.page,
        isLoading: false,
      );

      if (currentSelected != null) {
        fetchClassDetail(currentSelected.id);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
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

  Future<void> fetchSections() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _api.getSections(
        search: state.searchQuery,
        classId: state.selectedClassIdFilter,
        academicYear: state.academicYear,
        status: state.statusFilter,
        page: state.page,
        pageSize: state.pageSize,
      );

      state = state.copyWith(
        sections: res['sections'] ?? [],
        totalCount: res['totalCount'] ?? 0,
        totalPages: res['totalPages'] ?? 1,
        page: res['page'] ?? state.page,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> fetchSubjects() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _api.getSubjects(
        search: state.searchQuery,
        type: state.subjectTypeFilter,
        status: state.statusFilter,
        page: state.page,
        pageSize: state.pageSize,
      );

      state = state.copyWith(
        subjects: res['subjects'] ?? [],
        totalCount: res['totalCount'] ?? 0,
        totalPages: res['totalPages'] ?? 1,
        page: res['page'] ?? state.page,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> createClass({
    required String name,
    required String code,
    String stage = 'Secondary',
    String? academicYear,
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
        academicYear: academicYear ?? state.academicYear,
        displayOrder: displayOrder,
        status: status,
        sections: sections,
      );

      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([fetchStats(), fetchClasses()]);
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
        await Future.wait([fetchStats(), fetchClasses(), fetchClassDetail(classId)]);
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
        await Future.wait([fetchStats(), fetchClasses()]);
      }
      return res;
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> restoreClass(String classId) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.restoreClass(classId);
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([fetchStats(), fetchClasses()]);
      }
      return res;
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> createSection({
    required String classId,
    required String name,
    required String code,
    int capacity = 40,
    String? roomNumber,
    String? academicYear,
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
        academicYear: academicYear ?? state.academicYear,
        status: status,
      );

      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([
          fetchStats(),
          if (state.activeTab == 0 && state.selectedClass != null)
            fetchClassDetail(state.selectedClass!.id)
          else
            fetchSections()
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
        status: status,
      );

      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        if (state.activeTab == 0 && state.selectedClass != null) {
          await fetchClassDetail(state.selectedClass!.id);
        } else {
          await fetchSections();
        }
        return true;
      }
      return false;
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
          if (state.activeTab == 0 && state.selectedClass != null)
            fetchClassDetail(state.selectedClass!.id)
          else
            fetchSections()
        ]);
      }
      return res;
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> restoreSection(String sectionId) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.restoreSection(sectionId);
      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([
          fetchStats(),
          if (state.activeTab == 0 && state.selectedClass != null)
            fetchClassDetail(state.selectedClass!.id)
          else
            fetchSections()
        ]);
      }
      return res;
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return {'success': false, 'error': e.toString()};
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
        classIds: classIds,
      );

      state = state.copyWith(isMutating: false);
      if (res['success'] == true) {
        await Future.wait([
          fetchStats(),
          fetchSubjects(),
          if (state.selectedClass != null) fetchClassDetail(state.selectedClass!.id),
          if (state.activeTab == 0) fetchClasses(),
          if (state.activeTab == 1) fetchSections(),
        ]);
        return true;
      }
      return false;
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

  Future<Map<String, dynamic>> restoreSubject(String subjectId) async {
    state = state.copyWith(isMutating: true, clearError: true);
    try {
      final res = await _api.restoreSubject(subjectId);
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

  Future<bool> assignTeachers({
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
        await fetchClassDetail(classId);
        if (state.activeTab == 0) fetchClasses();
        if (state.activeTab == 1) fetchSections();
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<Map<String, dynamic>> assignStudents({
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
        await Future.wait([fetchStats(), fetchClassDetail(classId)]);
        if (state.activeTab == 0) fetchClasses();
        if (state.activeTab == 1) fetchSections();
      }
      return res;
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> manageSubjects({
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
          fetchClassDetail(classId),
          fetchClasses(),
          fetchSections(),
          fetchSubjects(),
        ]);
        return true;
      }
      return false;
    } catch (e) {
      state = state.copyWith(isMutating: false, errorMessage: e.toString());
      return false;
    }
  }
}

final classProvider = StateNotifierProvider<ClassNotifier, ClassState>((ref) {
  return ClassNotifier();
});
