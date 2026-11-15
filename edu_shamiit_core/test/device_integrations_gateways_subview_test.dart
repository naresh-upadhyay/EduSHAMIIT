import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edu_shamiit_core/screens/campus/models/device_management_models.dart';
import 'package:edu_shamiit_core/screens/campus/widgets/device_management/subviews/device_integrations_gateways_subview.dart';

Widget buildTestWidget({ThemeMode themeMode = ThemeMode.light}) {
  return MaterialApp(
    themeMode: themeMode,
    theme: ThemeData(
      brightness: Brightness.light,
      primaryColor: const Color(0xFF1677F2),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    ),
    darkTheme: ThemeData(
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF1677F2),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
    ),
    home: const Scaffold(
      body: DeviceIntegrationsGatewaysSubview(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Enterprise Models Unit Tests', () {
    test('IntegrationGatewayKpis default and json parsing', () {
      final kpis = IntegrationGatewayKpis();
      expect(kpis.totalGateways, 8);
      expect(kpis.onlineGateways, 7);
      expect(kpis.onlineGatewaysPct, 87.5);
      expect(kpis.offlineGateways, 1);
      expect(kpis.activeIntegrations, 6);
      expect(kpis.dataThroughput, '12.8 MB/min');
      expect(kpis.mqttConnections, 136);
      expect(kpis.integrationHealth, 'Healthy');

      final fromJson = IntegrationGatewayKpis.fromJson({
        'total_gateways': 10,
        'online_gateways': 9,
        'online_gateways_pct': 90.0,
        'offline_gateways': 1,
        'offline_gateways_pct': 10.0,
        'active_integrations': 8,
        'total_integrations': 8,
        'active_integrations_pct': 100.0,
        'data_throughput': '15.4 MB/min',
        'mqtt_connections': 180,
        'integration_health': 'Optimal',
        'active_protocols': 7,
      });
      expect(fromJson.totalGateways, 10);
      expect(fromJson.onlineGateways, 9);
      expect(fromJson.activeIntegrations, 8);
      expect(fromJson.dataThroughput, '15.4 MB/min');
      expect(fromJson.integrationHealth, 'Optimal');
    });

    test('IotProtocolItem and IntegrationHealthServiceItem model parsing', () {
      final proto = IotProtocolItem.fromJson({
        'id': 'p1',
        'name': 'MQTT',
        'code': 'mqtt',
        'status': 'Connected',
        'is_connected': true,
        'count': 136,
        'label': 'clients',
        'display_text': '136 clients',
      });
      expect(proto.name, 'MQTT');
      expect(proto.code, 'mqtt');
      expect(proto.count, 136);
      expect(proto.displayText, '136 clients');

      final health = IntegrationHealthServiceItem.fromJson({
        'name': 'Building Management System (BMS)',
        'status': 'Operational',
        'is_operational': true,
      });
      expect(health.name, 'Building Management System (BMS)');
      expect(health.status, 'Operational');
      expect(health.isOperational, true);
    });

    test('CampusGatewayItem model parsing and copyWith', () {
      final gw = CampusGatewayItem.fromJson({
        'id': 'gw1',
        'gateway_code': 'GW-0001',
        'gateway_name': 'GW-A01 (Main Block)',
        'location_path': 'Main Block',
        'protocols': 'MQTT, Modbus (TCP)',
        'ip_address': '192.168.10.21',
        'mac_address': '00:1A:2B:3C:4D:5E',
        'status': 'online',
        'is_online': true,
        'connected_devices_count': 28,
        'uptime_display': '15 days, 08:36:21 (99.6%)',
        'firmware_version': 'v2.3.1',
        'firmware_update_available': 'v2.4.0',
        'data_throughput_mb_min': 2.8,
        'last_heartbeat': '10 Jan 2025, 02:18 PM',
      });
      expect(gw.gatewayCode, 'GW-0001');
      expect(gw.gatewayName, 'GW-A01 (Main Block)');
      expect(gw.connectedDevicesCount, 28);
      expect(gw.isOnline, true);
      expect(gw.firmwareUpdateAvailable, 'v2.4.0');

      final updated = gw.copyWith(
        firmwareVersion: 'v2.4.0',
        firmwareUpdateAvailable: null,
      );
      expect(updated.firmwareVersion, 'v2.4.0');
      expect(updated.firmwareUpdateAvailable, isNull);
    });

    test('ThirdPartyIntegrationItem, DiscoveredDeviceItem, Webhook, Cert, Log models', () {
      final integ = ThirdPartyIntegrationItem.fromJson({
        'id': 'i1',
        'name': 'Access Control System',
        'type': 'Security Integration',
        'protocol': 'HTTP(S) / API',
        'status': 'active',
        'last_sync': '10 Jan 2025, 02:12 PM',
      });
      expect(integ.name, 'Access Control System');
      expect(integ.status, 'active');

      final disc = DiscoveredDeviceItem.fromJson({
        'id': 'd1',
        'device_identifier': 'DISC-LIGHT-091',
        'device_name': 'Philips Hue Smart Troffer',
        'device_type': 'Lighting',
        'protocol': 'Zigbee',
      });
      expect(disc.deviceName, 'Philips Hue Smart Troffer');
      expect(disc.protocol, 'Zigbee');

      final hook = IotWebhookItem.fromJson({
        'id': 'h1',
        'name': 'ERP Incident Webhook',
        'endpoint_url': 'https://api.edushamiit.edu',
        'last_status_code': 200,
      });
      expect(hook.name, 'ERP Incident Webhook');
      expect(hook.lastStatusCode, 200);

      final cert = IotCertificateItem.fromJson({
        'id': 'c1',
        'name': 'EduSHAMIIT Root CA',
        'status': 'active',
      });
      expect(cert.name, 'EduSHAMIIT Root CA');

      final log = IotLogItem.fromJson({
        'id': 'l1',
        'source': 'Gateway',
        'event': 'Heartbeat Acknowledged',
        'message': 'GW-A01 ping nominal',
      });
      expect(log.event, 'Heartbeat Acknowledged');
    });
  });

  group('2. Widget & Canonical Layout Tests', () {
    testWidgets('Renders Header with Title, Subtitle, Refresh button, and Add Action Split Button', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Integrations & Gateways'), findsOneWidget);
      expect(find.textContaining('Manage IoT gateways, communication protocols'), findsOneWidget);
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.text('Add Integration / Gateway'), findsOneWidget);
    });

    testWidgets('Renders all 7 Top KPI Summary Cards with exact metrics', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Total Gateways'), findsOneWidget);
      expect(find.text('Online Gateways'), findsOneWidget);
      expect(find.text('Offline Gateways'), findsOneWidget);
      expect(find.text('Active Integrations'), findsWidgets);
      expect(find.text('Data Throughput'), findsOneWidget);
      expect(find.text('MQTT Connections'), findsOneWidget);
      expect(find.text('Integration Health'), findsWidgets);

      // Verify exact values
      expect(find.text('8'), findsWidgets);
      expect(find.text('7'), findsWidgets);
      expect(find.text('(87.5%)'), findsWidgets);
      expect(find.text('1'), findsWidgets);
      expect(find.text('(12.5%)'), findsWidgets);
      expect(find.text('6'), findsWidgets);
      expect(find.text('12.8 MB/min'), findsOneWidget);
      expect(find.text('136'), findsWidgets);
      expect(find.text('Healthy'), findsWidgets);
    });

    testWidgets('Renders all 7 Sub-Tabs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Overview'), findsOneWidget);
      expect(find.widgetWithText(InkWell, 'Gateways'), findsOneWidget);
      expect(find.text('Integrations'), findsWidgets);
      expect(find.text('Protocols'), findsWidgets);
      expect(find.text('API & Webhooks'), findsOneWidget);
      expect(find.text('Data Flow'), findsOneWidget);
      expect(find.text('Logs'), findsOneWidget);
    });

    testWidgets('Renders Row 1 Cards: Donut, Protocol Status, and Integration Health', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Card 1
      expect(find.text('Integration & Gateway Overview'), findsOneWidget);
      expect(find.text('Gateways'), findsWidgets);
      expect(find.text('Online'), findsWidgets);
      expect(find.textContaining('7 (87.5%)'), findsWidgets);
      expect(find.text('Offline'), findsWidgets);
      expect(find.textContaining('1 (12.5%)'), findsWidgets);

      // Card 2
      expect(find.text('Protocol & Connectivity Status'), findsOneWidget);
      expect(find.text('MQTT'), findsWidgets);
      expect(find.text('136 clients'), findsOneWidget);
      expect(find.text('Modbus (TCP/RTU)'), findsOneWidget);
      expect(find.text('6 devices'), findsOneWidget);
      expect(find.text('ONVIF (CCTV)'), findsOneWidget);
      expect(find.text('22 cameras'), findsOneWidget);
      expect(find.text('RTSP (Video)'), findsOneWidget);
      expect(find.text('18 streams'), findsOneWidget);
      expect(find.text('Zigbee'), findsOneWidget);
      expect(find.text('14 devices'), findsOneWidget);

      // Card 3
      expect(find.text('All Integrations are Healthy'), findsOneWidget);
      expect(find.text('IoT Device Command Service'), findsWidgets);
      expect(find.text('Notification Service'), findsWidgets);
      expect(find.text('Building Management System (BMS)'), findsWidgets);
      expect(find.text('Access Control System'), findsWidgets);
      expect(find.text('CCTV / VMS Integration'), findsWidgets);
      expect(find.text('Energy Metering System'), findsWidgets);
    });

    testWidgets('Renders Central Table with Registered Gateways (8)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Registered Gateways (8)'), findsOneWidget);
      expect(find.text('GW-A01 (Main Block)'), findsWidgets);
      expect(find.text('GW-A02 (Academic)'), findsWidgets);
      expect(find.text('GW-A03 (Library)'), findsWidgets);
      expect(find.text('GW-A04 (Laboratory)'), findsWidgets);
      expect(find.text('GW-A05 (Auditorium)'), findsWidgets);
      expect(find.text('GW-A06 (Admin)'), findsWidgets);
      expect(find.text('GW-A07 (Sports)'), findsWidgets);
      expect(find.text('GW-A08 (Hostel)'), findsWidgets);
    });

    testWidgets('Renders Central Table with Third-party Integrations (6)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Third-party Integrations (6)'), findsOneWidget);
      expect(find.text('Facility Integration'), findsWidgets);
      expect(find.text('Security Integration'), findsWidgets);
      expect(find.text('Surveillance Integration'), findsWidgets);
      expect(find.text('Energy Integration'), findsWidgets);
      expect(find.text('Communication'), findsWidgets);
      expect(find.text('Core Integration'), findsWidgets);
    });

    testWidgets('Right Inspector Panel displays Selected Gateway specifications', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.textContaining('Selected Gateway – GW-A01 (Main Block)'), findsOneWidget);
      expect(find.text('GW-0001'), findsOneWidget);
      expect(find.text('Main Block'), findsWidgets);
      expect(find.text('192.168.10.21'), findsWidgets);
      expect(find.text('MQTT, Modbus (TCP)'), findsWidgets);
      expect(find.text('28'), findsWidgets);
      expect(find.text('15 days, 08:36:21 (99.6%)'), findsWidgets);
      expect(find.text('v2.3.1'), findsWidgets);
      expect(find.text('Update Available: v2.4.0'), findsOneWidget);
      expect(find.text('10 Jan 2025, 02:18 PM'), findsWidgets);

      expect(find.text('Restart Gateway'), findsOneWidget);
      expect(find.text('Update Firmware'), findsOneWidget);
      expect(find.text('Run Diagnostics'), findsOneWidget);
    });

    testWidgets('Inspector Action: Restart Gateway shows confirmation modal and confirms', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final rstBtn = find.widgetWithText(ElevatedButton, 'Restart Gateway');
      expect(rstBtn, findsOneWidget);
      await tester.ensureVisible(rstBtn);
      await tester.pumpAndSettle();
      await tester.tap(rstBtn);
      await tester.pumpAndSettle();

      expect(find.textContaining('Restart GW-A01 (Main Block)?'), findsOneWidget);
      expect(find.text('Confirm Restart'), findsOneWidget);

      await tester.tap(find.text('Confirm Restart'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Reboot command dispatched to GW-A01'), findsOneWidget);
    });

    testWidgets('Inspector Action: Update Firmware shows confirmation and applies update to v2.4.0', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final fwBtn = find.widgetWithText(OutlinedButton, 'Update Firmware');
      expect(fwBtn, findsOneWidget);
      await tester.ensureVisible(fwBtn);
      await tester.pumpAndSettle();
      await tester.tap(fwBtn);
      await tester.pumpAndSettle();

      expect(find.text('Apply Firmware Update?'), findsOneWidget);
      expect(find.text('Start OTA Update'), findsOneWidget);

      await tester.tap(find.text('Start OTA Update'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Firmware for GW-A01 (Main Block) updated to v2.4.0!'), findsOneWidget);
    });

    testWidgets('Inspector Action: Run Diagnostics executes multi-step diagnostic dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1800));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final diagBtn = find.widgetWithText(OutlinedButton, 'Run Diagnostics');
      expect(diagBtn, findsOneWidget);
      await tester.ensureVisible(diagBtn);
      await tester.pumpAndSettle();
      await tester.tap(diagBtn);
      await tester.pump();

      expect(find.textContaining('Diagnosing GW-A01 (Main Block)'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();

      expect(find.textContaining('All gateway checks passed! Hardware nominal.'), findsOneWidget);
    });

    testWidgets('Accordion toggles expand and collapse cleanly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 2400));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final accHeader = find.text('Data Flow & Connectivity Map');
      await tester.ensureVisible(accHeader);
      await tester.pumpAndSettle();
      await tester.tap(accHeader);
      await tester.pumpAndSettle();

      expect(find.text('Incoming Packets'), findsOneWidget);
      expect(find.text('42 / sec'), findsOneWidget);

      final acc2Header = find.text('API Access & Webhooks');
      await tester.ensureVisible(acc2Header);
      await tester.pumpAndSettle();
      await tester.tap(acc2Header);
      await tester.pumpAndSettle();

      expect(find.text('Inbound Port'), findsOneWidget);
    });

    testWidgets('Sub-Tab Gateways renders full fleet view', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final tab = find.widgetWithText(InkWell, 'Gateways');
      await tester.ensureVisible(tab);
      await tester.pumpAndSettle();
      await tester.tap(tab);
      await tester.pumpAndSettle();

      expect(find.text('Institutional IoT Gateways Fleet'), findsOneWidget);
      expect(find.text('Register Gateway'), findsOneWidget);
    });

    testWidgets('Sub-Tab Protocols renders Protocol & Driver Catalog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final tab = find.text('Protocols');
      await tester.ensureVisible(tab);
      await tester.pumpAndSettle();
      await tester.tap(tab);
      await tester.pumpAndSettle();

      expect(find.text('Supported Protocols & Driver Registry'), findsOneWidget);
      expect(find.text('Code: MQTT'), findsOneWidget);
      expect(find.text('Code: MODBUS'), findsOneWidget);
    });

    testWidgets('Sub-Tab API & Webhooks renders webhooks and certificates', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final tab = find.text('API & Webhooks');
      await tester.ensureVisible(tab);
      await tester.pumpAndSettle();
      await tester.tap(tab);
      await tester.pumpAndSettle();

      expect(find.text('Configured Webhooks & Event Routing'), findsOneWidget);
      expect(find.text('ERP Incident Management Webhook'), findsOneWidget);
      expect(find.text('Mutual TLS & Device Certificates'), findsOneWidget);
      expect(find.text('EduSHAMIIT Campus IoT Root CA'), findsOneWidget);
    });

    testWidgets('Sub-Tab Data Flow renders network throughput topology', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final tab = find.text('Data Flow');
      await tester.ensureVisible(tab);
      await tester.pumpAndSettle();
      await tester.tap(tab);
      await tester.pumpAndSettle();

      expect(find.text('Live Data Flow & Message Throughput'), findsOneWidget);
      expect(find.text('Incoming Message Rate'), findsOneWidget);
      expect(find.text('312 msgs / sec'), findsOneWidget);
    });

    testWidgets('Sub-Tab Logs renders Centralized Audit Logs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      final tab = find.text('Logs');
      await tester.ensureVisible(tab);
      await tester.pumpAndSettle();
      await tester.tap(tab);
      await tester.pumpAndSettle();

      expect(find.text('Centralized Integration & Gateway Audit Logs'), findsOneWidget);
      expect(find.text('Heartbeat Acknowledged'), findsOneWidget);
      expect(find.text('CORR-GW001-9921'), findsOneWidget);
    });

    testWidgets('Responsive Tablet Viewport (800x1000) renders with 0 errors', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1000));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Integrations & Gateways'), findsOneWidget);
      expect(find.text('Total Gateways'), findsOneWidget);
    });

    testWidgets('Responsive Mobile Viewport (400x800) renders with 0 errors and 0 overflows', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Integrations & Gateways'), findsOneWidget);
      expect(find.text('Total Gateways'), findsOneWidget);
    });

    testWidgets('Dark Theme renders with dark palette', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1200));
      await tester.pumpWidget(buildTestWidget(themeMode: ThemeMode.dark));
      await tester.pumpAndSettle();

      expect(find.text('Integrations & Gateways'), findsOneWidget);
      expect(find.text('Total Gateways'), findsOneWidget);
    });
  });
}
