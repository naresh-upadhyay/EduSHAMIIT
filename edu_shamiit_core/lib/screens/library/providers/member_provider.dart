import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/member_models.dart';
import '../services/member_api_service.dart';

class MemberState {
  final bool isLoading;
  final bool isStatsLoading;
  final bool isFilterOptionsLoading;
  final bool isActionLoading;
  final bool isSearchingProfiles;
  final List<LibraryMemberModel> members;
  final MemberStatsModel stats;
  final MemberFilterOptionsModel filterOptions;
  final LibraryMemberModel? selectedMember;
  final List<MemberBorrowItemModel> selectedMemberBooks;
  final List<MemberFineItemModel> selectedMemberFines;
  final List<MemberBorrowItemModel> selectedMemberHistory;
  final List<MemberAuditModel> selectedMemberAudits;
  final Map<String, dynamic> selectedMemberSummary;
  final bool isDrawerOpen;
  final Set<String> selectedMemberIds;
  final List<ProfileSearchResultModel> profileSearchResults;

  // Search & Filter state
  final String searchQuery;
  final String selectedMemberType;
  final String selectedClass;
  final String selectedDepartment;
  final String selectedStatus;
  final String selectedMembershipFilter;

  // Pagination & Sorting
  final String sortBy;
  final String sortOrder;
  final int currentPage;
  final int pageSize;
  final int totalRecords;
  final int totalPages;
  final String viewMode; // 'TABLE' or 'CARDS'

  // Feedback
  final String? errorMessage;
  final String? successMessage;

  const MemberState({
    this.isLoading = false,
    this.isStatsLoading = false,
    this.isFilterOptionsLoading = false,
    this.isActionLoading = false,
    this.isSearchingProfiles = false,
    this.members = const [],
    this.stats = const MemberStatsModel(),
    this.filterOptions = const MemberFilterOptionsModel(),
    this.selectedMember,
    this.selectedMemberBooks = const [],
    this.selectedMemberFines = const [],
    this.selectedMemberHistory = const [],
    this.selectedMemberAudits = const [],
    this.selectedMemberSummary = const {},
    this.isDrawerOpen = false,
    this.selectedMemberIds = const {},
    this.profileSearchResults = const [],
    this.searchQuery = '',
    this.selectedMemberType = 'All Member Types',
    this.selectedClass = 'All Classes',
    this.selectedDepartment = 'All Departments',
    this.selectedStatus = 'Status: All',
    this.selectedMembershipFilter = 'Membership: All',
    this.sortBy = 'member_code',
    this.sortOrder = 'asc',
    this.currentPage = 1,
    this.pageSize = 10,
    this.totalRecords = 0,
    this.totalPages = 1,
    this.viewMode = 'TABLE',
    this.errorMessage,
    this.successMessage,
  });

