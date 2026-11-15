import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/exams/screens/take_exam_screen.dart';

Map<String, dynamic> _sampleTakeInfoPayload() {
  return {
    'exam': {
      'id': 'e20eb0e2-ad40-4c27-9966-08935c529395',
      'title': 'Half Yearly Assessment — Advanced Science & Mathematics',
      'subject': 'Mathematics & Chemistry',
      'duration_minutes': 90,
      'total_marks': 100,
      'passing_marks': 33,
      'negative_marking': true,
      'instructions': '1. Read every question carefully.\n2. Do not switch tabs.',
    },
    'candidate': {
      'id': 'u-1',
      'name': 'King Doe VeryLongCandidateNameForOverflowTest',
      'class_name': '10A',
      'role': 'student',
    },
    'sections': [
      {
        'id': 'sec-a',
        'name': 'Section A — Objective Single Choice Questions',
        'section_code': 'A',
        'sequence_number': 1,
      },
      {
        'id': 'sec-b',
        'name': 'Section B — Short Answer Questions (2 Marks Each) Extremely Long Name',
        'section_code': 'B',
        'sequence_number': 2,
      },
      {
        'id': 'sec-c',
        'name': 'Section C — Long Answer & Multi Select Questions (5 Marks Each)',
        'section_code': 'C',
        'sequence_number': 3,
      },
    ],
    'questions': [
      {
        'id': 'q1',
        'section_id': 'sec-a',
        'section_name': 'Section A — Objective Single Choice Questions',
        'order_number': 1,
        'question_type': 'mcq',
        'question_text': 'What is the approximate value of π used in basic geometry?',
        'marks': 1,
        'negative_marks': 0.25,
        'options': [
          {'label': 'A', 'text': '3.14', 'value': '3.14'},
          {'label': 'B', 'text': '5.14', 'value': '5.14'},
          {'label': 'C', 'text': '4.14', 'value': '4.14'},
          {'label': 'D', 'text': '2.14', 'value': '2.14'},
        ],
      },
      {
        'id': 'q2',
        'section_id': 'sec-c',
        'section_name': 'Section C — Long Answer & Multi Select Questions (5 Marks Each)',
        'order_number': 2,
        'question_type': 'multi_select',
        'question_text': 'Select all prime numbers from the options below:',
        'marks': 2,
        'options': [
          {'label': 'A', 'text': '2', 'value': 'A'},
          {'label': 'B', 'text': '3', 'value': 'B'},
          {'label': 'C', 'text': '4', 'value': 'C'},
          {'label': 'D', 'text': '5', 'value': 'D'},
        ],
      },
      {
        'id': 'q3',
        'section_id': 'sec-b',
        'section_name': 'Section B — Short Answer Questions (2 Marks Each) Extremely Long Name',
        'order_number': 3,
        'question_type': 'short_answer',
        'question_text': 'Explain Newton’s second law of motion with a real-life example.',
        'marks': 3,
        'options': [],
      },
    ],
    'saved_answers': {},
    'session': {'id': 'sess-1', 'remaining_seconds': 2314, 'status': 'in_progress'},
    'is_submitted': false,
  };
}

Future<void> _pumpTakeExamAtSize(
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
        home: TakeExamScreen(
          examId: 'e20eb0e2-ad40-4c27-9966-08935c529395',
          initialTakeInfoForTest: _sampleTakeInfoPayload(),
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
  testWidgets('TakeExamScreen renders cleanly with zero overflow across Desktop, Tablet, Mobile & Landscape', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final viewports = <Size>[
      const Size(1440, 900), // Wide Desktop
      const Size(1100, 768), // Desktop/Laptop matching screenshot constraint with ERP sidebar
      const Size(1100, 400), // Short laptop window (tight height guard)
      const Size(820, 1024), // Tablet Portrait
      const Size(900, 620),  // Tablet Landscape
      const Size(640, 360),  // Mobile Landscape
      const Size(375, 812),  // Standard Phone
      const Size(320, 568),  // Ultra-narrow Phone
    ];

    for (final size in viewports) {
      await _pumpTakeExamAtSize(tester, size, themeMode: ThemeMode.light);
      expect(find.text('What is the approximate value of π used in basic geometry?'), findsOneWidget);

      await _pumpTakeExamAtSize(tester, size, themeMode: ThemeMode.dark);
      expect(find.text('What is the approximate value of π used in basic geometry?'), findsOneWidget);
    }
  });

  testWidgets('TakeExamScreen handles Mobile Palette/Sections sheets, Section Filter, and Dialogs with zero overflow', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpTakeExamAtSize(tester, const Size(320, 568), themeMode: ThemeMode.dark);

    // 1. Open Grid Sheet on ultra-narrow 320px mobile
    expect(find.text('Grid (0/3)'), findsOneWidget);
    await tester.tap(find.text('Grid (0/3)'));
    await tester.pumpAndSettle();
    expect(find.text('Question Palette'), findsOneWidget);

    // Select question 2 (multi-select) from palette sheet
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Select all prime numbers'), findsOneWidget);

    // 2. Toggle multi-select option A ('2') on & off -> answered count accurately returns to 0
    await tester.ensureVisible(find.text('2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2'));
    await tester.pump();
    expect(find.text('Grid (1/3)'), findsOneWidget);

    await tester.tap(find.text('2'));
    await tester.pump();
    expect(find.text('Grid (0/3)'), findsOneWidget);

    // 3. Open Submit Confirmation dialog at 320x568
    await tester.tap(find.text('Submit'));
    await tester.pumpAndSettle();
    expect(find.text('Submit Examination?'), findsOneWidget);
    await tester.tap(find.text('Back to Exam'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('TakeExamScreen Desktop dropdown filter with long section names has zero RenderFlex overflow', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpTakeExamAtSize(tester, const Size(1100, 768), themeMode: ThemeMode.light);

    expect(find.text('Question Grid'), findsOneWidget);
    expect(find.text('All Sections'), findsOneWidget);

    // Change filter dropdown to long Section B name
    await tester.tap(find.text('All Sections'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Section B — Short Answer Questions (2 Marks Each) Extremely Long Name').last);
    await tester.pumpAndSettle();

    // Grid should now show only question #3
    expect(find.text('3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
