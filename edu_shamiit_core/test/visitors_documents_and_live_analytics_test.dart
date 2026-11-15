import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/screens/visitors/models/visitor_models.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/visitors_bottom_analytics.dart';
import 'package:edu_shamiit_core/screens/visitors/widgets/dialogs/visitor_registration_dialog.dart';
import 'package:edu_shamiit_core/screens/visitors/providers/visitors_provider.dart';

void main() {
  group('Visitor Documents & Live Analytics Tests', () {
    test('AttachedVisitorDoc serializes custom typed document type correctly', () {
      final doc = AttachedVisitorDoc(
        type: 'Adhar',
        name: 'Adhar_Card_Front.pdf',
        size: 51200,
      );

      expect(doc.typeController.text, 'Adhar');
      expect(doc.nameController.text, 'Adhar_Card_Front.pdf');

      // User types custom type
      doc.typeController.text = 'Vehicle RC';
      final json = doc.toJson();
      expect(json['document_type'], 'Vehicle RC');
      expect(json['document_name'], 'Adhar_Card_Front.pdf');
      expect(json['verification_status'], 'VERIFIED');
      doc.dispose();
    });

    test('VisitorDetail360 parses documents and visit history with is_current', () {
      final json = {
        'visit': {'id': 'v-1', 'status': 'Inside', 'purpose': 'Official Meeting'},
        'visitor': {'id': 'vis-1', 'full_name': 'KIOI', 'phone': '9876543210'},
        'documents': [
          {'id': 'd-1', 'document_name': 'Adhar_Card.pdf', 'document_type': 'Adhar', 'verification_status': 'VERIFIED'},
          {'id': 'd-2', 'document_name': 'Driving_License.png', 'document_type': 'Driving License', 'verification_status': 'VERIFIED'},
        ],
        'visit_history': [
          {'id': 'v-1', 'visit_number': 'VIS-001', 'purpose': 'Official Meeting', 'status': 'Inside', 'is_current': true},
          {'id': 'v-0', 'visit_number': 'VIS-000', 'purpose': 'Meet Student', 'status': 'Checked Out', 'is_current': false},
        ]
      };

      final detail = VisitorDetail360.fromJson(json);
      expect(detail.visitorName, 'KIOI');
      expect(detail.documents.length, 2);
      expect(detail.documents[0]['document_type'], 'Adhar');
      expect(detail.documents[1]['document_type'], 'Driving License');
      expect(detail.visitHistory.length, 2);
      expect(detail.visitHistory[0]['is_current'], true);
      expect(detail.visitHistory[1]['is_current'], false);
    });

    testWidgets('LocationBarChartCard renders with live location analytics', (tester) async {
      const customAnalytics = VisitorAnalyticsData(
        locations: [
          {'location': 'Main Gate', 'count': 20},
          {'location': 'Library', 'count': 15},
          {'location': 'Science Lab', 'count': 8},
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visitorsProvider.overrideWith((ref) => _MockVisitorsNotifier(
              const VisitorsState(analytics: customAnalytics),
            )),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: LocationBarChartCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text("Today's Visitors by Location"), findsOneWidget);
      expect(find.text('Main Gate'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('Library'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('Science Lab'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('RecentVisitorsCard renders live recent visitors from state', (tester) async {
      const customAnalytics = VisitorAnalyticsData(
        recentVisitors: [
          {
            'id': 'rec-1',
            'visitor_name': 'KIOI',
            'purpose': 'Meet Student',
            'destination': 'Main Gate',
            'time': '10:30 AM',
            'status': 'Inside',
          },
          {
            'id': 'rec-2',
            'visitor_name': 'Dr. Rajeshwar Sharma',
            'purpose': 'Official Audit',
            'destination': 'Director Office',
            'time': '09:15 AM',
            'status': 'Checked Out',
          },
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visitorsProvider.overrideWith((ref) => _MockVisitorsNotifier(
              const VisitorsState(analytics: customAnalytics),
            )),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: RecentVisitorsCard(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Recent Visitors'), findsOneWidget);
      expect(find.text('KIOI'), findsOneWidget);
      expect(find.text('Meet Student'), findsOneWidget);
      expect(find.text('Dr. Rajeshwar Sharma'), findsOneWidget);
      expect(find.text('Official Audit'), findsOneWidget);
      expect(find.text('Inside'), findsOneWidget);
      expect(find.text('Checked Out'), findsOneWidget);
    });

    testWidgets('VisitorRegistrationDialog renders Identity & Verification Documents section', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            visitorsProvider.overrideWith((ref) => _MockVisitorsNotifier(
              const VisitorsState(),
            )),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: VisitorRegistrationDialog(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Identity & Verification Documents'), findsOneWidget);
      expect(find.text('Add Document'), findsOneWidget);
    });
  });
}

class _MockVisitorsNotifier extends StateNotifier<VisitorsState> implements VisitorsNotifier {
  _MockVisitorsNotifier(super.state);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
