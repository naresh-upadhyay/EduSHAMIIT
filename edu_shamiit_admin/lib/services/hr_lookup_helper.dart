import 'package:flutter/foundation.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_core/services/lookup_event_bus.dart';

class HRLookupItem {
  final String id;
  final String code;
  final String label;
  final String description;
  final String status;
  final int sortOrder;

  const HRLookupItem({
    required this.id,
    required this.code,
    required this.label,
    this.description = '',
    this.status = 'ACTIVE',
    this.sortOrder = 0,
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';

  factory HRLookupItem.fromJson(Map<String, dynamic> json) {
    return HRLookupItem(
      id: json['id']?.toString() ?? '',
      code: json['value_code']?.toString() ?? json['code']?.toString() ?? '',
      label: json['value_name']?.toString() ?? json['label']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? 'ACTIVE',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );
  }
}

class HRLookupHelper extends ChangeNotifier {
  static final HRLookupHelper instance = HRLookupHelper._internal();
  HRLookupHelper._internal() {
    // Reactively listen to global lookup modifications from Lookup Management
    LookupEventBus.instance.addListener(_onGlobalLookupChanged);
  }

  final ApiService _api = ApiService();
  final Map<String, List<HRLookupItem>> _cache = {};

  void _onGlobalLookupChanged() {
    final event = LookupEventBus.instance.lastEvent;
    clearCache(event?.keyCode);
  }

  /// Preload common HR lookup keys in parallel
  Future<void> preloadHRLookups() async {
    await Future.wait([
      getLookupItems('DEPARTMENT'),
      getLookupItems('DESIGNATION'),
      getLookupItems('EMPLOYMENT_TYPE'),
      getLookupItems('WORK_MODE'),
      getLookupItems('RECRUITMENT_SOURCE'),
      getLookupItems('INTERVIEW_ROUND'),
      getLookupItems('INTERVIEW_MODE'),
      getLookupItems('ASSESSMENT_TYPE'),
      getLookupItems('RECRUITMENT_STAGE'),
      getLookupItems('TRAINING_CATEGORY'),
      getLookupItems('TRAINING_TYPE'),
      getLookupItems('TRAINING_MODE'),
      getLookupItems('TRAINING_ASSESSMENT_TYPE'),
      getLookupItems('POLICY_APPLICABILITY'),
      getLookupItems('POLICY_REVIEW_FREQUENCY'),
      getLookupItems('HR_DOCUMENT_TYPE'),
      getLookupItems('DOCUMENT_ACCESS_LEVEL'),
      getLookupItems('HR_TEMPLATE_TYPE'),
      getLookupItems('ONBOARDING_TASK_CATEGORY'),
    ]);
  }

  /// Get lookup items (full metadata) for a given key code
  Future<List<HRLookupItem>> getLookupItems(
    String keyCode, {
    List<HRLookupItem>? defaultFallback,
    bool forceRefresh = false,
  }) async {
    final upperKey = keyCode.toUpperCase().trim();
    if (!forceRefresh && _cache.containsKey(upperKey) && _cache[upperKey]!.isNotEmpty) {
      return _cache[upperKey]!;
    }

    if (upperKey == 'DEPARTMENT' || upperKey == 'DEPARTMENTS') {
      try {
        final res = await _api.get('/departments', useCache: false);
        final dynamic rawData = res['data'] ?? (res is List ? res : null);
        if (rawData is List && rawData.isNotEmpty) {
          final list = rawData.map((e) {
            final m = Map<String, dynamic>.from(e as Map);
            return HRLookupItem(
              id: m['id']?.toString() ?? '',
              code: m['code']?.toString() ?? (m['name']?.toString() ?? ''),
              label: m['name']?.toString() ?? '',
              description: m['description']?.toString() ?? '',
              sortOrder: m['sort_order'] is int ? m['sort_order'] as int : int.tryParse(m['sort_order']?.toString() ?? '0') ?? 0,
              status: m['status']?.toString() ?? 'ACTIVE',
            );
          }).where((item) => item.isActive && item.label.isNotEmpty).toList();

          if (list.isNotEmpty) {
            _cache[upperKey] = list;
            return list;
          }
        }
      } catch (_) {}
    }

    try {
      final res = await _api.get(
        '/lookups/code/$upperKey',
        query: {'include_inactive': false},
        useCache: false,
      );

      if (res['success'] == true && res['values'] is List) {
        final list = (res['values'] as List)
            .map((e) => HRLookupItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .where((item) => item.isActive)
            .toList();

        if (list.isNotEmpty) {
          _cache[upperKey] = list;
          return list;
        }
      }
    } catch (_) {}

    final fallback = _cache[upperKey] ?? defaultFallback ?? _getDefaultItems(upperKey);
    _cache[upperKey] = fallback;
    return fallback;
  }

  /// Get lookup string labels for dropdowns (e.g. ['Academics', 'Administration'])
  Future<List<String>> getLookupLabels(
    String keyCode, {
    List<String>? defaultFallback,
    bool forceRefresh = false,
  }) async {
    final items = await getLookupItems(
      keyCode,
      defaultFallback: defaultFallback?.map((lbl) => HRLookupItem(id: lbl, code: lbl, label: lbl)).toList(),
      forceRefresh: forceRefresh,
    );
    return items.map((e) => e.label).toList();
  }

  /// Synchronously get cached labels or default fallback
  List<String> getCachedLabels(String keyCode, {List<String>? defaultFallback}) {
    final upperKey = keyCode.toUpperCase().trim();
    if (_cache.containsKey(upperKey) && _cache[upperKey]!.isNotEmpty) {
      return _cache[upperKey]!.map((e) => e.label).toList();
    }
    return defaultFallback ?? _getDefaultItems(upperKey).map((e) => e.label).toList();
  }

  /// Invalidate cache and broadcast to all listeners
  void clearCache([String? keyCode]) {
    if (keyCode != null && keyCode.isNotEmpty) {
      _cache.remove(keyCode.toUpperCase().trim());
    } else {
      _cache.clear();
    }
    notifyListeners();
  }

  /// Explicitly refresh a lookup key from backend and notify listeners
  Future<List<String>> refreshKey(String keyCode) async {
    final labels = await getLookupLabels(keyCode, forceRefresh: true);
    notifyListeners();
    return labels;
  }

  /// Default fallback items when offline or during initial render
  List<HRLookupItem> _getDefaultItems(String key) {
    switch (key) {
      case 'DEPARTMENT':
        return const [
          HRLookupItem(id: '1', code: 'ACADEMIC', label: 'Academic / Teaching'),
          HRLookupItem(id: '2', code: 'ADMINISTRATION', label: 'Administration'),
          HRLookupItem(id: '3', code: 'MATHEMATICS', label: 'Mathematics'),
          HRLookupItem(id: '4', code: 'SCIENCE', label: 'Science'),
          HRLookupItem(id: '5', code: 'LANGUAGES', label: 'English / Languages'),
          HRLookupItem(id: '6', code: 'SOCIAL_STUDIES', label: 'Social Studies & Humanities'),
          HRLookupItem(id: '7', code: 'COMPUTER_SCIENCE', label: 'Computer Science & IT'),
          HRLookupItem(id: '8', code: 'FINANCE', label: 'Finance & Accounts'),
          HRLookupItem(id: '9', code: 'HR', label: 'Human Resources'),
          HRLookupItem(id: '10', code: 'LIBRARY', label: 'Library & Information'),
          HRLookupItem(id: '11', code: 'SPORTS', label: 'Physical Education & Sports'),
          HRLookupItem(id: '12', code: 'ARTS', label: 'Arts & Performing Arts'),
          HRLookupItem(id: '13', code: 'TRANSPORT', label: 'Transport & Fleet'),
          HRLookupItem(id: '14', code: 'HOSTEL', label: 'Hostel & Residential'),
          HRLookupItem(id: '15', code: 'SECURITY', label: 'Security & Safety'),
          HRLookupItem(id: '16', code: 'HEALTH_CLINIC', label: 'Medical & Health Clinic'),
          HRLookupItem(id: '17', code: 'MAINTENANCE', label: 'Maintenance & Facilities'),
          HRLookupItem(id: '18', code: 'EXAMINATION', label: 'Examination & Assessment'),
          HRLookupItem(id: '19', code: 'STUDENT_AFFAIRS', label: 'Student Affairs & Admissions'),
          HRLookupItem(id: '20', code: 'GENERAL', label: 'General / Unassigned'),
        ];
      case 'DESIGNATION':
        return const [
          HRLookupItem(id: '1', code: 'PRINCIPAL', label: 'Principal / Head of School'),
          HRLookupItem(id: '2', code: 'VICE_PRINCIPAL', label: 'Vice Principal'),
          HRLookupItem(id: '3', code: 'HOD', label: 'Head of Department (HOD)'),
          HRLookupItem(id: '4', code: 'PGT', label: 'Post Graduate Teacher (PGT)'),
          HRLookupItem(id: '5', code: 'TGT', label: 'Trained Graduate Teacher (TGT)'),
          HRLookupItem(id: '6', code: 'PRT', label: 'Primary Teacher (PRT)'),
          HRLookupItem(id: '7', code: 'KINDERGARTEN_TEACHER', label: 'Pre-Primary / Kindergarten Teacher'),
          HRLookupItem(id: '8', code: 'ARTS_TEACHER', label: 'Activity / Arts / Music Teacher'),
          HRLookupItem(id: '9', code: 'PET', label: 'Physical Education Instructor (PET)'),
          HRLookupItem(id: '10', code: 'COUNSELOR', label: 'Special Educator / Counselor'),
          HRLookupItem(id: '11', code: 'LAB_ASSISTANT', label: 'Laboratory Assistant'),
          HRLookupItem(id: '12', code: 'LIBRARIAN', label: 'Librarian / Media Specialist'),
          HRLookupItem(id: '13', code: 'ADMIN_OFFICER', label: 'Administrative Officer'),
          HRLookupItem(id: '14', code: 'ACCOUNTANT', label: 'Accountant / Finance Executive'),
          HRLookupItem(id: '15', code: 'HR_EXECUTIVE', label: 'Human Resources Executive'),
          HRLookupItem(id: '16', code: 'IT_ADMIN', label: 'IT Support Engineer / System Admin'),
          HRLookupItem(id: '17', code: 'FLEET_MANAGER', label: 'Transport Incharge / Fleet Manager'),
          HRLookupItem(id: '18', code: 'BUS_DRIVER', label: 'School Bus Driver'),
          HRLookupItem(id: '19', code: 'SECURITY_GUARD', label: 'Security Officer / Guard'),
          HRLookupItem(id: '20', code: 'SUPPORT_STAFF', label: 'Support Staff / Housekeeping'),
        ];
      case 'EMPLOYMENT_TYPE':
        return const [
          HRLookupItem(id: '1', code: 'FULL_TIME', label: 'Full-time'),
          HRLookupItem(id: '2', code: 'PART_TIME', label: 'Part-time'),
          HRLookupItem(id: '3', code: 'CONTRACTUAL', label: 'Contractual'),
          HRLookupItem(id: '4', code: 'TEMPORARY', label: 'Temporary'),
          HRLookupItem(id: '5', code: 'VISITING_FACULTY', label: 'Visiting Faculty'),
          HRLookupItem(id: '6', code: 'INTERNSHIP', label: 'Internship'),
        ];
      case 'WORK_MODE':
        return const [
          HRLookupItem(id: '1', code: 'ON_SITE', label: 'On-site'),
          HRLookupItem(id: '2', code: 'HYBRID', label: 'Hybrid'),
          HRLookupItem(id: '3', code: 'REMOTE', label: 'Remote'),
        ];
      case 'RECRUITMENT_SOURCE':
        return const [
          HRLookupItem(id: '1', code: 'WEBSITE', label: 'Website'),
          HRLookupItem(id: '2', code: 'LINKEDIN', label: 'LinkedIn'),
          HRLookupItem(id: '3', code: 'REFERRAL', label: 'Referral'),
          HRLookupItem(id: '4', code: 'JOB_PORTAL', label: 'Job Portal'),
          HRLookupItem(id: '5', code: 'CAMPUS', label: 'Campus'),
          HRLookupItem(id: '6', code: 'WALK_IN', label: 'Direct Walk-in'),
          HRLookupItem(id: '7', code: 'AGENCY', label: 'Recruitment Agency'),
          HRLookupItem(id: '8', code: 'OTHERS', label: 'Others'),
        ];
      case 'INTERVIEW_ROUND':
        return const [
          HRLookupItem(id: '1', code: 'ROUND_1_SCREENING', label: 'Round 1 - Screening'),
          HRLookupItem(id: '2', code: 'ROUND_2_TECHNICAL', label: 'Round 2 - Technical / Demo'),
          HRLookupItem(id: '3', code: 'ROUND_3_PANEL', label: 'Round 3 - Panel Interview'),
          HRLookupItem(id: '4', code: 'ROUND_4_FINAL', label: 'Round 4 - Final / HR Discussion'),
        ];
      case 'INTERVIEW_MODE':
        return const [
          HRLookupItem(id: '1', code: 'IN_PERSON', label: 'In Person'),
          HRLookupItem(id: '2', code: 'ONLINE', label: 'Online'),
          HRLookupItem(id: '3', code: 'PHONE', label: 'Phone'),
        ];
      case 'ASSESSMENT_TYPE':
        return const [
          HRLookupItem(id: '1', code: 'TEACHING_DEMO', label: 'Teaching Demo'),
          HRLookupItem(id: '2', code: 'WRITTEN_TEST', label: 'Written Test'),
          HRLookupItem(id: '3', code: 'TECHNICAL_TEST', label: 'Technical Test'),
          HRLookupItem(id: '4', code: 'PRACTICAL', label: 'Practical'),
          HRLookupItem(id: '5', code: 'PSYCHOMETRIC', label: 'Psychometric'),
          HRLookupItem(id: '6', code: 'OTHER', label: 'Other'),
        ];
      case 'RECRUITMENT_STAGE':
        return const [
          HRLookupItem(id: '1', code: 'APPLIED', label: 'Applied'),
          HRLookupItem(id: '2', code: 'SHORTLISTED', label: 'Shortlisted'),
          HRLookupItem(id: '3', code: 'INTERVIEW', label: 'Interview'),
          HRLookupItem(id: '4', code: 'SELECTED', label: 'Selected'),
          HRLookupItem(id: '5', code: 'OFFERED', label: 'Offered'),
          HRLookupItem(id: '6', code: 'HIRED', label: 'Hired'),
          HRLookupItem(id: '7', code: 'REJECTED', label: 'Rejected'),
        ];
      case 'TRAINING_CATEGORY':
        return const [
          HRLookupItem(id: '1', code: 'DIGITAL_TECH', label: 'Digital & Technology'),
          HRLookupItem(id: '2', code: 'PROF_DEV', label: 'Professional Development'),
          HRLookupItem(id: '3', code: 'COMPLIANCE', label: 'Compliance & Regulatory'),
          HRLookupItem(id: '4', code: 'SOFT_SKILLS', label: 'Soft Skills & Communication'),
          HRLookupItem(id: '5', code: 'HEALTH_SAFETY', label: 'Health, Safety & Medical'),
          HRLookupItem(id: '6', code: 'LEADERSHIP', label: 'Leadership & Management'),
        ];
      case 'TRAINING_TYPE':
        return const [
          HRLookupItem(id: '1', code: 'TECHNICAL', label: 'Technical'),
          HRLookupItem(id: '2', code: 'PROFESSIONAL', label: 'Professional Development'),
          HRLookupItem(id: '3', code: 'COMPLIANCE', label: 'Compliance'),
          HRLookupItem(id: '4', code: 'SOFT_SKILLS', label: 'Soft Skills'),
          HRLookupItem(id: '5', code: 'SAFETY', label: 'Safety'),
          HRLookupItem(id: '6', code: 'ORIENTATION', label: 'Orientation'),
          HRLookupItem(id: '7', code: 'LEADERSHIP', label: 'Leadership'),
          HRLookupItem(id: '8', code: 'OTHER', label: 'Other'),
        ];
      case 'TRAINING_MODE':
        return const [
          HRLookupItem(id: '1', code: 'ONLINE', label: 'Online'),
          HRLookupItem(id: '2', code: 'OFFLINE', label: 'Offline'),
          HRLookupItem(id: '3', code: 'HYBRID', label: 'Hybrid'),
          HRLookupItem(id: '4', code: 'WORKSHOP', label: 'Workshop'),
        ];
      case 'TRAINING_ASSESSMENT_TYPE':
        return const [
          HRLookupItem(id: '1', code: 'NONE', label: 'None'),
          HRLookupItem(id: '2', code: 'QUIZ', label: 'Quiz'),
          HRLookupItem(id: '3', code: 'ASSIGNMENT', label: 'Assignment'),
          HRLookupItem(id: '4', code: 'EVALUATION', label: 'Evaluation'),
        ];
      case 'POLICY_APPLICABILITY':
        return const [
          HRLookupItem(id: '1', code: 'ENTIRE_INSTITUTE', label: 'Entire Institute'),
          HRLookupItem(id: '2', code: 'DEPARTMENT', label: 'Department'),
          HRLookupItem(id: '3', code: 'ROLE', label: 'Role'),
          HRLookupItem(id: '4', code: 'SELECTED_USERS', label: 'Selected Users'),
        ];
      case 'POLICY_REVIEW_FREQUENCY':
        return const [
          HRLookupItem(id: '1', code: 'QUARTERLY', label: 'Quarterly'),
          HRLookupItem(id: '2', code: 'SEMI_ANNUAL', label: 'Semi-Annual'),
          HRLookupItem(id: '3', code: 'ANNUAL', label: 'Annual'),
          HRLookupItem(id: '4', code: 'BIENNIAL', label: 'Biennial'),
        ];
      case 'HR_DOCUMENT_TYPE':
        return const [
          HRLookupItem(id: '1', code: 'EMPLOYEE_DOCUMENT', label: 'Employee Document'),
          HRLookupItem(id: '2', code: 'HR_DOCUMENT', label: 'HR Document'),
          HRLookupItem(id: '3', code: 'COMPLIANCE_DOCUMENT', label: 'Compliance Document'),
          HRLookupItem(id: '4', code: 'CERTIFICATE', label: 'Certificate'),
          HRLookupItem(id: '5', code: 'CONTRACT', label: 'Contract'),
          HRLookupItem(id: '6', code: 'JOINING_DOCUMENT', label: 'Joining Document'),
          HRLookupItem(id: '7', code: 'ID_VERIFICATION', label: 'Identity / Verification'),
          HRLookupItem(id: '8', code: 'TRAINING_CERTIFICATE', label: 'Training Certificate'),
          HRLookupItem(id: '9', code: 'LEGAL_DOCUMENT', label: 'Legal Document'),
          HRLookupItem(id: '10', code: 'TEMPLATE', label: 'Template'),
          HRLookupItem(id: '11', code: 'OTHER', label: 'Other'),
        ];
      case 'DOCUMENT_ACCESS_LEVEL':
        return const [
          HRLookupItem(id: '1', code: 'INSTITUTE_WIDE', label: 'Institute Wide'),
          HRLookupItem(id: '2', code: 'DEPARTMENT', label: 'Department Only'),
          HRLookupItem(id: '3', code: 'DESIGNATION', label: 'Designation Only'),
          HRLookupItem(id: '4', code: 'CONFIDENTIAL_HR', label: 'Confidential HR'),
        ];
      case 'HR_TEMPLATE_TYPE':
        return const [
          HRLookupItem(id: '1', code: 'OFFER_LETTER', label: 'Offer Letter'),
          HRLookupItem(id: '2', code: 'APPOINTMENT_LETTER', label: 'Appointment Letter'),
          HRLookupItem(id: '3', code: 'WARNING_LETTER', label: 'Warning Letter'),
          HRLookupItem(id: '4', code: 'EXPERIENCE_LETTER', label: 'Experience Letter'),
          HRLookupItem(id: '5', code: 'RELIEVING_LETTER', label: 'Relieving Letter'),
          HRLookupItem(id: '6', code: 'NDA', label: 'NDA & Confidentiality'),
          HRLookupItem(id: '7', code: 'CODE_OF_CONDUCT', label: 'Code of Conduct'),
          HRLookupItem(id: '8', code: 'JOINING_CHECKLIST', label: 'Joining Checklist'),
          HRLookupItem(id: '9', code: 'HR_FORMS', label: 'HR Forms'),
          HRLookupItem(id: '10', code: 'CUSTOM', label: 'Custom'),
        ];
      case 'ONBOARDING_TASK_CATEGORY':
        return const [
          HRLookupItem(id: '1', code: 'HR', label: 'HR'),
          HRLookupItem(id: '2', code: 'IT', label: 'IT'),
          HRLookupItem(id: '3', code: 'ADMINISTRATION', label: 'Administration'),
          HRLookupItem(id: '4', code: 'DEPARTMENT', label: 'Department'),
          HRLookupItem(id: '5', code: 'SECURITY', label: 'Security'),
        ];
      default:
        return const [];
    }
  }
}
