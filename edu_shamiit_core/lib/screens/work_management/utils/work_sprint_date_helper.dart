import 'package:intl/intl.dart';
import '../models/work_models.dart';

/// Helper to dynamically calculate and format Agile sprint dates,
/// ensuring that current, upcoming, and previous sprints logically match
/// the real-time calendar date (e.g. November 2026 instead of hardcoded January).
class WorkSprintDateHelper {
  static DateTime? _mockNow;

  /// Visible for testing to inject a custom reference date.
  static void setMockNow(DateTime? mock) => _mockNow = mock;

  /// Returns current real-time or mocked reference date.
  static DateTime get now => _mockNow ?? DateTime.now();

  /// Current active sprint start date.
  /// Sprints follow a 14-day cadence:
  /// - Days 1 to 14 of current month
  /// - Days 15 to 28 of current month
  static DateTime get currentSprintStart {
    final n = now;
    return n.day <= 14
        ? DateTime(n.year, n.month, 1)
        : DateTime(n.year, n.month, 15);
  }

  /// Current active sprint end date (14 calendar days).
  static DateTime get currentSprintEnd {
    final n = now;
    return n.day <= 14
        ? DateTime(n.year, n.month, 14)
        : DateTime(n.year, n.month, 28);
  }

  /// Next sprint start date.
  static DateTime get nextSprintStart {
    final n = now;
    if (n.day <= 14) {
      return DateTime(n.year, n.month, 15);
    } else {
      return DateTime(n.year, n.month + 1, 1);
    }
  }

  /// Next sprint end date.
  static DateTime get nextSprintEnd {
    final n = now;
    if (n.day <= 14) {
      return DateTime(n.year, n.month, 28);
    } else {
      return DateTime(n.year, n.month + 1, 14);
    }
  }

  /// Previous sprint start date.
  static DateTime get prevSprintStart {
    final n = now;
    if (n.day <= 14) {
      return DateTime(n.year, n.month - 1, 15);
    } else {
      return DateTime(n.year, n.month, 1);
    }
  }

  /// Previous sprint end date.
  static DateTime get prevSprintEnd {
    final n = now;
    if (n.day <= 14) {
      return DateTime(n.year, n.month - 1, 28);
    } else {
      return DateTime(n.year, n.month, 14);
    }
  }

  /// Short formatted range for current sprint: e.g. "Nov 15 – Nov 28" or "Nov 1 – Nov 14".
  static String get currentSprintShortRange {
    final s = currentSprintStart;
    final e = currentSprintEnd;
    final startFmt = DateFormat('MMM d').format(s);
    final endFmt = DateFormat('MMM d').format(e);
    return '$startFmt – $endFmt';
  }

  /// Short formatted range for next sprint: e.g. "Dec 1 – Dec 14".
  static String get nextSprintShortRange {
    final s = nextSprintStart;
    final e = nextSprintEnd;
    final startFmt = DateFormat('MMM d').format(s);
    final endFmt = DateFormat('MMM d').format(e);
    return '$startFmt – $endFmt';
  }

  /// Short formatted range for previous sprint: e.g. "Nov 1 – Nov 14".
  static String get prevSprintShortRange {
    final s = prevSprintStart;
    final e = prevSprintEnd;
    final startFmt = DateFormat('MMM d').format(s);
    final endFmt = DateFormat('MMM d').format(e);
    return '$startFmt – $endFmt';
  }

  /// Full duration string: e.g. "Nov 15, 2026 – Nov 28, 2026 (14 days)".
  static String get currentSprintFullDurationRange {
    final s = currentSprintStart;
    final e = currentSprintEnd;
    return '${DateFormat('MMM dd, yyyy').format(s)} – ${DateFormat('MMM dd, yyyy').format(e)} (14 days)';
  }

  /// Board dropdown label for current sprint:
  /// e.g. "Current Sprint (Nov 15 – Nov 28)"
  static String get currentSprintBoardDropdownLabel {
    return 'Current Sprint ($currentSprintShortRange)';
  }

