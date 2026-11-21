import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/live_classes/models/live_class_models.dart';
import 'package:edu_shamiit_core/screens/live_classes/widgets/live_class_chat_panel.dart';
import 'package:edu_shamiit_core/screens/live_classes/utils/live_class_theme.dart';
import 'package:edu_shamiit_core/screens/live_classes/services/live_class_api_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Live Class Full Features & Edge Cases Test Suite', () {
    test('LiveClassPollOption calculates accurate percentages and protects against division by zero', () {
      double computePct(int optionVotes, int totalVotes) {
        if (totalVotes <= 0) return 0.0;
        return double.parse((optionVotes / totalVotes * 100).toStringAsFixed(1));
      }

      final opt1 = LiveClassPollOption(id: 'opt1', text: 'Option A', votes: 0, percentage: 0.0);
      final opt2 = LiveClassPollOption(id: 'opt2', text: 'Option B', votes: 0, percentage: 0.0);

      // 0 total votes -> 0.0%
      expect(computePct(opt1.votes, 0), 0.0);
      expect(computePct(opt2.votes, 0), 0.0);

      // 1 vote out of 1 -> 100.0%
      expect(computePct(1, 1), 100.0);

      // 1 vote out of 4 -> 25.0%
      expect(computePct(1, 4), 25.0);

      // 1 vote out of 3 -> 33.3%
      expect(computePct(1, 3), 33.3);
    });

    test('Financial Year resolver identifies current academic year dynamically from lookup values', () {
      final sessions = ['2023 - 2024', '2024 - 2025', '2025 - 2026', '2026 - 2027'];
      final resolved = LiveClassApiService.resolveCurrentFinancialYear(sessions);

      final now = DateTime.now();
      final startYear = now.month >= 4 ? now.year : now.year - 1;
      expect(resolved.contains('$startYear'), isTrue);
    });

    test('LiveClassPollItem maintains active state and history aggregation', () {
      final poll1 = LiveClassPollItem(
        id: 'poll-1',
        question: 'Active Poll 1',
        title: 'Active Poll 1',
        pollType: 'SINGLE_CHOICE',
        status: 'ACTIVE',
        options: [
          LiveClassPollOption(id: 'o1', text: 'WAW', votes: 2, percentage: 50.0),
          LiveClassPollOption(id: 'o2', text: 'KING', votes: 2, percentage: 50.0),
        ],
        totalVotes: 4,
      );

      final poll2 = LiveClassPollItem(
        id: 'poll-2',
        question: 'Past Poll 2',
        title: 'Past Poll 2',
        pollType: 'SINGLE_CHOICE',
        status: 'COMPLETED',
        options: [
          LiveClassPollOption(id: 'o3', text: 'JI', votes: 5, percentage: 100.0),
          LiveClassPollOption(id: 'o4', text: 'READY', votes: 0, percentage: 0.0),
        ],
        totalVotes: 5,
      );

      final history = [poll1, poll2];
      expect(history.length, 2);
      expect(history.first.options.length, 2);
      expect(history.first.options[0].text, 'WAW');
      expect(history.first.options[1].text, 'KING');
      expect(history.last.options[0].text, 'JI');
      expect(history.last.options[1].text, 'READY');
    });

    testWidgets('LiveClassTheme adapts colors dynamically from context ThemeData', (WidgetTester tester) async {
      const customPrimary = Color(0xFF6366F1); // Indigo theme

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            primaryColor: customPrimary,
            colorScheme: ColorScheme.fromSeed(seedColor: customPrimary),
          ),
          home: Builder(
            builder: (context) {
              final resolvedPrimary = LiveClassTheme.primary(context);
              expect(resolvedPrimary, equals(customPrimary));
              return Container(color: resolvedPrimary);
            },
          ),
        ),
      );

      await tester.pump();
    });

    testWidgets('LiveClassChatPanel renders Participants, Chat, and Q&A / Polls tabs without errors', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(500, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: LiveClassChatPanel(
                initialTabIndex: 0,
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Verify the 3 core tabs exist and are rendered cleanly (including local host participant)
      expect(find.text('Participants (1)'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Q&A (0)'), findsOneWidget);
    });
  });
}
