import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/hostel_models.dart';
import '../models/hostel_fee_models.dart';
import '../models/hostel_leave_outing_models.dart';
import '../models/hostel_complaint_models.dart';
import '../services/hostel_api_service.dart';
import '../services/hostel_fee_service.dart';
import '../services/hostel_leave_service.dart';
import '../services/hostel_complaint_service.dart';
import '../services/hostel_lookup_helper.dart';
import '../../../utils/download_helper.dart';

class HostelState {
  final int activeTab; // 0: Overview, 1: Rooms & Allocation, 2: Hostel Students, 3: Staff Management, 4: Fees & Billing
  final String selectedAcademicYear;
  final HostelKPIs kpis;
  final List<HostelBuilding> structureTree;
  final List<HostelRoomItem> rooms;
  final Map<String, dynamic> pagination;
  final int roomsPageSize;
  final String roomsSortBy;
  final String roomsSortOrder;
  final String contextTitle;
  final String? selectedBuildingId;
  final String? selectedFloorId;
  final String? selectedRoomId;
  final HostelRoomDetail? selectedRoomDetail;
  final int inspectorTab; // 0: Facilities, 1: Students, 2: Maintenance, 3: History
  final String searchQuery;
  final String hostelFilter;
  final String floorFilter;
  final String roomTypeFilter;
  final String statusFilter;
  final HostelFilterOptions filterOptions;
  final bool isLoading;
  final bool isTreeLoading;
  final bool isDetailLoading;
  final String? errorMessage;
  final String? successMessage;

  // Hostel Students Module State
  final HostelStudentsKPIs studentsKPIs;
  final List<HostelStudentRosterItem> studentsRoster;
  final HostelStudentRosterPagination studentsPagination;
  final String? selectedStudentId;
  final HostelStudentDetail360? selectedStudentDetail;
  final bool isStudentsLoading;
  final bool isStudentDetailLoading;
  final String studentsSearch;
  final String studentsHostelFilter;
  final String studentsClassFilter;
  final String studentsStatusFilter;
  final String studentsFeeStatusFilter;
  final DateTimeRange? selectedDateRange;
  final Set<String> selectedStudentRosterIds;
  final int studentsPageSize;
  final String studentsSortBy;
  final String studentsSortOrder;
  final int studentDrawerTab; // 0: Overview, 1: Details, 2: Fees, 3: Leave/Outing, 4: Documents

  // Hostel Staff Module State
  final HostelStaffKPIs staffKPIs;
  final List<HostelStaffRosterItem> staffRoster;
  final HostelStaffRosterPagination staffPagination;
  final String? selectedStaffAssignmentId;
  final HostelStaffDetail360? selectedStaffDetail;
  final bool isStaffLoading;
  final bool isStaffDetailLoading;
  final String staffSearch;
  final String staffHostelFilter;
  final String staffRoleFilter;
  final String staffStatusFilter;
  final DateTime? staffJoinedDateFilter;
  final Set<String> selectedStaffAssignmentIds;
  final String staffSortBy;
  final String staffSortOrder;
  final int staffDrawerTab; // 0: Overview, 1: Assignment, 2: Leave, 3: Documents, 4: History
  final bool isStaffDrawerOpen;

  // Hostel Fees & Billing Module State
  final HostelFeeKPIs feesKPIs;
  final HostelFeeSummaryDonut feeSummaryDonut;
  final List<HostelUpcomingInvoiceItem> upcomingInvoices;
  final List<HostelRecentPaymentItem> recentPayments;
  final List<HostelStudentFeeItem> studentFeesRoster;
  final HostelFeeRosterPagination feesPagination;
  final String? selectedFeeStudentId;
  final HostelStudentFeeDetail360? selectedFeeStudentDetail;
  final bool isFeesLoading;
  final bool isFeeDetailLoading;
  final String feesSearch;
  final String feesHostelFilter;
  final String feesClassFilter;
  final String feesStatusFilter;
  final DateTimeRange? feesDateRange;
  final Set<String> selectedFeeAccountIds;
  final int feesPageSize;
  final String? feesSortBy;
  final String feesSortOrder;
  final int feesSubTab; // 0: Student Fees, 1: Invoices, 2: Payments, 3: Fee Structure, 4: Discounts & Concessions, 5: Reports
  final int feeDrawerTab; // 0: Overview, 1: Fee Breakdown, 2: Invoices, 3: Payments, 4: Ledger, 5: Concessions, 6: History
  final bool isFeeDrawerOpen;
  final List<HostelFeePlanModel> feePlans;
  final Map<String, dynamic> feePlansPagination;
  final String feePlansSortBy;
  final String feePlansSortOrder;
  final int feePlansPageSize;
  final List<HostelInvoiceItemModel> invoicesList;
  final Map<String, dynamic> invoicesPagination;
  final String invoicesSortBy;
  final String invoicesSortOrder;
  final int invoicesPageSize;
  final List<HostelPaymentReceiptModel> paymentsList;
  final Map<String, dynamic> paymentsPagination;
  final String paymentsSortBy;
  final String paymentsSortOrder;
  final int paymentsPageSize;
  final List<Map<String, dynamic>> refundsList;
  final Map<String, dynamic> refundsPagination;
  final String refundsSortBy;
  final String refundsSortOrder;
  final int refundsPageSize;

  // Hostel Leave & Outing Module State
  final LeaveOutingKpiData leaveKpis;
  final List<LeaveOutingRequestItem> leaveRequests;
  final Map<String, dynamic> leavePagination;
  final LeaveOutingRequestItem? selectedLeaveRequest;
  final bool isLeaveLoading;
  final int leaveSubTab; // 0: Requests, 1: Gate Pass
  final String leaveSearchQuery;
  final String leaveHostelFilter;
  final String leaveTypeFilter;
  final String leaveStatusFilter;
  final DateTimeRange? leaveDateRange;
  final String leaveSortBy;
  final String leaveSortOrder;
  final List<AwaitingApprovalItem> awaitingApprovalList;
  final List<LeaveOutingRequestItem> currentlyOutList;
  final List<GatePassData> gatePassesList;
  final Map<String, dynamic> gatePassesPagination;
  final String gatePassesSortBy;
  final String gatePassesSortOrder;
  final bool isGatePassesLoading;
  final LeaveOutingSettingsData leaveSettings;
  final bool isLeaveDrawerOpen;

  // Hostel Complaints Module State
  final ComplaintKpiData complaintKpis;
  final List<HostelComplaintItem> complaintsList;
  final ComplaintPagination complaintsPagination;
  final String? selectedComplaintId;
  final HostelComplaintDetail360? selectedComplaintDetail;
  final bool isComplaintsLoading;
  final bool isComplaintDetailLoading;
  final String complaintsSearch;
  final String complaintsHostelFilter;
  final String complaintsCategoryFilter;
  final String complaintsPriorityFilter;
  final String complaintsStatusFilter;
  final String complaintsSubtab;
  final DateTimeRange? complaintsDateRange;
  final Set<String> selectedComplaintIds;
  final String complaintsSortBy;
  final String complaintsSortOrder;
  final int complaintDrawerTab; // 0: Overview, 1: Updates, 2: Assign & Resolve, 3: Attachments
  final bool isComplaintDrawerOpen;

  // Overview Module State (Tab 0)
  final Map<String, dynamic> overviewData;
  final bool isOverviewLoading;

  // Reports Module State (Tab 8)
  final Map<String, dynamic> reportsData;
  final bool isReportsLoading;
  final String selectedReportType;
  final DateTime? reportsStartDate;
  final DateTime? reportsEndDate;
  final Map<String, dynamic>? turnoverForecast;
  final bool isTurnoverForecastLoading;
  final List<String> schoolClasses;
  final List<String> availableAcademicYears;

  HostelState({
    this.activeTab = 0, // Default to Tab 0: Overview Dashboard
    this.selectedAcademicYear = '2026 - 2027',
    this.availableAcademicYears = const ['2024 - 2025', '2025 - 2026', '2026 - 2027'],
    required this.kpis,
    this.structureTree = const [],
    this.rooms = const [],
    this.pagination = const {'total_records': 0, 'page': 1, 'page_size': 10, 'total_pages': 1},
    this.roomsPageSize = 10,
    this.roomsSortBy = 'room_number',
    this.roomsSortOrder = 'ASC',
    this.contextTitle = 'Rooms',
    this.selectedBuildingId,
    this.selectedFloorId,
    this.selectedRoomId,
    this.selectedRoomDetail,
    this.inspectorTab = 0,
    this.searchQuery = '',
    this.hostelFilter = 'All Hostels',
    this.floorFilter = 'All Floors',
    this.roomTypeFilter = 'All Room Types',
    this.statusFilter = 'All Status',
    required this.filterOptions,
    this.isLoading = false,
    this.isTreeLoading = false,
    this.isDetailLoading = false,
    this.errorMessage,
    this.successMessage,

    // Overview Module defaults
    this.overviewData = const {},
    this.isOverviewLoading = false,

    // Reports Module defaults
    this.reportsData = const {},
    this.isReportsLoading = false,
    this.selectedReportType = 'occupancy',
    this.reportsStartDate,
    this.reportsEndDate,
    this.turnoverForecast,
    this.isTurnoverForecastLoading = false,
    this.schoolClasses = const [],

    // Hostel Students Module defaults
    required this.studentsKPIs,
    this.studentsRoster = const [],
    required this.studentsPagination,
    this.selectedStudentId,
    this.selectedStudentDetail,
    this.isStudentsLoading = false,
    this.isStudentDetailLoading = false,
    this.studentsSearch = '',
    this.studentsHostelFilter = 'All Hostels',
    this.studentsClassFilter = 'All Classes',
    this.studentsStatusFilter = 'All Status',
    this.studentsFeeStatusFilter = 'All Fees',
    this.selectedDateRange,
    this.selectedStudentRosterIds = const {},
    this.studentsPageSize = 10,
    this.studentsSortBy = 'student_name',
    this.studentsSortOrder = 'ASC',
    this.studentDrawerTab = 0,

    // Hostel Staff Module defaults
    required this.staffKPIs,
    this.staffRoster = const [],
    required this.staffPagination,
    this.selectedStaffAssignmentId,
    this.selectedStaffDetail,
    this.isStaffLoading = false,
    this.isStaffDetailLoading = false,
    this.staffSearch = '',
    this.staffHostelFilter = 'All Hostels',
    this.staffRoleFilter = 'All Roles',
    this.staffStatusFilter = 'All Status',
    this.staffJoinedDateFilter,
    this.selectedStaffAssignmentIds = const {},
    this.staffSortBy = 'default',
    this.staffSortOrder = 'ASC',
    this.staffDrawerTab = 0,
    this.isStaffDrawerOpen = false,

    // Hostel Fees & Billing Module defaults
    required this.feesKPIs,
    required this.feeSummaryDonut,
    this.upcomingInvoices = const [],
    this.recentPayments = const [],
    this.studentFeesRoster = const [],
    required this.feesPagination,
    this.selectedFeeStudentId,
    this.selectedFeeStudentDetail,
    this.isFeesLoading = false,
    this.isFeeDetailLoading = false,
    this.feesSearch = '',
    this.feesHostelFilter = 'All Hostels',
    this.feesClassFilter = 'All Classes',
    this.feesStatusFilter = 'All Status',
    this.feesDateRange,
    this.selectedFeeAccountIds = const {},
    this.feesPageSize = 10,
    this.feesSortBy,
    this.feesSortOrder = 'ASC',
    this.feesSubTab = 0,
    this.feeDrawerTab = 0,
    this.isFeeDrawerOpen = false,
    this.feePlans = const [],
    this.feePlansPagination = const {'total_records': 0, 'page': 1, 'page_size': 10, 'total_pages': 1},
    this.feePlansSortBy = 'name',
    this.feePlansSortOrder = 'ASC',
    this.feePlansPageSize = 10,
    this.invoicesList = const [],
    this.invoicesPagination = const {'total_records': 0, 'page': 1, 'page_size': 10, 'total_pages': 1},
    this.invoicesSortBy = 'invoice_date',
    this.invoicesSortOrder = 'DESC',
    this.invoicesPageSize = 10,
    this.paymentsList = const [],
    this.paymentsPagination = const {'total_records': 0, 'page': 1, 'page_size': 10, 'total_pages': 1},
    this.paymentsSortBy = 'payment_date',
    this.paymentsSortOrder = 'DESC',
    this.paymentsPageSize = 10,
    this.refundsList = const [],
    this.refundsPagination = const {'total_records': 0, 'page': 1, 'page_size': 10, 'total_pages': 1},
    this.refundsSortBy = 'created_at',
    this.refundsSortOrder = 'DESC',
    this.refundsPageSize = 10,

    // Hostel Leave & Outing Module defaults
    required this.leaveKpis,
    this.leaveRequests = const [],
    this.leavePagination = const {'total': 0, 'page': 1, 'page_size': 10, 'total_pages': 1},
    this.selectedLeaveRequest,
    this.isLeaveLoading = false,
    this.leaveSubTab = 0,
    this.leaveSearchQuery = '',
    this.leaveHostelFilter = 'All Hostels',
    this.leaveTypeFilter = 'All Types',
    this.leaveStatusFilter = 'All Status',
    this.leaveDateRange,
    this.leaveSortBy = 'request_number',
    this.leaveSortOrder = 'ASC',
    this.awaitingApprovalList = const [],
    this.currentlyOutList = const [],
    this.gatePassesList = const [],
    this.gatePassesPagination = const {'total': 0, 'page': 1, 'page_size': 10, 'total_pages': 1},
    this.gatePassesSortBy = 'generated_at',
    this.gatePassesSortOrder = 'DESC',
    this.isGatePassesLoading = false,
    required this.leaveSettings,
    this.isLeaveDrawerOpen = false,

    // Hostel Complaints Module defaults
    this.complaintKpis = const ComplaintKpiData(),
    this.complaintsList = const [],
    this.complaintsPagination = const ComplaintPagination(),
    this.selectedComplaintId,
    this.selectedComplaintDetail,
    this.isComplaintsLoading = false,
    this.isComplaintDetailLoading = false,
    this.complaintsSearch = '',
    this.complaintsHostelFilter = 'All Hostels',
    this.complaintsCategoryFilter = 'All Categories',
    this.complaintsPriorityFilter = 'All Priorities',
    this.complaintsStatusFilter = 'All Status',
    this.complaintsSubtab = 'All Complaints',
    this.complaintsDateRange,
    this.selectedComplaintIds = const {},
    this.complaintsSortBy = 'created_at',
    this.complaintsSortOrder = 'desc',
    this.complaintDrawerTab = 0,
    this.isComplaintDrawerOpen = false,
  });

  factory HostelState.initial() => HostelState(
        kpis: HostelKPIs(),
        filterOptions: HostelFilterOptions(),
        studentsKPIs: HostelStudentsKPIs(),
        studentsPagination: HostelStudentRosterPagination(),
        staffKPIs: HostelStaffKPIs(),
        staffPagination: HostelStaffRosterPagination(),
        feesKPIs: HostelFeeKPIs(),
        feeSummaryDonut: HostelFeeSummaryDonut(),
        feesPagination: HostelFeeRosterPagination(),
        leaveKpis: const LeaveOutingKpiData(),
        leaveSettings: const LeaveOutingSettingsData(),
        complaintKpis: const ComplaintKpiData(),
        complaintsPagination: const ComplaintPagination(),
      );

