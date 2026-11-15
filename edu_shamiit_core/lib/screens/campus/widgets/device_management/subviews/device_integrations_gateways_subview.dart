import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:edu_shamiit_core/config/app_config.dart';
import '../../../models/device_management_models.dart';

/// Integrations & Gateways Management Subview
/// Matches the canonical design of:
/// Campus Management -> Device Management & Control -> Integrations & Gateways
class DeviceIntegrationsGatewaysSubview extends StatefulWidget {
  final VoidCallback? onBackToDashboard;

  const DeviceIntegrationsGatewaysSubview({
    super.key,
    this.onBackToDashboard,
  });

  @override
  State<DeviceIntegrationsGatewaysSubview> createState() =>
      _DeviceIntegrationsGatewaysSubviewState();
}

class _DeviceIntegrationsGatewaysSubviewState
    extends State<DeviceIntegrationsGatewaysSubview> {
  // Navigation & Tabs
  int _selectedSubTab =
      0; // 0: Overview, 1: Gateways, 2: Integrations, 3: Protocols, 4: API & Webhooks, 5: Data Flow, 6: Logs

  // Navigation & State
  bool _isLoading = false;
  List<IotCertificateItem> _certificates = [];

  // KPIs
  IntegrationGatewayKpis _kpis = IntegrationGatewayKpis();

  // Protocols & Health
  List<IotProtocolItem> _protocols = [];
  List<IntegrationHealthServiceItem> _healthServices = [];

  // Gateways & Integrations Lists
  List<CampusGatewayItem> _gateways = [];
  List<ThirdPartyIntegrationItem> _integrations = [];
  List<DiscoveredDeviceItem> _discoveredDevices = [];
  List<IotWebhookItem> _webhooks = [];
  List<IotLogItem> _logs = [];

  // Selected Gateway for Right Inspector Panel
  CampusGatewayItem? _selectedGateway;

  // Accordion Expand States
  bool _accDataFlowExpanded = false;
  bool _accApiWebhooksExpanded = false;
  bool _accLogsEventsExpanded = false;
  bool _accSyncSchedulesExpanded = false;
  bool _accHealthHistoryExpanded = false;

  // Multi-select

  // Base API URL
  String get _baseUrl => '${AppConfig.apiBaseUrl}/v1/devices';

  @override
  void initState() {
    super.initState();
    _loadSeedData();
    _fetchLiveDashboard();
  }

  void _loadSeedData() {
    _kpis = IntegrationGatewayKpis(
      totalGateways: 8,
      onlineGateways: 7,
      onlineGatewaysPct: 87.5,
      offlineGateways: 1,
      offlineGatewaysPct: 12.5,
      activeIntegrations: 6,
      totalIntegrations: 6,
      activeIntegrationsPct: 100.0,
      dataThroughput: '12.8 MB/min',
      mqttConnections: 136,
      integrationHealth: 'Healthy',
      activeProtocols: 6,
    );

    _protocols = [
      IotProtocolItem(
          id: '1',
          name: 'MQTT',
          code: 'mqtt',
          status: 'Connected',
          isConnected: true,
          count: 136,
          label: 'clients',
          displayText: '136 clients'),
      IotProtocolItem(
          id: '2',
          name: 'Modbus (TCP/RTU)',
          code: 'modbus',
          status: 'Active',
          isConnected: true,
          count: 6,
          label: 'devices',
          displayText: '6 devices'),
      IotProtocolItem(
          id: '3',
          name: 'HTTP(S)',
          code: 'http',
          status: 'Active',
          isConnected: true,
          count: 3,
          label: 'integrations',
          displayText: '3 integrations'),
      IotProtocolItem(
          id: '4',
          name: 'ONVIF (CCTV)',
          code: 'onvif',
          status: 'Active',
          isConnected: true,
          count: 22,
          label: 'cameras',
          displayText: '22 cameras'),
      IotProtocolItem(
          id: '5',
          name: 'RTSP (Video)',
          code: 'rtsp',
          status: 'Active',
          isConnected: true,
          count: 18,
          label: 'streams',
          displayText: '18 streams'),
      IotProtocolItem(
          id: '6',
          name: 'Zigbee',
          code: 'zigbee',
          status: 'Active',
          isConnected: true,
          count: 14,
          label: 'devices',
          displayText: '14 devices'),
    ];

    _healthServices = [
      IntegrationHealthServiceItem(
          name: 'IoT Device Command Service',
          status: 'Operational',
          isOperational: true),
      IntegrationHealthServiceItem(
          name: 'Notification Service',
          status: 'Operational',
          isOperational: true),
      IntegrationHealthServiceItem(
          name: 'Building Management System (BMS)',
          status: 'Operational',
          isOperational: true),
      IntegrationHealthServiceItem(
          name: 'Access Control System',
          status: 'Operational',
          isOperational: true),
      IntegrationHealthServiceItem(
          name: 'CCTV / VMS Integration',
          status: 'Operational',
          isOperational: true),
      IntegrationHealthServiceItem(
          name: 'Energy Metering System',
          status: 'Operational',
          isOperational: true),
    ];

    _gateways = [
      CampusGatewayItem(
          id: 'b1000000-0000-0000-0000-000000000001',
          gatewayCode: 'GW-0001',
          gatewayName: 'GW-A01 (Main Block)',
          locationPath: 'Main Block',
          protocols: 'MQTT, Modbus (TCP)',
          ipAddress: '192.168.10.21',
          status: 'online',
          isOnline: true,
          connectedDevicesCount: 28,
          uptimeDisplay: '15 days, 08:36:21 (99.6%)',
          firmwareVersion: 'v2.3.1',
          firmwareUpdateAvailable: 'v2.4.0',
          lastHeartbeat: '10 Jan 2025, 02:18 PM'),
      CampusGatewayItem(
          id: 'b1000000-0000-0000-0000-000000000002',
          gatewayCode: 'GW-0002',
          gatewayName: 'GW-A02 (Academic)',
          locationPath: 'Academic Block (A)',
          protocols: 'MQTT, Zigbee',
          ipAddress: '192.168.10.22',
          status: 'online',
          isOnline: true,
          connectedDevicesCount: 18,
          uptimeDisplay: '14 days, 12:15:00 (99.2%)',
          firmwareVersion: 'v2.4.0',
          firmwareUpdateAvailable: null,
          lastHeartbeat: '10 Jan 2025, 02:17 PM'),
      CampusGatewayItem(
          id: 'b1000000-0000-0000-0000-000000000003',
          gatewayCode: 'GW-0003',
          gatewayName: 'GW-A03 (Library)',
          locationPath: 'Library Block',
          protocols: 'MQTT, Modbus',
          ipAddress: '192.168.10.23',
          status: 'online',
          isOnline: true,
          connectedDevicesCount: 12,
          uptimeDisplay: '22 days, 04:30:10 (99.8%)',
          firmwareVersion: 'v2.4.0',
          firmwareUpdateAvailable: null,
          lastHeartbeat: '10 Jan 2025, 02:17 PM'),
      CampusGatewayItem(
          id: 'b1000000-0000-0000-0000-000000000004',
          gatewayCode: 'GW-0004',
          gatewayName: 'GW-A04 (Laboratory)',
          locationPath: 'Laboratory Block',
          protocols: 'MQTT, HTTP(S)',
          ipAddress: '192.168.10.24',
          status: 'online',
          isOnline: true,
          connectedDevicesCount: 16,
          uptimeDisplay: '10 days, 18:05:40 (98.9%)',
          firmwareVersion: 'v2.4.0',
          firmwareUpdateAvailable: null,
          lastHeartbeat: '10 Jan 2025, 02:16 PM'),
      CampusGatewayItem(
          id: 'b1000000-0000-0000-0000-000000000005',
          gatewayCode: 'GW-0005',
          gatewayName: 'GW-A05 (Auditorium)',
          locationPath: 'Auditorium',
          protocols: 'MQTT, RTSP',
          ipAddress: '192.168.10.25',
          status: 'online',
          isOnline: true,
          connectedDevicesCount: 20,
          uptimeDisplay: '18 days, 09:22:15 (99.4%)',
          firmwareVersion: 'v2.4.0',
          firmwareUpdateAvailable: null,
          lastHeartbeat: '10 Jan 2025, 02:18 PM'),
      CampusGatewayItem(
          id: 'b1000000-0000-0000-0000-000000000006',
          gatewayCode: 'GW-0006',
          gatewayName: 'GW-A06 (Admin)',
          locationPath: 'Administrative Block',
          protocols: 'MQTT, ONVIF',
          ipAddress: '192.168.10.26',
          status: 'online',
          isOnline: true,
          connectedDevicesCount: 14,
          uptimeDisplay: '30 days, 01:10:00 (99.9%)',
          firmwareVersion: 'v2.4.0',
          firmwareUpdateAvailable: null,
          lastHeartbeat: '10 Jan 2025, 02:17 PM'),
      CampusGatewayItem(
          id: 'b1000000-0000-0000-0000-000000000007',
          gatewayCode: 'GW-0007',
          gatewayName: 'GW-A07 (Sports)',
          locationPath: 'Sports Complex',
          protocols: 'MQTT, Zigbee',
          ipAddress: '192.168.10.27',
          status: 'online',
          isOnline: true,
          connectedDevicesCount: 8,
          uptimeDisplay: '12 days, 06:45:00 (98.7%)',
          firmwareVersion: 'v2.4.0',
          firmwareUpdateAvailable: null,
          lastHeartbeat: '10 Jan 2025, 02:16 PM'),
      CampusGatewayItem(
          id: 'b1000000-0000-0000-0000-000000000008',
          gatewayCode: 'GW-0008',
          gatewayName: 'GW-A08 (Hostel)',
          locationPath: 'Hostel Block',
          protocols: 'MQTT, Modbus',
          ipAddress: '192.168.10.28',
          status: 'offline',
          isOnline: false,
          connectedDevicesCount: 0,
          uptimeDisplay: '0 days, 00:00:00 (0.0%)',
          firmwareVersion: 'v2.2.8',
          firmwareUpdateAvailable: 'v2.4.0',
          lastHeartbeat: '10 Jan 2025, 11:42 AM'),
    ];

    _selectedGateway = _gateways.first;

    _integrations = [
      ThirdPartyIntegrationItem(
          id: 'c1000000-0000-0000-0000-000000000001',
          name: 'Building Management System (BMS)',
          type: 'Facility Integration',
          category: 'bms',
          provider: 'Schneider Electric',
          protocol: 'Modbus (TCP)',
          connectionMode: 'Direct',
          connectedDevicesCount: 6,
          status: 'active',
          isActive: true,
          lastSync: '10 Jan 2025, 02:10 PM'),
      ThirdPartyIntegrationItem(
          id: 'c1000000-0000-0000-0000-000000000002',
          name: 'Access Control System',
          type: 'Security Integration',
          category: 'access_control',
          provider: 'HID Global',
          protocol: 'HTTP(S) / API',
          connectionMode: 'Cloud API',
          connectedDevicesCount: 14,
          status: 'active',
          isActive: true,
          lastSync: '10 Jan 2025, 02:12 PM'),
      ThirdPartyIntegrationItem(
          id: 'c1000000-0000-0000-0000-000000000003',
          name: 'CCTV / Video Management (VMS)',
          type: 'Surveillance Integration',
          category: 'vms',
          provider: 'Hikvision / Milestone',
          protocol: 'ONVIF / RTSP',
          connectionMode: 'Hybrid',
          connectedDevicesCount: 22,
          status: 'active',
          isActive: true,
          lastSync: '10 Jan 2025, 02:11 PM'),
      ThirdPartyIntegrationItem(
          id: 'c1000000-0000-0000-0000-000000000004',
          name: 'Energy Metering System',
          type: 'Energy Integration',
          category: 'energy',
          provider: 'Schneider PowerLogic',
          protocol: 'Modbus (TCP)',
          connectionMode: 'Gateway Bridge',
          connectedDevicesCount: 8,
          status: 'active',
          isActive: true,
          lastSync: '10 Jan 2025, 02:09 PM'),
      ThirdPartyIntegrationItem(
          id: 'c1000000-0000-0000-0000-000000000005',
          name: 'Notification Service (SMS/Email)',
          type: 'Communication',
          category: 'notification',
          provider: 'Twilio / SendGrid',
          protocol: 'HTTP(S) / API',
          connectionMode: 'REST API',
          connectedDevicesCount: 12,
          status: 'active',
          isActive: true,
          lastSync: '10 Jan 2025, 02:08 PM'),
      ThirdPartyIntegrationItem(
          id: 'c1000000-0000-0000-0000-000000000006',
          name: 'IoT Device Command Service',
          type: 'Core Integration',
          category: 'core',
          provider: 'EduSHAMIIT Core Engine',
          protocol: 'MQTT',
          connectionMode: 'Direct Broker',
          connectedDevicesCount: 136,
          status: 'active',
          isActive: true,
          lastSync: '10 Jan 2025, 02:15 PM'),
    ];

    _discoveredDevices = [
      DiscoveredDeviceItem(
          id: '1',
          deviceIdentifier: 'DISC-LIGHT-091',
          deviceName: 'Philips Hue Smart Troffer',
          deviceType: 'Lighting',
          protocol: 'Zigbee',
          manufacturer: 'Philips',
          model: 'Hue Pro 60x60',
          ipAddress: '192.168.10.191',
          locationSuggestion: 'Main Block > Reception',
          status: 'newly_discovered'),
      DiscoveredDeviceItem(
          id: '2',
          deviceIdentifier: 'DISC-METER-042',
          deviceName: 'Schneider PowerLogic PM5300',
          deviceType: 'Energy Meter',
          protocol: 'Modbus',
          manufacturer: 'Schneider',
          model: 'PM5350',
          ipAddress: '192.168.10.142',
          locationSuggestion: 'Academic Block (A) > Electrical Room',
          status: 'identified'),
      DiscoveredDeviceItem(
          id: '3',
          deviceIdentifier: 'DISC-CAM-008',
          deviceName: 'Hikvision 4K PTZ Camera',
          deviceType: 'CCTV',
          protocol: 'ONVIF',
          manufacturer: 'Hikvision',
          model: 'DS-2DE4425IW-DE',
          ipAddress: '192.168.10.208',
          locationSuggestion: 'Auditorium > Stage Overhead',
          status: 'pending_approval'),
      DiscoveredDeviceItem(
          id: '4',
          deviceIdentifier: 'DISC-ENV-014',
          deviceName: 'Milesight IAQ Sensor (CO2/VOC)',
          deviceType: 'Environment',
          protocol: 'Zigbee',
          manufacturer: 'Milesight',
          model: 'AM103L',
          ipAddress: '192.168.10.174',
          locationSuggestion: 'Laboratory Block > Chemistry Lab',
          status: 'identified'),
    ];

    _webhooks = [
      IotWebhookItem(
          id: '1',
          name: 'ERP Incident Management Webhook',
          direction: 'outgoing',
          endpointUrl: 'https://api.edushamiit.edu/v1/incidents/ingest',
          eventTypes: ['device.critical_fault', 'gateway.offline'],
          status: 'active',
          lastDelivery: '10 Jan 2025, 02:15 PM',
          lastStatusCode: 200),
      IotWebhookItem(
          id: '2',
          name: 'Facility Security Alert Forwarder',
          direction: 'outgoing',
          endpointUrl: 'https://security.edushamiit.edu/alerts',
          eventTypes: ['access.breach', 'door.forced_open'],
          status: 'active',
          lastDelivery: '10 Jan 2025, 02:12 PM',
          lastStatusCode: 200),
      IotWebhookItem(
          id: '3',
          name: 'BMS Telemetry Ingestion Endpoint',
          direction: 'incoming',
          endpointUrl: '/api/v1/integrations/webhooks/bms-inbound',
          eventTypes: ['bms.telemetry', 'hvac.sync'],
          status: 'active',
          lastDelivery: '10 Jan 2025, 02:10 PM',
          lastStatusCode: 200),
    ];

    _certificates = [
      IotCertificateItem(
          id: '1',
          name: 'EduSHAMIIT Campus IoT Root CA',
          certType: 'ca',
          subject: 'CN=EduSHAMIIT IoT Root CA, O=EduSHAMIIT',
          issuer: 'CN=EduSHAMIIT Root CA',
          status: 'active',
          thumbprint: 'E4:92:A1:B8:3C:D0:1F:55:82:94:10:FA:9C:22:EE:71'),
      IotCertificateItem(
          id: '2',
          name: 'EMQX Mosquitto Broker Server TLS',
          certType: 'server',
          subject: 'CN=mqtt.edushamiit.internal',
          issuer: 'CN=EduSHAMIIT IoT Root CA',
          status: 'active',
          thumbprint: 'A1:33:4F:90:CC:12:88:BB:77:45:09:12:FE:54:11:29'),
      IotCertificateItem(
          id: '3',
          name: 'Gateway Fleet Mutual TLS Client',
          certType: 'gateway',
          subject: 'CN=gw-fleet.edushamiit.internal',
          issuer: 'CN=EduSHAMIIT IoT Root CA',
          status: 'active',
          thumbprint: '99:81:72:63:54:45:36:27:18:09:AA:BB:CC:DD:EE:FF'),
    ];

    _logs = [
      IotLogItem(
          id: '1',
          source: 'Gateway',
          severity: 'info',
          protocol: 'MQTT',
          event: 'Heartbeat Acknowledged',
          message:
              'GW-A01 reported 28 healthy client telemetry links with 0 packet drops',
          correlationId: 'CORR-GW001-9921',
          timestamp: '10 Jan 2025, 02:18 PM'),
      IotLogItem(
          id: '2',
          source: 'Integration',
          severity: 'info',
          protocol: 'MQTT',
          event: 'Broker QoS 1 Verified',
          message:
              'IoT Device Command Service publisher channel synchronized with 136 devices',
          correlationId: 'CORR-MQTT-4412',
          timestamp: '10 Jan 2025, 02:15 PM'),
      IotLogItem(
          id: '3',
          source: 'Integration',
          severity: 'info',
          protocol: 'HTTP(S)',
          event: 'Access Control Event Polled',
          message: 'HID Door controller access logs polled: 14 doors secured',
          correlationId: 'CORR-ACC-8819',
          timestamp: '10 Jan 2025, 02:12 PM'),
      IotLogItem(
          id: '4',
          source: 'Integration',
          severity: 'info',
          protocol: 'Modbus',
          event: 'BMS Register Sync OK',
          message:
              'Modbus TCP polling cycle finished: 48 holding registers updated in 12ms',
          correlationId: 'CORR-BMS-3310',
          timestamp: '10 Jan 2025, 02:10 PM'),
      IotLogItem(
          id: '5',
          source: 'Gateway',
          severity: 'warning',
          protocol: 'Modbus',
          event: 'Gateway Connection Timeout',
          message:
              'GW-A08 (Hostel) missed 3 consecutive keep-alive intervals; marked offline',
          correlationId: 'CORR-GW008-0114',
          timestamp: '10 Jan 2025, 11:42 AM'),
    ];
  }

  Future<void> _fetchLiveDashboard() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/integrations-gateways/dashboard'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _kpis = IntegrationGatewayKpis.fromJson(data['kpis'] ?? {});
            if (data['protocols'] is List) {
              _protocols = (data['protocols'] as List)
                  .map((p) => IotProtocolItem.fromJson(p))
                  .toList();
            }
            if (data['integration_health_items'] is List) {
              _healthServices = (data['integration_health_items'] as List)
                  .map((h) => IntegrationHealthServiceItem.fromJson(h))
                  .toList();
            }
          });
        }
      }
    } catch (_) {
      // Fallback to seeded data
    }
    _fetchGateways();
    _fetchIntegrations();
  }

  Future<void> _fetchGateways() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/integrations-gateways/gateways'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true && mounted) {
          final list = (data['gateways'] as List)
              .map((g) => CampusGatewayItem.fromJson(g))
              .toList();
          setState(() {
            _gateways = list;
            if (_selectedGateway != null) {
              _selectedGateway = list.firstWhere(
                  (x) => x.id == _selectedGateway!.id,
                  orElse: () => list.first);
            } else if (list.isNotEmpty) {
              _selectedGateway = list.first;
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchIntegrations() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/integrations-gateways/integrations'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _integrations = (data['integrations'] as List)
                .map((i) => ThirdPartyIntegrationItem.fromJson(i))
                .toList();
          });
        }
      }
    } catch (_) {}
  }

  // --- ACTIONS ---

  void _restartSelectedGateway() async {
    if (_selectedGateway == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.restart_alt_rounded, color: Color(0xFF1677F2)),
            const SizedBox(width: 8),
            Expanded(child: Text('Restart ${_selectedGateway!.gatewayName}?')),
          ],
        ),
        content: Text(
          'Are you sure you want to send a remote reboot signal to ${_selectedGateway!.gatewayName} (${_selectedGateway!.gatewayCode})?\n\nConnected devices (${_selectedGateway!.connectedDevicesCount}) will momentarily buffer telemetry locally.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1677F2),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Restart'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Reboot command dispatched to ${_selectedGateway!.gatewayName} via MQTT!'),
          backgroundColor: const Color(0xFF1677F2),
        ),
      );
      try {
        await http.post(Uri.parse(
            '$_baseUrl/integrations-gateways/gateways/${_selectedGateway!.id}/restart'));
      } catch (_) {}
    }
  }

  void _updateSelectedGatewayFirmware() async {
    if (_selectedGateway == null) return;
    final targetVer = _selectedGateway!.firmwareUpdateAvailable ?? 'v2.4.0';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update_alt_rounded, color: Color(0xFF1677F2)),
            SizedBox(width: 8),
            Expanded(child: Text('Apply Firmware Update?')),
          ],
        ),
        content: Text(
          'Target Version: $targetVer\nCurrent Version: ${_selectedGateway!.firmwareVersion}\nGateway: ${_selectedGateway!.gatewayName}\n\nThe gateway will download the signed image over TLS, verify cryptographic checksums, and perform a seamless A/B rollback-safe boot.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1677F2),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start OTA Update'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _selectedGateway = _selectedGateway!.copyWith(
          firmwareVersion: targetVer,
          firmwareUpdateAvailable: null,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Firmware for ${_selectedGateway!.gatewayName} updated to $targetVer!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      try {
        await http.post(
          Uri.parse(
              '$_baseUrl/integrations-gateways/gateways/${_selectedGateway!.id}/update-firmware'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'target_version': targetVer}),
        );
      } catch (_) {}
    }
  }

  void _runSelectedGatewayDiagnostics() async {
    if (_selectedGateway == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          _GatewayDiagnosticsProgressDialog(gateway: _selectedGateway!),
    );
  }

  void _openAddIntegrationWizard() {
    showDialog(
      context: context,
      builder: (ctx) => _AddIntegrationWizardDialog(
        onCreated: (newInteg) {
          setState(() {
            _integrations.add(newInteg);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Integration "${newInteg.name}" registered successfully!'),
                backgroundColor: const Color(0xFF10B981)),
          );
        },
      ),
    );
  }

  void _openRegisterGatewayWizard() {
    showDialog(
      context: context,
      builder: (ctx) => _RegisterGatewayWizardDialog(
        onCreated: (newGw) {
          setState(() {
            _gateways.add(newGw);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Gateway "${newGw.gatewayName}" registered successfully!'),
                backgroundColor: const Color(0xFF10B981)),
          );
        },
      ),
    );
  }

  void _openDeviceDiscoveryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _DeviceDiscoveryModalDialog(
        gateways: _gateways,
        discoveredDevices: _discoveredDevices,
        onApproved: (device) {
          setState(() {
            _discoveredDevices.removeWhere((d) => d.id == device.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Device "${device.deviceName}" approved and mapped into Device Registry!'),
                backgroundColor: const Color(0xFF10B981)),
          );
        },
      ),
    );
  }

  // --- BUILD METHODS ---

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Header Banner with Refresh & Add Integration/Gateway Dropdown
          _buildTopHeader(isDark, screenWidth),
          const SizedBox(height: 14),

          // 2. Top 7 KPI Summary Cards
          _buildTopKpiCards(isDark, screenWidth),
          const SizedBox(height: 16),

          // 3. Sub-Tabs Bar (Overview, Gateways, Integrations, Protocols, API & Webhooks, Data Flow, Logs)
          _buildSubTabsBar(isDark),
          const SizedBox(height: 16),

          // 4. View switched dynamically by sub-tab index
          _buildActiveSubTabView(isDark, screenWidth),
        ],
      ),
    );
  }

  // --- TOP HEADER ---
  Widget _buildTopHeader(bool isDark, double width) {
    final isCompact = width < 900;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildHeaderIcon(),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Integrations & Gateways',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Manage IoT gateways, communication protocols and third-party integrations to connect and control campus devices.',
                            style: TextStyle(
                                color: Color(0xFF64748B), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildRefreshButton(isDark),
                    _buildAddActionSplitButton(),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                _buildHeaderIcon(),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Integrations & Gateways',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.4),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Manage IoT gateways, communication protocols and third-party integrations to connect and control campus devices.',
                        style:
                            TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      ),
                    ],
                  ),
                ),
                _buildRefreshButton(isDark),
                const SizedBox(width: 10),
                _buildAddActionSplitButton(),
              ],
            ),
    );
  }

  Widget _buildHeaderIcon() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1677F2).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.hub_outlined, color: Color(0xFF1677F2), size: 28),
    );
  }

  Widget _buildRefreshButton(bool isDark) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? Colors.white70 : const Color(0xFF334155),
        side: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: () {
        setState(() => _isLoading = true);
        _fetchLiveDashboard().then((_) {
          if (mounted) setState(() => _isLoading = false);
        });
      },
      icon: _isLoading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.refresh_rounded, size: 16),
      label: const Text('Refresh',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildAddActionSplitButton() {
    return PopupMenuButton<String>(
      onSelected: (val) {
        if (val == 'integration') {
          _openAddIntegrationWizard();
        } else if (val == 'gateway') {
          _openRegisterGatewayWizard();
        } else if (val == 'discover') {
          _openDeviceDiscoveryDialog();
        }
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'integration',
          child: Row(
            children: [
              Icon(Icons.extension_outlined,
                  size: 18, color: Color(0xFF1677F2)),
              SizedBox(width: 10),
              Text('Add Integration',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'gateway',
          child: Row(
            children: [
              Icon(Icons.router_outlined, size: 18, color: Color(0xFF10B981)),
              SizedBox(width: 10),
              Text('Register Gateway',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: 'discover',
          child: Row(
            children: [
              Icon(Icons.radar_rounded, size: 18, color: Color(0xFF8B5CF6)),
              SizedBox(width: 10),
              Text('Discover Devices',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1677F2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1677F2).withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 18, color: Colors.white),
            SizedBox(width: 6),
            Flexible(
              child: Text(
                'Add Integration / Gateway',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.arrow_drop_down_rounded,
                size: 18, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  // --- TOP 7 KPI CARDS ---
  Widget _buildTopKpiCards(bool isDark, double width) {
    final cards = [
      _buildKpiCard('Total Gateways', '${_kpis.totalGateways}', '',
          Icons.router_outlined, const Color(0xFF1677F2), isDark),
      _buildKpiCard(
          'Online Gateways',
          '${_kpis.onlineGateways}',
          '(${_kpis.onlineGatewaysPct}%)',
          Icons.check_circle_outline_rounded,
          const Color(0xFF10B981),
          isDark),
      _buildKpiCard(
          'Offline Gateways',
          '${_kpis.offlineGateways}',
          '(${_kpis.offlineGatewaysPct}%)',
          Icons.power_settings_new_rounded,
          const Color(0xFF64748B),
          isDark),
      _buildKpiCard('Active Integrations', '${_kpis.activeIntegrations}', '',
          Icons.cable_rounded, const Color(0xFF1677F2), isDark),
      _buildKpiCard('Data Throughput', _kpis.dataThroughput, '',
          Icons.bar_chart_rounded, const Color(0xFF1677F2), isDark),
      _buildKpiCard('MQTT Connections', '${_kpis.mqttConnections}', '',
          Icons.wifi_tethering_rounded, const Color(0xFF1677F2), isDark),
      _buildKpiCard('Integration Health', _kpis.integrationHealth, '',
          Icons.shield_outlined, const Color(0xFF10B981), isDark),
    ];

    if (width < 750) {
      final cardWidth = (width - 40) / 2;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
      );
    } else if (width < 1200) {
      final cardWidth = (width - 62) / 4;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children:
            cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
      );
    }

    return Row(
      children: cards
          .map((c) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: c,
                ),
              ))
          .toList(),
    );
  }

  Widget _buildKpiCard(String title, String mainValue, String subValue,
      IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 10.5,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  children: [
                    Text(
                      mainValue,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3),
                    ),
                    if (subValue.isNotEmpty)
                      Text(
                        subValue,
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: color),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SUB-TABS BAR ---
  Widget _buildSubTabsBar(bool isDark) {
    final tabs = [
      'Overview',
      'Gateways',
      'Integrations',
      'Protocols',
      'API & Webhooks',
      'Data Flow',
      'Logs',
    ];

    return Container(
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                width: 1.5)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: tabs.asMap().entries.map((entry) {
            final idx = entry.key;
            final label = entry.value;
            final isSelected = _selectedSubTab == idx;

            return InkWell(
              onTap: () => setState(() => _selectedSubTab = idx),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected
                          ? const Color(0xFF1677F2)
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected
                        ? const Color(0xFF1677F2)
                        : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // --- ACTIVE SUB-TAB VIEW ---
  Widget _buildActiveSubTabView(bool isDark, double width) {
    switch (_selectedSubTab) {
      case 0:
        return _buildOverviewTabView(isDark, width);
      case 1:
        return _buildGatewaysTabView(isDark, width);
      case 2:
        return _buildIntegrationsTabView(isDark, width);
      case 3:
        return _buildProtocolsTabView(isDark, width);
      case 4:
        return _buildApiWebhooksTabView(isDark, width);
      case 5:
        return _buildDataFlowTabView(isDark, width);
      case 6:
        return _buildLogsTabView(isDark, width);
      default:
        return _buildOverviewTabView(isDark, width);
    }
  }

  // ============================================================================
  // TAB 1: OVERVIEW TAB VIEW (MATCHING CANONICAL SCREENSHOT)
  // ============================================================================
  Widget _buildOverviewTabView(bool isDark, double width) {
    final isDesktop = width >= 1100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Row 1: 3 Cards (Donut Overview, Protocol Status, Integration Health)
        _buildOverviewRow1(isDark, width),
        const SizedBox(height: 16),

        // Row 2: Central Tables (Gateways & Integrations) + Right Inspector Panel
        if (isDesktop)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left 68%: Two Tables
              Expanded(
                flex: 68,
                child: Column(
                  children: [
                    _buildRegisteredGatewaysTableCard(isDark),
                    const SizedBox(height: 16),
                    _buildThirdPartyIntegrationsTableCard(isDark),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Right 32%: Selected Gateway Inspector Panel
              Expanded(
                flex: 32,
                child: _buildRightInspectorPanel(isDark),
              ),
            ],
          )
        else
          Column(
            children: [
              _buildRegisteredGatewaysTableCard(isDark),
              const SizedBox(height: 16),
              _buildThirdPartyIntegrationsTableCard(isDark),
              const SizedBox(height: 16),
              _buildRightInspectorPanel(isDark),
            ],
          ),
      ],
    );
  }

  // --- ROW 1: 3 OVERVIEW CARDS ---
  Widget _buildOverviewRow1(bool isDark, double width) {
    final isCompact = width < 950;

    final card1 = _buildDonutOverviewCard(isDark);
    final card2 = _buildProtocolStatusCard(isDark);
    final card3 = _buildIntegrationHealthCard(isDark);

    if (isCompact) {
      return Column(
        children: [
          card1,
          const SizedBox(height: 12),
          card2,
          const SizedBox(height: 12),
          card3,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: card1),
        const SizedBox(width: 14),
        Expanded(child: card2),
        const SizedBox(width: 14),
        Expanded(child: card3),
      ],
    );
  }

  // CARD 1: Integration & Gateway Overview (Donut Chart)
  Widget _buildDonutOverviewCard(bool isDark) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xFF1677F2), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Integration & Gateway Overview',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              children: [
                // Custom Donut Painter
                Expanded(
                  flex: 5,
                  child: Center(
                    child: SizedBox(
                      width: 120,
                      height: 120,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(120, 120),
                            painter: _GatewayDonutPainter(
                              onlinePct: _kpis.onlineGatewaysPct,
                              offlinePct: _kpis.offlineGatewaysPct,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${_kpis.totalGateways}',
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5),
                              ),
                              const Text('Gateways',
                                  style: TextStyle(
                                      fontSize: 10, color: Color(0xFF64748B))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Legend
                Expanded(
                  flex: 6,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDonutLegendRow(
                          'Online',
                          '${_kpis.onlineGateways} (${_kpis.onlineGatewaysPct}%)',
                          const Color(0xFF10B981)),
                      const SizedBox(height: 10),
                      _buildDonutLegendRow(
                          'Offline',
                          '${_kpis.offlineGateways} (${_kpis.offlineGatewaysPct}%)',
                          const Color(0xFFEF4444)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 20),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.hub_outlined,
                      color: Color(0xFF1677F2), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Integrations: ${_kpis.activeIntegrations} (${_kpis.activeIntegrationsPct.toInt()}%)',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1677F2)),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.layers_outlined,
                      color: Color(0xFF1677F2), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'Protocols: ${_kpis.activeProtocols} Active',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1677F2)),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDonutLegendRow(String label, String value, Color color) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                  child: Text(label,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF64748B)),
                      overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 4),
              Flexible(
                  child: Text(value,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis)),
            ],
          ),
        ),
      ],
    );
  }

  // CARD 2: Protocol & Connectivity Status
  Widget _buildProtocolStatusCard(bool isDark) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xFF10B981), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Protocol & Connectivity Status',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.separated(
              itemCount: _protocols.length,
              separatorBuilder: (_, __) => const SizedBox(height: 5),
              itemBuilder: (ctx, i) {
                final p = _protocols[i];
                return Row(
                  children: [
                    _getProtocolIcon(p.code),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        p.name,
                        style: const TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        p.status == 'Connected' ? '✓ Connected' : '✓ Active',
                        style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      p.displayText,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _getProtocolIcon(String code) {
    IconData icon = Icons.cable_rounded;
    Color color = const Color(0xFF1677F2);
    if (code == 'mqtt') {
      icon = Icons.wifi_tethering_rounded;
      color = const Color(0xFF1677F2);
    } else if (code == 'modbus') {
      icon = Icons.developer_board_rounded;
      color = const Color(0xFF0284C7);
    } else if (code == 'http') {
      icon = Icons.http_rounded;
      color = const Color(0xFF0D9488);
    } else if (code == 'onvif') {
      icon = Icons.videocam_outlined;
      color = const Color(0xFF059669);
    } else if (code == 'rtsp') {
      icon = Icons.video_collection_outlined;
      color = const Color(0xFF4F46E5);
    } else if (code == 'zigbee') {
      icon = Icons.share_rounded;
      color = const Color(0xFFE11D48);
    }
    return Icon(icon, size: 16, color: color);
  }

  // CARD 3: Integration Health (Operational Services)
  Widget _buildIntegrationHealthCard(bool isDark) {
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                      color: Color(0xFF10B981), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Integration Health',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Color(0xFF10B981), size: 16),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'All Integrations are Healthy',
                    style: TextStyle(
                        color: Color(0xFF10B981),
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.separated(
              itemCount: _healthServices.length,
              separatorBuilder: (_, __) => const SizedBox(height: 4),
              itemBuilder: (ctx, i) {
                final s = _healthServices[i];
                return Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: Color(0xFF10B981), size: 14),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        s.name,
                        style: const TextStyle(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      s.status,
                      style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981)),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- CENTRAL TABLE 1: REGISTERED GATEWAYS ---
  Widget _buildRegisteredGatewaysTableCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.dns_outlined,
                          color: Color(0xFF1677F2), size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Registered Gateways (${_gateways.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => setState(() => _selectedSubTab = 1),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View All',
                          style: TextStyle(
                              color: Color(0xFF1677F2),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      Icon(Icons.arrow_forward_rounded,
                          color: Color(0xFF1677F2), size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Gateways Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              headingRowHeight: 38,
              dataRowMinHeight: 46,
              dataRowMaxHeight: 46,
              horizontalMargin: 12,
              columnSpacing: 16,
              columns: const [
                DataColumn(
                    label: Text('Gateway Name',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(
                    label: Text('Location',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(
                    label: Text('Protocol(s)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(
                    label: Text('Status',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(
                    label: Text('Connected Devices',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(
                    label: Text('Last Heartbeat',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(
                    label: Text('Actions',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: _gateways.map((gw) {
                final isSelected = _selectedGateway?.id == gw.id;
                final isOnline = gw.isOnline;

                return DataRow(
                  selected: isSelected,
                  onSelectChanged: (_) {
                    setState(() => _selectedGateway = gw);
                  },
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.router_outlined,
                              size: 16,
                              color: isOnline
                                  ? const Color(0xFF1677F2)
                                  : const Color(0xFF64748B)),
                          const SizedBox(width: 8),
                          Text(gw.gatewayName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
                    ),
                    DataCell(Text(gw.locationPath,
                        style: const TextStyle(fontSize: 12))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF1677F2).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(gw.protocols,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1677F2))),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: (isOnline
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444))
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                    color: isOnline
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFFEF4444),
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 4),
                            Text(
                              isOnline ? 'Online' : 'Offline',
                              style: TextStyle(
                                  color: isOnline
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                    DataCell(Text('${gw.connectedDevicesCount}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                    DataCell(Text(gw.lastHeartbeat,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B)))),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                size: 16, color: Color(0xFF1677F2)),
                            onPressed: () {
                              setState(() => _selectedGateway = gw);
                            },
                            tooltip: 'Configure Gateway',
                          ),
                          IconButton(
                            icon: const Icon(Icons.restart_alt_rounded,
                                size: 16, color: Color(0xFF64748B)),
                            onPressed: () {
                              setState(() => _selectedGateway = gw);
                              _restartSelectedGateway();
                            },
                            tooltip: 'Restart Gateway',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // --- CENTRAL TABLE 2: THIRD-PARTY INTEGRATIONS ---
  Widget _buildThirdPartyIntegrationsTableCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.extension_outlined,
                          color: Color(0xFF1677F2), size: 18),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Third-party Integrations (${_integrations.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => setState(() => _selectedSubTab = 2),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View All',
                          style: TextStyle(
                              color: Color(0xFF1677F2),
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      Icon(Icons.arrow_forward_rounded,
                          color: Color(0xFF1677F2), size: 14),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Integrations Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              headingRowHeight: 38,
              dataRowMinHeight: 46,
              dataRowMaxHeight: 46,
              horizontalMargin: 12,
              columnSpacing: 16,
              columns: const [
                DataColumn(
                    label: Text('Integration Name',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(
                    label: Text('Type',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(
                    label: Text('Protocol / Method',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(
                    label: Text('Status',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(
                    label: Text('Last Sync',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(
                    label: Text('Actions',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: _integrations.map((integ) {
                return DataRow(
                  cells: [
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _getIntegrationCategoryIcon(integ.category),
                          const SizedBox(width: 8),
                          Text(integ.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 12)),
                        ],
                      ),
                    ),
                    DataCell(Text(integ.type,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF64748B)))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF1677F2).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(integ.protocol,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1677F2))),
                      ),
                    ),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle_rounded,
                                color: Color(0xFF10B981), size: 12),
                            SizedBox(width: 4),
                            Text('Active',
                                style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    DataCell(Text(integ.lastSync,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B)))),
                    DataCell(
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit_outlined,
                                size: 16, color: Color(0xFF1677F2)),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          'Configuring ${integ.name}...')));
                            },
                            tooltip: 'Configure',
                          ),
                          IconButton(
                            icon: const Icon(Icons.sync_rounded,
                                size: 16, color: Color(0xFF10B981)),
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Syncing ${integ.name}...'),
                                      backgroundColor:
                                          const Color(0xFF10B981)));
                            },
                            tooltip: 'Sync Now',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getIntegrationCategoryIcon(String category) {
    IconData icon = Icons.cable_rounded;
    Color color = const Color(0xFF1677F2);
    if (category == 'bms') {
      icon = Icons.apartment_rounded;
      color = const Color(0xFF0284C7);
    } else if (category == 'access_control') {
      icon = Icons.security_rounded;
      color = const Color(0xFF10B981);
    } else if (category == 'vms') {
      icon = Icons.videocam_outlined;
      color = const Color(0xFF8B5CF6);
    } else if (category == 'energy') {
      icon = Icons.bolt_rounded;
      color = const Color(0xFFF59E0B);
    } else if (category == 'notification') {
      icon = Icons.email_outlined;
      color = const Color(0xFFEC4899);
    } else if (category == 'core') {
      icon = Icons.hub_rounded;
      color = const Color(0xFF1677F2);
    }
    return Icon(icon, size: 16, color: color);
  }

  // --- RIGHT SECTION: SELECTED GATEWAY INSPECTOR PANEL ---
  Widget _buildRightInspectorPanel(bool isDark) {
    if (_selectedGateway == null) {
      return Container(
        height: 300,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color:
                  isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: const Center(
            child: Text('Select a gateway to inspect specifications')),
      );
    }

    final gw = _selectedGateway!;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Inspector Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.settings_input_composite_rounded,
                          color: Color(0xFF1677F2), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Selected Gateway – ${gw.gatewayName}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 16, color: Color(0xFF1677F2)),
                  onPressed: () {},
                  tooltip: 'Edit Gateway',
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Gateway Hardware Graphic & Online Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Physical Router Vector Graphic
                    _buildPhysicalGatewayGraphic(gw.isOnline),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: (gw.isOnline
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFEF4444))
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                        color: gw.isOnline
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFFEF4444),
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Text(
                                  gw.isOnline ? 'Online' : 'Offline',
                                  style: TextStyle(
                                      color: gw.isOnline
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFEF4444),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildInspectorKeyValue('Gateway ID', gw.gatewayCode),
                          _buildInspectorKeyValue('Location', gw.locationPath),
                          _buildInspectorKeyValue('IP Address', gw.ipAddress),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Specs Key-Value Table
                _buildInspectorKeyValue('Protocol(s)', gw.protocols),
                _buildInspectorKeyValue(
                    'Connected Devices', '${gw.connectedDevicesCount}'),
                _buildInspectorKeyValue('Uptime', gw.uptimeDisplay),
                _buildFirmwareRow(gw),
                _buildInspectorKeyValue('Last Heartbeat', gw.lastHeartbeat),

                const SizedBox(height: 14),

                // Primary Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1677F2),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _restartSelectedGateway,
                        icon: const Icon(Icons.restart_alt_rounded, size: 15),
                        label: const Text('Restart Gateway',
                            style: TextStyle(
                                fontSize: 11.5, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _updateSelectedGatewayFirmware,
                        icon: const Icon(Icons.system_update_alt_rounded,
                            size: 14),
                        label: const Text('Update Firmware',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _runSelectedGatewayDiagnostics,
                        icon:
                            const Icon(Icons.monitor_heart_outlined, size: 14),
                        label: const Text('Run Diagnostics',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 5 ACCORDION SECTIONS
          _buildInspectorAccordion(
            title: 'Data Flow & Connectivity Map',
            icon: Icons.alt_route_rounded,
            isExpanded: _accDataFlowExpanded,
            onToggle: () =>
                setState(() => _accDataFlowExpanded = !_accDataFlowExpanded),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAccordionKeyValue('Incoming Packets', '42 / sec'),
                _buildAccordionKeyValue('Outgoing Packets', '38 / sec'),
                _buildAccordionKeyValue('Packet Loss', '0.02% (Nominal)'),
                _buildAccordionKeyValue(
                    'Current Throughput', '${gw.dataThroughputMbMin} MB/min'),
              ],
            ),
            isDark: isDark,
          ),
          _buildInspectorAccordion(
            title: 'API Access & Webhooks',
            icon: Icons.code_rounded,
            isExpanded: _accApiWebhooksExpanded,
            onToggle: () => setState(
                () => _accApiWebhooksExpanded = !_accApiWebhooksExpanded),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAccordionKeyValue('Inbound Port', '8082 / 1883'),
                _buildAccordionKeyValue('Outbound Webhooks', '2 Active'),
                _buildAccordionKeyValue('Authentication', 'Mutual TLS / Token'),
              ],
            ),
            isDark: isDark,
          ),
          _buildInspectorAccordion(
            title: 'Integration Logs & Events',
            icon: Icons.list_alt_rounded,
            isExpanded: _accLogsEventsExpanded,
            onToggle: () => setState(
                () => _accLogsEventsExpanded = !_accLogsEventsExpanded),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: _logs.take(3).map((l) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle,
                          size: 6,
                          color: l.severity == 'warning'
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFF10B981)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(l.event,
                                style: const TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w600)),
                            Text(l.message,
                                style: const TextStyle(
                                    fontSize: 10, color: Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            isDark: isDark,
          ),
          _buildInspectorAccordion(
            title: 'Data Synchronization & Schedules',
            icon: Icons.schedule_rounded,
            isExpanded: _accSyncSchedulesExpanded,
            onToggle: () => setState(
                () => _accSyncSchedulesExpanded = !_accSyncSchedulesExpanded),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAccordionKeyValue('Sync Interval', 'Every 5 seconds'),
                _buildAccordionKeyValue(
                    'Active Automation Schedules', '8 Schedules'),
                _buildAccordionKeyValue(
                    'Last Coordinated Sync', '10 Jan 2025, 02:18 PM'),
              ],
            ),
            isDark: isDark,
          ),
          _buildInspectorAccordion(
            title: 'Integration Health History',
            icon: Icons.show_chart_rounded,
            isExpanded: _accHealthHistoryExpanded,
            onToggle: () => setState(
                () => _accHealthHistoryExpanded = !_accHealthHistoryExpanded),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAccordionKeyValue('30-Day MTBF', '720 hours'),
                _buildAccordionKeyValue('Historical Availability', '99.6%'),
                _buildAccordionKeyValue(
                    'Unplanned Disconnects', '1 event (2 mins)'),
              ],
            ),
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildPhysicalGatewayGraphic(bool isOnline) {
    return Container(
      width: 100,
      height: 70,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF334155), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Antennas
          Positioned(
            left: 14,
            top: 2,
            child: Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                    color: const Color(0xFF475569),
                    borderRadius: BorderRadius.circular(1))),
          ),
          Positioned(
            right: 14,
            top: 2,
            child: Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                    color: const Color(0xFF475569),
                    borderRadius: BorderRadius.circular(1))),
          ),
          // Router Chassis
          Positioned(
            bottom: 6,
            left: 6,
            right: 6,
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                              color: isOnline
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                              shape: BoxShape.circle)),
                      const SizedBox(width: 3),
                      Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle)),
                      const SizedBox(width: 3),
                      Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                              color: Color(0xFF1677F2),
                              shape: BoxShape.circle)),
                    ],
                  ),
                  const Icon(Icons.wifi_rounded,
                      size: 14, color: Colors.white70),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInspectorKeyValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          Flexible(
            child: Text(
              value,
              style:
                  const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFirmwareRow(CampusGatewayItem gw) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Firmware Version',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
          const SizedBox(width: 8),
          Flexible(
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              runSpacing: 4,
              children: [
                Text(gw.firmwareVersion,
                    style: const TextStyle(
                        fontSize: 11.5, fontWeight: FontWeight.w600)),
                if (gw.firmwareUpdateAvailable != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1677F2).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Update Available: ${gw.firmwareUpdateAvailable}',
                      style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1677F2)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccordionKeyValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          Text(value,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInspectorAccordion({
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required Widget content,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: const Color(0xFF1677F2)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 12),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: const Color(0xFF64748B),
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: content,
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 2: GATEWAYS FULL VIEW
  // ============================================================================
  Widget _buildGatewaysTabView(bool isDark, double width) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            const Text('Institutional IoT Gateways Fleet',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white),
              onPressed: _openRegisterGatewayWizard,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Register Gateway'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildRegisteredGatewaysTableCard(isDark),
      ],
    );
  }

  // ============================================================================
  // TAB 3: INTEGRATIONS FULL VIEW
  // ============================================================================
  Widget _buildIntegrationsTabView(bool isDark, double width) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            const Text('Third-party IoT Integrations Catalog',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1677F2),
                  foregroundColor: Colors.white),
              onPressed: _openAddIntegrationWizard,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Integration'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildThirdPartyIntegrationsTableCard(isDark),
      ],
    );
  }

  // ============================================================================
  // TAB 4: PROTOCOLS FULL VIEW
  // ============================================================================
  Widget _buildProtocolsTabView(bool isDark, double width) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Supported Protocols & Driver Registry',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
              'Standardized fieldbus, network, and IoT protocols active on campus.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _protocols.map((p) {
              return Container(
                width: width < 640 ? double.infinity : 280,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F172A)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _getProtocolIcon(p.code),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  p.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4)),
                          child: Text(p.status,
                              style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Code: ${p.code.toUpperCase()}',
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B))),
                    const SizedBox(height: 4),
                    Text('Connected: ${p.displayText}',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 5: API & WEBHOOKS
  // ============================================================================
  Widget _buildApiWebhooksTabView(bool isDark, double width) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Configured Webhooks & Event Routing',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
              'Real-time event subscriptions dispatched to external platforms and security systems.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          const SizedBox(height: 14),
          ..._webhooks.map((w) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(
                      w.direction == 'outgoing'
                          ? Icons.call_made_rounded
                          : Icons.call_received_rounded,
                      color: const Color(0xFF1677F2),
                      size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(w.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(w.endpointUrl,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text('HTTP ${w.lastStatusCode}',
                        style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
          const Text('Mutual TLS & Device Certificates',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
              'Active root authorities, MQTT server TLS, and gateway client certificates.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          const SizedBox(height: 14),
          ..._certificates.map((c) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined,
                      color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 12.5)),
                        const SizedBox(height: 2),
                        Text(c.subject,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF64748B))),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(c.status.toUpperCase(),
                        style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 6: DATA FLOW VIEW
  // ============================================================================
  Widget _buildDataFlowTabView(bool isDark, double width) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Live Data Flow & Message Throughput',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 6),
          const Text(
              'Telemetry pipeline ingress, MQTT broker queue, and downstream ERP synchronization.',
              style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildDataFlowMetricBox(
                    'Incoming Message Rate',
                    '312 msgs / sec',
                    Icons.arrow_downward_rounded,
                    const Color(0xFF10B981),
                    isDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDataFlowMetricBox(
                    'Aggregated Throughput',
                    _kpis.dataThroughput,
                    Icons.speed_rounded,
                    const Color(0xFF1677F2),
                    isDark),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDataFlowMetricBox(
                    'MQTT Active Clients',
                    '${_kpis.mqttConnections} connected',
                    Icons.devices_rounded,
                    const Color(0xFF8B5CF6),
                    isDark),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataFlowMetricBox(
      String label, String value, IconData icon, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          const SizedBox(height: 4),
          Text(value,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ============================================================================
  // TAB 7: LOGS VIEW
  // ============================================================================
  Widget _buildLogsTabView(bool isDark, double width) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.all(14),
            child: Text('Centralized Integration & Gateway Audit Logs',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
          const Divider(height: 1),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false,
              headingRowHeight: 38,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 44,
              horizontalMargin: 12,
              columnSpacing: 16,
              columns: const [
                DataColumn(
                    label: Text('Source',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(
                    label: Text('Severity',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(
                    label: Text('Protocol',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(
                    label: Text('Event',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(
                    label: Text('Message',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(
                    label: Text('Correlation ID',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
                DataColumn(
                    label: Text('Timestamp',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12))),
              ],
              rows: _logs.map((l) {
                Color sevColor = const Color(0xFF10B981);
                if (l.severity == 'warning') sevColor = const Color(0xFFF59E0B);
                if (l.severity == 'error') sevColor = const Color(0xFFEF4444);

                return DataRow(
                  cells: [
                    DataCell(Text(l.source,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: sevColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(l.severity.toUpperCase(),
                            style: TextStyle(
                                color: sevColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                    DataCell(
                        Text(l.protocol, style: const TextStyle(fontSize: 11))),
                    DataCell(Text(l.event,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 12))),
                    DataCell(Text(l.message,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B)))),
                    DataCell(Text(l.correlationId,
                        style: const TextStyle(
                            fontSize: 10.5, fontFamily: 'monospace'))),
                    DataCell(Text(l.timestamp,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFF64748B)))),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CUSTOM DONUT PAINTER FOR GATEWAY HEALTH
// ============================================================================
class _GatewayDonutPainter extends CustomPainter {
  final double onlinePct;
  final double offlinePct;

  _GatewayDonutPainter({required this.onlinePct, required this.offlinePct});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;

    final paintBg = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, paintBg);

    double startAngle = -1.57079632679; // -90 deg
    const pi2 = 6.28318530718;

    // Online Segment (Green)
    final sweepOnline = (onlinePct / 100.0) * pi2;
    final paintOnline = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepOnline,
        false,
        paintOnline);

    // Offline Segment (Red)
    startAngle += sweepOnline;
    final sweepOffline = (offlinePct / 100.0) * pi2;
    final paintOffline = Paint()
      ..color = const Color(0xFFEF4444)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepOffline,
        false,
        paintOffline);
  }

  @override
  bool shouldRepaint(covariant _GatewayDonutPainter oldDelegate) => true;
}

// ============================================================================
// MODALS & WIZARDS
// ============================================================================

/// Gateway Diagnostics Dialog with live test sequence
class _GatewayDiagnosticsProgressDialog extends StatefulWidget {
  final CampusGatewayItem gateway;

  const _GatewayDiagnosticsProgressDialog({required this.gateway});

  @override
  State<_GatewayDiagnosticsProgressDialog> createState() =>
      _GatewayDiagnosticsProgressDialogState();
}

class _GatewayDiagnosticsProgressDialogState
    extends State<_GatewayDiagnosticsProgressDialog> {
  int _step = 0;
  bool _finished = false;

  final List<String> _checks = [
    'ICMP Echo Ping Handshake',
    'MQTT Broker Connection Verification',
    'Modbus Transceiver Loopback Test',
    'Flash Storage & Memory Check',
    'DC Power Rail Stability Audit',
  ];

  @override
  void initState() {
    super.initState();
    _runSteps();
  }

  void _runSteps() async {
    for (int i = 0; i < _checks.length; i++) {
      await Future.delayed(const Duration(milliseconds: 600));
      if (mounted) setState(() => _step = i + 1);
    }
    if (mounted) setState(() => _finished = true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.monitor_heart_outlined, color: Color(0xFF1677F2)),
          const SizedBox(width: 8),
          Expanded(child: Text('Diagnosing ${widget.gateway.gatewayName}')),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                'Executing diagnostics suite on ${widget.gateway.ipAddress}...',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 14),
            ..._checks.asMap().entries.map((e) {
              final idx = e.key;
              final name = e.value;
              final isDone = _step > idx;
              final isCurrent = _step == idx;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    if (isDone)
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF10B981), size: 16)
                    else if (isCurrent)
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      const Icon(Icons.circle_outlined,
                          color: Color(0xFFCBD5E1), size: 16),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(name,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: isDone
                                    ? FontWeight.w600
                                    : FontWeight.normal))),
                    if (isDone)
                      const Text('Passed',
                          style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                  ],
                ),
              );
            }),
            if (_finished) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6)),
                child: const Row(
                  children: [
                    Icon(Icons.verified_rounded,
                        color: Color(0xFF10B981), size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          'All gateway checks passed! Hardware nominal.',
                          style: TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (_finished)
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1677F2),
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
      ],
    );
  }
}

/// Multi-step Add Integration Wizard Dialog
class _AddIntegrationWizardDialog extends StatefulWidget {
  final Function(ThirdPartyIntegrationItem) onCreated;

  const _AddIntegrationWizardDialog({required this.onCreated});

  @override
  State<_AddIntegrationWizardDialog> createState() =>
      _AddIntegrationWizardDialogState();
}

class _AddIntegrationWizardDialogState
    extends State<_AddIntegrationWizardDialog> {
  final _nameCtrl = TextEditingController(text: 'Campus Fire & Alarm System');
  String _type = 'Facility Integration';
  String _protocol = 'Modbus (TCP)';
  final String _provider = 'Honeywell';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.extension_outlined, color: Color(0xFF1677F2)),
          SizedBox(width: 8),
          Text('Add New Integration'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Integration Name',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  border: OutlineInputBorder(), isDense: true),
            ),
            const SizedBox(height: 12),
            const Text('Category / Type',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _type,
              isDense: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(
                    value: 'Facility Integration',
                    child: Text('Facility Integration (BMS / HVAC)')),
                DropdownMenuItem(
                    value: 'Security Integration',
                    child: Text('Security Integration (Access / Locks)')),
                DropdownMenuItem(
                    value: 'Surveillance Integration',
                    child: Text('Surveillance Integration (CCTV / VMS)')),
                DropdownMenuItem(
                    value: 'Energy Integration',
                    child: Text('Energy Integration (Smart Meters)')),
              ],
              onChanged: (v) => setState(() => _type = v!),
            ),
            const SizedBox(height: 12),
            const Text('Communication Protocol',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _protocol,
              isDense: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(
                    value: 'Modbus (TCP)', child: Text('Modbus (TCP)')),
                DropdownMenuItem(value: 'MQTT', child: Text('MQTT Broker')),
                DropdownMenuItem(
                    value: 'HTTP(S) / API', child: Text('HTTP(S) / REST API')),
                DropdownMenuItem(
                    value: 'ONVIF / RTSP', child: Text('ONVIF / RTSP')),
                DropdownMenuItem(value: 'Zigbee', child: Text('Zigbee 3.0')),
              ],
              onChanged: (v) => setState(() => _protocol = v!),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1677F2),
              foregroundColor: Colors.white),
          onPressed: () {
            final item = ThirdPartyIntegrationItem(
              id: 'c1000000-${DateTime.now().millisecondsSinceEpoch}',
              name: _nameCtrl.text.trim(),
              type: _type,
              protocol: _protocol,
              provider: _provider,
              lastSync: 'Just now',
            );
            widget.onCreated(item);
            Navigator.pop(context);
          },
          child: const Text('Save & Activate'),
        ),
      ],
    );
  }
}

/// Multi-step Register Gateway Wizard Dialog
class _RegisterGatewayWizardDialog extends StatefulWidget {
  final Function(CampusGatewayItem) onCreated;

  const _RegisterGatewayWizardDialog({required this.onCreated});

  @override
  State<_RegisterGatewayWizardDialog> createState() =>
      _RegisterGatewayWizardDialogState();
}

class _RegisterGatewayWizardDialogState
    extends State<_RegisterGatewayWizardDialog> {
  final _nameCtrl = TextEditingController(text: 'GW-A09 (Science Block)');
  final _codeCtrl = TextEditingController(text: 'GW-0009');
  final _ipCtrl = TextEditingController(text: '192.168.10.29');
  String _location = 'Science Block';
  final String _protocol = 'MQTT, Modbus';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.router_outlined, color: Color(0xFF10B981)),
          SizedBox(width: 8),
          Text('Register Physical IoT Gateway'),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Gateway Name',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), isDense: true)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Gateway Code',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      TextField(
                          controller: _codeCtrl,
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(), isDense: true)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('IP Address',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      TextField(
                          controller: _ipCtrl,
                          decoration: const InputDecoration(
                              border: OutlineInputBorder(), isDense: true)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text('Location',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            TextField(
              decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  isDense: true,
                  hintText: _location),
              onChanged: (v) => _location = v,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white),
          onPressed: () {
            final gw = CampusGatewayItem(
              id: 'b1000000-${DateTime.now().millisecondsSinceEpoch}',
              gatewayCode: _codeCtrl.text.trim(),
              gatewayName: _nameCtrl.text.trim(),
              ipAddress: _ipCtrl.text.trim(),
              locationPath: _location,
              protocols: _protocol,
              status: 'online',
              isOnline: true,
              connectedDevicesCount: 0,
              uptimeDisplay: '0 days, 00:01:00 (100.0%)',
              firmwareVersion: 'v2.4.0',
              firmwareUpdateAvailable: null,
              lastHeartbeat: 'Just now',
            );
            widget.onCreated(gw);
            Navigator.pop(context);
          },
          child: const Text('Provision & Register'),
        ),
      ],
    );
  }
}

/// Device Discovery Modal Dialog
class _DeviceDiscoveryModalDialog extends StatefulWidget {
  final List<CampusGatewayItem> gateways;
  final List<DiscoveredDeviceItem> discoveredDevices;
  final Function(DiscoveredDeviceItem) onApproved;

  const _DeviceDiscoveryModalDialog({
    required this.gateways,
    required this.discoveredDevices,
    required this.onApproved,
  });

  @override
  State<_DeviceDiscoveryModalDialog> createState() =>
      _DeviceDiscoveryModalDialogState();
}

class _DeviceDiscoveryModalDialogState
    extends State<_DeviceDiscoveryModalDialog> {
  bool _isScanning = false;

  void _triggerScan() async {
    setState(() => _isScanning = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Network scan complete: 4 edge devices discovered!'),
            backgroundColor: Color(0xFF10B981)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.radar_rounded, color: Color(0xFF8B5CF6)),
          const SizedBox(width: 8),
          const Expanded(child: Text('Device Discovery & Auto-Enrollment')),
          if (_isScanning)
            const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            OutlinedButton.icon(
              onPressed: _triggerScan,
              icon: const Icon(Icons.search_rounded, size: 14),
              label: const Text('Scan Mesh', style: TextStyle(fontSize: 11)),
            ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: widget.discoveredDevices.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('No pending discovered devices')),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: widget.discoveredDevices.length,
                separatorBuilder: (_, __) => const Divider(height: 12),
                itemBuilder: (ctx, i) {
                  final dev = widget.discoveredDevices[i];
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color:
                                const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.devices_other_rounded,
                            color: Color(0xFF8B5CF6), size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(dev.deviceName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12.5)),
                            Text(
                                '${dev.deviceType} • ${dev.protocol} • ${dev.ipAddress}',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF64748B))),
                            Text(
                                'Location Suggestion: ${dev.locationSuggestion}',
                                style: const TextStyle(
                                    fontSize: 10.5, color: Color(0xFF1677F2))),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          minimumSize: const Size(60, 30),
                        ),
                        onPressed: () {
                          widget.onApproved(dev);
                        },
                        child: const Text('Approve',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  );
                },
              ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close')),
      ],
    );
  }
}
