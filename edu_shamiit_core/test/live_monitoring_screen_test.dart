import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/exams/screens/live_monitoring_screen.dart';
import 'package:edu_shamiit_core/screens/exams/widgets/monitoring_donut_chart.dart';

Map<String, dynamic> _sampleMonitoringSeed() {
  return {
    'overview': {
      'exam': {
        'id': '9c9183a5-ff36-4de7-aa3e-e591e120f809',
        'title': 'Annual Examination 2025-26',
        'subject_name': 'Mathematics',
        'target_classes': ['Class 10 - Section A'],
        'exam_date': '2026-03-15',
        'start_time': '2026-03-15T09:00:00Z',
        'end_time': '2026-03-15T11:00:00Z',
        'duration_minutes': 120,
        'exam_remaining_seconds': 5256,
        'exam_type': 'online',
      },
      'monitoring_session': {
        'status': 'LIVE',
        'reentry_window_open': true,
        'auto_flag_tab_switch_threshold': 3,
      },
      'kpis': {
        'total_students': 6,
        'online_in_exam': 3,
        'in_progress': 3,
        'violations': 3,
        'disconnected': 1,
        'completed': 1,
        'paused': 1,
        'not_started': 1,
        'pending_reentry_requests': 1,
      },
      // Mutually-exclusive buckets sum == 6 (1+1+1+1+1+1 = 6; Online/In Exam = in_exam + warning + violation = 3)
      'status_breakdown': [
        {'key': 'in_exam', 'label': 'In Exam', 'count': 1, 'pct': 16.7},
        {'key': 'warning', 'label': 'Warning', 'count': 1, 'pct': 16.7},
        {'key': 'violation', 'label': 'Violation', 'count': 1, 'pct': 16.7},
        {'key': 'disconnected', 'label': 'Disconnected', 'count': 1, 'pct': 16.7},
        {'key': 'completed', 'label': 'Completed', 'count': 1, 'pct': 16.7},
        {'key': 'not_started', 'label': 'Not Started', 'count': 1, 'pct': 16.7},
      ],
      'announcements': [],
    },
    'candidates': {
      'candidates': [
        {
          'candidate_id': 'cand-1',
          'session_id': 'sess-1',
          'full_name': 'Ananya Sharma',
          'roll_number': '1001',
          'class_name': 'Class 10 - A',
          'monitoring_status': 'ACTIVE',
          'warnings_count': 0,
          'camera_active': true,
          'camera_permission': 'granted',
          'mic_active': true,
          'mic_permission': 'granted',
          'screen_share_active': true,
          'screen_share_state': 'granted',
          'network_status': 'GOOD',
          'latency_ms': 42,
          'answered_count': 18,
          'total_questions': 25,
          'remaining_seconds': 5200,
          'extra_minutes': 0,
          'is_paused': false,
          'browser_info': 'Chrome 145 Desktop',
          'reentry_count': 0,
          'max_reentry_attempts': 2,
          'last_activity_label': '09:02 AM (Active)',
        },
        {
          'candidate_id': 'cand-2',
          'session_id': 'sess-2',
          'full_name': 'Diya Singh',
          'roll_number': '1002',
          'class_name': 'Class 10 - A',
          'monitoring_status': 'WARNING',
          'warnings_count': 1,
          'camera_active': true,
          'camera_permission': 'granted',
          'mic_active': true,
          'mic_permission': 'granted',
          'screen_share_active': true,
          'screen_share_state': 'granted',
          'network_status': 'GOOD',
          'latency_ms': 55,
          'answered_count': 14,
          'total_questions': 25,
          'remaining_seconds': 4980,
          'extra_minutes': 0,
          'is_paused': false,
          'browser_info': 'Edge 145 Desktop',
          'reentry_count': 0,
          'max_reentry_attempts': 2,
          'last_activity_label': '09:06 AM (Tab Switch Detected)',
        },
        {
          'candidate_id': 'cand-3',
          'session_id': 'sess-3',
          'full_name': 'Arjun Mehta',
          'roll_number': '1003',
          'class_name': 'Class 10 - A',
          'monitoring_status': 'DISCONNECTED',
          'warnings_count': 2,
          'camera_active': false,
          'camera_permission': 'granted',
          'mic_active': false,
          'mic_permission': 'granted',
          'screen_share_active': false,
          'screen_share_state': 'stopped',
          'network_status': 'OFFLINE',
          'answered_count': 10,
          'total_questions': 25,
          'remaining_seconds': 4500,
          'extra_minutes': 5,
          'is_paused': false,
          'pending_request_id': 'req-1',
          'reentry_reason': 'Wi-Fi dropped briefly during exam.',
          'browser_info': 'Chrome Desktop',
          'reentry_count': 2,
          'max_reentry_attempts': 2,
          'last_activity_label': '09:07 AM (Disconnected)',
        },
        {
          'candidate_id': 'cand-4',
          'session_id': 'sess-4',
          'full_name': 'Rohan Verma',
          'roll_number': '1004',
          'class_name': 'Class 10 - A',
          'monitoring_status': 'VIOLATION',
          'warnings_count': 3,
          'camera_active': false,
          'camera_permission': 'denied',
          'mic_active': false,
          'mic_permission': 'granted',
          'screen_share_active': false,
          'screen_share_state': 'not_shared',
          'network_status': 'UNSTABLE',
          'answered_count': 7,
          'total_questions': 25,
          'remaining_seconds': 4100,
          'extra_minutes': 0,
          'is_paused': true,
          'last_activity_label': '09:08 AM (Fullscreen Exited)',
        },
        {
          'candidate_id': 'cand-5',
          'session_id': 'sess-5',
          'full_name': 'Sneha Rao',
          'roll_number': '1005',
          'class_name': 'Class 10 - A',
          'monitoring_status': 'SUBMITTED',
          'warnings_count': 0,
          'camera_active': false,
          'mic_active': false,
          'screen_share_active': false,
          'network_status': 'GOOD',
          'answered_count': 25,
          'total_questions': 25,
          'remaining_seconds': 0,
          'last_activity_label': '09:45 AM (Submitted)',
        },
        {
          'candidate_id': 'cand-6',
          'full_name': 'Vikram Das',
          'roll_number': '1006',
          'class_name': 'Class 10 - A',
          'monitoring_status': 'NOT_STARTED',
          'warnings_count': 0,
          'camera_active': false,
          'mic_active': false,
          'screen_share_active': false,
          'network_status': 'OFFLINE',
          'answered_count': 0,
          'total_questions': 25,
          'remaining_seconds': 7200,
          'last_activity_label': 'Not joined yet',
        },
      ],
      'pagination': {'page': 1, 'page_size': 8, 'total': 6, 'total_pages': 1},
    },
    'incidents': {
      'summary': {'total': 2, 'open': 1, 'resolved': 1},
      'incidents': [
        {
          'id': 'inc-1',
          'candidate_id': 'cand-3',
          'candidate_name': 'Arjun Mehta',
          'violation_type': 'tab_switch',
          'title': 'Switched Browser Tab',
          'description': 'Candidate window lost focus for 6s.',
          'severity': 'high',
          'status': 'open',
          'detection_source': 'browser',
          'occurred_at': '2026-11-11T08:05:00Z',
        },
        {
          'id': 'inc-2',
          'candidate_id': 'cand-2',
          'candidate_name': 'Diya Singh',
          'violation_type': 'fullscreen_exit',
          'title': 'Fullscreen Exited',
          'description': 'Exited proctored fullscreen mode.',
          'severity': 'medium',
          'status': 'resolved',
          'detection_source': 'browser',
          'occurred_at': '2026-11-11T08:01:00Z',
        },
      ],
    },
    'audit_logs': {
      'logs': [
        {
          'id': 'log-1',
          'candidate_id': 'cand-3',
          'candidate_name': 'Arjun Mehta',
          'actor_name': 'Dr. Anita Menon',
          'actor_role': 'teacher',
          'action_type': 'extend_time',
          'reason': 'Network drop compensation +5 mins',
          'created_at': '2026-11-11T08:06:00Z',
        },
      ],
    },
  };
}

