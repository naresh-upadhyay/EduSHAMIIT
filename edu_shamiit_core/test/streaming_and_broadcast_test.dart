import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_shamiit_core/screens/live_classes/streaming/models/broadcast_models.dart';
import 'package:edu_shamiit_core/screens/live_classes/streaming/providers/broadcast_provider.dart';
import 'package:edu_shamiit_core/screens/live_classes/streaming/widgets/live_stream_player.dart';
import 'package:edu_shamiit_core/screens/live_classes/streaming/widgets/live_analytics_chart.dart';
import 'package:edu_shamiit_core/screens/live_classes/streaming/streaming_and_broadcast_workspace.dart';

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('Streaming & Broadcast Models & Providers Tests', () {
    test('LiveBroadcastItem deserialization & uptime formatting', () {
      final item = LiveBroadcastItem.fromJson({
        'id': 1,
        'broadcastCode': 'BC-LIVE-MATH10A',
        'title': 'Class 10 - Mathematics: Quadratic Equations',
        'description': 'Live class on Quadratic Equations',
        'category': 'Education',
        'privacy': 'Public',
        'streamQuality': '1080p (Full HD)',
        'bitrateMode': 'Auto (Recommended)',
        'status': 'live',
        'uptimeSeconds': 1638,
        'currentViewers': 426,
        'totalViews': 1248,
        'likesCount': 267,
        'streamHealth': 'Excellent',
        'resolution': '1080p',
        'actualBitrateKbps': 4500,
        'actualFps': 30,
      });

      expect(item.id, equals(1));
      expect(item.title, contains('Quadratic Equations'));
      expect(item.currentViewers, equals(426));
      expect(item.formattedUptime, equals('00:27:18'));
    });

    test('BroadcastDestinationItem deserialization and copyWith', () {
      final dest = BroadcastDestinationItem.fromJson({
        'id': 1,
        'platformKey': 'youtube',
        'destinationName': 'YouTube Live',
        'rtmpUrl': 'rtmp://a.rtmp.youtube.com/live2',
        'streamKey': 'yt_key_123',
        'isActive': true,
        'isConnected': true,
        'syncStatus': 'streaming',
        'viewers': 248,
      });

      expect(dest.platformKey, equals('youtube'));
      expect(dest.isActive, isTrue);

      final toggled = dest.copyWith(isActive: false, syncStatus: 'ready');
      expect(toggled.isActive, isFalse);
      expect(toggled.syncStatus, equals('ready'));
    });

    test('BroadcastProvider tab switching & duration formatting', () {
      final provider = BroadcastProvider();
      expect(provider.selectedTabIndex, equals(0));

      provider.setTabIndex(2);
      expect(provider.selectedTabIndex, equals(2));

      expect(provider.formattedLiveDuration, equals('27:18'));
      expect(provider.formattedLiveUptime, equals('00:27:18'));

      provider.dispose();
    });
  });

  group('Streaming & Broadcast UI Widgets Tests', () {
    testWidgets('LiveStreamPlayer renders LIVE badge and viewers count', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 300,
              child: LiveStreamPlayer(
                title: 'Quadratic Equations',
                formattedDuration: '27:18',
                viewers: 426,
              ),
            ),
          ),
        ),
      );

      expect(find.text('LIVE'), findsOneWidget);
      expect(find.text('27:18'), findsOneWidget);
      expect(find.text('426 watching'), findsOneWidget);
      expect(find.text('Quadratic Equations'), findsOneWidget);
      expect(find.text('ax\u00B2 + bx + c = 0'), findsOneWidget);
    });

    testWidgets('LiveAnalyticsChart renders 30-min trend and peak pill', (WidgetTester tester) async {
      const points = [
        AnalyticsPoint(minuteMark: '00:00', viewerCount: 45),
        AnalyticsPoint(minuteMark: '05:00', viewerCount: 160),
        AnalyticsPoint(minuteMark: '10:00', viewerCount: 250),
        AnalyticsPoint(minuteMark: '15:00', viewerCount: 310),
        AnalyticsPoint(minuteMark: '20:00', viewerCount: 360),
        AnalyticsPoint(minuteMark: '25:00', viewerCount: 410),
        AnalyticsPoint(minuteMark: '27:18', viewerCount: 426),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 500,
              height: 200,
              child: LiveAnalyticsChart(
                points: points,
                currentPeak: 426,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Live Viewers (Last 30 Minutes)'), findsOneWidget);
      expect(find.text('426'), findsOneWidget);
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('27:18'), findsOneWidget);
    });

    testWidgets('StreamingAndBroadcastWorkspace renders all 5 sub-tab pills', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreamingAndBroadcastWorkspace(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Streaming & Broadcast'), findsOneWidget);
      expect(find.text('Live Streaming'), findsOneWidget);
      expect(find.text('Scheduled Broadcasts'), findsOneWidget);
      expect(find.text('Past Streams'), findsOneWidget);
      expect(find.text('Stream Analytics'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