  HostelState copyWith({
    int? activeTab,
    String? selectedAcademicYear,
    List<String>? availableAcademicYears,
    HostelKPIs? kpis,
    List<HostelBuilding>? structureTree,
    List<HostelRoomItem>? rooms,
    Map<String, dynamic>? pagination,
    int? roomsPageSize,
    String? roomsSortBy,
    String? roomsSortOrder,
    String? contextTitle,
    String? selectedBuildingId,
    String? selectedFloorId,
    String? selectedRoomId,
    HostelRoomDetail? selectedRoomDetail,
    int? inspectorTab,
    String? searchQuery,
    String? hostelFilter,
    String? floorFilter,
    String? roomTypeFilter,
    String? statusFilter,
    HostelFilterOptions? filterOptions,
    bool? isLoading,
    bool? isTreeLoading,
    bool? isDetailLoading,
    String? errorMessage,
    String? successMessage,
    bool clearSelectedFloor = false,
    bool clearSelectedBuilding = false,
    bool clearSelectedRoom = false,

    // Students Module fields
    HostelStudentsKPIs? studentsKPIs,
    List<HostelStudentRosterItem>? studentsRoster,
    HostelStudentRosterPagination? studentsPagination,
    String? selectedStudentId,
    HostelStudentDetail360? selectedStudentDetail,
    bool? isStudentsLoading,
    bool? isStudentDetailLoading,
    String? studentsSearch,
    String? studentsHostelFilter,
    String? studentsClassFilter,
    String? studentsStatusFilter,
    String? studentsFeeStatusFilter,
    DateTimeRange? selectedDateRange,
    Set<String>? selectedStudentRosterIds,
    int? studentsPageSize,
    String? studentsSortBy,
    String? studentsSortOrder,
    int? studentDrawerTab,
    bool clearSelectedStudent = false,

    // Staff Module fields
    HostelStaffKPIs? staffKPIs,
    List<HostelStaffRosterItem>? staffRoster,
    HostelStaffRosterPagination? staffPagination,
    String? selectedStaffAssignmentId,
    HostelStaffDetail360? selectedStaffDetail,
    bool? isStaffLoading,
    bool? isStaffDetailLoading,
    String? staffSearch,
    String? staffHostelFilter,
    String? staffRoleFilter,
    String? staffStatusFilter,
    DateTime? staffJoinedDateFilter,
    Set<String>? selectedStaffAssignmentIds,
    String? staffSortBy,
    String? staffSortOrder,
    int? staffDrawerTab,
    bool? isStaffDrawerOpen,
    bool clearSelectedStaff = false,

    // Hostel Fees & Billing Module fields
    HostelFeeKPIs? feesKPIs,
    HostelFeeSummaryDonut? feeSummaryDonut,
    List<HostelUpcomingInvoiceItem>? upcomingInvoices,
    List<HostelRecentPaymentItem>? recentPayments,
    List<HostelStudentFeeItem>? studentFeesRoster,
    HostelFeeRosterPagination? feesPagination,
    String? selectedFeeStudentId,
    HostelStudentFeeDetail360? selectedFeeStudentDetail,
    bool? isFeesLoading,
    bool? isFeeDetailLoading,
    String? feesSearch,
    String? feesHostelFilter,
    String? feesClassFilter,
    String? feesStatusFilter,
    DateTimeRange? feesDateRange,
    Set<String>? selectedFeeAccountIds,
    int? feesPageSize,
    String? feesSortBy,
    String? feesSortOrder,
    int? feesSubTab,
    int? feeDrawerTab,
    bool? isFeeDrawerOpen,
    List<HostelFeePlanModel>? feePlans,
    Map<String, dynamic>? feePlansPagination,
    String? feePlansSortBy,
    String? feePlansSortOrder,
    int? feePlansPageSize,
    List<HostelInvoiceItemModel>? invoicesList,
    Map<String, dynamic>? invoicesPagination,
    String? invoicesSortBy,
    String? invoicesSortOrder,
    int? invoicesPageSize,
    List<HostelPaymentReceiptModel>? paymentsList,
    Map<String, dynamic>? paymentsPagination,
    String? paymentsSortBy,
    String? paymentsSortOrder,
    int? paymentsPageSize,
    List<Map<String, dynamic>>? refundsList,
    Map<String, dynamic>? refundsPagination,
    String? refundsSortBy,
    String? refundsSortOrder,
    int? refundsPageSize,
    bool clearSelectedFeeStudent = false,

    // Hostel Leave & Outing Module fields
    LeaveOutingKpiData? leaveKpis,
    List<LeaveOutingRequestItem>? leaveRequests,
    Map<String, dynamic>? leavePagination,
    LeaveOutingRequestItem? selectedLeaveRequest,
    bool? isLeaveLoading,
    int? leaveSubTab,
    String? leaveSearchQuery,
    String? leaveHostelFilter,
    String? leaveTypeFilter,
    String? leaveStatusFilter,
    DateTimeRange? leaveDateRange,
    bool clearLeaveDateRange = false,
    String? leaveSortBy,
    String? leaveSortOrder,
    List<AwaitingApprovalItem>? awaitingApprovalList,
    List<LeaveOutingRequestItem>? currentlyOutList,
    List<GatePassData>? gatePassesList,
    Map<String, dynamic>? gatePassesPagination,
    String? gatePassesSortBy,
    String? gatePassesSortOrder,
    bool? isGatePassesLoading,
    LeaveOutingSettingsData? leaveSettings,
    bool? isLeaveDrawerOpen,
    bool clearSelectedLeaveRequest = false,

    // Hostel Complaints Module fields
    ComplaintKpiData? complaintKpis,
    List<HostelComplaintItem>? complaintsList,
    ComplaintPagination? complaintsPagination,
    String? selectedComplaintId,
    HostelComplaintDetail360? selectedComplaintDetail,
    bool? isComplaintsLoading,
    bool? isComplaintDetailLoading,
    String? complaintsSearch,
    String? complaintsHostelFilter,
    String? complaintsCategoryFilter,
    String? complaintsPriorityFilter,
    String? complaintsStatusFilter,
    String? complaintsSubtab,
    DateTimeRange? complaintsDateRange,
    Set<String>? selectedComplaintIds,
    String? complaintsSortBy,
    String? complaintsSortOrder,
    int? complaintDrawerTab,
    bool? isComplaintDrawerOpen,
    bool clearSelectedComplaint = false,
    bool clearComplaintsDateRange = false,
    bool clearReportDates = false,

    // Overview & Reports Module fields
    Map<String, dynamic>? overviewData,
    bool? isOverviewLoading,
    Map<String, dynamic>? reportsData,
    bool? isReportsLoading,
    String? selectedReportType,
    DateTime? reportsStartDate,
    DateTime? reportsEndDate,
    Map<String, dynamic>? turnoverForecast,
    bool? isTurnoverForecastLoading,
    List<String>? schoolClasses,
  }) {
    return HostelState(
      activeTab: activeTab ?? this.activeTab,
      selectedAcademicYear: selectedAcademicYear ?? this.selectedAcademicYear,
      availableAcademicYears: availableAcademicYears ?? this.availableAcademicYears,
      kpis: kpis ?? this.kpis,
      structureTree: structureTree ?? this.structureTree,
      rooms: rooms ?? this.rooms,
      pagination: pagination ?? this.pagination,
      roomsPageSize: roomsPageSize ?? this.roomsPageSize,
      roomsSortBy: roomsSortBy ?? this.roomsSortBy,
      roomsSortOrder: roomsSortOrder ?? this.roomsSortOrder,
      contextTitle: contextTitle ?? this.contextTitle,
      selectedBuildingId: clearSelectedBuilding ? null : (selectedBuildingId ?? this.selectedBuildingId),
      selectedFloorId: clearSelectedFloor ? null : (selectedFloorId ?? this.selectedFloorId),
      selectedRoomId: clearSelectedRoom ? null : (selectedRoomId ?? this.selectedRoomId),
      selectedRoomDetail: clearSelectedRoom ? null : (selectedRoomDetail ?? this.selectedRoomDetail),
      inspectorTab: inspectorTab ?? this.inspectorTab,
      searchQuery: searchQuery ?? this.searchQuery,
      hostelFilter: hostelFilter ?? this.hostelFilter,
      floorFilter: floorFilter ?? this.floorFilter,
      roomTypeFilter: roomTypeFilter ?? this.roomTypeFilter,
      statusFilter: statusFilter ?? this.statusFilter,
      filterOptions: filterOptions ?? this.filterOptions,
      isLoading: isLoading ?? this.isLoading,
      isTreeLoading: isTreeLoading ?? this.isTreeLoading,
      isDetailLoading: isDetailLoading ?? this.isDetailLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,

      // Students
      studentsKPIs: studentsKPIs ?? this.studentsKPIs,
      studentsRoster: studentsRoster ?? this.studentsRoster,
      studentsPagination: studentsPagination ?? this.studentsPagination,
      selectedStudentId: clearSelectedStudent ? null : (selectedStudentId ?? this.selectedStudentId),
      selectedStudentDetail: clearSelectedStudent ? null : (selectedStudentDetail ?? this.selectedStudentDetail),
      isStudentsLoading: isStudentsLoading ?? this.isStudentsLoading,
      isStudentDetailLoading: isStudentDetailLoading ?? this.isStudentDetailLoading,
      studentsSearch: studentsSearch ?? this.studentsSearch,
      studentsHostelFilter: studentsHostelFilter ?? this.studentsHostelFilter,
      studentsClassFilter: studentsClassFilter ?? this.studentsClassFilter,
      studentsStatusFilter: studentsStatusFilter ?? this.studentsStatusFilter,
      studentsFeeStatusFilter: studentsFeeStatusFilter ?? this.studentsFeeStatusFilter,
      selectedDateRange: selectedDateRange ?? this.selectedDateRange,
      selectedStudentRosterIds: selectedStudentRosterIds ?? this.selectedStudentRosterIds,
      studentsPageSize: studentsPageSize ?? this.studentsPageSize,
      studentsSortBy: studentsSortBy ?? this.studentsSortBy,
      studentsSortOrder: studentsSortOrder ?? this.studentsSortOrder,
      studentDrawerTab: studentDrawerTab ?? this.studentDrawerTab,

      // Staff
      staffKPIs: staffKPIs ?? this.staffKPIs,
      staffRoster: staffRoster ?? this.staffRoster,
      staffPagination: staffPagination ?? this.staffPagination,
      selectedStaffAssignmentId: clearSelectedStaff ? null : (selectedStaffAssignmentId ?? this.selectedStaffAssignmentId),
      selectedStaffDetail: clearSelectedStaff ? null : (selectedStaffDetail ?? this.selectedStaffDetail),
      isStaffLoading: isStaffLoading ?? this.isStaffLoading,
      isStaffDetailLoading: isStaffDetailLoading ?? this.isStaffDetailLoading,
      staffSearch: staffSearch ?? this.staffSearch,
      staffHostelFilter: staffHostelFilter ?? this.staffHostelFilter,
      staffRoleFilter: staffRoleFilter ?? this.staffRoleFilter,
      staffStatusFilter: staffStatusFilter ?? this.staffStatusFilter,
      staffJoinedDateFilter: staffJoinedDateFilter ?? this.staffJoinedDateFilter,
      selectedStaffAssignmentIds: selectedStaffAssignmentIds ?? this.selectedStaffAssignmentIds,
      staffSortBy: staffSortBy ?? this.staffSortBy,
      staffSortOrder: staffSortOrder ?? this.staffSortOrder,
      staffDrawerTab: staffDrawerTab ?? this.staffDrawerTab,
      isStaffDrawerOpen: isStaffDrawerOpen ?? this.isStaffDrawerOpen,

      // Fees & Billing
      feesKPIs: feesKPIs ?? this.feesKPIs,
      feeSummaryDonut: feeSummaryDonut ?? this.feeSummaryDonut,
      upcomingInvoices: upcomingInvoices ?? this.upcomingInvoices,
      recentPayments: recentPayments ?? this.recentPayments,
      studentFeesRoster: studentFeesRoster ?? this.studentFeesRoster,
      feesPagination: feesPagination ?? this.feesPagination,
      selectedFeeStudentId: clearSelectedFeeStudent ? null : (selectedFeeStudentId ?? this.selectedFeeStudentId),
      selectedFeeStudentDetail: clearSelectedFeeStudent ? null : (selectedFeeStudentDetail ?? this.selectedFeeStudentDetail),
      isFeesLoading: isFeesLoading ?? this.isFeesLoading,
      isFeeDetailLoading: isFeeDetailLoading ?? this.isFeeDetailLoading,
      feesSearch: feesSearch ?? this.feesSearch,
      feesHostelFilter: feesHostelFilter ?? this.feesHostelFilter,
      feesClassFilter: feesClassFilter ?? this.feesClassFilter,
      feesStatusFilter: feesStatusFilter ?? this.feesStatusFilter,
      feesDateRange: feesDateRange ?? this.feesDateRange,
      selectedFeeAccountIds: selectedFeeAccountIds ?? this.selectedFeeAccountIds,
      feesPageSize: feesPageSize ?? this.feesPageSize,
      feesSortBy: feesSortBy ?? this.feesSortBy,
      feesSortOrder: feesSortOrder ?? this.feesSortOrder,
      feesSubTab: feesSubTab ?? this.feesSubTab,
      feeDrawerTab: feeDrawerTab ?? this.feeDrawerTab,
      isFeeDrawerOpen: isFeeDrawerOpen ?? this.isFeeDrawerOpen,
      feePlans: feePlans ?? this.feePlans,
      feePlansPagination: feePlansPagination ?? this.feePlansPagination,
      feePlansSortBy: feePlansSortBy ?? this.feePlansSortBy,
      feePlansSortOrder: feePlansSortOrder ?? this.feePlansSortOrder,
      feePlansPageSize: feePlansPageSize ?? this.feePlansPageSize,
      invoicesList: invoicesList ?? this.invoicesList,
      invoicesPagination: invoicesPagination ?? this.invoicesPagination,
      invoicesSortBy: invoicesSortBy ?? this.invoicesSortBy,
      invoicesSortOrder: invoicesSortOrder ?? this.invoicesSortOrder,
      invoicesPageSize: invoicesPageSize ?? this.invoicesPageSize,
      paymentsList: paymentsList ?? this.paymentsList,
      paymentsPagination: paymentsPagination ?? this.paymentsPagination,
      paymentsSortBy: paymentsSortBy ?? this.paymentsSortBy,
      paymentsSortOrder: paymentsSortOrder ?? this.paymentsSortOrder,
      paymentsPageSize: paymentsPageSize ?? this.paymentsPageSize,
      refundsList: refundsList ?? this.refundsList,
      refundsPagination: refundsPagination ?? this.refundsPagination,
      refundsSortBy: refundsSortBy ?? this.refundsSortBy,
      refundsSortOrder: refundsSortOrder ?? this.refundsSortOrder,
      refundsPageSize: refundsPageSize ?? this.refundsPageSize,

      // Leave & Outing
      leaveKpis: leaveKpis ?? this.leaveKpis,
      leaveRequests: leaveRequests ?? this.leaveRequests,
      leavePagination: leavePagination ?? this.leavePagination,
      selectedLeaveRequest: clearSelectedLeaveRequest ? null : (selectedLeaveRequest ?? this.selectedLeaveRequest),
      isLeaveLoading: isLeaveLoading ?? this.isLeaveLoading,
      leaveSubTab: leaveSubTab ?? this.leaveSubTab,
      leaveSearchQuery: leaveSearchQuery ?? this.leaveSearchQuery,
      leaveHostelFilter: leaveHostelFilter ?? this.leaveHostelFilter,
      leaveTypeFilter: leaveTypeFilter ?? this.leaveTypeFilter,
      leaveStatusFilter: leaveStatusFilter ?? this.leaveStatusFilter,
      leaveDateRange: clearLeaveDateRange ? null : (leaveDateRange ?? this.leaveDateRange),
      leaveSortBy: leaveSortBy ?? this.leaveSortBy,
      leaveSortOrder: leaveSortOrder ?? this.leaveSortOrder,
      awaitingApprovalList: awaitingApprovalList ?? this.awaitingApprovalList,
      currentlyOutList: currentlyOutList ?? this.currentlyOutList,
      gatePassesList: gatePassesList ?? this.gatePassesList,
      gatePassesPagination: gatePassesPagination ?? this.gatePassesPagination,
      gatePassesSortBy: gatePassesSortBy ?? this.gatePassesSortBy,
      gatePassesSortOrder: gatePassesSortOrder ?? this.gatePassesSortOrder,
      isGatePassesLoading: isGatePassesLoading ?? this.isGatePassesLoading,
      leaveSettings: leaveSettings ?? this.leaveSettings,
      isLeaveDrawerOpen: isLeaveDrawerOpen ?? this.isLeaveDrawerOpen,

      // Complaints
      complaintKpis: complaintKpis ?? this.complaintKpis,
      complaintsList: complaintsList ?? this.complaintsList,
      complaintsPagination: complaintsPagination ?? this.complaintsPagination,
      selectedComplaintId: clearSelectedComplaint ? null : (selectedComplaintId ?? this.selectedComplaintId),
      selectedComplaintDetail: clearSelectedComplaint ? null : (selectedComplaintDetail ?? this.selectedComplaintDetail),
      isComplaintsLoading: isComplaintsLoading ?? this.isComplaintsLoading,
      isComplaintDetailLoading: isComplaintDetailLoading ?? this.isComplaintDetailLoading,
      complaintsSearch: complaintsSearch ?? this.complaintsSearch,
      complaintsHostelFilter: complaintsHostelFilter ?? this.complaintsHostelFilter,
      complaintsCategoryFilter: complaintsCategoryFilter ?? this.complaintsCategoryFilter,
      complaintsPriorityFilter: complaintsPriorityFilter ?? this.complaintsPriorityFilter,
      complaintsStatusFilter: complaintsStatusFilter ?? this.complaintsStatusFilter,
      complaintsSubtab: complaintsSubtab ?? this.complaintsSubtab,
      complaintsDateRange: clearComplaintsDateRange ? null : (complaintsDateRange ?? this.complaintsDateRange),
      selectedComplaintIds: selectedComplaintIds ?? this.selectedComplaintIds,
      complaintsSortBy: complaintsSortBy ?? this.complaintsSortBy,
      complaintsSortOrder: complaintsSortOrder ?? this.complaintsSortOrder,
      complaintDrawerTab: complaintDrawerTab ?? this.complaintDrawerTab,
      isComplaintDrawerOpen: isComplaintDrawerOpen ?? this.isComplaintDrawerOpen,
      overviewData: overviewData ?? this.overviewData,
      isOverviewLoading: isOverviewLoading ?? this.isOverviewLoading,
      reportsData: reportsData ?? this.reportsData,
      isReportsLoading: isReportsLoading ?? this.isReportsLoading,
      selectedReportType: selectedReportType ?? this.selectedReportType,
      reportsStartDate: clearReportDates ? null : (reportsStartDate ?? this.reportsStartDate),
      reportsEndDate: clearReportDates ? null : (reportsEndDate ?? this.reportsEndDate),
      turnoverForecast: turnoverForecast ?? this.turnoverForecast,
      isTurnoverForecastLoading: isTurnoverForecastLoading ?? this.isTurnoverForecastLoading,
      schoolClasses: schoolClasses ?? this.schoolClasses,
    );
  }
}

