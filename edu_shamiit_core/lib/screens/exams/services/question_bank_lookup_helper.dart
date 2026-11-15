import '../../../services/api_service.dart';
import '../../../services/lookup_event_bus.dart';

class QuestionBankLookupItem {
  final String code;
  final String name;
  final String? id;
  final String? description;

  const QuestionBankLookupItem({
    required this.code,
    required this.name,
    this.id,
    this.description,
  });

  factory QuestionBankLookupItem.fromJson(Map<String, dynamic> json) {
    return QuestionBankLookupItem(
      code: (json['code'] ?? json['value_code'] ?? '').toString(),
      name: (json['label'] ?? json['value_name'] ?? json['name'] ?? json['code'] ?? '').toString(),
      id: json['id']?.toString(),
      description: json['description']?.toString(),
    );
  }

  String get lookupCode => code;
  String get lookupValue => name;
}

class QuestionBankLookupHelper {
  static final QuestionBankLookupHelper instance = QuestionBankLookupHelper._internal();
  QuestionBankLookupHelper._internal() {
    LookupEventBus.instance.addListener(() {
      clearCache();
    });
  }

  final ApiService _api = ApiService();
  final Map<String, List<QuestionBankLookupItem>> _cache = {};

  Future<List<QuestionBankLookupItem>> getLookupItems(
    String keyCode, {
    List<QuestionBankLookupItem>? fallbacks,
    bool forceRefresh = false,
  }) async {
    final upperKey = keyCode.toUpperCase().trim();
    if (!forceRefresh && _cache.containsKey(upperKey) && _cache[upperKey]!.isNotEmpty) {
      return _cache[upperKey]!;
    }

    try {
      final res = await _api.get(
        '/lookups/code/$upperKey',
        query: {'include_inactive': false},
        useCache: false,
      );

      if (res['success'] == true && res['values'] is List) {
        final list = (res['values'] as List)
            .map((e) => QuestionBankLookupItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();

        if (list.isNotEmpty) {
          _cache[upperKey] = list;
          return list;
        }
      }
    } catch (_) {}

    if (fallbacks != null && fallbacks.isNotEmpty) {
      _cache[upperKey] = fallbacks;
      return fallbacks;
    }

    return [];
  }

  void clearCache([String? keyCode]) {
    if (keyCode != null) {
      _cache.remove(keyCode.toUpperCase().trim());
    } else {
      _cache.clear();
    }
  }

  // Specialized convenience getters for Question Bank module
  Future<List<QuestionBankLookupItem>> getQuestionTypes() async {
    return getLookupItems(
      'QUESTION_TYPE',
      fallbacks: const [
        QuestionBankLookupItem(code: 'MCQ', name: 'Multiple Choice (MCQ)'),
        QuestionBankLookupItem(code: 'MULTI_SELECT', name: 'Multi Select'),
        QuestionBankLookupItem(code: 'SHORT_ANSWER', name: 'Short Answer'),
        QuestionBankLookupItem(code: 'LONG_ANSWER', name: 'Long Answer'),
        QuestionBankLookupItem(code: 'TRUE_FALSE', name: 'True / False'),
        QuestionBankLookupItem(code: 'FILL_BLANKS', name: 'Fill in the Blanks'),
        QuestionBankLookupItem(code: 'MATCH_FOLLOWING', name: 'Match the Following'),
        QuestionBankLookupItem(code: 'ASSERTION_REASON', name: 'Assertion and Reason'),
        QuestionBankLookupItem(code: 'CASE_STUDY', name: 'Case Study / Passage'),
        QuestionBankLookupItem(code: 'NUMERICAL', name: 'Numerical Problem'),
        QuestionBankLookupItem(code: 'DESCRIPTIVE', name: 'Descriptive / Essay'),
        QuestionBankLookupItem(code: 'DIAGRAM', name: 'Diagram / Image Based'),
        QuestionBankLookupItem(code: 'PRACTICAL', name: 'Oral / Practical'),
      ],
    );
  }

  Future<List<QuestionBankLookupItem>> getDifficultyLevels() async {
    return getLookupItems(
      'QUESTION_DIFFICULTY',
      fallbacks: const [
        QuestionBankLookupItem(code: 'EASY', name: 'Easy'),
        QuestionBankLookupItem(code: 'MEDIUM', name: 'Medium'),
        QuestionBankLookupItem(code: 'HARD', name: 'Hard'),
        QuestionBankLookupItem(code: 'VERY_EASY', name: 'Very Easy'),
        QuestionBankLookupItem(code: 'VERY_HARD', name: 'Very Hard'),
      ],
    );
  }

  Future<List<QuestionBankLookupItem>> getDifficulties() => getDifficultyLevels();

  Future<List<QuestionBankLookupItem>> getQuestionStatuses() async {
    return getLookupItems(
      'QUESTION_STATUS',
      fallbacks: const [
        QuestionBankLookupItem(code: 'APPROVED', name: 'Approved'),
        QuestionBankLookupItem(code: 'PENDING_REVIEW', name: 'Pending Review'),
        QuestionBankLookupItem(code: 'DRAFT', name: 'Draft'),
        QuestionBankLookupItem(code: 'REJECTED', name: 'Rejected'),
        QuestionBankLookupItem(code: 'ARCHIVED', name: 'Archived'),
      ],
    );
  }

  Future<List<QuestionBankLookupItem>> getQuestionTags() async {
    return getLookupItems(
      'QUESTION_TAGS',
      fallbacks: const [
        QuestionBankLookupItem(code: 'IMPORTANT', name: 'Important'),
        QuestionBankLookupItem(code: 'PREVIOUS_YEAR', name: 'Previous Year'),
        QuestionBankLookupItem(code: 'BOARD_PATTERN', name: 'Board Pattern'),
        QuestionBankLookupItem(code: 'CONCEPTUAL', name: 'Conceptual'),
        QuestionBankLookupItem(code: 'HOTS', name: 'HOTS'),
        QuestionBankLookupItem(code: 'COMPETENCY_BASED', name: 'Competency Based'),
        QuestionBankLookupItem(code: 'PRACTICE', name: 'Practice'),
        QuestionBankLookupItem(code: 'REVISION', name: 'Revision'),
      ],
    );
  }

  Future<List<QuestionBankLookupItem>> getQuestionSources() async {
    return getLookupItems(
      'QUESTION_SOURCE',
      fallbacks: const [
        QuestionBankLookupItem(code: 'TEACHER_CREATED', name: 'Teacher Created'),
        QuestionBankLookupItem(code: 'PREVIOUS_YEAR', name: 'Previous Year Paper'),
        QuestionBankLookupItem(code: 'TEXTBOOK', name: 'Textbook'),
        QuestionBankLookupItem(code: 'EXTERNAL_REFERENCE', name: 'External Reference'),
        QuestionBankLookupItem(code: 'IMPORTED', name: 'Imported'),
        QuestionBankLookupItem(code: 'AI_GENERATED', name: 'AI Generated'),
      ],
    );
  }

  Future<List<QuestionBankLookupItem>> getQuestionLanguages() async {
    return getLookupItems(
      'QUESTION_LANGUAGE',
      fallbacks: const [
        QuestionBankLookupItem(code: 'EN', name: 'English'),
        QuestionBankLookupItem(code: 'HI', name: 'Hindi'),
        QuestionBankLookupItem(code: 'SA', name: 'Sanskrit'),
        QuestionBankLookupItem(code: 'FR', name: 'French'),
        QuestionBankLookupItem(code: 'ES', name: 'Spanish'),
      ],
    );
  }

  Future<List<QuestionBankLookupItem>> getPaperTypes() async {
    return getLookupItems(
      'PAPER_TYPE',
      fallbacks: const [
        QuestionBankLookupItem(code: 'FINAL_EXAM', name: 'Final Exam'),
        QuestionBankLookupItem(code: 'UNIT_TEST', name: 'Unit Test'),
        QuestionBankLookupItem(code: 'HALF_YEARLY', name: 'Half Yearly'),
        QuestionBankLookupItem(code: 'ANNUAL_EXAM', name: 'Annual Examination'),
        QuestionBankLookupItem(code: 'MONTHLY_TEST', name: 'Monthly Test'),
        QuestionBankLookupItem(code: 'MOCK_TEST', name: 'Mock Test'),
        QuestionBankLookupItem(code: 'PRACTICAL', name: 'Practical Exam'),
        QuestionBankLookupItem(code: 'CLASS_TEST', name: 'Class Test'),
      ],
    );
  }

  Future<List<QuestionBankLookupItem>> getPaperStatuses() async {
    return getLookupItems(
      'PAPER_STATUS',
      fallbacks: const [
        QuestionBankLookupItem(code: 'DRAFT', name: 'Draft'),
        QuestionBankLookupItem(code: 'IN_REVIEW', name: 'In Review'),
        QuestionBankLookupItem(code: 'APPROVED', name: 'Approved'),
        QuestionBankLookupItem(code: 'PUBLISHED', name: 'Published'),
        QuestionBankLookupItem(code: 'ARCHIVED', name: 'Archived'),
      ],
    );
  }

  Future<List<QuestionBankLookupItem>> getSectionTypes() async {
    return getLookupItems(
      'SECTION_TYPE',
      fallbacks: const [
        QuestionBankLookupItem(code: 'MCQ_SECTION', name: 'Multiple Choice Questions'),
        QuestionBankLookupItem(code: 'SHORT_SECTION', name: 'Short Answer Questions'),
        QuestionBankLookupItem(code: 'LONG_SECTION', name: 'Long Answer Questions'),
        QuestionBankLookupItem(code: 'ASSERTION_REASON_SECTION', name: 'Assertion and Reason'),
        QuestionBankLookupItem(code: 'CASE_STUDY_SECTION', name: 'Case Study / Passage'),
        QuestionBankLookupItem(code: 'FILL_BLANKS_SECTION', name: 'Fill in the Blanks'),
        QuestionBankLookupItem(code: 'MATCHING_SECTION', name: 'Match the Following'),
      ],
    );
  }

  Future<List<QuestionBankLookupItem>> getAcademicSessions() async {
    return getLookupItems(
      'ACADEMIC_SESSION',
      fallbacks: const [
        QuestionBankLookupItem(code: '2025-26', name: '2025-26'),
        QuestionBankLookupItem(code: '2024-25', name: '2024-25'),
        QuestionBankLookupItem(code: '2026-27', name: '2026-27'),
      ],
    );
  }

  Future<List<QuestionBankLookupItem>> getExamCategories() async {
    return getLookupItems(
      'EXAM_CATEGORY',
      fallbacks: const [
        QuestionBankLookupItem(code: 'FINAL_EXAM', name: 'Final Exam'),
        QuestionBankLookupItem(code: 'MID_TERM', name: 'Mid Term'),
        QuestionBankLookupItem(code: 'UNIT_TEST', name: 'Unit Test'),
        QuestionBankLookupItem(code: 'HALF_YEARLY', name: 'Half Yearly'),
        QuestionBankLookupItem(code: 'PRE_BOARD', name: 'Pre Board'),
        QuestionBankLookupItem(code: 'QUARTERLY', name: 'Quarterly'),
        QuestionBankLookupItem(code: 'ANNUAL_EXAM', name: 'Annual Examination'),
      ],
    );
  }

  Future<List<QuestionBankLookupItem>> getExamModes() async {
    return getLookupItems(
      'EXAM_MODE',
      fallbacks: const [
        QuestionBankLookupItem(code: 'offline', name: 'Offline / Paper'),
        QuestionBankLookupItem(code: 'online', name: 'Online / CBT'),
        QuestionBankLookupItem(code: 'hybrid', name: 'Hybrid'),
      ],
    );
  }

  Future<List<QuestionBankLookupItem>> getExamStatuses() async {
    return getLookupItems(
      'EXAM_STATUS',
      fallbacks: const [
        QuestionBankLookupItem(code: 'scheduled', name: 'Scheduled'),
        QuestionBankLookupItem(code: 'ongoing', name: 'Ongoing'),
        QuestionBankLookupItem(code: 'completed', name: 'Completed'),
        QuestionBankLookupItem(code: 'draft', name: 'Draft'),
        QuestionBankLookupItem(code: 'cancelled', name: 'Cancelled'),
      ],
    );
  }
}