Future<void> _pumpMonitoringAtSize(
  WidgetTester tester,
  Size size, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;

  final capturedErrors = <FlutterErrorDetails>[];
  final origOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    capturedErrors.add(details);
  };

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        themeMode: themeMode,
        theme: ThemeData.light(useMaterial3: true),
        darkTheme: ThemeData.dark(useMaterial3: true),
        home: LiveMonitoringScreen(
          examId: '9c9183a5-ff36-4de7-aa3e-e591e120f809',
          initialMonitoringDataForTest: _sampleMonitoringSeed(),
        ),
      ),
    ),
  );

  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));

  FlutterError.onError = origOnError;
  expect(
    capturedErrors,
    isEmpty,
    reason: 'Unexpected Flutter layout/render errors at $size ($themeMode): '
        '${capturedErrors.map((e) => e.exceptionAsString()).join(' | ')}',
  );
}

void main() {
  testWidgets('LiveMonitoringScreen renders zero overflow across Desktop, Tablet & Mobile in Light and Dark themes', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final viewports = <Size>[
      const Size(1440, 900), // Desktop reference layout
      const Size(1120, 768), // Laptop
      const Size(820, 1024), // Tablet portrait
      const Size(390, 844),  // Mobile portrait
      const Size(320, 640),  // Narrow phone
    ];

    for (final size in viewports) {
      await _pumpMonitoringAtSize(tester, size, themeMode: ThemeMode.light);
      expect(find.text('Exam Monitoring'), findsOneWidget);
      expect(find.text('Annual Examination 2025-26'), findsOneWidget);
      expect(find.byType(MonitoringDonutSummaryCard), findsOneWidget);

      await _pumpMonitoringAtSize(tester, size, themeMode: ThemeMode.dark);
      expect(find.text('Exam Monitoring'), findsOneWidget);
    }
  });

  testWidgets('LiveMonitoringScreen displays KPIs, Donut breakdown, Inspector selection, Tabs & Dialogs cleanly', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpMonitoringAtSize(tester, const Size(1440, 900), themeMode: ThemeMode.light);

    // Header KPIs & Donut Center Ratio (3/6)
    expect(find.text('Total Students'), findsOneWidget);
    expect(find.text('Online / In Exam'), findsOneWidget);
    expect(find.text('Exited / Disconnected'), findsOneWidget);
    expect(find.text('3/6'), findsOneWidget);

    // Pending re-entry banner
    expect(find.textContaining('requested re-entry approval'), findsOneWidget);

    // Initial inspector shows first candidate (Ananya Sharma)
    expect(find.text('Roll No: 1001 • Class 10 - A'), findsOneWidget);

    // Click Arjun Mehta (cand-3) who has a Pending Re-entry Request
    await tester.tap(find.text('Arjun Mehta').first);
    await tester.pumpAndSettle();

    expect(find.text('Roll No: 1003 • Class 10 - A'), findsOneWidget);
    expect(find.text('Pending Re-entry Request'), findsOneWidget);
    expect(find.text('Approve Rejoin'), findsOneWidget);

    // Switch Student Details inner subtabs (Activity, Violations, More, Monitoring)
    Future<void> scrollAndTap(Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await scrollAndTap(find.text('Activity'));
    expect(find.textContaining('EXTEND_TIME'), findsOneWidget);

    await scrollAndTap(find.textContaining('Violations (1)'));
    expect(find.text('Switched Browser Tab'), findsOneWidget);

    await scrollAndTap(find.text('More'));
    expect(find.text('Re-entries Used'), findsOneWidget);

    await scrollAndTap(find.text('Monitoring'));

    // Test Proctoring Action Dialogs (Send Warning, + Extra Time, Stop Exam)
    await scrollAndTap(find.text('Send Warning'));
    expect(find.textContaining('Send Warning — Arjun Mehta'), findsOneWidget);
    expect(find.text('Warning Message'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await scrollAndTap(find.text('+ Extra Time'));
    expect(find.textContaining('Grant Extra Time'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await scrollAndTap(find.text('Stop Exam'));
    expect(find.text('Terminate Attempt'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Switch all 5 Main Navigation Tabs cleanly
    await scrollAndTap(find.text('Student List'));
    expect(find.text('Students (6)'), findsOneWidget);

    await scrollAndTap(find.text('Violation Reports'));
    expect(find.textContaining('Violation Reports (2)'), findsOneWidget);
    expect(find.textContaining('Switched Browser Tab'), findsOneWidget);

    await scrollAndTap(find.text('Incident Logs'));
    expect(find.textContaining('Invigilation Audit Logs (1)'), findsOneWidget);

    await scrollAndTap(find.text('Exam Controls'));
    expect(find.text('Exam-Wide Controls'), findsOneWidget);
    expect(find.text('Emergency Submit All Active Sessions'), findsOneWidget);
    expect(find.text('Broadcast Live Announcement'), findsOneWidget);

    // Switch back to Live Monitoring and test Grid View Mode toggles (2x2 & Compact List)
    await scrollAndTap(find.text('Live Monitoring'));
    await scrollAndTap(find.byTooltip('Large 2x2'));
    await scrollAndTap(find.byTooltip('Compact List'));
    await scrollAndTap(find.byTooltip('Grid 4x2'));
  });
}