  MemberState copyWith({
    bool? isLoading,
    bool? isStatsLoading,
    bool? isFilterOptionsLoading,
    bool? isActionLoading,
    bool? isSearchingProfiles,
    List<LibraryMemberModel>? members,
    MemberStatsModel? stats,
    MemberFilterOptionsModel? filterOptions,
    LibraryMemberModel? selectedMember,
    bool clearSelectedMember = false,
    List<MemberBorrowItemModel>? selectedMemberBooks,
    List<MemberFineItemModel>? selectedMemberFines,
    List<MemberBorrowItemModel>? selectedMemberHistory,
    List<MemberAuditModel>? selectedMemberAudits,
    Map<String, dynamic>? selectedMemberSummary,
    bool? isDrawerOpen,
    Set<String>? selectedMemberIds,
    List<ProfileSearchResultModel>? profileSearchResults,
    String? searchQuery,
    String? selectedMemberType,
    String? selectedClass,
    String? selectedDepartment,
    String? selectedStatus,
    String? selectedMembershipFilter,
    String? sortBy,
    String? sortOrder,
    int? currentPage,
    int? pageSize,
    int? totalRecords,
    int? totalPages,
    String? viewMode,
    String? errorMessage,
    String? successMessage,
    bool clearMessages = false,
  }) {
    return MemberState(
      isLoading: isLoading ?? this.isLoading,
      isStatsLoading: isStatsLoading ?? this.isStatsLoading,
      isFilterOptionsLoading: isFilterOptionsLoading ?? this.isFilterOptionsLoading,
      isActionLoading: isActionLoading ?? this.isActionLoading,
      isSearchingProfiles: isSearchingProfiles ?? this.isSearchingProfiles,
      members: members ?? this.members,
      stats: stats ?? this.stats,
      filterOptions: filterOptions ?? this.filterOptions,
      selectedMember: clearSelectedMember ? null : (selectedMember ?? this.selectedMember),
      selectedMemberBooks: selectedMemberBooks ?? this.selectedMemberBooks,
      selectedMemberFines: selectedMemberFines ?? this.selectedMemberFines,
      selectedMemberHistory: selectedMemberHistory ?? this.selectedMemberHistory,
      selectedMemberAudits: selectedMemberAudits ?? this.selectedMemberAudits,
      selectedMemberSummary: selectedMemberSummary ?? this.selectedMemberSummary,
      isDrawerOpen: isDrawerOpen ?? this.isDrawerOpen,
      selectedMemberIds: selectedMemberIds ?? this.selectedMemberIds,
      profileSearchResults: profileSearchResults ?? this.profileSearchResults,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedMemberType: selectedMemberType ?? this.selectedMemberType,
      selectedClass: selectedClass ?? this.selectedClass,
      selectedDepartment: selectedDepartment ?? this.selectedDepartment,
      selectedStatus: selectedStatus ?? this.selectedStatus,
      selectedMembershipFilter: selectedMembershipFilter ?? this.selectedMembershipFilter,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,
      totalRecords: totalRecords ?? this.totalRecords,
      totalPages: totalPages ?? this.totalPages,
      viewMode: viewMode ?? this.viewMode,
      errorMessage: clearMessages ? null : (errorMessage ?? this.errorMessage),
      successMessage: clearMessages ? null : (successMessage ?? this.successMessage),
    );
  }
}

class MemberNotifier extends StateNotifier<MemberState> {
  final MemberApiService _apiService;
  Timer? _debounceTimer;

  MemberNotifier(this._apiService) : super(const MemberState()) {
    init();
  }

  Future<void> init() async {
    await Future.wait([
      fetchStats(),
      fetchFilterOptions(),
      fetchMembers(),
    ]);
  }

  /// Fetch aggregated KPI numbers
  Future<void> fetchStats() async {
    state = state.copyWith(isStatsLoading: true);
    try {
      final stats = await _apiService.fetchMemberStats();
      state = state.copyWith(stats: stats, isStatsLoading: false);
    } catch (e) {
      state = state.copyWith(isStatsLoading: false);
    }
  }

  /// Fetch dynamic dropdown options
  Future<void> fetchFilterOptions() async {
    state = state.copyWith(isFilterOptionsLoading: true);
    try {
      final options = await _apiService.fetchFilterOptions();
      state = state.copyWith(filterOptions: options, isFilterOptionsLoading: false);
    } catch (e) {
      state = state.copyWith(isFilterOptionsLoading: false);
    }
  }

