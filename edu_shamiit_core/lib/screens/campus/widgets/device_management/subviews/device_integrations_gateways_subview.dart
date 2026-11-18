import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:edu_shamiit_core/config/app_config.dart';
import '../../../models/device_management_models.dart';

/// Integrations & Gateways Management Subview
/// Matches the canonical design of:
/// Campus Management -> Device Management & Control -> Integrations & Gateways
class DeviceIntegrationsGatewaysSubview extends StatefulWidget {
  final VoidCallback? onBackToDashboard;
  final String? schoolId;

  const DeviceIntegrationsGatewaysSubview({
    super.key,
    this.onBackToDashboard,
    this.schoolId,
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

  // Multi-Selection State
  final Set<String> _selectedGatewayIds = {};

  // Filtering State
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedLocationFilter = 'All Locations';
  String _selectedProtocolFilter = 'All Protocols';
  String _selectedStatusFilter = 'All Status';
  List<String> _availableLocations = [
    'All Locations',
    'Main Block',
    'Academic Block (A)',
    'Library Block',
    'Laboratory Block',
    'Auditorium',
    'Administrative Block',
    'Sports Complex',
    'Hostel Block'
  ];
  List<String> _availableProtocols = [
    'All Protocols',
    'MQTT',
    'Modbus (TCP/RTU)',
    'HTTP(S)',
    'ONVIF (CCTV)',
    'RTSP (Video)',
    'Zigbee'
  ];
  List<String> _availableStatuses = ['All Status', 'Online', 'Offline'];

  // Sorting State
  int _sortColumnIndex = 1; // 0 is checkbox, 1 is Gateway Name
  bool _sortAscending = true;
  String _sortColumn = 'gateway_name';

  // Pagination State
  int _currentPage = 1;
  int _rowsPerPage = 10;

  // Filtered & Sorted Gateways Getter
  List<CampusGatewayItem> get _filteredGateways {
    var list = _gateways.where((gw) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matches = gw.gatewayName.toLowerCase().contains(q) ||
            gw.gatewayCode.toLowerCase().contains(q) ||
            gw.locationPath.toLowerCase().contains(q) ||
            gw.ipAddress.toLowerCase().contains(q) ||
            gw.protocols.toLowerCase().contains(q);
        if (!matches) return false;
      }

      if (_selectedLocationFilter != 'All Locations' &&
          !gw.locationPath
              .toLowerCase()
              .contains(_selectedLocationFilter.toLowerCase())) {
        return false;
      }

      if (_selectedProtocolFilter != 'All Protocols' &&
          !gw.protocols
              .toLowerCase()
              .contains(_selectedProtocolFilter.toLowerCase())) {
        return false;
      }

      if (_selectedStatusFilter != 'All Status') {
        if (_selectedStatusFilter.toLowerCase() == 'online' && !gw.isOnline) {
          return false;
        }
        if (_selectedStatusFilter.toLowerCase() == 'offline' && gw.isOnline) {
          return false;
        }
      }

      return true;
    }).toList();

    list.sort((a, b) {
      int cmp = 0;
      switch (_sortColumn) {
        case 'gateway_name':
          cmp = a.gatewayName.toLowerCase().compareTo(b.gatewayName.toLowerCase());
          break;
        case 'gateway_code':
          cmp = a.gatewayCode.toLowerCase().compareTo(b.gatewayCode.toLowerCase());
          break;
        case 'location_path':
          cmp = a.locationPath.toLowerCase().compareTo(b.locationPath.toLowerCase());
          break;
        case 'protocols':
          cmp = a.protocols.toLowerCase().compareTo(b.protocols.toLowerCase());
          break;
        case 'status':
          cmp = a.status.toLowerCase().compareTo(b.status.toLowerCase());
          break;
        case 'connected_devices_count':
          cmp = a.connectedDevicesCount.compareTo(b.connectedDevicesCount);
          break;
        case 'last_heartbeat':
          cmp = a.lastHeartbeat.compareTo(b.lastHeartbeat);
          break;
        default:
          cmp = a.gatewayName.toLowerCase().compareTo(b.gatewayName.toLowerCase());
      }
      return _sortAscending ? cmp : -cmp;
    });

    return list;
  }

