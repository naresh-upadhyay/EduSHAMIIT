import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/exams/screens/exam_prestart_screen.dart';

Map<String, dynamic> _buildSamplePrestartSeed({
  String? targetScope,
  bool canCustomize = true,
}) {
  return {
    'exam': {
      'id': '17967dcb-9502-4579-80dc-e29b2311b0e1',
      'title': 'KING2',
      'subject': 'Chemistry',
      'exam_category': 'Unit Test',
      'exam_mode': 'offline',
      'duration_minutes': 90,
      'total_marks': 100,
      'total_questions': 0,
      'start_time': '09:00 AM, Nov 10, 2026',
      'end_time': '10:30 AM, Nov 10, 2026',
      'target_scope': targetScope ?? '10A, Class 12B (Commerce), Class 12C (Arts), Class 1A',
    },
    'candidate': {
      'id': 'cand-uuid-1',
      'name': 'King Doe',
      'email': 'king@school.edu',
      'roll_number': '1001',
      'class_name': '',
      'section_name': '',
    },
    'permissions': {
      'can_customize': canCustomize,
    },
    'readiness_policy': {
      'camera_mode': 'REQUIRED',
      'microphone_mode': 'REQUIRED',
      'screen_share_mode': 'OPTIONAL',
      'device_check_mode': 'REQUIRED',
      'fullscreen_required': true,
      'max_tab_switches': 3,
      'instruction_acknowledgment_required': true,
    },
    'instructions': {
      'general': [
        {'id': '1', 'description': 'Read all questions carefully before answering.'},
        {'id': '2', 'description': 'The exam consists of MCQ, Short Answer, and Long Answer questions.'},
      ],
      'during_exam': [
        {'id': '3', 'description': 'Maintain quiet environment throughout the session.'},
      ],
      'proctoring': [
        {'id': '4', 'description': 'Camera and microphone monitoring are active during this exam.'},
      ],
      'technical': [
        {'id': '5', 'description': 'Ensure stable network connection and battery backup.'},
      ],
      'submission': [
        {'id': '6', 'description': 'Submit your answers before the countdown timer expires.'},
      ],
    },
    'warnings': [
      'Do not switch tabs, open other applications or use external devices.',
      'Your screen, camera and microphone will be monitored throughout the exam.',
      'Any suspicious activity will be reported directly to your teacher.',
    ],
    'prestart_session': {
      'acknowledged': false,
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final viewports = <String, Size>{
    'Desktop 1440x900': const Size(1440, 900),
    'Laptop 1120x768': const Size(1120, 768),
    'Tablet 820x1024': const Size(820, 1024),
    'Mobile 390x844': const Size(390, 844),
    'Narrow 320x640': const Size(320, 640),
  };

  testWidgets(
    'ExamPrestartScreen renders zero overflow across Desktop, Laptop, Tablet & Mobile in Light and Dark themes',
    (WidgetTester tester) async {
      final seed = _buildSamplePrestartSeed();

      for (final entry in viewports.entries) {
        for (final isDark in [false, true]) {
          final List<FlutterErrorDetails> overflowErrors = [];
          final originalOnError = FlutterError.onError;
          FlutterError.onError = (FlutterErrorDetails details) {
            final msg = details.exceptionAsString();
            if (msg.contains('overflowed by') || msg.contains('RenderFlex overflowed')) {
              overflowErrors.add(details);
            }
            originalOnError?.call(details);
          };

          tester.view.physicalSize = entry.value;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });

          await tester.pumpWidget(
            ProviderScope(
              child: MaterialApp(
                theme: isDark ? ThemeData.dark() : ThemeData.light(),
                home: Scaffold(
                  body: ExamPrestartScreen(
                    examId: '17967dcb-9502-4579-80dc-e29b2311b0e1',
                    initialSeedData: seed,
                  ),
                ),
              ),
            ),
          );

          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(
            overflowErrors,
            isEmpty,
            reason:
                'Found ${overflowErrors.length} overflow(s) in viewport ${entry.key} (${isDark ? "Dark" : "Light"}): '
                '${overflowErrors.map((e) => e.exceptionAsString()).join(" | ")}',
          );

          // Verify critical elements are rendered
          expect(find.text('Examination – Pre-Start Instructions & System Check'), findsOneWidget);
          expect(find.text('KING2'), findsOneWidget);
          expect(find.text('System & Permissions Check'), findsOneWidget);
          expect(find.text('Exam Readiness'), findsOneWidget);
          expect(find.text('Important Warnings'), findsOneWidget);
          expect(find.text('Important Instructions'), findsOneWidget);

          FlutterError.onError = originalOnError;
        }
      }
    },
  );

  testWidgets(
    'ExamPrestartScreen Exam Setter Mode (Customization Studio) renders zero overflow across all viewports',
    (WidgetTester tester) async {
      final seed = _buildSamplePrestartSeed(canCustomize: true);

      for (final entry in viewports.entries) {
        final List<FlutterErrorDetails> overflowErrors = [];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (FlutterErrorDetails details) {
          final msg = details.exceptionAsString();
          if (msg.contains('overflowed by') || msg.contains('RenderFlex overflowed')) {
            overflowErrors.add(details);
          }
          originalOnError?.call(details);
        };

        tester.view.physicalSize = entry.value;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: Scaffold(
                body: ExamPrestartScreen(
                  examId: '17967dcb-9502-4579-80dc-e29b2311b0e1',
                  initialSeedData: seed,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Switch to Exam Setter Mode
        final customizeBtn = find.text('Customize Exam Rules');
        if (customizeBtn.evaluate().isNotEmpty) {
          await tester.tap(customizeBtn);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));

          expect(find.text('Exam Setter Customization Studio'), findsOneWidget);
          expect(find.text('Camera Proctoring'), findsOneWidget);
          expect(find.text('Microphone Access'), findsOneWidget);
          expect(find.text('Screen Share'), findsAtLeastNWidgets(1));
          expect(find.text('Device & Network Check'), findsOneWidget);
        }

        expect(
          overflowErrors,
          isEmpty,
          reason:
              'Found ${overflowErrors.length} overflow(s) in Setter Mode viewport ${entry.key}: '
              '${overflowErrors.map((e) => e.exceptionAsString()).join(" | ")}',
        );

        FlutterError.onError = originalOnError;
      }
    },
  );
}