class HostelNotifier extends StateNotifier<HostelState> {
  final HostelApiService _service = HostelApiService();
  final HostelFeeService _feeService = HostelFeeService();
  final HostelLeaveService _leaveService = HostelLeaveService();
  final HostelComplaintService _complaintService = HostelComplaintService();
  HostelApiService get service => _service;
  HostelFeeService get feeService => _feeService;
  HostelLeaveService get leaveService => _leaveService;
  HostelComplaintService get complaintService => _complaintService;

  HostelNotifier() : super(HostelState.initial()) {
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    state = state.copyWith(isLoading: true, isTreeLoading: true);
    // Dynamically load academic years from lookups DB
    HostelLookupHelper.instance.getLookupLabels('ACADEMIC_YEAR').then((years) {
      if (years.isNotEmpty) {
        state = state.copyWith(availableAcademicYears: years);
      }
    }).catchError((_) {});

    // Also load overview, students, staff, fees, leave, complaints and reports data in parallel
    loadOverviewData();
    loadStudentsData();
    loadStaffData();
    loadFeesData();
    loadLeaveOutingData();
    loadComplaintsData();
    loadReportsData();

    try {
      final kpisFuture = _service.getKPIs(academicYear: state.selectedAcademicYear);
      final treeFuture = _service.getStructureTree();
      final filterOptsFuture = _service.getFilterOptions();

      final results = await Future.wait([kpisFuture, treeFuture, filterOptsFuture]);
      final kpis = results[0] as HostelKPIs;
      final tree = results[1] as List<HostelBuilding>;
      final filterOpts = results[2] as HostelFilterOptions;

      String? autoBId;
      String? autoFId;

      // Auto-select 1st Floor of Boys Hostel A if present (matching screenshot)
      if (tree.isNotEmpty) {
        final bha = tree.firstWhere(
          (b) => b.name.contains('Boys Hostel A'),
          orElse: () => tree.first,
        );
        autoBId = bha.id;
        if (bha.floors.isNotEmpty) {
          final f1 = bha.floors.firstWhere(
            (f) => f.floorNumber == 1,
            orElse: () => bha.floors.first,
          );
          autoFId = f1.id;
        }
      }

      state = state.copyWith(
        kpis: kpis,
        structureTree: tree,
        filterOptions: filterOpts,
        selectedBuildingId: autoBId,
        selectedFloorId: autoFId,
        isTreeLoading: false,
      );

      await fetchRooms();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isTreeLoading: false,
        errorMessage: 'Failed to load hostel data: $e',
      );
    }
  }

  Future<void> fetchRooms({int page = 1}) async {
    state = state.copyWith(isLoading: true);
    try {
      final res = await _service.getRooms(
        search: state.searchQuery,
        buildingId: state.selectedBuildingId,
        floorId: state.selectedFloorId,
        roomType: state.roomTypeFilter == 'All Room Types' ? 'ALL' : state.roomTypeFilter,
        status: state.statusFilter == 'All Status' ? 'ALL' : state.statusFilter,
        page: page,
        pageSize: state.roomsPageSize,
        sortBy: state.roomsSortBy,
        sortOrder: state.roomsSortOrder,
      );

      final roomsList = res['rooms'] as List<HostelRoomItem>;
      final pagination = res['pagination'] as Map<String, dynamic>;
      final contextTitle = res['context_title'] as String;

      // Auto-select first room (e.g. A-101) for Right Inspector if not selected or invalid
      String? selectId = state.selectedRoomId;
      if (selectId == null || !roomsList.any((r) => r.id == selectId)) {
        if (roomsList.isNotEmpty) {
          selectId = roomsList.first.id;
        }
      }

      state = state.copyWith(
        rooms: roomsList,
        pagination: pagination,
        contextTitle: contextTitle,
        selectedRoomId: selectId,
        isLoading: false,
      );

      if (selectId != null) {
        await fetchRoomDetail(selectId);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to fetch rooms: $e',
      );
    }
  }

  Future<void> fetchRoomDetail(String roomId) async {
    state = state.copyWith(isDetailLoading: true, selectedRoomId: roomId);
    try {
      final detail = await _service.getRoomDetail(roomId);
      state = state.copyWith(
        selectedRoomDetail: detail,
        isDetailLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isDetailLoading: false);
    }
  }

  void selectTab(int index) {
    state = state.copyWith(activeTab: index);
    if (index == 0) {
      loadOverviewData();
    } else if (index == 1) {
      if (state.structureTree.isEmpty) refreshAll();
    } else if (index == 2) {
      if (state.studentsRoster.isEmpty) loadStudentsData();
    } else if (index == 3) {
      if (state.staffRoster.isEmpty) loadStaffData();
    } else if (index == 4) {
      loadFeesData();
    } else if (index == 5) {
      loadLeaveOutingData();
    } else if (index == 6) {
      loadComplaintsData();
    } else if (index == 7) {
      loadReportsData();
      fetchTurnoverForecast();
    }
  }

  void selectAcademicYear(String year) {
    state = state.copyWith(selectedAcademicYear: year);
    _service.getKPIs(academicYear: year).then((kpis) {
      state = state.copyWith(kpis: kpis);
    });
    if (state.activeTab == 0) {
      loadOverviewData();
    } else if (state.activeTab == 1) {
      refreshAll();
    } else if (state.activeTab == 2) {
      loadStudentsData();
    } else if (state.activeTab == 3) {
      loadStaffData();
    } else if (state.activeTab == 4) {
      loadFeesData();
    } else if (state.activeTab == 5) {
      loadLeaveOutingData();
    } else if (state.activeTab == 6) {
      loadComplaintsData();
    } else if (state.activeTab == 7) {
      loadReportsData();
      fetchTurnoverForecast();
    }
  }

  // ==========================================================================
  // TAB 0: OVERVIEW DASHBOARD METHODS
  // ==========================================================================

  Future<void> loadOverviewData() async {
    state = state.copyWith(isOverviewLoading: true);
    try {
      final data = await _service.getOverviewAnalytics(academicYear: state.selectedAcademicYear);
      state = state.copyWith(overviewData: data, isOverviewLoading: false);
    } catch (e) {
      state = state.copyWith(isOverviewLoading: false);
    }
  }

  // ==========================================================================
  // TAB 8: REPORTS & EXPORTS METHODS
  // ==========================================================================

  Future<void> loadReportsData({
    String? reportType,
    DateTime? startDate,
    DateTime? endDate,
    bool clearDates = false,
  }) async {
    final type = reportType ?? state.selectedReportType;
    final effectiveStart = clearDates ? null : (startDate ?? state.reportsStartDate);
    final effectiveEnd = clearDates ? null : (endDate ?? state.reportsEndDate);
    state = state.copyWith(
      isReportsLoading: true,
      selectedReportType: type,
      clearReportDates: clearDates,
      reportsStartDate: effectiveStart,
      reportsEndDate: effectiveEnd,
    );
    try {
      final res = await _service.getReportsData(
        reportType: type,
        academicYear: state.selectedAcademicYear,
        startDate: effectiveStart,
        endDate: effectiveEnd,
      );
      state = state.copyWith(reportsData: res, isReportsLoading: false);
    } catch (e) {
      state = state.copyWith(isReportsLoading: false);
    }
  }

  void setReportType(String type) {
    loadReportsData(reportType: type);
  }

  void setReportDateRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) {
      loadReportsData(clearDates: true);
    } else {
      loadReportsData(startDate: start, endDate: end);
    }
  }

  Future<bool> exportReportCsv({List<Map<String, dynamic>>? customRecords}) async {
    try {
      final records = customRecords ?? (state.reportsData['records'] as List<dynamic>? ?? []);
      if (records.isEmpty) {
        showError('No records to export');
        return false;
      }
      final buffer = StringBuffer();
      final first = records.first as Map<String, dynamic>;
      final headers = first.keys.toList();
      buffer.writeln(headers.map((h) => '"${h.replaceAll('_', ' ').toUpperCase()}"').join(','));

      for (final r in records) {
        final row = r as Map<String, dynamic>;
        final line = headers.map((h) {
          final val = row[h];
          if (val == null) return '""';
          return '"${val.toString().replaceAll('"', '""')}"';
        }).join(',');
        buffer.writeln(line);
      }

      final bytes = utf8.encode(buffer.toString());
      final dateStr = DateTime.now().toIso8601String().split('T')[0];
      final filename = 'hostel_${state.selectedReportType}_report_$dateStr.csv';
      await getDownloadHelper().downloadBytes(bytes, filename);
      showSuccess('Report exported: $filename');
      return true;
    } catch (e) {
      showError('Failed to export CSV: $e');
      return false;
    }
  }

  Future<void> fetchTurnoverForecast() async {
    state = state.copyWith(isTurnoverForecastLoading: true);
    try {
      final res = await _service.getTurnoverForecast(academicYear: state.selectedAcademicYear);
      state = state.copyWith(turnoverForecast: res, isTurnoverForecastLoading: false);
    } catch (e) {
      state = state.copyWith(isTurnoverForecastLoading: false);
    }
  }

  Future<void> fetchSchoolClasses() async {
    try {
      final classes = await _service.getSchoolClasses();
      if (classes.isNotEmpty) {
        state = state.copyWith(schoolClasses: classes);
      }
    } catch (_) {}
  }

  Future<bool> bulkUpdateRoomStatus(List<String> roomIds, String status) async {
    try {
      final res = await _service.bulkUpdateRoomStatus(roomIds: roomIds, status: status);
      if (res['success'] == true) {
        showSuccess('Updated ${res['updated_count'] ?? roomIds.length} rooms to $status');
        await fetchRooms();
        return true;
      } else {
        showError(res['message'] ?? 'Failed to update rooms');
      }
    } catch (e) {
      showError('Error updating room status: $e');
    }
    return false;
  }

  Future<bool> deleteBed(String bedId, String roomId) async {
    try {
      final success = await _service.deleteBed(bedId);
      if (success) {
        showSuccess('Bed deleted successfully');
        await fetchRoomDetail(roomId);
        await fetchRooms();
        return true;
      } else {
        showError('Failed to delete bed');
      }
    } catch (e) {
      showError('Error deleting bed: $e');
    }
    return false;
  }

  void selectBuilding(String? buildingId) {
    state = state.copyWith(
      selectedBuildingId: buildingId,
      clearSelectedFloor: true,
    );
    fetchRooms(page: 1);
  }

  void selectFloor(String? buildingId, String? floorId) {
    state = state.copyWith(
      selectedBuildingId: buildingId,
      selectedFloorId: floorId,
    );
    fetchRooms(page: 1);
  }

  void selectRoom(String roomId) {
    fetchRoomDetail(roomId);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    fetchRooms(page: 1);
  }

  void setHostelFilter(String hostel) {
    state = state.copyWith(hostelFilter: hostel);
    // Find building ID if not 'All Hostels'
    if (hostel == 'All Hostels') {
      selectBuilding(null);
    } else {
      final b = state.structureTree.firstWhere(
        (b) => b.name == hostel,
        orElse: () => state.structureTree.first,
      );
      selectBuilding(b.id);
    }
  }

  void setFloorFilter(String floor) {
    state = state.copyWith(floorFilter: floor);
    if (floor == 'All Floors') {
      state = state.copyWith(clearSelectedFloor: true);
      fetchRooms(page: 1);
    } else {
      final f = state.filterOptions.floors.firstWhere(
        (f) => f['name'] == floor,
        orElse: () => {},
      );
      if (f.isNotEmpty && f['id'] != null) {
        selectFloor(f['building_id'], f['id']);
      }
    }
  }

  void setRoomTypeFilter(String type) {
    state = state.copyWith(roomTypeFilter: type);
    fetchRooms(page: 1);
  }

  void setStatusFilter(String status) {
    state = state.copyWith(statusFilter: status);
    fetchRooms(page: 1);
  }

  void setPage(int page) {
    fetchRooms(page: page);
  }

  void setRoomsPageSize(int pageSize) {
    state = state.copyWith(roomsPageSize: pageSize);
    fetchRooms(page: 1);
  }

  void setRoomsSort(String sortBy) {
    final nextOrder = (state.roomsSortBy == sortBy && state.roomsSortOrder == 'ASC')
        ? 'DESC'
        : 'ASC';
    state = state.copyWith(roomsSortBy: sortBy, roomsSortOrder: nextOrder);
    fetchRooms(page: 1);
  }

  void setInspectorTab(int tab) {
    state = state.copyWith(inspectorTab: tab);
  }

  Future<void> refreshAll() async {
    await loadInitialData();
  }

  Future<void> fetchStructureTree() async {
    try {
      final tree = await _service.getStructureTree();
      state = state.copyWith(structureTree: tree);
    } catch (_) {}
  }

  void clearNotifications() {
    state = state.copyWith(errorMessage: null, successMessage: null);
  }

  void showSuccess(String message) {
    state = state.copyWith(successMessage: message);
  }

  void showError(String message) {
    state = state.copyWith(errorMessage: message);
  }

  // ==========================================================================
  // HOSTEL STUDENTS ACTIONS
  // ==========================================================================

  Future<void> loadStudentsData() async {
    state = state.copyWith(isStudentsLoading: true);
    try {
      final kpisFuture = _service.getStudentsKPIs(academicYear: state.selectedAcademicYear);
      final rosterFuture = _service.getStudentsRoster(
        academicYear: state.selectedAcademicYear,
        search: state.studentsSearch,
        hostelId: _resolveHostelId(state.studentsHostelFilter),
        classId: _resolveClassId(state.studentsClassFilter),
        status: state.studentsStatusFilter == 'All Status' ? 'ALL' : state.studentsStatusFilter,
        feeStatus: state.studentsFeeStatusFilter == 'All Fees' ? 'ALL' : state.studentsFeeStatusFilter,
        page: 1,
        pageSize: state.studentsPageSize,
        sortBy: state.studentsSortBy,
        sortOrder: state.studentsSortOrder,
      );

      final results = await Future.wait([kpisFuture, rosterFuture]);
      final kpis = results[0] as HostelStudentsKPIs;
      final rosterData = results[1] as Map<String, dynamic>;
      final rosterList = rosterData['data'] as List<HostelStudentRosterItem>;
      final pagination = rosterData['pagination'] as HostelStudentRosterPagination;

      String? selectId = state.selectedStudentId;
      if (selectId == null || !rosterList.any((s) => s.admissionId == selectId || s.id == selectId)) {
        if (rosterList.isNotEmpty) {
          selectId = rosterList.first.admissionId;
        }
      }

      state = state.copyWith(
        studentsKPIs: kpis,
        studentsRoster: rosterList,
        studentsPagination: pagination,
        selectedStudentId: selectId,
        isStudentsLoading: false,
      );

      if (selectId != null) {
        await fetchStudentDetail(selectId);
      }
      if (state.schoolClasses.isEmpty) {
        fetchSchoolClasses();
      }
    } catch (e) {
      state = state.copyWith(
        isStudentsLoading: false,
        errorMessage: 'Failed to load hostel students: $e',
      );
    }
  }

  Future<void> fetchStudentsRoster({int page = 1}) async {
    state = state.copyWith(isStudentsLoading: true);
    try {
      final res = await _service.getStudentsRoster(
        academicYear: state.selectedAcademicYear,
        search: state.studentsSearch,
        hostelId: _resolveHostelId(state.studentsHostelFilter),
        classId: _resolveClassId(state.studentsClassFilter),
        status: state.studentsStatusFilter == 'All Status' ? 'ALL' : state.studentsStatusFilter,
        feeStatus: state.studentsFeeStatusFilter == 'All Fees' ? 'ALL' : state.studentsFeeStatusFilter,
        page: page,
        pageSize: state.studentsPageSize,
        sortBy: state.studentsSortBy,
        sortOrder: state.studentsSortOrder,
      );

      final rosterList = res['data'] as List<HostelStudentRosterItem>;
      final pagination = res['pagination'] as HostelStudentRosterPagination;

      String? selectId = state.selectedStudentId;
      if (selectId == null || !rosterList.any((s) => s.admissionId == selectId || s.id == selectId)) {
        if (rosterList.isNotEmpty) {
          selectId = rosterList.first.admissionId;
        }
      }

      state = state.copyWith(
        studentsRoster: rosterList,
        studentsPagination: pagination,
        selectedStudentId: selectId,
        isStudentsLoading: false,
      );

      if (selectId != null) {
        await fetchStudentDetail(selectId);
      }
      if (state.schoolClasses.isEmpty) {
        fetchSchoolClasses();
      }
    } catch (e) {
      state = state.copyWith(
        isStudentsLoading: false,
        errorMessage: 'Failed to fetch students roster: $e',
      );
    }
  }

  Future<void> fetchStudentDetail(String admissionOrStudentId) async {
    state = state.copyWith(isStudentDetailLoading: true, selectedStudentId: admissionOrStudentId);
    try {
      final detail = await _service.getStudentDetail(admissionOrStudentId);
      if (detail != null) {
        state = state.copyWith(
          selectedStudentDetail: detail,
          isStudentDetailLoading: false,
        );
      } else {
        state = state.copyWith(isStudentDetailLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isStudentDetailLoading: false);
    }
  }

  void selectStudent(String admissionId) {
    fetchStudentDetail(admissionId);
  }

  Future<bool> uploadStudentDocument({
    required String studentId,
    required String documentName,
    required String documentType,
    String? fileUrl,
    int fileSizeBytes = 0,
    String mimeType = 'application/pdf',
    String? admissionId,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    try {
      final Map<String, dynamic> res;
      if (fileBytes != null && fileBytes.isNotEmpty && fileName != null) {
        res = await _service.uploadStudentDocumentMultipart(
          studentId: studentId,
          fileBytes: fileBytes,
          fileName: fileName,
          documentName: documentName,
          documentType: documentType,
          admissionId: admissionId,
        );
      } else {
        res = await _service.uploadStudentDocument(
          studentId: studentId,
          documentName: documentName,
          documentType: documentType,
          fileUrl: fileUrl ?? 'https://documents.edushamiit.edu/hostel/$documentName',
          fileSizeBytes: fileSizeBytes,
          mimeType: mimeType,
          admissionId: admissionId,
        );
      }
      if (res['success'] == true) {
        showSuccess(res['message'] ?? 'Document uploaded successfully');
        final targetId = admissionId ??
            state.selectedStudentDetail?.admissionId ??
            state.selectedStudentDetail?.studentId ??
            state.selectedStudentId;
        if (targetId != null) {
          await fetchStudentDetail(targetId);
        }
        return true;
      } else {
        showError(res['message'] ?? 'Failed to upload document');
      }
    } catch (e) {
      showError('Error uploading document: $e');
    }
    return false;
  }

  Future<bool> deleteStudentDocument(String documentId) async {
    try {
      final ok = await _service.deleteStudentDocument(documentId);
      if (ok) {
        showSuccess('Document deleted successfully');
        if (state.selectedStudentDetail != null) {
          final updatedDocs = state.selectedStudentDetail!.documents
              .where((doc) => doc.id != documentId)
              .toList();
          state = state.copyWith(
            selectedStudentDetail: state.selectedStudentDetail!.copyWith(documents: updatedDocs),
          );
        }
        final targetId = state.selectedStudentDetail?.admissionId ??
            state.selectedStudentDetail?.studentId ??
            state.selectedStudentId;
        if (targetId != null) {
          await fetchStudentDetail(targetId);
        }
        return true;
      } else {
        showError('Failed to delete document');
      }
    } catch (e) {
      showError('Error deleting document: $e');
    }
    return false;
  }

  Future<List<int>?> downloadStudentDocument(String documentId) async {
    return await _service.downloadStudentDocumentBytes(documentId);
  }

  void setStudentsSearch(String query) {
    state = state.copyWith(studentsSearch: query);
    fetchStudentsRoster(page: 1);
  }

  void setStudentsHostelFilter(String hostel) {
    state = state.copyWith(studentsHostelFilter: hostel);
    fetchStudentsRoster(page: 1);
  }

  void setStudentsClassFilter(String className) {
    state = state.copyWith(studentsClassFilter: className);
    fetchStudentsRoster(page: 1);
  }

  void setStudentsStatusFilter(String status) {
    state = state.copyWith(studentsStatusFilter: status);
    fetchStudentsRoster(page: 1);
  }

  void setStudentsFeeStatusFilter(String feeStatus) {
    state = state.copyWith(studentsFeeStatusFilter: feeStatus);
    fetchStudentsRoster(page: 1);
  }

  void setStudentsDateRange(DateTimeRange? range) {
    state = state.copyWith(selectedDateRange: range);
    fetchStudentsRoster(page: 1);
  }

  void setStudentsPage(int page) {
    fetchStudentsRoster(page: page);
  }

  void setStudentsPageSize(int pageSize) {
    state = state.copyWith(studentsPageSize: pageSize);
    fetchStudentsRoster(page: 1);
  }

  Future<bool> bulkStudentsAction(String action, {String? reason}) async {
    final ids = state.selectedStudentRosterIds.toList();
    if (ids.isEmpty) {
      showError('Select at least one hostel student');
      return false;
    }
    try {
      final res = await _service.bulkStudentsAction(
        admissionIds: ids,
        action: action,
        reason: reason,
      );
      if (res['success'] == true) {
        state = state.copyWith(selectedStudentRosterIds: const {});
        showSuccess(res['message']?.toString() ?? 'Bulk operation completed');
        await Future.wait([
          loadStudentsData(),
          fetchRooms(),
          fetchStructureTree(),
        ]);
        loadOverviewData();
        return true;
      } else {
        showError(res['message']?.toString() ?? 'Bulk action could not process selected students');
      }
    } catch (e) {
      showError('Bulk action failed: $e');
    }
    return false;
  }

  void setStudentsSort(String sortBy) {
    if (state.studentsSortBy == sortBy) {
      final nextOrder = state.studentsSortOrder == 'ASC' ? 'DESC' : 'ASC';
      state = state.copyWith(studentsSortOrder: nextOrder);
    } else {
      state = state.copyWith(studentsSortBy: sortBy, studentsSortOrder: 'ASC');
    }
    fetchStudentsRoster(page: 1);
  }

  void setStudentDrawerTab(int tab) {
    state = state.copyWith(studentDrawerTab: tab);
  }

  void toggleSelectAllStudents(bool selectAll) {
    if (selectAll) {
      final ids = state.studentsRoster.map((s) => s.admissionId).toSet();
      state = state.copyWith(selectedStudentRosterIds: ids);
    } else {
      state = state.copyWith(selectedStudentRosterIds: {});
    }
  }

  void toggleSelectStudent(String admissionId) {
    final current = Set<String>.from(state.selectedStudentRosterIds);
    if (current.contains(admissionId)) {
      current.remove(admissionId);
    } else {
      current.add(admissionId);
    }
    state = state.copyWith(selectedStudentRosterIds: current);
  }

  String? _resolveHostelId(String hostelFilter) {
    if (hostelFilter == 'All Hostels' || hostelFilter.isEmpty) return null;
    final found = state.structureTree.where((b) => b.name == hostelFilter || b.id == hostelFilter);
    return found.isNotEmpty ? found.first.id : null;
  }

  String? _resolveClassId(String classFilter) {
    if (classFilter == 'All Classes' || classFilter.isEmpty) return null;
    return null;
  }

  Future<bool> admitStudent(Map<String, dynamic> payload) async {
    try {
      final res = await _service.admitStudent(payload);
      if (res['success'] == true) {
        showSuccess(res['message'] ?? 'Student admitted successfully');
        await loadStudentsData();
        await fetchRooms();
        await fetchStructureTree();
        loadOverviewData();
        return true;
      } else {
        showError(res['message'] ?? 'Admission failed');
      }
    } catch (e) {
      showError('Failed to admit student: $e');
    }
    return false;
  }

  Future<bool> transferStudentBed(Map<String, dynamic> payload) async {
    try {
      final res = await _service.transferStudentBed(payload);
      if (res['success'] == true) {
        showSuccess(res['message'] ?? 'Room transferred successfully');
        await loadStudentsData();
        await fetchRooms();
        await fetchStructureTree();
        loadOverviewData();
        return true;
      } else {
        showError(res['message'] ?? 'Transfer failed');
      }
    } catch (e) {
      showError('Failed to transfer student: $e');
    }
    return false;
  }

  Future<bool> releaseStudentBed(Map<String, dynamic> payload) async {
    try {
      final res = await _service.releaseBed(payload);
      if (res['success'] == true) {
        showSuccess(res['message'] ?? 'Bed released successfully');
        await loadStudentsData();
        await fetchRooms();
        await fetchStructureTree();
        loadOverviewData();
        return true;
      } else {
        showError(res['message'] ?? 'Release bed failed');
      }
    } catch (e) {
      showError('Failed to release bed: $e');
    }
    return false;
  }

  Future<bool> checkoutStudent(Map<String, dynamic> payload) async {
    try {
      final res = await _service.checkoutHostelStudent(payload);
      if (res['success'] == true) {
        showSuccess(res['message'] ?? 'Student checked out successfully');
        await loadStudentsData();
        await fetchRooms();
        await fetchStructureTree();
        loadOverviewData();
        return true;
      } else {
        showError(res['message'] ?? 'Check out failed');
      }
    } catch (e) {
      showError('Failed to check out student: $e');
    }
    return false;
  }

  Future<bool> exportStudentsCsv({bool onlySelected = false}) async {
    try {
      final selectedIds = onlySelected ? state.selectedStudentRosterIds.toList() : null;
      if (onlySelected && (selectedIds == null || selectedIds.isEmpty)) {
        showError('Select at least one student to export');
        return false;
      }
      showSuccess('Exporting hostel students roster...');
      final bytes = await _service.exportStudentsCsv(
        academicYear: state.selectedAcademicYear,
        search: state.studentsSearch,
        hostelId: _resolveHostelId(state.studentsHostelFilter),
        status: state.studentsStatusFilter != 'All Status' ? state.studentsStatusFilter : 'ALL',
        feeStatus: state.studentsFeeStatusFilter != 'All Fees' ? state.studentsFeeStatusFilter : 'ALL',
        admissionIds: selectedIds,
      );
      if (bytes != null && bytes.isNotEmpty) {
        final dateStr = DateTime.now().toIso8601String().split('T')[0];
        await getDownloadHelper().downloadBytes(Uint8List.fromList(bytes), 'hostel_students_$dateStr.csv');
        showSuccess('Hostel students CSV downloaded successfully');
        return true;
      } else {
        showError('Unable to download CSV file');
      }
    } catch (e) {
      showError('Error exporting CSV: $e');
    }
    return false;
  }

  // ==========================================================================
  // HOSTEL STAFF ACTIONS
  // ==========================================================================

  Future<void> loadStaffData() async {
    state = state.copyWith(isStaffLoading: true);
    try {
      final kpisFuture = _service.getStaffKPIs(state.selectedAcademicYear);
      final rosterFuture = _service.getStaffRoster(
        academicYear: state.selectedAcademicYear,
        search: state.staffSearch,
        hostelId: _resolveHostelId(state.staffHostelFilter),
        role: state.staffRoleFilter == 'All Roles' ? 'ALL' : state.staffRoleFilter,
        status: state.staffStatusFilter == 'All Status' ? 'ALL' : state.staffStatusFilter,
        page: 1,
        pageSize: state.staffPagination.pageSize,
        sortBy: state.staffSortBy,
        sortOrder: state.staffSortOrder,
      );

      final results = await Future.wait([kpisFuture, rosterFuture]);
      final kpis = results[0] as HostelStaffKPIs? ?? HostelStaffKPIs();
      final rosterData = results[1] as Map<String, dynamic>;
      final rosterList = rosterData['data'] as List<HostelStaffRosterItem>;
      final pagination = rosterData['pagination'] as HostelStaffRosterPagination;

      String? selectId = state.selectedStaffAssignmentId;
      if (selectId == null || !rosterList.any((s) => s.assignmentId == selectId)) {
        if (rosterList.isNotEmpty) {
          selectId = rosterList.first.assignmentId;
        }
      }

      state = state.copyWith(
        staffKPIs: kpis,
        staffRoster: rosterList,
        staffPagination: pagination,
        selectedStaffAssignmentId: selectId,
        isStaffLoading: false,
      );

      if (selectId != null) {
        await fetchStaffDetail(selectId);
      }
    } catch (e) {
      state = state.copyWith(
        isStaffLoading: false,
        errorMessage: 'Failed to load hostel staff: $e',
      );
    }
  }

  Future<void> fetchStaffRoster({int? page}) async {
    state = state.copyWith(isStaffLoading: true);
    try {
      final currentPage = page ?? state.staffPagination.currentPage;
      final rosterData = await _service.getStaffRoster(
        academicYear: state.selectedAcademicYear,
        search: state.staffSearch,
        hostelId: _resolveHostelId(state.staffHostelFilter),
        role: state.staffRoleFilter == 'All Roles' ? 'ALL' : state.staffRoleFilter,
        status: state.staffStatusFilter == 'All Status' ? 'ALL' : state.staffStatusFilter,
        page: currentPage,
        pageSize: state.staffPagination.pageSize,
        sortBy: state.staffSortBy,
        sortOrder: state.staffSortOrder,
      );

      final rosterList = rosterData['data'] as List<HostelStaffRosterItem>;
      final pagination = rosterData['pagination'] as HostelStaffRosterPagination;

      state = state.copyWith(
        staffRoster: rosterList,
        staffPagination: pagination,
        isStaffLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isStaffLoading: false,
        errorMessage: 'Failed to fetch staff roster: $e',
      );
    }
  }

  Future<void> fetchStaffDetail(String assignmentId) async {
    state = state.copyWith(isStaffDetailLoading: true, selectedStaffAssignmentId: assignmentId);
    try {
      final detail = await _service.getStaffDetail(assignmentId);
      state = state.copyWith(
        selectedStaffDetail: detail,
        isStaffDetailLoading: false,
        isStaffDrawerOpen: true,
      );
    } catch (e) {
      state = state.copyWith(isStaffDetailLoading: false);
    }
  }

  void selectStaff(String assignmentId) {
    fetchStaffDetail(assignmentId);
  }

  void closeStaffDrawer() {
    state = state.copyWith(isStaffDrawerOpen: false);
  }

  void openStaffDrawer() {
    state = state.copyWith(isStaffDrawerOpen: true);
  }

  void setStaffDrawerTab(int tab) {
    state = state.copyWith(staffDrawerTab: tab);
  }

  void setStaffSearch(String query) {
    state = state.copyWith(staffSearch: query);
    fetchStaffRoster(page: 1);
  }

  void setStaffHostelFilter(String hostel) {
    state = state.copyWith(staffHostelFilter: hostel);
    fetchStaffRoster(page: 1);
  }

  void setStaffRoleFilter(String role) {
    state = state.copyWith(staffRoleFilter: role);
    fetchStaffRoster(page: 1);
  }

  void setStaffStatusFilter(String status) {
    state = state.copyWith(staffStatusFilter: status);
    fetchStaffRoster(page: 1);
  }

  void setStaffJoinedDateFilter(DateTime? date) {
    state = state.copyWith(staffJoinedDateFilter: date);
    fetchStaffRoster(page: 1);
  }

  void setStaffPage(int page) {
    fetchStaffRoster(page: page);
  }

  void setStaffPageSize(int pageSize) {
    state = state.copyWith(
      staffPagination: HostelStaffRosterPagination(
        currentPage: 1,
        pageSize: pageSize,
        totalRecords: state.staffPagination.totalRecords,
        totalPages: (state.staffPagination.totalRecords / pageSize).ceil(),
      ),
    );
    fetchStaffRoster(page: 1);
  }

  void setStaffSort(String sortBy) {
    final newOrder = (state.staffSortBy == sortBy && state.staffSortOrder == 'ASC') ? 'DESC' : 'ASC';
    state = state.copyWith(staffSortBy: sortBy, staffSortOrder: newOrder);
    fetchStaffRoster(page: 1);
  }

  void toggleStaffSelection(String assignmentId) {
    final current = Set<String>.from(state.selectedStaffAssignmentIds);
    if (current.contains(assignmentId)) {
      current.remove(assignmentId);
    } else {
      current.add(assignmentId);
    }
    state = state.copyWith(selectedStaffAssignmentIds: current);
  }

  void selectAllStaff(bool selectAll) {
    if (selectAll) {
      final allIds = state.staffRoster.map((s) => s.assignmentId).toSet();
      state = state.copyWith(selectedStaffAssignmentIds: allIds);
    } else {
      state = state.copyWith(selectedStaffAssignmentIds: {});
    }
  }

  Future<bool> assignStaff(Map<String, dynamic> payload) async {
    try {
      final res = await _service.assignStaff(payload);
      if (res['success'] == true) {
        showSuccess(res['message'] ?? 'Staff assigned successfully');
        await loadStaffData();
        return true;
      } else {
        showError(res['message'] ?? 'Staff assignment failed');
      }
    } catch (e) {
      showError('Failed to assign staff: $e');
    }
    return false;
  }

  Future<bool> updateStaffAssignment(String assignmentId, Map<String, dynamic> payload) async {
    try {
      final res = await _service.updateStaffAssignment(assignmentId, payload);
      if (res['success'] == true) {
        showSuccess(res['message'] ?? 'Assignment updated successfully');
        await loadStaffData();
        await fetchStaffDetail(assignmentId);
        return true;
      } else {
        showError(res['message'] ?? 'Update failed');
      }
    } catch (e) {
      showError('Failed to update assignment: $e');
    }
    return false;
  }

  Future<bool> transferStaff(String assignmentId, Map<String, dynamic> payload) async {
    try {
      final res = await _service.transferStaff(assignmentId, payload);
      if (res['success'] == true) {
        showSuccess(res['message'] ?? 'Staff transferred successfully');
        await loadStaffData();
        return true;
      } else {
        showError(res['message'] ?? 'Transfer failed');
      }
    } catch (e) {
      showError('Failed to transfer staff: $e');
    }
    return false;
  }

  Future<bool> endStaffAssignment(String assignmentId, Map<String, dynamic> payload) async {
    try {
      final res = await _service.endStaffAssignment(assignmentId, payload);
      if (res['success'] == true) {
        showSuccess(res['message'] ?? 'Staff assignment ended successfully');
        await loadStaffData();
        return true;
      } else {
        showError(res['message'] ?? 'End assignment failed');
      }
    } catch (e) {
      showError('Failed to end assignment: $e');
    }
    return false;
  }

  Future<bool> bulkStaffActions({
    required String action,
    required List<String> assignmentIds,
    String? newHostelId,
    String? reason,
  }) async {
    if (assignmentIds.isEmpty) return false;
    try {
      final payload = {
        'action': action,
        'assignment_ids': assignmentIds,
        if (newHostelId != null) 'new_hostel_id': newHostelId,
        if (reason != null) 'reason': reason,
      };
      final res = await _service.bulkStaffActions(payload);
      if (res['success'] == true) {
        showSuccess(res['message'] ?? 'Bulk action completed');
        state = state.copyWith(selectedStaffAssignmentIds: {});
        await loadStaffData();
        return true;
      } else {
        showError(res['message'] ?? 'Bulk action failed');
      }
    } catch (e) {
      showError('Bulk action error: $e');
    }
    return false;
  }

  Future<bool> uploadStaffDocument({
    required String staffId,
    required String documentName,
    required String documentType,
    String? fileUrl,
    int fileSizeBytes = 0,
    String mimeType = 'application/pdf',
    String verificationStatus = 'VERIFIED',
    String? notes,
    List<int>? fileBytes,
    String? fileName,
  }) async {
    try {
      Map<String, dynamic> res;
      if (fileBytes != null && fileBytes.isNotEmpty && fileName != null) {
        res = await _service.uploadStaffDocumentMultipart(
          staffId: staffId,
          fileBytes: fileBytes,
          fileName: fileName,
          documentName: documentName,
          documentType: documentType,
          verificationStatus: verificationStatus,
          notes: notes,
        );
      } else {
        res = await _service.uploadStaffDocument(
          staffId: staffId,
          documentName: documentName,
          documentType: documentType,
          fileUrl: fileUrl ?? 'https://documents.edushamiit.edu/staff/$documentName',
          fileSizeBytes: fileSizeBytes,
          mimeType: mimeType,
          verificationStatus: verificationStatus,
          notes: notes,
        );
      }
      if (res['success'] == true) {
        showSuccess('Staff document uploaded successfully');
        await fetchStaffDetail(staffId);
        return true;
      } else {
        showError(res['message'] ?? 'Failed to upload staff document');
      }
    } catch (e) {
      showError('Failed to upload staff document: $e');
    }
    return false;
  }

  Future<bool> verifyStaffDocument({
    required String staffId,
    required String documentId,
    required String verificationStatus,
    String? notes,
  }) async {
    try {
      final ok = await _service.verifyStaffDocument(
        documentId: documentId,
        verificationStatus: verificationStatus,
        notes: notes,
      );
      if (ok) {
        showSuccess('Document verification status updated');
        await fetchStaffDetail(staffId);
        return true;
      } else {
        showError('Failed to update verification status');
      }
    } catch (e) {
      showError('Failed to update verification status: $e');
    }
    return false;
  }

  Future<bool> deleteStaffDocument({
    required String staffId,
    required String documentId,
  }) async {
    try {
      final ok = await _service.deleteStaffDocument(documentId);
      if (ok) {
        showSuccess('Document deleted successfully');
        if (state.selectedStaffDetail != null) {
          final updatedDocs = state.selectedStaffDetail!.documents
              .where((doc) => doc.id != documentId)
              .toList();
          state = state.copyWith(
            selectedStaffDetail: state.selectedStaffDetail!.copyWith(documents: updatedDocs),
          );
        }
        await fetchStaffDetail(staffId);
        return true;
      } else {
        showError('Failed to delete document');
      }
    } catch (e) {
      showError('Failed to delete document: $e');
    }
    return false;
  }

  Future<List<int>?> downloadStaffDocument(String documentId) async {
    return await _service.downloadStaffDocumentBytes(documentId);
  }

  Future<bool> recordStaffLeave({
    required String staffId,
    required String leaveType,
    required String startDate,
    required String endDate,
    required String reason,
    String substituteStaffName = 'Backup Warden',
    String emergencyContact = '',
  }) async {
    try {
      final res = await _service.recordStaffLeave(
        staffId: staffId,
        leaveType: leaveType,
        startDate: startDate,
        endDate: endDate,
        reason: reason,
        substituteStaffName: substituteStaffName,
        emergencyContact: emergencyContact,
      );
      if (res['success'] == true) {
        showSuccess('Staff leave recorded successfully');
        await fetchStaffDetail(staffId);
        await fetchStaffRoster();
        return true;
      } else {
        showError(res['message'] ?? 'Failed to record staff leave');
      }
    } catch (e) {
      showError('Failed to record staff leave: $e');
    }
    return false;
  }

  Future<bool> returnStaffToDuty(String staffId) async {
    try {
      final ok = await _service.returnStaffToDuty(staffId);
      if (ok) {
        showSuccess('Staff returned to active duty successfully');
        await fetchStaffDetail(staffId);
        await fetchStaffRoster();
        return true;
      } else {
        showError('Failed to return staff to active duty');
      }
    } catch (e) {
      showError('Failed to return staff to active duty: $e');
    }
    return false;
  }

  // ==========================================================================
  // HOSTEL FEES & BILLING ACTIONS
  // ==========================================================================

  Future<void> loadFeesData() async {
    state = state.copyWith(isFeesLoading: true);
    await Future.wait([
      loadFeeSummary(),
      loadStudentFees(page: 1),
      loadFeeStructures(),
      fetchInvoicesList(),
      fetchPaymentsList(),
      fetchRefundsList(),
    ]);
    state = state.copyWith(isFeesLoading: false);
  }

  Future<void> fetchInvoicesList({int? page}) async {
    final targetPage = page ?? (state.invoicesPagination['page'] as int? ?? 1);
    try {
      final res = await _feeService.getInvoices(
        academicYear: state.selectedAcademicYear,
        page: targetPage,
        pageSize: state.invoicesPageSize,
        sortBy: state.invoicesSortBy,
        sortOrder: state.invoicesSortOrder,
      );
      final rawList = res['invoices'] as List<dynamic>? ?? [];
      final items = rawList.map((e) => HostelInvoiceItemModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      final pag = Map<String, dynamic>.from(res['pagination'] as Map? ?? {});
      state = state.copyWith(invoicesList: items, invoicesPagination: pag);
    } catch (_) {}
  }

  void setInvoicesPage(int page) => fetchInvoicesList(page: page);

  void setInvoicesPageSize(int pageSize) {
    state = state.copyWith(invoicesPageSize: pageSize);
    fetchInvoicesList(page: 1);
  }

  void setInvoicesSort(String sortBy, String sortOrder) {
    state = state.copyWith(invoicesSortBy: sortBy, invoicesSortOrder: sortOrder);
    fetchInvoicesList(page: 1);
  }

  Future<void> fetchPaymentsList({int? page}) async {
    final targetPage = page ?? (state.paymentsPagination['page'] as int? ?? 1);
    try {
      final res = await _feeService.getPayments(
        academicYear: state.selectedAcademicYear,
        page: targetPage,
        pageSize: state.paymentsPageSize,
        sortBy: state.paymentsSortBy,
        sortOrder: state.paymentsSortOrder,
      );
      final rawList = res['payments'] as List<dynamic>? ?? [];
      final items = rawList.map((e) => HostelPaymentReceiptModel.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      final pag = Map<String, dynamic>.from(res['pagination'] as Map? ?? {});
      state = state.copyWith(paymentsList: items, paymentsPagination: pag);
    } catch (_) {}
  }

  void setPaymentsPage(int page) => fetchPaymentsList(page: page);

  void setPaymentsPageSize(int pageSize) {
    state = state.copyWith(paymentsPageSize: pageSize);
    fetchPaymentsList(page: 1);
  }

  void setPaymentsSort(String sortBy, String sortOrder) {
    state = state.copyWith(paymentsSortBy: sortBy, paymentsSortOrder: sortOrder);
    fetchPaymentsList(page: 1);
  }

  Future<void> fetchRefundsList({int? page}) async {
    final targetPage = page ?? (state.refundsPagination['page'] as int? ?? 1);
    try {
      final res = await _feeService.getRefundsPaged(
        page: targetPage,
        pageSize: state.refundsPageSize,
        sortBy: state.refundsSortBy,
        sortOrder: state.refundsSortOrder,
      );
      final list = res['refunds'] as List<Map<String, dynamic>>? ?? [];
      final pag = Map<String, dynamic>.from(res['pagination'] as Map? ?? {});
      state = state.copyWith(refundsList: list, refundsPagination: pag);
    } catch (_) {}
  }

  void setRefundsPage(int page) => fetchRefundsList(page: page);

  void setRefundsPageSize(int pageSize) {
    state = state.copyWith(refundsPageSize: pageSize);
    fetchRefundsList(page: 1);
  }

  void setRefundsSort(String sortBy, String sortOrder) {
    state = state.copyWith(refundsSortBy: sortBy, refundsSortOrder: sortOrder);
    fetchRefundsList(page: 1);
  }

  Future<void> loadFeeSummary() async {
    try {
      final res = await _feeService.getFeeSummary(academicYear: state.selectedAcademicYear);
      state = state.copyWith(
        feesKPIs: res['kpis'] as HostelFeeKPIs,
        feeSummaryDonut: res['fee_summary'] as HostelFeeSummaryDonut,
        upcomingInvoices: res['upcoming_invoices'] as List<HostelUpcomingInvoiceItem>,
        recentPayments: res['recent_payments'] as List<HostelRecentPaymentItem>,
      );
    } catch (e) {
      // Ignored
    }
  }

  Future<void> loadStudentFees({int page = 1}) async {
    try {
      final res = await _feeService.getStudentFees(
        academicYear: state.selectedAcademicYear,
        search: state.feesSearch,
        hostelId: _resolveHostelId(state.feesHostelFilter),
        className: state.feesClassFilter == 'All Classes' ? null : state.feesClassFilter,
        status: state.feesStatusFilter == 'All Status' ? null : state.feesStatusFilter,
        page: page,
        pageSize: state.feesPageSize,
        sortBy: state.feesSortBy,
        sortOrder: state.feesSortOrder,
      );

      final list = res['students'] as List<HostelStudentFeeItem>;
      final pagination = res['pagination'] as HostelFeeRosterPagination;

      String? selectId = state.selectedFeeStudentId;
      if (selectId == null || !list.any((s) => s.studentId == selectId || s.id == selectId)) {
        if (list.isNotEmpty) {
          selectId = list.first.studentId;
        }
      }

      state = state.copyWith(
        studentFeesRoster: list,
        feesPagination: pagination,
        selectedFeeStudentId: selectId,
      );

      if (selectId != null && state.isFeeDrawerOpen) {
        await fetchFeeStudentDetail(selectId);
      }
    } catch (e) {
      showError('Failed to fetch student fees: $e');
    }
  }

  Future<void> loadFeeStructures({int? page}) async {
    final targetPage = page ?? (state.feePlansPagination['page'] as int? ?? 1);
    try {
      final res = await _feeService.getFeeStructuresPaged(
        academicYear: state.selectedAcademicYear,
        page: targetPage,
        pageSize: state.feePlansPageSize,
        sortBy: state.feePlansSortBy,
        sortOrder: state.feePlansSortOrder,
      );
      final list = res['plans'] as List<HostelFeePlanModel>? ?? [];
      final pag = Map<String, dynamic>.from(res['pagination'] as Map? ?? {});
      state = state.copyWith(feePlans: list, feePlansPagination: pag);
    } catch (e) {
      // Ignored
    }
  }

  void setFeePlansPage(int page) => loadFeeStructures(page: page);

  void setFeePlansPageSize(int pageSize) {
    state = state.copyWith(feePlansPageSize: pageSize);
    loadFeeStructures(page: 1);
  }

  void setFeePlansSort(String sortBy, String sortOrder) {
    state = state.copyWith(feePlansSortBy: sortBy, feePlansSortOrder: sortOrder);
    loadFeeStructures(page: 1);
  }

  Future<void> fetchFeeStudentDetail(String studentId) async {
    state = state.copyWith(isFeeDetailLoading: true, selectedFeeStudentId: studentId);
    try {
      final detail = await _feeService.getStudentFee360(studentId);
      state = state.copyWith(
        selectedFeeStudentDetail: detail,
        isFeeDetailLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isFeeDetailLoading: false);
    }
  }

  void openFeeDrawer(String studentId, {HostelStudentFeeDetail360? initialDetail}) {
    state = state.copyWith(
      selectedFeeStudentId: studentId,
      selectedFeeStudentDetail: initialDetail ?? state.selectedFeeStudentDetail,
      isFeeDrawerOpen: true,
      feeDrawerTab: 0,
    );
    if (initialDetail == null) {
      fetchFeeStudentDetail(studentId);
    }
  }

  void closeFeeDrawer() {
    state = state.copyWith(isFeeDrawerOpen: false);
  }

  void setFeeDrawerTab(int tab) {
    state = state.copyWith(feeDrawerTab: tab);
  }

  void setFeesSearch(String query) {
    state = state.copyWith(feesSearch: query);
    loadStudentFees(page: 1);
  }

  void setFeesHostelFilter(String hostel) {
    state = state.copyWith(feesHostelFilter: hostel);
    loadStudentFees(page: 1);
  }

  void setFeesClassFilter(String className) {
    state = state.copyWith(feesClassFilter: className);
    loadStudentFees(page: 1);
  }

  void setFeesStatusFilter(String status) {
    state = state.copyWith(feesStatusFilter: status);
    loadStudentFees(page: 1);
  }

  void setFeesSort(String? sortBy, String sortOrder) {
    state = state.copyWith(feesSortBy: sortBy, feesSortOrder: sortOrder);
    loadStudentFees(page: 1);
  }

  void setFeesPageSize(int pageSize) {
    state = state.copyWith(feesPageSize: pageSize);
    loadStudentFees(page: 1);
  }

  void setFeesSubTab(int index) {
    state = state.copyWith(feesSubTab: index);
  }

  void toggleSelectFeeAccount(String accountId) {
    final next = Set<String>.from(state.selectedFeeAccountIds);
    if (next.contains(accountId)) {
      next.remove(accountId);
    } else {
      next.add(accountId);
    }
    state = state.copyWith(selectedFeeAccountIds: next);
  }

  void selectAllFeeAccounts(bool selectAll) {
    if (selectAll) {
      final ids = state.studentFeesRoster.map((s) => s.id).toSet();
      state = state.copyWith(selectedFeeAccountIds: ids);
    } else {
      state = state.copyWith(selectedFeeAccountIds: {});
    }
  }

  Future<bool> collectPayment(Map<String, dynamic> payload) async {
    try {
      final res = await _feeService.collectPayment(payload);
      if (res['success'] == true) {
        showSuccess(res['message'] ?? 'Payment recorded successfully');
        await loadFeeSummary();
        await loadStudentFees(page: state.feesPagination.page);
        if (state.selectedFeeStudentId != null) {
          await fetchFeeStudentDetail(state.selectedFeeStudentId!);
        }
        return true;
      } else {
        showError(res['message'] ?? 'Failed to record payment');
      }
    } catch (e) {
      showError('Error recording payment: $e');
    }
    return false;
  }

  Future<bool> generateSingleInvoice(Map<String, dynamic> payload) async {
    try {
      final res = await _feeService.generateInvoice(payload);
      if (res['success'] == true) {
        showSuccess(res['message'] ?? 'Invoice generated successfully');
        await loadFeeSummary();
        await loadStudentFees(page: state.feesPagination.page);
        if (state.selectedFeeStudentId != null) {
          await fetchFeeStudentDetail(state.selectedFeeStudentId!);
        }
        return true;
      } else {
        showError(res['message'] ?? 'Failed to generate invoice');
      }
    } catch (e) {
      showError('Error generating invoice: $e');
    }
    return false;
  }

  Future<bool> generateBulkInvoices(Map<String, dynamic> payload) async {
    try {
      final res = await _feeService.generateBulkInvoices(payload);
      if (res['success'] == true) {
        showSuccess(res['message'] ?? 'Bulk invoices generated successfully');
        await loadFeeSummary();
        await loadStudentFees(page: 1);
        return true;
      } else {
        showError(res['message'] ?? 'Failed to generate bulk invoices');
      }
    } catch (e) {
      showError('Error in bulk invoice generation: $e');
    }
    return false;
  }

  Future<bool> applyConcession(Map<String, dynamic> payload) async {
    try {
      final res = await _feeService.applyConcession(payload);
      if (res['success'] == true) {
        showSuccess(res['message'] ?? 'Concession applied successfully');
        await loadFeeSummary();
        await loadStudentFees(page: state.feesPagination.page);
        if (state.selectedFeeStudentId != null) {
          await fetchFeeStudentDetail(state.selectedFeeStudentId!);
        }
        return true;
      } else {
        showError(res['message'] ?? 'Failed to apply concession');
      }
    } catch (e) {
      showError('Error applying concession: $e');
    }
    return false;
  }

  Future<bool> addPenalty(Map<String, dynamic> payload) async {
    try {
      final res = await _feeService.addPenalty(payload);
      if (res['success'] == true) {
        showSuccess(res['message'] ?? 'Penalty added successfully');
        await loadFeeSummary();
        await loadStudentFees(page: state.feesPagination.page);
        if (state.selectedFeeStudentId != null) {
          await fetchFeeStudentDetail(state.selectedFeeStudentId!);
        }
        return true;
      } else {
        showError(res['message'] ?? 'Failed to add penalty');
      }
    } catch (e) {
      showError('Error adding penalty: $e');
    }
    return false;
  }

  Future<bool> requestRefund(Map<String, dynamic> payload) async {
    try {
      final res = await _feeService.requestRefund(payload);
      if (res['success'] == true) {
        showSuccess(res['message'] ?? 'Refund requested successfully');
        if (state.selectedFeeStudentId != null) {
          await fetchFeeStudentDetail(state.selectedFeeStudentId!);
        }
        return true;
      } else {
        showError(res['message'] ?? 'Failed to request refund');
      }
    } catch (e) {
      showError('Error requesting refund: $e');
    }
    return false;
  }

  Future<bool> approveRefund(String refundId, Map<String, dynamic> payload) async {
    try {
      final res = await _feeService.approveRefund(refundId, payload);
      if (res['success'] == true) {
        showSuccess(res['message'] ?? 'Refund approved');
        await loadFeeSummary();
        await loadStudentFees(page: state.feesPagination.page);
        if (state.selectedFeeStudentId != null) {
          await fetchFeeStudentDetail(state.selectedFeeStudentId!);
        }
        return true;
      } else {
        showError(res['message'] ?? 'Failed to approve refund');
      }
    } catch (e) {
      showError('Error approving refund: $e');
    }
    return false;
  }

  Future<bool> addStudentFeeHead(String studentId, Map<String, dynamic> payload) async {
    try {
      final ok = await _feeService.addStudentFeeHead(studentId, payload);
      if (ok) {
        showSuccess('Fee head added successfully');
        await loadFeeSummary();
        await loadStudentFees(page: state.feesPagination.page);
        await fetchFeeStudentDetail(studentId);
        return true;
      } else {
        showError('Failed to add fee head');
      }
    } catch (e) {
      showError('Error adding fee head: $e');
    }
    return false;
  }

  Future<bool> updateStudentFeeHead(String studentId, String headId, Map<String, dynamic> payload) async {
    try {
      final ok = await _feeService.updateStudentFeeHead(studentId, headId, payload);
      if (ok) {
        showSuccess('Fee head updated successfully');
        await loadFeeSummary();
        await loadStudentFees(page: state.feesPagination.page);
        await fetchFeeStudentDetail(studentId);
        return true;
      } else {
        showError('Failed to update fee head');
      }
    } catch (e) {
      showError('Error updating fee head: $e');
    }
    return false;
  }

  Future<bool> deleteStudentFeeHead(String studentId, String headId) async {
    try {
      final ok = await _feeService.deleteStudentFeeHead(studentId, headId);
      if (ok) {
        showSuccess('Fee head deleted successfully');
        await loadFeeSummary();
        await loadStudentFees(page: state.feesPagination.page);
        await fetchFeeStudentDetail(studentId);
        return true;
      } else {
        showError('Failed to delete fee head');
      }
    } catch (e) {
      showError('Error deleting fee head: $e');
    }
    return false;
  }

  Future<bool> sendFeeReminders(Map<String, dynamic> payload) async {
    try {
      final res = await _feeService.sendReminders(payload);
      if (res['success'] == true) {
        showSuccess(res['message'] ?? 'Fee reminders dispatched');
        return true;
      } else {
        showError(res['message'] ?? 'Failed to send reminders');
      }
    } catch (e) {
      showError('Error sending reminders: $e');
    }
    return false;
  }

  Future<bool> createFeeStructure(Map<String, dynamic> payload) async {
    try {
      final res = await _feeService.createFeeStructure(payload);
      if (res['success'] == true) {
        showSuccess(res['message'] ?? 'Fee plan created successfully');
        await loadFeeStructures();
        return true;
      } else {
        showError(res['message'] ?? 'Failed to create fee plan');
      }
    } catch (e) {
      showError('Error creating fee plan: $e');
    }
    return false;
  }

  Future<bool> exportFeesCsv({bool onlySelected = false}) async {
    try {
      showSuccess('Exporting hostel fees CSV...');
      String? hostelId;
      if (state.feesHostelFilter != 'All Hostels' && state.feesHostelFilter.isNotEmpty) {
        final match = state.structureTree.where((h) => h.name == state.feesHostelFilter).firstOrNull;
        if (match != null) hostelId = match.id;
      }
      
      List<String>? targetIds;
      if (onlySelected || state.selectedFeeAccountIds.isNotEmpty) {
        targetIds = state.selectedFeeAccountIds.toList();
      }

      final bytes = await _feeService.exportFeesCsv(
        academicYear: state.selectedAcademicYear,
        hostelId: hostelId,
        className: state.feesClassFilter,
        status: state.feesStatusFilter,
        search: state.feesSearch,
        accountIds: targetIds,
        studentIds: targetIds,
      );
      if (bytes != null && bytes.isNotEmpty) {
        final dateStr = DateTime.now().toIso8601String().split('T')[0];
        final filename = 'hostel_fees_${state.selectedAcademicYear.replaceAll(' ', '_')}_$dateStr.csv';
        await getDownloadHelper().downloadBytes(bytes, filename);
        showSuccess('Hostel fees CSV downloaded successfully');
        return true;
      } else {
        showError('Unable to download CSV file');
      }
    } catch (e) {
      showError('Error exporting CSV: $e');
    }
    return false;
  }

  // ==========================================================================
  // HOSTEL LEAVE & OUTING MANAGEMENT WORKFLOWS
  // ==========================================================================

  Future<void> loadLeaveOutingData({bool refreshKPIs = true}) async {
    state = state.copyWith(isLeaveLoading: true);
    try {
      LeaveOutingKpiData? kpis;
      if (refreshKPIs) {
        try {
          kpis = await _leaveService.getKpis(academicYear: state.selectedAcademicYear);
        } catch (e) {
          debugPrint('Error loading leave KPIs: $e');
        }
      }

      Map<String, dynamic> reqData = {'items': <LeaveOutingRequestItem>[], 'total': 0};
      try {
        final fromDateStr = state.leaveDateRange?.start.toIso8601String().split('T').first;
        final toDateStr = state.leaveDateRange?.end.toIso8601String().split('T').first;

        reqData = await _leaveService.getRequests(
          search: state.leaveSearchQuery,
          hostelId: state.leaveHostelFilter,
          requestType: state.leaveTypeFilter,
          status: state.leaveStatusFilter,
          fromDate: fromDateStr,
          toDate: toDateStr,
          page: state.leavePagination['page'] as int? ?? 1,
          pageSize: state.leavePagination['page_size'] as int? ?? 10,
          sortBy: state.leaveSortBy,
          sortOrder: state.leaveSortOrder,
          academicYear: state.selectedAcademicYear,
        );
      } catch (e) {
        debugPrint('Error loading leave requests: $e');
      }

      List<AwaitingApprovalItem> awaitingList = [];
      try {
        awaitingList = await _leaveService.getAwaitingApproval(limit: 8);
      } catch (e) {
        debugPrint('Error loading awaiting approval: $e');
      }

      Map<String, dynamic> currData = {'items': <LeaveOutingRequestItem>[]};
      try {
        currData = await _leaveService.getCurrentlyOut();
      } catch (e) {
        debugPrint('Error loading currently out: $e');
      }

      LeaveOutingSettingsData? settings;
      try {
        settings = await _leaveService.getSettings();
      } catch (e) {
        debugPrint('Error loading settings: $e');
      }

      LeaveOutingRequestItem? refreshedSelected = state.selectedLeaveRequest;
      if (refreshedSelected != null && reqData['items'] != null) {
        final items = reqData['items'] as List<LeaveOutingRequestItem>;
        final match = items.where((r) => r.id == refreshedSelected!.id);
        if (match.isNotEmpty) {
          final row = match.first;
          refreshedSelected = refreshedSelected.copyWith(
            status: row.status,
            version: row.version,
            actualExitAt: row.actualExitAt ?? refreshedSelected.actualExitAt,
            actualReturnAt: row.actualReturnAt ?? refreshedSelected.actualReturnAt,
            approvedByName: row.approvedByName ?? refreshedSelected.approvedByName,
            approvedAt: row.approvedAt ?? refreshedSelected.approvedAt,
            approvalRemarks: row.approvalRemarks ?? refreshedSelected.approvalRemarks,
            documents: row.documents.isNotEmpty ? row.documents : refreshedSelected.documents,
            timeline: refreshedSelected.timeline.isNotEmpty ? refreshedSelected.timeline : row.timeline,
          );
        }
      }

      state = state.copyWith(
        leaveKpis: kpis ?? state.leaveKpis,
        leaveRequests: reqData['items'] as List<LeaveOutingRequestItem>? ?? state.leaveRequests,
        selectedLeaveRequest: refreshedSelected,
        leavePagination: {
          'total': reqData['total'] ?? state.leavePagination['total'] ?? 0,
          'page': reqData['page'] ?? state.leavePagination['page'] ?? 1,
          'page_size': reqData['page_size'] ?? state.leavePagination['page_size'] ?? 10,
          'total_pages': reqData['total_pages'] ?? state.leavePagination['total_pages'] ?? 1,
        },
        awaitingApprovalList: awaitingList.isNotEmpty ? awaitingList : state.awaitingApprovalList,
        currentlyOutList: currData['items'] as List<LeaveOutingRequestItem>? ?? state.currentlyOutList,
        leaveSettings: settings ?? state.leaveSettings,
        isLeaveLoading: false,
      );
      loadGatePasses();
    } catch (e) {
      state = state.copyWith(
        isLeaveLoading: false,
        errorMessage: 'Failed to load leave & outing data: $e',
      );
    }
  }

  Future<void> refreshLeaveOuting() async {
    await loadLeaveOutingData(refreshKPIs: true);
  }

  void setLeaveSubTab(int index) {
    var status = state.leaveStatusFilter;
    if (index == 1 && (status == 'PENDING' || status == 'REJECTED')) {
      status = 'All Status';
    }
    state = state.copyWith(leaveSubTab: index, leaveStatusFilter: status);
    if (index == 1 || index == 3) {
      loadGatePasses(resetPage: true);
    } else {
      loadLeaveOutingData(refreshKPIs: false);
    }
  }

  Future<void> loadGatePasses({
    bool resetPage = false,
    String? search,
    String? status,
    String? hostelName,
    String? requestType,
    DateTimeRange? dateRange,
  }) async {
    state = state.copyWith(isGatePassesLoading: true);
    try {
      final page = resetPage ? 1 : (state.gatePassesPagination['page'] as int? ?? 1);
      final activeSearch = search ?? state.leaveSearchQuery;
      final activeStatus = status ?? (state.leaveStatusFilter != 'All Status' ? state.leaveStatusFilter : null);
      final activeHostel = hostelName ?? (state.leaveHostelFilter != 'All Hostels' ? state.leaveHostelFilter : null);
      final activeType = requestType ?? (state.leaveTypeFilter != 'All Types' ? state.leaveTypeFilter : null);
      final activeRange = dateRange ?? state.leaveDateRange;

      final res = await _leaveService.getGatePasses(
        search: activeSearch,
        status: activeStatus,
        hostelName: activeHostel,
        requestType: activeType,
        fromDate: activeRange?.start != null ? DateFormat('yyyy-MM-dd').format(activeRange!.start) : null,
        toDate: activeRange?.end != null ? DateFormat('yyyy-MM-dd').format(activeRange!.end) : null,
        academicYear: state.selectedAcademicYear,
        page: page,
        pageSize: state.gatePassesPagination['page_size'] as int? ?? 10,
        sortBy: state.gatePassesSortBy,
        sortOrder: state.gatePassesSortOrder,
      );
      state = state.copyWith(
        gatePassesList: res['items'] as List<GatePassData>? ?? [],
        gatePassesPagination: {
          'total': res['total'] ?? 0,
          'page': res['page'] ?? 1,
          'page_size': res['page_size'] ?? 10,
          'total_pages': res['total_pages'] ?? 1,
        },
        isGatePassesLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isGatePassesLoading: false);
    }
  }

  Future<void> setGatePassPage(int page) async {
    final current = state.gatePassesPagination;
    state = state.copyWith(
      gatePassesPagination: {
        ...current,
        'page': page,
      },
    );
    await loadGatePasses();
  }

  Future<void> setGatePassPageSize(int size) async {
    final current = state.gatePassesPagination;
    state = state.copyWith(
      gatePassesPagination: {
        ...current,
        'page': 1,
        'page_size': size,
      },
    );
    await loadGatePasses();
  }

  Future<void> setGatePassSort(String sortBy) async {
    final nextOrder = (state.gatePassesSortBy == sortBy && state.gatePassesSortOrder == 'ASC')
        ? 'DESC'
        : 'ASC';
    state = state.copyWith(gatePassesSortBy: sortBy, gatePassesSortOrder: nextOrder);
    await loadGatePasses(resetPage: true);
  }

  void setLeaveSearch(String query) {
    state = state.copyWith(
      leaveSearchQuery: query,
      leavePagination: {...state.leavePagination, 'page': 1},
      gatePassesPagination: {...state.gatePassesPagination, 'page': 1},
    );
    loadLeaveOutingData(refreshKPIs: false);
    loadGatePasses(resetPage: true);
  }

  void setLeaveSearchQuery(String query) => setLeaveSearch(query);

  void setLeaveDateRange(DateTimeRange? range) {
    state = state.copyWith(
      leaveDateRange: range,
      clearLeaveDateRange: range == null,
      leavePagination: {...state.leavePagination, 'page': 1},
      gatePassesPagination: {...state.gatePassesPagination, 'page': 1},
    );
    loadLeaveOutingData(refreshKPIs: false);
    loadGatePasses(resetPage: true);
  }

  void setLeaveHostelFilter(String hostel) {
    state = state.copyWith(
      leaveHostelFilter: hostel,
      leavePagination: {...state.leavePagination, 'page': 1},
      gatePassesPagination: {...state.gatePassesPagination, 'page': 1},
    );
    loadLeaveOutingData(refreshKPIs: false);
    loadGatePasses(resetPage: true);
  }

  void setLeaveTypeFilter(String type) {
    state = state.copyWith(
      leaveTypeFilter: type,
      leavePagination: {...state.leavePagination, 'page': 1},
      gatePassesPagination: {...state.gatePassesPagination, 'page': 1},
    );
    loadLeaveOutingData(refreshKPIs: false);
    loadGatePasses(resetPage: true);
  }

  void setLeaveStatusFilter(String status) {
    state = state.copyWith(
      leaveStatusFilter: status,
      leavePagination: {...state.leavePagination, 'page': 1},
      gatePassesPagination: {...state.gatePassesPagination, 'page': 1},
    );
    loadLeaveOutingData(refreshKPIs: false);
    loadGatePasses(resetPage: true);
  }

  void setLeavePage(int page) {
    state = state.copyWith(
      leavePagination: {...state.leavePagination, 'page': page},
    );
    loadLeaveOutingData(refreshKPIs: false);
  }

  void setLeavePageSize(int pageSize) {
    state = state.copyWith(
      leavePagination: {...state.leavePagination, 'page_size': pageSize, 'page': 1},
    );
    loadLeaveOutingData(refreshKPIs: false);
  }

  void setLeaveSort(String sortBy) {
    final newOrder = (state.leaveSortBy == sortBy && state.leaveSortOrder == 'asc') ? 'desc' : 'asc';
    state = state.copyWith(leaveSortBy: sortBy, leaveSortOrder: newOrder);
    loadLeaveOutingData(refreshKPIs: false);
  }

  void selectLeaveRequest(LeaveOutingRequestItem? req) {
    state = state.copyWith(
      selectedLeaveRequest: req,
      isLeaveDrawerOpen: req != null,
    );
    if (req != null) {
      refreshSelectedLeaveRequest(req.id);
    }
  }

  Future<void> refreshSelectedLeaveRequest(String id) async {
    try {
      final detail = await _leaveService.getRequestById(id);
      if (detail != null && state.selectedLeaveRequest?.id == id) {
        final current = state.selectedLeaveRequest!;
        final item = LeaveOutingRequestItem.fromJson(detail);
        final resolvedItem = (item.studentName == 'Unknown Student' && current.studentName != 'Unknown Student')
            ? item.copyWith(
                studentName: current.studentName,
                studentId: current.studentId.isNotEmpty ? current.studentId : item.studentId,
                admissionNumber: current.admissionNumber ?? item.admissionNumber,
                rollNumber: current.rollNumber ?? item.rollNumber,
                className: current.className ?? item.className,
                sectionName: current.sectionName ?? item.sectionName,
                hostelName: current.hostelName ?? item.hostelName,
                roomNumber: current.roomNumber ?? item.roomNumber,
                bedNumber: current.bedNumber ?? item.bedNumber,
              )
            : item;

        final updatedList = state.leaveRequests.map((r) {
          if (r.id == resolvedItem.id) {
            return resolvedItem;
          }
          return r;
        }).toList();

        state = state.copyWith(
          selectedLeaveRequest: resolvedItem,
          leaveRequests: updatedList,
        );
      }
    } catch (_) {}
  }

  Future<void> selectLeaveRequestById(String id) async {
    final matches = state.leaveRequests.where((r) => r.id == id);
    if (matches.isNotEmpty) {
      selectLeaveRequest(matches.first);
      return;
    }
    final detail = await _leaveService.getRequestById(id);
    if (detail != null) {
      final item = LeaveOutingRequestItem.fromJson(detail);
      selectLeaveRequest(item);
    }
  }

  void clearSelectedLeaveRequest() {
    state = state.copyWith(
      clearSelectedLeaveRequest: true,
      isLeaveDrawerOpen: false,
    );
  }

  Future<bool> createLeaveOutingRequest(Map<String, dynamic> payload) async {
    try {
      if (!payload.containsKey('academic_year') || payload['academic_year'] == null || (payload['academic_year'] as String).isEmpty) {
        payload['academic_year'] = state.selectedAcademicYear;
      }
      final res = await _leaveService.createRequest(payload);
      if (res['success'] == true) {
        showSuccess(res['message'] ?? 'Leave/Outing request created successfully');
        await loadLeaveOutingData();
        if (state.leaveSubTab == 1 || state.leaveSubTab == 3) {
          await loadGatePasses();
        }
        if (state.selectedStudentId != null) {
          await fetchStudentDetail(state.selectedStudentId!);
        }
        return true;
      } else {
        showError(res['message'] ?? 'Failed to create request');
      }
    } catch (e) {
      showError('Error creating request: $e');
    }
    return false;
  }

  Future<bool> approveLeaveRequest(String id, {String remarks = 'Approved by Warden.', int? version}) async {
    try {
      final res = await _leaveService.approveRequest(id, notes: remarks, version: version ?? 1);
      if (res['success'] == true) {
        showSuccess('Request approved & Digital Gate Pass generated');
        if (res['data'] is Map<String, dynamic>) {
          state = state.copyWith(selectedLeaveRequest: LeaveOutingRequestItem.fromJson(res['data'] as Map<String, dynamic>));
        }
        await loadLeaveOutingData(refreshKPIs: true);
        await refreshSelectedLeaveRequest(id);
        return true;
      } else {
        showError(res['message'] ?? 'Failed to approve request');
      }
    } catch (e) {
      showError('Error approving request: $e');
    }
    return false;
  }

  Future<bool> rejectLeaveRequest(String id, {required String reason, int? version}) async {
    try {
      final res = await _leaveService.rejectRequest(id, reason: reason, version: version ?? 1);
      if (res['success'] == true) {
        showSuccess('Request rejected');
        if (res['data'] is Map<String, dynamic>) {
          state = state.copyWith(selectedLeaveRequest: LeaveOutingRequestItem.fromJson(res['data'] as Map<String, dynamic>));
        }
        await loadLeaveOutingData(refreshKPIs: true);
        await refreshSelectedLeaveRequest(id);
        return true;
      } else {
        showError(res['message'] ?? 'Failed to reject request');
      }
    } catch (e) {
      showError('Error rejecting request: $e');
    }
    return false;
  }

  Future<bool> cancelLeaveRequest(String id, {required String reason, int? version}) async {
    try {
      final res = await _leaveService.cancelRequest(id, reason: reason, version: version ?? 1);
      if (res['success'] == true) {
        showSuccess('Request cancelled');
        if (res['data'] is Map<String, dynamic>) {
          state = state.copyWith(selectedLeaveRequest: LeaveOutingRequestItem.fromJson(res['data'] as Map<String, dynamic>));
        }
        await loadLeaveOutingData(refreshKPIs: true);
        await refreshSelectedLeaveRequest(id);
        return true;
      } else {
        showError(res['message'] ?? 'Failed to cancel request');
      }
    } catch (e) {
      showError('Error cancelling request: $e');
    }
    return false;
  }

  Future<bool> markMovementExit(String id, {String gate = 'Main Gate', String? remarks}) async {
    try {
      final res = await _leaveService.markExit(id, gate: gate, remarks: remarks);
      if (res['success'] == true) {
        showSuccess('Student departure recorded (Status: EXITED)');
        if (res['data'] is Map<String, dynamic>) {
          state = state.copyWith(selectedLeaveRequest: LeaveOutingRequestItem.fromJson(res['data'] as Map<String, dynamic>));
        }
        await loadLeaveOutingData(refreshKPIs: true);
        await refreshSelectedLeaveRequest(id);
        return true;
      } else {
        showError(res['message'] ?? 'Failed to record exit');
      }
    } catch (e) {
      showError('Error recording exit: $e');
    }
    return false;
  }

  Future<bool> markMovementReturn(String id, {String gate = 'Main Gate', String? remarks}) async {
    try {
      final res = await _leaveService.markReturn(id, gate: gate, remarks: remarks);
      if (res['success'] == true) {
        showSuccess('Student return recorded (Status: RETURNED)');
        if (res['data'] is Map<String, dynamic>) {
          state = state.copyWith(selectedLeaveRequest: LeaveOutingRequestItem.fromJson(res['data'] as Map<String, dynamic>));
        }
        await loadLeaveOutingData(refreshKPIs: true);
        await refreshSelectedLeaveRequest(id);
        return true;
      } else {
        showError(res['message'] ?? 'Failed to record return');
      }
    } catch (e) {
      showError('Error recording return: $e');
    }
    return false;
  }

  Future<Map<String, dynamic>> verifyGatePass(String token) async {
    try {
      return await _leaveService.verifyGatePass(token);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> scanGatePassImage(String base64Image) async {
    try {
      return await _leaveService.scanGatePassImage(base64Image);
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<bool> executeGatePassScanAction(
    String identifier, {
    required String action,
    String gate = 'Main Gate',
    String? remarks,
  }) async {
    try {
      final res = await _leaveService.executeGatePassScanAction(
        identifier,
        action: action,
        gate: gate,
        remarks: remarks,
      );
      if (res['success'] == true) {
        final isExit = action.toUpperCase() == 'EXIT' || action.toUpperCase() == 'CHECK_OUT';
        showSuccess(isExit ? 'Departure recorded successfully' : 'Arrival recorded successfully');
        await loadGatePasses();
        await loadLeaveOutingData(refreshKPIs: true);
        if (state.selectedLeaveRequest != null) {
          await refreshSelectedLeaveRequest(state.selectedLeaveRequest!.id);
        }
        return true;
      } else {
        showError(res['message'] ?? 'Failed to record gate clearance');
        return false;
      }
    } catch (e) {
      showError('Error executing clearance: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // LEAVE & OUTING DRAWER FULL CRUD ACTIONS
  // ---------------------------------------------------------------------------

  Future<bool> uploadLeaveDocument(String requestId, Map<String, dynamic> docPayload) async {
    try {
      final res = await _leaveService.addDocument(requestId, docPayload);
      if (res['success'] == true) {
        showSuccess('Supporting document added successfully');
        await loadLeaveOutingData(refreshKPIs: false);
        await refreshSelectedLeaveRequest(requestId);
        return true;
      } else {
        showError(res['message'] ?? 'Failed to upload document');
      }
    } catch (e) {
      showError('Error uploading document: $e');
    }
    return false;
  }

  Future<bool> deleteLeaveDocument(String requestId, String docId) async {
    try {
      final res = await _leaveService.deleteDocument(requestId, docId);
      if (res['success'] == true) {
        showSuccess('Document deleted successfully');
        await loadLeaveOutingData(refreshKPIs: false);
        await refreshSelectedLeaveRequest(requestId);
        return true;
      } else {
        showError(res['message'] ?? 'Failed to delete document');
      }
    } catch (e) {
      showError('Error deleting document: $e');
    }
    return false;
  }

  Future<List<int>?> downloadLeaveDocumentBytes(String requestId, String docId) async {
    try {
      return await _leaveService.downloadDocumentBytes(requestId, docId);
    } catch (e) {
      showError('Error downloading document: $e');
      return null;
    }
  }

  Future<void> downloadAndSaveLeaveDocument(String requestId, String docId, String fileName) async {
    try {
      final bytes = await _leaveService.downloadDocumentBytes(requestId, docId);
      if (bytes != null && bytes.isNotEmpty) {
        await getDownloadHelper().downloadBytes(Uint8List.fromList(bytes), fileName);
        showSuccess('Document "$fileName" downloaded successfully');
      } else {
        showError('Unable to download document file');
      }
    } catch (e) {
      showError('Error downloading document: $e');
    }
  }

  Future<bool> addLeaveInternalNote(String requestId, {required String note, String category = 'General'}) async {
    try {
      final res = await _leaveService.addNote(requestId, note: note, category: category);
      if (res['success'] == true) {
        showSuccess('Internal note recorded');
        await loadLeaveOutingData(refreshKPIs: false);
        await refreshSelectedLeaveRequest(requestId);
        return true;
      } else {
        showError(res['message'] ?? 'Failed to add note');
      }
    } catch (e) {
      showError('Error adding note: $e');
    }
    return false;
  }

  Future<bool> deleteLeaveInternalNote(String requestId, String noteId) async {
    try {
      final res = await _leaveService.deleteNote(requestId, noteId);
      if (res['success'] == true) {
        showSuccess('Internal note deleted');
        await loadLeaveOutingData(refreshKPIs: false);
        await refreshSelectedLeaveRequest(requestId);
        return true;
      } else {
        showError(res['message'] ?? 'Failed to delete note');
      }
    } catch (e) {
      showError('Error deleting note: $e');
    }
    return false;
  }

  Future<bool> updateLeaveRequestDetails(String requestId, Map<String, dynamic> payload) async {
    try {
      final res = await _leaveService.updateRequest(requestId, payload);
      if (res['success'] == true) {
        showSuccess('Request details updated successfully');
        await loadLeaveOutingData(refreshKPIs: false);
        await refreshSelectedLeaveRequest(requestId);
        return true;
      } else {
        showError(res['message'] ?? 'Failed to update request');
      }
    } catch (e) {
      showError('Error updating request: $e');
    }
    return false;
  }

  Future<bool> deleteLeaveRequest(String requestId) async {
    try {
      final res = await _leaveService.deleteRequest(requestId);
      if (res['success'] == true) {
        showSuccess('Request deleted successfully');
        clearSelectedLeaveRequest();
        await loadLeaveOutingData(refreshKPIs: true);
        return true;
      } else {
        showError(res['message'] ?? 'Failed to delete request');
      }
    } catch (e) {
      showError('Error deleting request: $e');
    }
    return false;
  }

  Future<bool> toggleGuardianConfirmation(String requestId, bool confirmed) async {
    try {
      final res = await _leaveService.confirmGuardian(requestId, confirmed);
      if (res['success'] == true) {
        showSuccess(confirmed ? 'Guardian telephonic confirmation verified' : 'Guardian confirmation cleared');
        await loadLeaveOutingData(refreshKPIs: false);
        await refreshSelectedLeaveRequest(requestId);
        return true;
      } else {
        showError(res['message'] ?? 'Failed to update confirmation');
      }
    } catch (e) {
      showError('Error updating confirmation: $e');
    }
    return false;
  }

  Future<bool> revokeLeaveApproval(String requestId, {String? reason}) async {
    try {
      final res = await _leaveService.revokeApproval(requestId, reason: reason);
      if (res['success'] == true) {
        showSuccess('Approval revoked, request returned to Pending status');
        await loadLeaveOutingData(refreshKPIs: true);
        await refreshSelectedLeaveRequest(requestId);
        return true;
      } else {
        showError(res['message'] ?? 'Failed to revoke approval');
      }
    } catch (e) {
      showError('Error revoking approval: $e');
    }
    return false;
  }

  Future<bool> resetLeaveMovement(String requestId) async {
    try {
      final res = await _leaveService.resetMovement(requestId);
      if (res['success'] == true) {
        showSuccess('Movement record reset to Approved status');
        await loadLeaveOutingData(refreshKPIs: true);
        await refreshSelectedLeaveRequest(requestId);
        return true;
      } else {
        showError(res['message'] ?? 'Failed to reset movement');
      }
    } catch (e) {
      showError('Error resetting movement: $e');
    }
    return false;
  }

  Future<bool> updateLeaveMovement(String requestId, Map<String, dynamic> movementData) async {
    try {
      final res = await _leaveService.updateMovement(requestId, movementData);
      if (res['success'] == true) {
        showSuccess('Movement log updated successfully');
        await loadLeaveOutingData(refreshKPIs: false);
        await refreshSelectedLeaveRequest(requestId);
        return true;
      } else {
        showError(res['message'] ?? 'Failed to update movement log');
      }
    } catch (e) {
      showError('Error updating movement: $e');
    }
    return false;
  }

  Future<bool> generateLeaveGatePass(String requestId) async {
    try {
      final res = await _leaveService.generateGatePass(requestId);
      if (res['success'] == true) {
        showSuccess('Digital Gate Pass generated successfully');
        await loadGatePasses();
        await loadLeaveOutingData(refreshKPIs: false);
        await refreshSelectedLeaveRequest(requestId);
        return true;
      } else {
        showError(res['message'] ?? 'Failed to generate gate pass');
      }
    } catch (e) {
      showError('Error generating gate pass: $e');
    }
    return false;
  }

  void updateLeaveSetting({
    bool? leaveAllowed,
    bool? outingAllowed,
    bool? guardianConfirmationRequired,
    bool? autoGatepassOnApproval,
  }) {
    final current = state.leaveSettings;
    final updated = LeaveOutingSettingsData(
      leaveAllowed: leaveAllowed ?? current.leaveAllowed,
      outingAllowed: outingAllowed ?? current.outingAllowed,
      outingStartTime: current.outingStartTime,
      lastAllowedReturnTime: current.lastAllowedReturnTime,
      guardianConfirmationRequired: guardianConfirmationRequired ?? current.guardianConfirmationRequired,
      wardenApprovalRequired: current.wardenApprovalRequired,
      directorApprovalRequired: current.directorApprovalRequired,
      autoGatepassOnApproval: autoGatepassOnApproval ?? current.autoGatepassOnApproval,
      lateReturnGracePeriodMins: current.lateReturnGracePeriodMins,
      maxOutingsPerMonth: current.maxOutingsPerMonth,
      maxLeaveDays: current.maxLeaveDays,
    );
    state = state.copyWith(leaveSettings: updated);
  }

  Future<bool> saveLeaveSettings(LeaveOutingSettingsData settings) async {
    try {
      final res = await _leaveService.saveSettings(settings);
      if (res['success'] == true) {
        showSuccess('Movement rules and settings saved successfully');
        return true;
      } else {
        showError(res['message'] ?? 'Failed to save settings');
      }
    } catch (e) {
      showError('Error saving settings: $e');
    }
    return false;
  }

  Future<bool> exportLeaveOutingCsv() async {
    try {
      showSuccess('Exporting Leave & Outing requests to CSV...');
      final bytes = await _leaveService.exportLeaveOutingCsv(academicYear: state.selectedAcademicYear);
      if (bytes != null && bytes.isNotEmpty) {
        final dateStr = DateTime.now().toIso8601String().split('T')[0];
        await getDownloadHelper().downloadBytes(bytes, 'hostel_leave_outing_$dateStr.csv');
        showSuccess('Leave & Outing CSV downloaded successfully');
        return true;
      } else {
        showError('Unable to download CSV file');
      }
    } catch (e) {
      showError('Error exporting CSV: $e');
    }
    return false;
  }

  // ============================================================================
  // HOSTEL COMPLAINTS MODULE METHODS
  // ============================================================================

  Future<void> loadComplaintsData() async {
    state = state.copyWith(isComplaintsLoading: true);
    try {
      final overviewFuture = _complaintService.getOverview(academicYear: state.selectedAcademicYear);
      final fromDateStr = state.complaintsDateRange?.start.toIso8601String().split('T').first;
      final toDateStr = state.complaintsDateRange?.end.toIso8601String().split('T').first;
      final listFuture = _complaintService.getComplaints(
        search: state.complaintsSearch,
        hostel: state.complaintsHostelFilter,
        category: state.complaintsCategoryFilter,
        priority: state.complaintsPriorityFilter,
        status: state.complaintsStatusFilter,
        subtab: state.complaintsSubtab,
        fromDate: fromDateStr,
        toDate: toDateStr,
        page: state.complaintsPagination.page,
        pageSize: state.complaintsPagination.pageSize,
        sortBy: state.complaintsSortBy,
        sortOrder: state.complaintsSortOrder,
        academicYear: state.selectedAcademicYear,
      );

      final results = await Future.wait([overviewFuture, listFuture]);
      final kpis = results[0] as ComplaintKpiData;
      final listMap = results[1] as Map<String, dynamic>;
      final records = listMap['records'] as List<HostelComplaintItem>;
      final pagination = listMap['pagination'] as ComplaintPagination;

      String? autoSelectId = state.selectedComplaintId;
      if (autoSelectId == null || !records.any((r) => r.id == autoSelectId)) {
        if (records.isNotEmpty) {
          final match001 = records.firstWhere(
            (r) => r.complaintNumber == 'HC-2026-001' || r.complaintNumber == 'HC-2024-001',
            orElse: () => records.first,
          );
          autoSelectId = match001.id;
        } else {
          autoSelectId = null;
        }
      }

      state = state.copyWith(
        complaintKpis: kpis,
        complaintsList: records,
        complaintsPagination: pagination,
        isComplaintsLoading: false,
        selectedComplaintId: autoSelectId,
        selectedComplaintDetail: autoSelectId == null ? null : state.selectedComplaintDetail,
        isComplaintDrawerOpen: autoSelectId != null,
      );

      if (autoSelectId != null) {
        await fetchComplaintDetail(autoSelectId);
      }
    } catch (e) {
      state = state.copyWith(
        isComplaintsLoading: false,
        errorMessage: 'Failed to load complaints: $e',
      );
    }
  }

  Future<void> fetchComplaintsList({int? page}) async {
    state = state.copyWith(isComplaintsLoading: true);
    final targetPage = page ?? state.complaintsPagination.page;
    try {
      final fromDateStr = state.complaintsDateRange?.start.toIso8601String().split('T').first;
      final toDateStr = state.complaintsDateRange?.end.toIso8601String().split('T').first;
      final res = await _complaintService.getComplaints(
        search: state.complaintsSearch,
        hostel: state.complaintsHostelFilter,
        category: state.complaintsCategoryFilter,
        priority: state.complaintsPriorityFilter,
        status: state.complaintsStatusFilter,
        subtab: state.complaintsSubtab,
        fromDate: fromDateStr,
        toDate: toDateStr,
        page: targetPage,
        pageSize: state.complaintsPagination.pageSize,
        sortBy: state.complaintsSortBy,
        sortOrder: state.complaintsSortOrder,
        academicYear: state.selectedAcademicYear,
      );

      final records = res['records'] as List<HostelComplaintItem>;
      final pagination = res['pagination'] as ComplaintPagination;

      state = state.copyWith(
        complaintsList: records,
        complaintsPagination: pagination,
        isComplaintsLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isComplaintsLoading: false,
        errorMessage: 'Failed to filter complaints: $e',
      );
    }
  }

  Future<void> fetchComplaintDetail(String complaintId) async {
    state = state.copyWith(
      isComplaintDetailLoading: true,
      selectedComplaintId: complaintId,
      isComplaintDrawerOpen: true,
    );
    try {
      final detail = await _complaintService.getComplaintById(complaintId);
      state = state.copyWith(
        selectedComplaintDetail: detail,
        isComplaintDetailLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isComplaintDetailLoading: false,
        errorMessage: 'Failed to load complaint details: $e',
      );
    }
  }

  void selectComplaint(String complaintId) {
    fetchComplaintDetail(complaintId);
  }

  void closeComplaintDrawer() {
    state = state.copyWith(
      isComplaintDrawerOpen: false,
      clearSelectedComplaint: true,
    );
  }

  void setComplaintDrawerTab(int tab) {
    state = state.copyWith(complaintDrawerTab: tab);
  }

  void setComplaintsSearch(String query) {
    state = state.copyWith(
      complaintsSearch: query,
      complaintsPagination: ComplaintPagination(
        page: 1,
        pageSize: state.complaintsPagination.pageSize,
      ),
    );
    fetchComplaintsList(page: 1);
  }

  void setComplaintsHostel(String hostel) {
    state = state.copyWith(
      complaintsHostelFilter: hostel,
      complaintsPagination: ComplaintPagination(
        page: 1,
        pageSize: state.complaintsPagination.pageSize,
      ),
    );
    fetchComplaintsList(page: 1);
  }

  void setComplaintsCategory(String category) {
    state = state.copyWith(
      complaintsCategoryFilter: category,
      complaintsPagination: ComplaintPagination(
        page: 1,
        pageSize: state.complaintsPagination.pageSize,
      ),
    );
    fetchComplaintsList(page: 1);
  }

  void setComplaintsPriority(String priority) {
    state = state.copyWith(
      complaintsPriorityFilter: priority,
      complaintsPagination: ComplaintPagination(
        page: 1,
        pageSize: state.complaintsPagination.pageSize,
      ),
    );
    fetchComplaintsList(page: 1);
  }

  void setComplaintsStatus(String status) {
    state = state.copyWith(
      complaintsStatusFilter: status,
      complaintsPagination: ComplaintPagination(
        page: 1,
        pageSize: state.complaintsPagination.pageSize,
      ),
    );
    fetchComplaintsList(page: 1);
  }

  void setComplaintsSubtab(String subtab) {
    state = state.copyWith(
      complaintsSubtab: subtab,
      complaintsPagination: ComplaintPagination(
        page: 1,
        pageSize: state.complaintsPagination.pageSize,
      ),
    );
    fetchComplaintsList(page: 1);
  }

  void setComplaintsDateRange(DateTimeRange? range) {
    state = state.copyWith(
      complaintsDateRange: range,
      clearComplaintsDateRange: range == null,
      complaintsPagination: ComplaintPagination(
        page: 1,
        pageSize: state.complaintsPagination.pageSize,
      ),
    );
    fetchComplaintsList(page: 1);
  }

  void setComplaintsSort(String sortBy, String sortOrder) {
    state = state.copyWith(complaintsSortBy: sortBy, complaintsSortOrder: sortOrder);
    fetchComplaintsList();
  }

  void setComplaintsPage(int page) {
    fetchComplaintsList(page: page);
  }

  void setComplaintsPageSize(int size) {
    state = state.copyWith(
      complaintsPagination: ComplaintPagination(page: 1, pageSize: size),
    );
    fetchComplaintsList(page: 1);
  }

  void toggleComplaintSelection(String id) {
    final current = Set<String>.from(state.selectedComplaintIds);
    if (current.contains(id)) {
      current.remove(id);
    } else {
      current.add(id);
    }
    state = state.copyWith(selectedComplaintIds: current);
  }

  void selectAllComplaints(bool selectAll) {
    if (selectAll) {
      final ids = state.complaintsList.map((c) => c.id).toSet();
      state = state.copyWith(selectedComplaintIds: ids);
    } else {
      state = state.copyWith(selectedComplaintIds: const {});
    }
  }

  Future<String?> uploadComplaintAttachment(List<int> bytes, String filename) async {
    try {
      return await _complaintService.uploadAttachment(bytes, filename);
    } catch (e) {
      showError('Failed to upload attachment: $e');
      return null;
    }
  }

  Future<bool> uploadComplaintAttachmentForComplaint(
    String complaintId,
    List<int> bytes,
    String filename,
  ) async {
    try {
      final res = await _complaintService.uploadAttachmentToComplaint(
        complaintId,
        bytes,
        filename,
      );
      if (res['success'] == true) {
        showSuccess('Attachment uploaded successfully');
        await fetchComplaintDetail(complaintId);
        return true;
      } else {
        showError(res['message'] ?? 'Failed to upload attachment');
      }
    } catch (e) {
      showError('Error uploading attachment: $e');
    }
    return false;
  }

  Future<bool> createComplaint(Map<String, dynamic> payload) async {
    try {
      final res = await _complaintService.createComplaint(payload);
      if (res['success'] == true) {
        showSuccess('Complaint ${res['complaint_number'] ?? ''} raised successfully');
        await loadComplaintsData();
        return true;
      } else {
        showError(res['message'] ?? 'Failed to raise complaint');
      }
    } catch (e) {
      showError('Error creating complaint: $e');
    }
    return false;
  }

  Future<bool> assignComplaint(
    String id,
    String userId, {
    String? userName,
    String? role,
    String? notes,
  }) async {
    try {
      final res = await _complaintService.assignComplaint(
        id,
        assignedUserId: userId,
        assignedUserName: userName,
        assignedUserRole: role,
        notes: notes,
      );
      if (res['success'] == true) {
        showSuccess(res['message'] ?? 'Technician assigned successfully');
        await fetchComplaintDetail(id);
        await fetchComplaintsList();
        return true;
      } else {
        showError(res['message'] ?? 'Failed to assign complaint');
      }
    } catch (e) {
      showError('Error assigning complaint: $e');
    }
    return false;
  }

  Future<bool> updateComplaintStatus(
    String id,
    String status, {
    String? reason,
    String? summary,
    String? type,
    List<dynamic>? parts,
    double? cost,
    String? equipmentStatus,
  }) async {
    try {
      final res = await _complaintService.updateStatus(
        id,
        status: status,
        reason: reason,
        resolutionSummary: summary,
        resolutionType: type,
        partsUsed: parts,
        cost: cost,
        equipmentStatus: equipmentStatus,
      );
      if (res['success'] == true) {
        showSuccess(res['message'] ?? 'Status updated to $status');
        await fetchComplaintDetail(id);
        await fetchComplaintsList();
        await _complaintService.getOverview(academicYear: state.selectedAcademicYear).then((kpis) {
          state = state.copyWith(complaintKpis: kpis);
        });
        return true;
      } else {
        showError(res['message'] ?? 'Failed to update status');
      }
    } catch (e) {
      showError('Error updating status: $e');
    }
    return false;
  }

  Future<bool> resolveComplaint(
    String id,
    String summary, {
    String type = 'Repaired',
    List<dynamic>? parts,
    double? cost,
    String? equipmentStatus,
  }) async {
    try {
      final res = await _complaintService.resolveComplaint(
        id,
        resolutionSummary: summary,
        resolutionType: type,
        partsUsed: parts,
        cost: cost,
        equipmentStatus: equipmentStatus,
      );
      if (res['success'] == true) {
        showSuccess('Complaint marked as resolved');
        await fetchComplaintDetail(id);
        await fetchComplaintsList();
        await _complaintService.getOverview(academicYear: state.selectedAcademicYear).then((kpis) {
          state = state.copyWith(complaintKpis: kpis);
        });
        return true;
      } else {
        showError(res['message'] ?? 'Failed to resolve complaint');
      }
    } catch (e) {
      showError('Error resolving complaint: $e');
    }
    return false;
  }

  Future<bool> completeComplaint(String id) async {
    try {
      final res = await _complaintService.completeComplaint(id);
      if (res['success'] == true) {
        showSuccess('Complaint verified and completed');
        await fetchComplaintDetail(id);
        await fetchComplaintsList();
        await _complaintService.getOverview(academicYear: state.selectedAcademicYear).then((kpis) {
          state = state.copyWith(complaintKpis: kpis);
        });
        return true;
      } else {
        showError(res['message'] ?? 'Failed to complete complaint');
      }
    } catch (e) {
      showError('Error completing complaint: $e');
    }
    return false;
  }

  Future<bool> reopenComplaint(String id, {String? reason}) async {
    try {
      final res = await _complaintService.reopenComplaint(id, reason: reason);
      if (res['success'] == true) {
        showSuccess('Complaint reopened');
        await fetchComplaintDetail(id);
        await fetchComplaintsList();
        return true;
      } else {
        showError(res['message'] ?? 'Failed to reopen complaint');
      }
    } catch (e) {
      showError('Error reopening complaint: $e');
    }
    return false;
  }

  Future<bool> rejectComplaint(String id, String reason) async {
    try {
      final res = await _complaintService.rejectComplaint(id, reason: reason);
      if (res['success'] == true) {
        showSuccess('Complaint rejected');
        await fetchComplaintDetail(id);
        await fetchComplaintsList();
        return true;
      } else {
        showError(res['message'] ?? 'Failed to reject complaint');
      }
    } catch (e) {
      showError('Error rejecting complaint: $e');
    }
    return false;
  }

  Future<bool> cancelComplaint(String id, {String? reason}) async {
    try {
      final res = await _complaintService.cancelComplaint(id, reason: reason);
      if (res['success'] == true) {
        showSuccess('Complaint canceled');
        await fetchComplaintDetail(id);
        await fetchComplaintsList();
        return true;
      } else {
        showError(res['message'] ?? 'Failed to cancel complaint');
      }
    } catch (e) {
      showError('Error canceling complaint: $e');
    }
    return false;
  }

  Future<bool> addComplaintComment(
    String id,
    String message, {
    String type = 'PUBLIC_UPDATE',
    List<dynamic>? attachments,
  }) async {
    try {
      final res = await _complaintService.addComment(
        id,
        message: message,
        commentType: type,
        attachments: attachments,
      );
      if (res['success'] == true) {
        showSuccess(type == 'INTERNAL_NOTE' ? 'Internal note added' : 'Update posted to conversation');
        await fetchComplaintDetail(id);
        return true;
      } else {
        showError(res['message'] ?? 'Failed to add comment');
      }
    } catch (e) {
      showError('Error posting comment: $e');
    }
    return false;
  }

  Future<bool> submitComplaintFeedback(
    String id,
    int rating, {
    int? quality,
    int? responseTime,
    int? staffBehavior,
    String? comment,
    bool isSatisfied = true,
  }) async {
    try {
      final res = await _complaintService.submitFeedback(
        id,
        rating: rating,
        quality: quality,
        responseTime: responseTime,
        staffBehavior: staffBehavior,
        comment: comment,
        isSatisfied: isSatisfied,
      );
      if (res['success'] == true) {
        showSuccess('Thank you for rating our service!');
        await fetchComplaintDetail(id);
        return true;
      } else {
        showError(res['message'] ?? 'Failed to submit feedback');
      }
    } catch (e) {
      showError('Error submitting feedback: $e');
    }
    return false;
  }

  Future<bool> bulkComplaintAction(
    String action, {
    String? userId,
    String? userName,
    String? priority,
    String? status,
    String? notes,
  }) async {
    final ids = state.selectedComplaintIds.toList();
    if (ids.isEmpty) {
      showError('Please select at least one complaint for bulk action');
      return false;
    }
    try {
      final res = await _complaintService.bulkAction(
        complaintIds: ids,
        action: action,
        userId: userId,
        userName: userName,
        priority: priority,
        status: status,
        notes: notes,
      );
      if (res['success'] == true) {
        showSuccess('Bulk action completed for ${ids.length} complaints');
        state = state.copyWith(selectedComplaintIds: const {});
        await loadComplaintsData();
        return true;
      } else {
        showError(res['message'] ?? 'Bulk action failed');
      }
    } catch (e) {
      showError('Error performing bulk action: $e');
    }
    return false;
  }

  Future<bool> exportComplaintsCsv() async {
    try {
      showSuccess('Exporting Complaints to CSV...');
      final bytes = await _complaintService.exportComplaintsCsv(
        academicYear: state.selectedAcademicYear,
        search: state.complaintsSearch,
        hostel: state.complaintsHostelFilter,
        category: state.complaintsCategoryFilter,
        priority: state.complaintsPriorityFilter,
        status: state.complaintsStatusFilter,
        subtab: state.complaintsSubtab,
      );
      if (bytes != null && bytes.isNotEmpty) {
        final dateStr = DateTime.now().toIso8601String().split('T')[0];
        await getDownloadHelper().downloadBytes(bytes, 'hostel_complaints_$dateStr.csv');
        showSuccess('Complaints CSV downloaded successfully');
        return true;
      } else {
        showError('Unable to download CSV file');
      }
    } catch (e) {
      showError('Error exporting complaints CSV: $e');
    }
    return false;
  }

  Future<void> refreshComplaints() async {
    await loadComplaintsData();
  }
}


final hostelProvider = StateNotifierProvider<HostelNotifier, HostelState>((ref) {
  return HostelNotifier();
});