  /// Fetch paginated and filtered members list
  Future<void> fetchMembers({bool resetPage = false}) async {
    final page = resetPage ? 1 : state.currentPage;
    state = state.copyWith(isLoading: true, currentPage: page);

    try {
      final res = await _apiService.fetchMembers(
        search: state.searchQuery,
        memberType: state.selectedMemberType,
        className: state.selectedClass,
        department: state.selectedDepartment,
        status: state.selectedStatus,
        membershipFilter: state.selectedMembershipFilter,
        sortBy: state.sortBy,
        sortOrder: state.sortOrder,
        page: page,
        pageSize: state.pageSize,
      );

      state = state.copyWith(
        members: res['members'] as List<LibraryMemberModel>,
        totalRecords: res['total'] as int,
        totalPages: res['totalPages'] as int,
        isLoading: false,
      );
    } catch (e, stack) {
      debugPrint('[MemberProvider] fetchMembers error: $e\n$stack');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load library members: ${e.toString().replaceAll("Exception:", "").trim()}',
      );
    }
  }

  /// Live search with debounce
  void onSearchChanged(String query) {
    state = state.copyWith(searchQuery: query);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      fetchMembers(resetPage: true);
    });
  }

  /// Search existing profiles for adding a member
  Future<void> searchProfiles(String query, {String? role}) async {
    state = state.copyWith(isSearchingProfiles: true);
    try {
      final results = await _apiService.searchProfiles(query: query, role: role);
      state = state.copyWith(profileSearchResults: results, isSearchingProfiles: false);
    } catch (e) {
      state = state.copyWith(isSearchingProfiles: false);
    }
  }

  /// Filter Setters
  void setMemberType(String type) {
    state = state.copyWith(selectedMemberType: type);
    fetchMembers(resetPage: true);
  }

  void setClass(String className) {
    state = state.copyWith(selectedClass: className);
    fetchMembers(resetPage: true);
  }

  void setDepartment(String department) {
    state = state.copyWith(selectedDepartment: department);
    fetchMembers(resetPage: true);
  }

  void setStatus(String status) {
    state = state.copyWith(selectedStatus: status);
    fetchMembers(resetPage: true);
  }

  void setMembershipFilter(String filter) {
    state = state.copyWith(selectedMembershipFilter: filter);
    fetchMembers(resetPage: true);
  }

  void resetFilters() {
    state = state.copyWith(
      searchQuery: '',
      selectedMemberType: 'All Member Types',
      selectedClass: 'All Classes',
      selectedDepartment: 'All Departments',
      selectedStatus: 'Status: All',
      selectedMembershipFilter: 'Membership: All',
    );
    fetchMembers(resetPage: true);
  }

  /// Sort and Pagination Setters
  void setSorting(String sortBy) {
    if (state.sortBy == sortBy) {
      final newOrder = state.sortOrder.toLowerCase() == 'asc' ? 'desc' : 'asc';
      state = state.copyWith(sortOrder: newOrder);
    } else {
      state = state.copyWith(sortBy: sortBy, sortOrder: 'asc');
    }
    fetchMembers(resetPage: true);
  }

  void setPage(int page) {
    if (page < 1 || page > state.totalPages || page == state.currentPage) return;
    state = state.copyWith(currentPage: page);
    fetchMembers();
  }

  void setPageSize(int size) {
    state = state.copyWith(pageSize: size);
    fetchMembers(resetPage: true);
  }

  /// Open Member Details Drawer
  Future<void> openMemberDetails(LibraryMemberModel member) async {
    state = state.copyWith(
      selectedMember: member,
      isDrawerOpen: true,
      selectedMemberBooks: const [],
      selectedMemberFines: const [],
      selectedMemberHistory: const [],
      selectedMemberAudits: const [],
    );

    try {
      final detail = await _apiService.fetchMemberDetail(member.id);
      state = state.copyWith(
        selectedMember: detail['member'] as LibraryMemberModel?,
        selectedMemberBooks: detail['current_books'] as List<MemberBorrowItemModel>,
        selectedMemberFines: detail['fines'] as List<MemberFineItemModel>,
        selectedMemberHistory: detail['history'] as List<MemberBorrowItemModel>,
        selectedMemberAudits: detail['audits'] as List<MemberAuditModel>,
        selectedMemberSummary: detail['summary'] as Map<String, dynamic>,
      );
    } catch (e) {
      // Retain basic member info if detail fetch fails
    }
  }

  void closeDrawer() {
    state = state.copyWith(isDrawerOpen: false, clearSelectedMember: true);
  }

  /// Multi-Row Selection Management
  void toggleMemberSelection(String memberId) {
    final set = Set<String>.from(state.selectedMemberIds);
    if (set.contains(memberId)) {
      set.remove(memberId);
    } else {
      set.add(memberId);
    }
    state = state.copyWith(selectedMemberIds: set);
  }

  void selectAllCurrentPage(bool selectAll) {
    if (selectAll) {
      final set = Set<String>.from(state.selectedMemberIds);
      set.addAll(state.members.map((e) => e.id));
      state = state.copyWith(selectedMemberIds: set);
    } else {
      final set = Set<String>.from(state.selectedMemberIds);
      for (final m in state.members) {
        set.remove(m.id);
      }
      state = state.copyWith(selectedMemberIds: set);
    }
  }

  void clearSelection() {
    state = state.copyWith(selectedMemberIds: const {});
  }

  /// Create Library Member
  Future<bool> createMember(Map<String, dynamic> data) async {
    state = state.copyWith(isActionLoading: true);
    try {
      final res = await _apiService.createMember(data);
      if (res['success'] == true || res['member_id'] != null) {
        state = state.copyWith(
          isActionLoading: false,
          successMessage: res['message']?.toString() ?? 'Library member created successfully.',
        );
        await Future.wait([fetchStats(), fetchMembers(resetPage: true)]);
        return true;
      } else {
        state = state.copyWith(
          isActionLoading: false,
          errorMessage: res['detail']?.toString() ?? res['message']?.toString() ?? 'Failed to create member.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  /// Update Library Member Parameters
  Future<bool> updateMember(String memberId, Map<String, dynamic> data) async {
    state = state.copyWith(isActionLoading: true);
    try {
      final res = await _apiService.updateMember(memberId, data);
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Member updated successfully.',
      );
      await Future.wait([fetchStats(), fetchMembers()]);
      if (state.selectedMember?.id == memberId) {
        openMemberDetails(state.selectedMember!);
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  /// Renew Membership
  Future<bool> renewMembership({
    required String memberId,
    required DateTime newExpiryDate,
    String? renewalPeriod,
    String? notes,
  }) async {
    state = state.copyWith(isActionLoading: true);
    try {
      final res = await _apiService.renewMembership(
        memberId: memberId,
        newExpiryDate: newExpiryDate,
        renewalPeriod: renewalPeriod,
        notes: notes,
      );
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Membership renewed successfully.',
      );
      await Future.wait([fetchStats(), fetchMembers()]);
      if (state.selectedMember?.id == memberId) {
        openMemberDetails(state.selectedMember!);
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  /// Suspend Member
  Future<bool> suspendMember(String memberId, {String? reason}) async {
    state = state.copyWith(isActionLoading: true);
    try {
      final res = await _apiService.suspendMember(memberId, reason: reason);
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Member suspended successfully.',
      );
      await Future.wait([fetchStats(), fetchMembers()]);
      if (state.selectedMember?.id == memberId) {
        openMemberDetails(state.selectedMember!);
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  /// Reactivate Member
  Future<bool> activateMember(String memberId) async {
    state = state.copyWith(isActionLoading: true);
    try {
      final res = await _apiService.activateMember(memberId);
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Member activated successfully.',
      );
      await Future.wait([fetchStats(), fetchMembers()]);
      if (state.selectedMember?.id == memberId) {
        openMemberDetails(state.selectedMember!);
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  /// Delete / Archive Member
  Future<bool> deleteMember(String memberId) async {
    state = state.copyWith(isActionLoading: true);
    try {
      final res = await _apiService.deleteMember(memberId);
      state = state.copyWith(
        isActionLoading: false,
        successMessage: res['message']?.toString() ?? 'Member deleted successfully.',
      );
      closeDrawer();
      await Future.wait([fetchStats(), fetchMembers()]);
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  /// Bulk Action
  Future<bool> executeBulkAction(String action, {Map<String, dynamic>? params}) async {
    if (state.selectedMemberIds.isEmpty) return false;
    state = state.copyWith(isActionLoading: true);
    try {
      final res = await _apiService.bulkAction(
        memberIds: state.selectedMemberIds.toList(),
        action: action,
        params: params,
      );
      state = state.copyWith(
        isActionLoading: false,
        selectedMemberIds: const {},
        successMessage: res['message']?.toString() ?? 'Bulk operation executed successfully.',
      );
      await Future.wait([fetchStats(), fetchMembers()]);
      return true;
    } catch (e) {
      state = state.copyWith(
        isActionLoading: false,
        errorMessage: e.toString().replaceAll('Exception:', '').trim(),
      );
      return false;
    }
  }

  void setViewMode(String mode) {
    state = state.copyWith(viewMode: mode);
  }

  void clearNotifications() {
    state = state.copyWith(clearMessages: true);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

final memberApiServiceProvider = Provider<MemberApiService>((ref) => MemberApiService());

final memberProvider = StateNotifierProvider<MemberNotifier, MemberState>((ref) {
  final apiService = ref.watch(memberApiServiceProvider);
  return MemberNotifier(apiService);
});