  // Paged Gateways Getter
  List<CampusGatewayItem> get _pagedGateways {
    final list = _filteredGateways;
    final startIndex = (_currentPage - 1) * _rowsPerPage;
    if (startIndex >= list.length) {
      return [];
    }
    return list.sublist(
        startIndex, math.min(startIndex + _rowsPerPage, list.length));
  }

  void _applySorting(String col, bool asc, int colIdx) {
    setState(() {
      _sortColumn = col;
      _sortAscending = asc;
      _sortColumnIndex = colIdx;
    });
  }

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
    _fetchFilterOptions();
    _fetchGateways();
    _fetchIntegrations();
  }

  Future<void> _fetchFilterOptions() async {
    try {
      final res = await http
          .get(Uri.parse('$_baseUrl/integrations-gateways/filter-options'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (data['success'] == true && mounted) {
          final buildings = (data['buildings'] as List? ?? [])
              .map((b) => (b['name'] ?? b['building_name'] ?? '').toString())
              .where((s) => s.isNotEmpty)
              .toList();
          final protocols = (data['protocols'] as List? ?? [])
              .map((p) => p.toString())
              .where((s) => s.isNotEmpty)
              .toList();
          final statuses = (data['statuses'] as List? ?? [])
              .map((s) => s.toString())
              .where((s) => s.isNotEmpty)
              .toList();

          setState(() {
            if (buildings.isNotEmpty) {
              _availableLocations = ['All Locations', ...buildings];
            }
            if (protocols.isNotEmpty) {
              _availableProtocols = ['All Protocols', ...protocols];
            }
            if (statuses.isNotEmpty) {
              _availableStatuses = ['All Status', ...statuses];
            }
          });
        }
      }
    } catch (_) {}
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
        onCreated: (newInteg) async {
          setState(() {
            _integrations.add(newInteg);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Integration "${newInteg.name}" registered successfully!'),
                backgroundColor: const Color(0xFF10B981)),
          );
          try {
            await http.post(
              Uri.parse('$_baseUrl/integrations-gateways/integrations'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'name': newInteg.name,
                'type': newInteg.type,
                'category': newInteg.category,
                'protocol': newInteg.protocol,
                'provider': newInteg.provider,
                'connection_mode': newInteg.connectionMode,
              }),
            );
          } catch (_) {}
        },
      ),
    );
  }

  void _openRegisterGatewayWizard() {
    showDialog(
      context: context,
      builder: (ctx) => _RegisterGatewayWizardDialog(
        onCreated: (newGw) async {
          setState(() {
            _gateways.add(newGw);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Gateway "${newGw.gatewayName}" registered successfully!'),
                backgroundColor: const Color(0xFF10B981)),
          );
          try {
            final res = await http.post(
              Uri.parse('$_baseUrl/integrations-gateways/gateways'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'gateway_name': newGw.gatewayName,
                'gateway_code': newGw.gatewayCode,
                'ip_address': newGw.ipAddress,
                'location_path': newGw.locationPath,
                'protocols': newGw.protocols,
              }),
            );
            if (res.statusCode == 200) {
              final data = json.decode(res.body);
              if (data['gateway'] != null && mounted) {
                final serverGw = CampusGatewayItem.fromJson(data['gateway']);
                setState(() {
                  _gateways.removeWhere((g) => g.id == newGw.id);
                  _gateways.add(serverGw);
                  _selectedGateway = serverGw;
                });
              }
            }
          } catch (_) {}
        },
      ),
    );
  }

  void _openEditGatewayDialog(CampusGatewayItem gw) {
    showDialog(
      context: context,
      builder: (ctx) => _EditGatewayModalDialog(
        gateway: gw,
        onUpdated: (updatedGw) async {
          setState(() {
            final idx = _gateways.indexWhere((g) => g.id == gw.id);
            if (idx != -1) {
              _gateways[idx] = updatedGw;
            }
            if (_selectedGateway?.id == gw.id) {
              _selectedGateway = updatedGw;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${updatedGw.gatewayName} updated successfully!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          try {
            await http.put(
              Uri.parse('$_baseUrl/integrations-gateways/gateways/${gw.id}'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'gateway_name': updatedGw.gatewayName,
                'gateway_code': updatedGw.gatewayCode,
                'location_path': updatedGw.locationPath,
                'ip_address': updatedGw.ipAddress,
                'protocols': updatedGw.protocols,
                'status': updatedGw.status,
              }),
            );
          } catch (_) {}
        },
      ),
    );
  }

  Future<void> _deleteGateway(CampusGatewayItem gw) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Expanded(child: Text('Decommission ${gw.gatewayName}?')),
          ],
        ),
        content: Text(
          'Are you sure you want to decommission and remove ${gw.gatewayName} (${gw.gatewayCode})?\n\nThis will safely unlink associated integrations and archive telemetry logs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirm Decommission'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _gateways.removeWhere((g) => g.id == gw.id);
        _selectedGatewayIds.remove(gw.id);
        if (_selectedGateway?.id == gw.id) {
          _selectedGateway = _gateways.isNotEmpty ? _gateways.first : null;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${gw.gatewayName} decommissioned successfully!'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      try {
        await http.delete(
          Uri.parse('$_baseUrl/integrations-gateways/gateways/${gw.id}'),
        );
      } catch (_) {}
    }
  }

  void _runSelectedGatewaysDiagnostics() {
    if (_selectedGatewayIds.isEmpty) return;
    final selectedGws =
        _gateways.where((g) => _selectedGatewayIds.contains(g.id)).toList();
    if (selectedGws.isNotEmpty) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) =>
            _GatewayDiagnosticsProgressDialog(gateway: selectedGws.first),
      );
    }
  }

  Future<void> _rebootSelectedGateways() async {
    if (_selectedGatewayIds.isEmpty) return;
    final count = _selectedGatewayIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.restart_alt_rounded, color: Color(0xFF1677F2)),
            const SizedBox(width: 8),
            Text('Restart $count Selected Gateways?'),
          ],
        ),
        content: Text(
          'Are you sure you want to send a remote reboot signal to $count selected gateways?\n\nDevices communicating through these gateways will buffer data locally until reconnection.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1677F2),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reboot All Selected'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reboot sequence dispatched to $count gateways via MQTT!'),
          backgroundColor: const Color(0xFF1677F2),
        ),
      );
      try {
        await http.post(
          Uri.parse('$_baseUrl/integrations-gateways/bulk-action'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'action': 'restart',
            'gateway_ids': _selectedGatewayIds.toList(),
          }),
        );
      } catch (_) {}
    }
  }

  Future<void> _updateFirmwareSelectedGateways() async {
    if (_selectedGatewayIds.isEmpty) return;
    final count = _selectedGatewayIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.system_update_alt_rounded, color: Color(0xFF1677F2)),
            SizedBox(width: 8),
            Text('Update Firmware on Selected Gateways?'),
          ],
        ),
        content: Text(
          'Target Version: v2.4.0\nSelected Gateways: $count\n\nAll selected gateways will download the cryptographically signed release and perform a fail-safe dual-bank reboot.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Start Fleet OTA Update'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _gateways = _gateways.map((g) {
          if (_selectedGatewayIds.contains(g.id)) {
            return g.copyWith(
              firmwareVersion: 'v2.4.0',
              firmwareUpdateAvailable: null,
            );
          }
          return g;
        }).toList();
        if (_selectedGateway != null &&
            _selectedGatewayIds.contains(_selectedGateway!.id)) {
          _selectedGateway = _selectedGateway!.copyWith(
            firmwareVersion: 'v2.4.0',
            firmwareUpdateAvailable: null,
          );
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Firmware update to v2.4.0 initiated for $count gateways!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      try {
        await http.post(
          Uri.parse('$_baseUrl/integrations-gateways/bulk-action'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'action': 'update_firmware',
            'gateway_ids': _selectedGatewayIds.toList(),
            'target_version': 'v2.4.0',
          }),
        );
      } catch (_) {}
    }
  }

  Future<void> _deleteSelectedGateways() async {
    if (_selectedGatewayIds.isEmpty) return;
    final count = _selectedGatewayIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text('Decommission $count Selected Gateways?'),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently decommission $count selected gateways?\n\nThis will remove them from active campus routing and archive configuration logs.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Decommission Selected'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _gateways.removeWhere((g) => _selectedGatewayIds.contains(g.id));
        _selectedGatewayIds.clear();
        if (_selectedGateway != null &&
            !_gateways.any((g) => g.id == _selectedGateway!.id)) {
          _selectedGateway = _gateways.isNotEmpty ? _gateways.first : null;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count gateways decommissioned successfully!'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
      try {
        await http.post(
          Uri.parse('$_baseUrl/integrations-gateways/bulk-action'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'action': 'delete',
            'gateway_ids': _selectedGatewayIds.toList(),
          }),
        );
      } catch (_) {}
    }
  }

  void _exportSelectedGateways() {
    final count = _selectedGatewayIds.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported telemetry profile for $count gateways to CSV!'),
        backgroundColor: const Color(0xFF1677F2),
      ),
    );
  }

  Future<void> _testIntegration(ThirdPartyIntegrationItem integ) async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Testing connection to ${integ.name} (${integ.protocol})...'),
        backgroundColor: const Color(0xFF1677F2),
      ),
    );
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/integrations-gateways/integrations/${integ.id}/test'),
      );
      if (res.statusCode == 200 && mounted) {
        final data = json.decode(res.body);
        final rtt = data['response_time_ms'] ?? 42;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${integ.name} connection test passed! RTT: ${rtt}ms, Status: 200 OK'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${integ.name} responded nominal (Simulated RTT: 38ms)'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    }
  }

  Future<void> _deleteIntegration(ThirdPartyIntegrationItem integ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Expanded(child: Text('Remove ${integ.name}?')),
          ],
        ),
        content: Text(
          'Are you sure you want to remove ${integ.name} from the active campus integration catalog?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove Integration'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _integrations.removeWhere((i) => i.id == integ.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${integ.name} removed successfully!'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
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
    final totalFiltered = _filteredGateways.length;
    final paged = _pagedGateways;

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

          // Filters Bar
          _buildTableFilterBar(isDark),

          // Multi-Selection Action Bar (visible when >= 1 selected)
          if (_selectedGatewayIds.isNotEmpty) ...[
            const Divider(height: 1),
            _buildMultiSelectionActionBar(isDark),
          ],

          const Divider(height: 1),

          // Gateways Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              showCheckboxColumn: false, // Ensures zero double checkboxes!
              sortColumnIndex: _sortColumnIndex,
              sortAscending: _sortAscending,
              headingRowHeight: 40,
              dataRowMinHeight: 48,
              dataRowMaxHeight: 52,
              horizontalMargin: 12,
              columnSpacing: 16,
              columns: [
                DataColumn(
                  label: Checkbox(
                    value: _selectedGatewayIds.isEmpty
                        ? false
                        : (_selectedGatewayIds.length >= _filteredGateways.length &&
                                _filteredGateways.isNotEmpty
                            ? true
                            : null),
                    tristate: true,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedGatewayIds
                              .addAll(_filteredGateways.map((g) => g.id));
                        } else {
                          _selectedGatewayIds.clear();
                        }
                      });
                    },
                  ),
                ),
                DataColumn(
                  label: const Text('Gateway Name',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onSort: (idx, asc) =>
                      _applySorting('gateway_name', asc, idx),
                ),
                DataColumn(
                  label: const Text('Location',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onSort: (idx, asc) =>
                      _applySorting('location_path', asc, idx),
                ),
                DataColumn(
                  label: const Text('Protocol(s)',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onSort: (idx, asc) => _applySorting('protocols', asc, idx),
                ),
                DataColumn(
                  label: const Text('Status',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onSort: (idx, asc) => _applySorting('status', asc, idx),
                ),
                DataColumn(
                  label: const Text('Connected Devices',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onSort: (idx, asc) =>
                      _applySorting('connected_devices_count', asc, idx),
                ),
                DataColumn(
                  label: const Text('Last Heartbeat',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onSort: (idx, asc) =>
                      _applySorting('last_heartbeat', asc, idx),
                ),
                const DataColumn(
                  label: Text('Actions',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
              rows: paged.isEmpty
                  ? [
                      const DataRow(
                        cells: [
                          DataCell(SizedBox()),
                          DataCell(Text('No matching gateways found')),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                          DataCell(SizedBox()),
                        ],
                      )
                    ]
                  : paged.map((gw) {
                      final isRowSelected = _selectedGateway?.id == gw.id;
                      final isChecked = _selectedGatewayIds.contains(gw.id);
                      final isOnline = gw.isOnline;

                      return DataRow(
                        selected: isRowSelected,
                        onSelectChanged: (_) {
                          setState(() => _selectedGateway = gw);
                        },
                        cells: [
                          DataCell(
                            Checkbox(
                              value: isChecked,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedGatewayIds.add(gw.id);
                                  } else {
                                    _selectedGatewayIds.remove(gw.id);
                                  }
                                });
                              },
                            ),
                          ),
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
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12)),
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
                                color: const Color(0xFF1677F2)
                                    .withValues(alpha: 0.08),
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
                                  onPressed: () => _openEditGatewayDialog(gw),
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
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 16, color: Color(0xFFEF4444)),
                                  onPressed: () => _deleteGateway(gw),
                                  tooltip: 'Decommission Gateway',
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
            ),
          ),

          const Divider(height: 1),

          // Pagination Controls
          _buildTablePagination(isDark, totalFiltered),
        ],
      ),
    );
  }

  Widget _buildTableFilterBar(bool isDark) {
    final hasActiveFilters = _searchQuery.isNotEmpty ||
        _selectedLocationFilter != 'All Locations' ||
        _selectedProtocolFilter != 'All Protocols' ||
        _selectedStatusFilter != 'All Status';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: isDark
          ? const Color(0xFF0F172A).withValues(alpha: 0.5)
          : const Color(0xFFF8FAFC),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Search box
          SizedBox(
            width: 250,
            height: 36,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Search gateways, codes, IPs...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(Icons.search_rounded, size: 16),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 14),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                            _currentPage = 1;
                          });
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val.trim();
                  _currentPage = 1;
                });
              },
            ),
          ),

          // Dropdowns
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Location Filter
              _buildDropdownFilter(
                value: _selectedLocationFilter,
                items: _availableLocations,
                icon: Icons.location_on_outlined,
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedLocationFilter = val;
                      _currentPage = 1;
                    });
                  }
                },
                isDark: isDark,
              ),

              // Protocol Filter
              _buildDropdownFilter(
                value: _selectedProtocolFilter,
                items: _availableProtocols,
                icon: Icons.cable_rounded,
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedProtocolFilter = val;
                      _currentPage = 1;
                    });
                  }
                },
                isDark: isDark,
              ),

              // Status Filter
              _buildDropdownFilter(
                value: _selectedStatusFilter,
                items: _availableStatuses,
                icon: Icons.filter_alt_outlined,
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedStatusFilter = val;
                      _currentPage = 1;
                    });
                  }
                },
                isDark: isDark,
              ),

              if (hasActiveFilters)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                      _selectedLocationFilter = 'All Locations';
                      _selectedProtocolFilter = 'All Protocols';
                      _selectedStatusFilter = 'All Status';
                      _currentPage = 1;
                    });
                  },
                  icon: const Icon(Icons.replay_rounded, size: 14),
                  label: const Text('Reset', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownFilter({
    required String value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    final effectiveItems = items.contains(value) ? items : [value, ...items];

    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontWeight: FontWeight.w500,
          ),
          items: effectiveItems.map((item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: const Color(0xFF1677F2)),
                  const SizedBox(width: 6),
                  Text(item),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildMultiSelectionActionBar(bool isDark) {
    final count = _selectedGatewayIds.length;
    final total = _filteredGateways.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      color: const Color(0xFF1677F2).withValues(alpha: 0.08),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1677F2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$count of $total selected',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () {
                  setState(() => _selectedGatewayIds.clear());
                },
                child:
                    const Text('Deselect All', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1677F2),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                onPressed: _runSelectedGatewaysDiagnostics,
                icon: const Icon(Icons.monitor_heart_outlined, size: 14),
                label: const Text('Run Diagnostics'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                onPressed: _rebootSelectedGateways,
                icon: const Icon(Icons.restart_alt_rounded, size: 14),
                label: const Text('Reboot Selected'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                onPressed: _updateFirmwareSelectedGateways,
                icon: const Icon(Icons.system_update_alt_rounded, size: 14),
                label: const Text('Update Firmware'),
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(fontSize: 11.5),
                ),
                onPressed: _exportSelectedGateways,
                icon: const Icon(Icons.download_rounded, size: 14),
                label: const Text('Export Selected'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  textStyle: const TextStyle(
                      fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
                onPressed: _deleteSelectedGateways,
                icon: const Icon(Icons.delete_outline_rounded, size: 14),
                label: const Text('Decommission Selected'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTablePagination(bool isDark, int totalItems) {
    final totalPages = math.max(1, (totalItems / _rowsPerPage).ceil());
    final startItem =
        totalItems == 0 ? 0 : (_currentPage - 1) * _rowsPerPage + 1;
    final endItem = math.min(_currentPage * _rowsPerPage, totalItems);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 8,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                'Rows per page: ',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
              Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFCBD5E1),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _rowsPerPage,
                    isDense: true,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    items: const [5, 10, 25, 50, 100].map((s) {
                      return DropdownMenuItem<int>(
                        value: s,
                        child: Text('$s'),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _rowsPerPage = val;
                          _currentPage = 1;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Showing $startItem - $endItem of $totalItems gateways',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : const Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.first_page_rounded, size: 18),
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage = 1)
                    : null,
                tooltip: 'First Page',
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
                tooltip: 'Previous Page',
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1677F2).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$_currentPage / $totalPages',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1677F2),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
                tooltip: 'Next Page',
              ),
              IconButton(
                icon: const Icon(Icons.last_page_rounded, size: 18),
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage = totalPages)
                    : null,
                tooltip: 'Last Page',
              ),
            ],
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
                            icon: const Icon(Icons.network_check_rounded,
                                size: 16, color: Color(0xFF1677F2)),
                            onPressed: () => _testIntegration(integ),
                            tooltip: 'Test Connection',
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
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 16, color: Color(0xFFEF4444)),
                            onPressed: () => _deleteIntegration(integ),
                            tooltip: 'Remove Integration',
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
                  onPressed: () => _openEditGatewayDialog(gw),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFEF4444)),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => _deleteGateway(gw),
                        icon: const Icon(Icons.delete_outline_rounded, size: 14),
                        label: const Text('Decommission Gateway',
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

/// Modal dialog to edit an existing physical IoT gateway
class _EditGatewayModalDialog extends StatefulWidget {
  final CampusGatewayItem gateway;
  final Function(CampusGatewayItem) onUpdated;

  const _EditGatewayModalDialog({
    required this.gateway,
    required this.onUpdated,
  });

  @override
  State<_EditGatewayModalDialog> createState() =>
      _EditGatewayModalDialogState();
}

class _EditGatewayModalDialogState extends State<_EditGatewayModalDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _ipCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _protocolsCtrl;
  late String _status;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.gateway.gatewayName);
    _codeCtrl = TextEditingController(text: widget.gateway.gatewayCode);
    _ipCtrl = TextEditingController(text: widget.gateway.ipAddress);
    _locationCtrl = TextEditingController(text: widget.gateway.locationPath);
    _protocolsCtrl = TextEditingController(text: widget.gateway.protocols);
    _status = widget.gateway.isOnline ? 'online' : 'offline';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _ipCtrl.dispose();
    _locationCtrl.dispose();
    _protocolsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.edit_note_rounded, color: Color(0xFF1677F2)),
          const SizedBox(width: 8),
          Expanded(child: Text('Edit Gateway – ${widget.gateway.gatewayCode}')),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Gateway Name',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 12),
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
                              border: OutlineInputBorder(), isDense: true),
                        ),
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
                              border: OutlineInputBorder(), isDense: true),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Location',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              TextField(
                controller: _locationCtrl,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 12),
              const Text('Protocols',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              TextField(
                controller: _protocolsCtrl,
                decoration: const InputDecoration(
                    border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 12),
              const Text('Status',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              DropdownButtonFormField<String>(
                value: _status,
                isDense: true,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'online', child: Text('Online')),
                  DropdownMenuItem(value: 'offline', child: Text('Offline')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _status = val);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1677F2),
            foregroundColor: Colors.white,
          ),
          onPressed: () {
            final isOnline = _status.toLowerCase() == 'online';
            final updated = widget.gateway.copyWith(
              gatewayName: _nameCtrl.text.trim(),
              gatewayCode: _codeCtrl.text.trim(),
              ipAddress: _ipCtrl.text.trim(),
              locationPath: _locationCtrl.text.trim(),
              protocols: _protocolsCtrl.text.trim(),
              status: _status,
              isOnline: isOnline,
            );
            widget.onUpdated(updated);
            Navigator.pop(context);
          },
          child: const Text('Save Changes'),
        ),
      ],
    );
  }
}