  /// Board dropdown label for next sprint:
  /// e.g. "Sprint 9 (Dec 1 – Dec 14)"
  static String get nextSprintBoardDropdownLabel {
    return 'Sprint 9 ($nextSprintShortRange)';
  }

  /// All sprint options available in Board dropdown selector.
  static List<String> get boardSprintOptions => [
        currentSprintBoardDropdownLabel,
        nextSprintBoardDropdownLabel,
        'All Sprints',
        'Backlog Only',
      ];

  /// Sprints tab dropdown label for current sprint.
  static String get currentSprintTabDropdownLabel => 'Current Sprint (Sprint 8)';

  /// Start date formatted: e.g. "Nov 15, 2026"
  static String get currentSprintStartFmt => DateFormat('MMM dd, yyyy').format(currentSprintStart);

  /// End date formatted: e.g. "Nov 28, 2026"
  static String get currentSprintEndFmt => DateFormat('MMM dd, yyyy').format(currentSprintEnd);

  /// Default item short due date: e.g. "Nov 28"
  static String get defaultItemDueDateFmt => DateFormat('MMM dd').format(currentSprintEnd);

  /// Default item full due date: e.g. "Nov 28, 2026"
  static String get defaultItemDueDateFull => DateFormat('MMM dd, yyyy').format(currentSprintEnd);

  /// Retrospective session date formatted: e.g. "Nov 28, 2026, 04:00 PM"
  static String get retroSessionDateFmt => '${DateFormat('MMM dd, yyyy').format(currentSprintEnd)}, 04:00 PM';

  /// Generates dynamic daily points for sprint capacity chart covering the active sprint.
  static List<SprintCapacityDailyPointModel> generateDailyCapacityPoints({int days = 14}) {
    final start = currentSprintStart;
    final List<SprintCapacityDailyPointModel> points = [];

    final plannedPattern = [25.0, 24.0, 26.0, 25.0, 23.0, 25.0, 27.0, 26.0, 25.0, 27.0, 26.0, 25.0, 24.0, 22.0];
    final actualPattern = [21.0, 20.0, 22.0, 21.0, 19.0, 20.0, 23.0, 21.0, 20.0, 22.0, 20.0, 22.0, 19.0, 18.0];

    for (int i = 0; i < days; i++) {
      final day = start.add(Duration(days: i));
      points.add(SprintCapacityDailyPointModel(
        fullDate: DateFormat('yyyy-MM-dd').format(day),
        dateFmt: DateFormat('MMM dd').format(day),
        capacityHours: 28.0,
        plannedHours: plannedPattern[i % plannedPattern.length],
        actualHours: actualPattern[i % actualPattern.length],
      ));
    }
    return points;
  }

  /// Dynamic list of upcoming sprints for the Sprints tab.
  static List<Map<String, dynamic>> get upcomingSprintsList {
    final nextStart = nextSprintStart;
    final nextEnd = nextSprintEnd;
    final nextRange = '${DateFormat('MMM dd, yyyy').format(nextStart)} – ${DateFormat('MMM dd, yyyy').format(nextEnd)}';

    final nextNextStart = nextEnd.add(const Duration(days: 1));
    final nextNextEnd = nextNextStart.add(const Duration(days: 13));
    final nextNextRange = '${DateFormat('MMM dd, yyyy').format(nextNextStart)} – ${DateFormat('MMM dd, yyyy').format(nextNextEnd)}';

    return [
      {
        'id': 's9',
        'name': 'Sprint 9',
        'date_range': nextRange,
        'status': 'Planned',
        'items_count': 18,
        'points': 42,
      },
      {
        'id': 's10',
        'name': 'Sprint 10',
        'date_range': nextNextRange,
        'status': 'Planned',
        'items_count': 14,
        'points': 35,
      },
    ];
  }
}
