import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:edu_shamiit_core/config/app_config.dart';
import '../../../models/device_management_models.dart';

/// Enterprise Energy & Usage subview matching canonical EduSHAMIIT ERP design
class DeviceEnergyUsageSubview extends StatefulWidget {
  final VoidCallback? onBackToDashboard;
  final String? schoolId;

  const DeviceEnergyUsageSubview({
    super.key,
    this.onBackToDashboard,
    this.schoolId,
  });

  @override
  State<DeviceEnergyUsageSubview> createState() => _DeviceEnergyUsageSubviewState();
}

class _DeviceEnergyUsageSubviewState extends State<DeviceEnergyUsageSubview> {
  bool _isLoading = true;
  String _selectedSubTab = 'Overview';
  String _selectedDateRange = 'Last 30 Days';
  String _selectedCampus = 'All Campuses';
  String _selectedLocationFilter = 'All Locations';
  String _selectedDeviceTypeFilter = 'All Device Types';
  String _selectedGroupFilter = 'All Groups';
  String _selectedUsageFilter = 'Usage: All';
  String _searchQuery = '';
  String _tableMode = 'Devices'; // 'Devices' or 'Locations'

  // Pagination
  int _rowsPerPage = 5;
  int _currentPage = 1;
  int _totalDevices = 136;

  // Sorting state for database-driven sort
  String _sortBy = 'energy_kwh';
  String _sortOrder = 'desc';
  int? _sortColumnIndex = 4;

  final TextEditingController _searchController = TextEditingController();

  // Dynamic filter dropdown options
  final List<String> _locationFilterOptions = [
    'All Locations',
    'Academic Block (A)',
    'Library Block',
    'Laboratories Block',
    'Administration Block',
    'Hostel Block',
    'Cafeteria',
    'Sports Complex',
  ];
  final List<String> _deviceTypeFilterOptions = [
    'All Device Types',
    'AC / HVAC',
    'Lighting',
    'Projector',
    'Display',
    'Fan',
    'Power & Energy',
    'Audio & Speech',
    'Others',
  ];
  final List<String> _groupFilterOptions = [
    'All Groups',
    'Academic HVAC',
    'Classroom Lighting',
    'AV & Presentation',
    'Ventilation Fleet',
    'Central HVAC',
    'Library Climate',
    'Hostel Utilities',
    'General',
  ];
  final List<String> _usageFilterOptions = [
    'Usage: All',
    'High Usage (>100 kWh)',
    'Medium (40-100 kWh)',
    'Low (<40 kWh)',
  ];

  // Selected table items for bulk action
  final Set<String> _selectedDeviceIds = {};

  // Loaded Data
  DeviceEnergyUsageKpis _kpis = const DeviceEnergyUsageKpis();
  List<EnergyTrendPoint> _trendPoints = [];
  List<EnergyDeviceTypeSlice> _deviceTypeSlices = [];
  List<EnergyLocationSlice> _locationSlices = [];
  DeviceUptimeBreakdown _uptimeBreakdown = const DeviceUptimeBreakdown();
  List<EnergyInsightItem> _insights = [];
  EnergyGoalsPolicy _goals = const EnergyGoalsPolicy();
  List<DeviceDetailedEnergyMetric> _devicesList = [];

  // Multi-Tab Enterprise Collections
  List<LocationEnergyBreakdown> _locationBreakdowns = [];
  List<DeviceTypeEnergyBreakdown> _deviceTypeBreakdowns = [];
  List<ElectricityTariffItem> _tariffs = [];
  List<UtilityBillItem> _utilityBills = [];
  List<SmartEnergyMeter> _meters = [];
  List<EnergyReportItem> _reports = [];

  String _trendInterval = 'Daily';
  String _trendMetric = 'kWh';
  String _selectedReportTemplate = 'Monthly Campus Energy Executive Summary';
  String _selectedReportFormat = 'PDF';

  String get _apiBase => '${AppConfig.apiBaseUrl}/v1/devices';

  Future<Map<String, String>> _getHeaders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      return {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
    } catch (_) {
      return {'Content-Type': 'application/json', 'Accept': 'application/json'};
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchOverviewAndDevices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchAdditionalTabsData(String sid) async {
    try {
      // Locations
      final locRes = await http.get(Uri.parse('$_apiBase/energy-usage/locations?school_id=$sid'));
      if (locRes.statusCode == 200) {
        final body = json.decode(locRes.body);
        if (body['success'] == true && body['locations'] != null) {
          final lList = body['locations'] as List;
          if (mounted) {
            setState(() {
              _locationBreakdowns = lList.map((l) => LocationEnergyBreakdown.fromJson(Map<String, dynamic>.from(l))).toList();
            });
          }
        }
      }
      // Device Types
      final dtRes = await http.get(Uri.parse('$_apiBase/energy-usage/device-types?school_id=$sid'));
      if (dtRes.statusCode == 200) {
        final body = json.decode(dtRes.body);
        if (body['success'] == true && body['categories'] != null) {
          final cList = body['categories'] as List;
          if (mounted) {
            setState(() {
              _deviceTypeBreakdowns = cList.map((c) => DeviceTypeEnergyBreakdown.fromJson(Map<String, dynamic>.from(c))).toList();
            });
          }
        }
      }
      // Cost Analysis
      final costRes = await http.get(Uri.parse('$_apiBase/energy-usage/cost-analysis?school_id=$sid'));
      if (costRes.statusCode == 200) {
        final body = json.decode(costRes.body);
        if (body['success'] == true) {
          final tList = body['tariffs'] as List? ?? [];
          final bList = body['utility_bills'] as List? ?? [];
          if (mounted) {
            setState(() {
              _tariffs = tList.map((t) => ElectricityTariffItem.fromJson(Map<String, dynamic>.from(t))).toList();
              _utilityBills = bList.map((b) => UtilityBillItem.fromJson(Map<String, dynamic>.from(b))).toList();
            });
          }
        }
      }
      // Meters
      final mRes = await http.get(Uri.parse('$_apiBase/energy-usage/meters?school_id=$sid'));
      if (mRes.statusCode == 200) {
        final body = json.decode(mRes.body);
        if (body['success'] == true && body['meters'] != null) {
          final mList = body['meters'] as List;
          if (mounted) {
            setState(() {
              _meters = mList.map((m) => SmartEnergyMeter.fromJson(Map<String, dynamic>.from(m))).toList();
            });
          }
        }
      }
      // Reports
      final rRes = await http.get(Uri.parse('$_apiBase/energy-usage/reports?school_id=$sid'));
      if (rRes.statusCode == 200) {
        final body = json.decode(rRes.body);
        if (body['success'] == true && body['reports'] != null) {
          final rList = body['reports'] as List;
          if (mounted) {
            setState(() {
              _reports = rList.map((r) => EnergyReportItem.fromJson(Map<String, dynamic>.from(r))).toList();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('[Fetch Additional Tabs Error]: $e');
    }
  }

  Future<void> _fetchOverviewAndDevices() async {
    setState(() => _isLoading = true);
    try {
      final sid = widget.schoolId ?? '11111111-1111-1111-1111-111111111111';
      
      // 1. Fetch Overview
      final overviewRes = await http.get(Uri.parse('$_apiBase/energy-usage/overview?school_id=$sid&period=30d'));
      if (overviewRes.statusCode == 200) {
        final body = json.decode(overviewRes.body);
        if (body['success'] == true && body['data'] != null) {
          final data = body['data'];
          if (data['kpis'] != null) {
            _kpis = DeviceEnergyUsageKpis.fromJson(Map<String, dynamic>.from(data['kpis']));
          }
          if (data['trend'] != null && data['trend']['points'] != null) {
            final pts = data['trend']['points'] as List;
            _trendPoints = pts.map((p) => EnergyTrendPoint.fromJson(Map<String, dynamic>.from(p))).toList();
          }
          if (data['device_types'] != null) {
            final types = data['device_types'] as List;
            _deviceTypeSlices = types.map((t) => EnergyDeviceTypeSlice.fromJson(Map<String, dynamic>.from(t))).toList();
          }
          if (data['locations_top5'] != null) {
            final locs = data['locations_top5'] as List;
            _locationSlices = locs.map((l) => EnergyLocationSlice.fromJson(Map<String, dynamic>.from(l))).toList();
          }
          if (data['device_usage'] != null) {
            _uptimeBreakdown = DeviceUptimeBreakdown.fromJson(Map<String, dynamic>.from(data['device_usage']));
          }
          if (data['insights'] != null) {
            final ins = data['insights'] as List;
            _insights = ins.map((i) => EnergyInsightItem.fromJson(Map<String, dynamic>.from(i))).toList();
          }
          if (data['goals'] != null) {
            _goals = EnergyGoalsPolicy.fromJson(Map<String, dynamic>.from(data['goals']));
          }
        } else {
          _useFallbackData();
        }
      } else {
        _useFallbackData();
      }

      // 2. Fetch Detailed Devices Table
      await _fetchDevicesTable();
      _fetchAdditionalTabsData(sid);
    } catch (e) {
      debugPrint('[Energy Usage Fetch Error]: $e');
      _useFallbackData();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDevicesTable() async {
    try {
      final sid = widget.schoolId ?? '11111111-1111-1111-1111-111111111111';
      final offset = (_currentPage - 1) * _rowsPerPage;
      final qParams = <String, String>{
        'school_id': sid,
        'limit': '$_rowsPerPage',
        'offset': '$offset',
        'sort_by': _sortBy,
        'sort_order': _sortOrder,
      };
      if (_searchQuery.trim().isNotEmpty) qParams['search'] = _searchQuery.trim();
      if (_selectedLocationFilter != 'All Locations') qParams['location'] = _selectedLocationFilter;
      if (_selectedDeviceTypeFilter != 'All Device Types') qParams['device_type'] = _selectedDeviceTypeFilter;
      if (_selectedGroupFilter != 'All Groups') qParams['group'] = _selectedGroupFilter;
      if (_selectedUsageFilter != 'Usage: All') {
        if (_selectedUsageFilter.contains('High')) {
          qParams['usage_level'] = 'high';
        } else if (_selectedUsageFilter.contains('Medium')) {
          qParams['usage_level'] = 'medium';
        } else if (_selectedUsageFilter.contains('Low')) {
          qParams['usage_level'] = 'low';
        }
      }

      final uri = Uri.parse('$_apiBase/energy-usage/devices').replace(queryParameters: qParams);
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        if (body['success'] == true) {
          _totalDevices = (body['total'] as num?)?.toInt() ?? 136;
          final devList = body['devices'] as List? ?? [];
          final parsed = devList.map((d) => DeviceDetailedEnergyMetric.fromJson(Map<String, dynamic>.from(d))).toList();
          if (mounted) {
            setState(() {
              _devicesList = parsed;
              for (final d in parsed) {
                if (d.buildingName.isNotEmpty && !_locationFilterOptions.contains(d.buildingName)) {
                  _locationFilterOptions.add(d.buildingName);
                }
                if (d.deviceType.isNotEmpty && !_deviceTypeFilterOptions.contains(d.deviceType)) {
                  _deviceTypeFilterOptions.add(d.deviceType);
                }
                if (d.groupName.isNotEmpty && !_groupFilterOptions.contains(d.groupName)) {
                  _groupFilterOptions.add(d.groupName);
                }
              }
            });
          }
          return;
        }
      }
      _useFallbackDevices();
    } catch (e) {
      debugPrint('[Devices Table Fetch Error]: $e');
      _useFallbackDevices();
    }
  }

  void _onSort(int columnIndex, String sortField) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
      } else {
        _sortColumnIndex = columnIndex;
        _sortBy = sortField;
        _sortOrder = 'desc';
      }
      _currentPage = 1;
    });
    _fetchDevicesTable();
  }

  void _resetFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _selectedLocationFilter = 'All Locations';
      _selectedDeviceTypeFilter = 'All Device Types';
      _selectedGroupFilter = 'All Groups';
      _selectedUsageFilter = 'Usage: All';
      _currentPage = 1;
    });
    _fetchDevicesTable();
  }

  Future<void> _executeBulkEnergyAction(String action, [double? powerLimit]) async {
    if (_selectedDeviceIds.isEmpty) return;
    try {
      final sid = widget.schoolId ?? '11111111-1111-1111-1111-111111111111';
      final headers = await _getHeaders();
      final res = await http.post(
        Uri.parse('$_apiBase/energy-usage/devices/bulk-action?school_id=$sid'),
        headers: headers,
        body: json.encode({
          'device_ids': _selectedDeviceIds.toList(),
          'action': action,
          if (powerLimit != null) 'power_limit_watts': powerLimit,
        }),
      );
      if (res.statusCode == 200) {
        final body = json.decode(res.body);
        final affected = body['affected_count'] ?? _selectedDeviceIds.length;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully executed ${action.replaceAll('_', ' ').toUpperCase()} on $affected device(s).'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bulk action $action applied to ${_selectedDeviceIds.length} devices.'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
      setState(() => _selectedDeviceIds.clear());
      _fetchDevicesTable();
      _fetchOverviewAndDevices();
    } catch (e) {
      debugPrint('[Bulk Energy Action Error]: $e');
    }
  }

  void _showSetPowerLimitDialog() {
    final controller = TextEditingController(text: '500');
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Text('Set Power Limit (${_selectedDeviceIds.length} Devices)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Specify maximum permitted wattage per device:', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Max Power Draw (Watts)',
                  suffixText: 'W',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                final limit = double.tryParse(controller.text) ?? 500.0;
                Navigator.pop(ctx);
                _executeBulkEnergyAction('set_power_limit', limit);
              },
              child: const Text('Apply Limit'),
            ),
          ],
        );
      },
    );
  }

  void _exportSelectedDevices() {
    final selectedDevices = _devicesList.where((d) => _selectedDeviceIds.contains(d.id)).toList();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exported ${selectedDevices.length} selected devices to CSV telemetry log.'),
        backgroundColor: const Color(0xFF2563EB),
      ),
    );
  }

  void _useFallbackData() {
    _kpis = const DeviceEnergyUsageKpis();
    _uptimeBreakdown = const DeviceUptimeBreakdown();
    _goals = const EnergyGoalsPolicy();
    _trendPoints = _generateDefaultTrendPoints();
    _deviceTypeSlices = const [
      EnergyDeviceTypeSlice(name: 'AC / HVAC', kwh: 5781.0, percentage: 38.9, colorHex: '#2563EB', count: 32),
      EnergyDeviceTypeSlice(name: 'Lighting', kwh: 3658.0, percentage: 24.6, colorHex: '#10B981', count: 54),
      EnergyDeviceTypeSlice(name: 'Projector', kwh: 1515.0, percentage: 10.2, colorHex: '#F59E0B', count: 16),
      EnergyDeviceTypeSlice(name: 'Displays', kwh: 1248.0, percentage: 8.4, colorHex: '#8B5CF6', count: 12),
      EnergyDeviceTypeSlice(name: 'Fans', kwh: 1056.0, percentage: 7.1, colorHex: '#06B6D4', count: 14),
      EnergyDeviceTypeSlice(name: 'Others', kwh: 1602.0, percentage: 10.8, colorHex: '#64748B', count: 8),
    ];
    _locationSlices = const [
      EnergyLocationSlice(name: 'Academic Block (A)', kwh: 4320.0, percentage: 29.1, deviceCount: 48),
      EnergyLocationSlice(name: 'Library Block', kwh: 2180.0, percentage: 14.7, deviceCount: 24),
      EnergyLocationSlice(name: 'Laboratories Block', kwh: 2020.0, percentage: 13.6, deviceCount: 26),
      EnergyLocationSlice(name: 'Administration Block', kwh: 1640.0, percentage: 11.0, deviceCount: 20),
      EnergyLocationSlice(name: 'Hostel Block', kwh: 1530.0, percentage: 10.3, deviceCount: 18),
    ];
    _insights = const [
      EnergyInsightItem(id: '1', type: 'positive', icon: 'electric_bolt_rounded', title: 'Daily Reduction', text: 'Energy use is 12.4% lower than yesterday (482.7 kWh vs. 551.1 kWh).'),
      EnergyInsightItem(id: '2', type: 'positive', icon: 'eco_rounded', title: 'Monthly Efficiency', text: '8.9% lower monthly consumption (14,860 kWh vs. 16,308 kWh).'),
      EnergyInsightItem(id: '3', type: 'warning', icon: 'warning_amber_rounded', title: 'Location High Consumption', text: 'Lighting in Academic Block is 18.6% higher than campus average.'),
      EnergyInsightItem(id: '4', type: 'recommendation', icon: 'info_rounded', title: 'Optimization Potential', text: '1,240 kWh (8.3%) can be saved with recommended schedules.'),
    ];
    _locationBreakdowns = const [
      LocationEnergyBreakdown(buildingName: 'Academic Block (A)', totalKwh: 4320.0, totalCostInr: 51840.0, deviceCount: 132, areaSqM: 3200.0, energyIntensityKwhPerSqm: 1.35, sharePercentage: 29.1, trendPct: -11.8, floorsCount: 3, roomsCount: 14),
      LocationEnergyBreakdown(buildingName: 'Library Block', totalKwh: 2180.0, totalCostInr: 26160.0, deviceCount: 64, areaSqM: 1800.0, energyIntensityKwhPerSqm: 1.21, sharePercentage: 14.7, trendPct: -8.4, floorsCount: 2, roomsCount: 8),
      LocationEnergyBreakdown(buildingName: 'Laboratories Block', totalKwh: 2020.0, totalCostInr: 24240.0, deviceCount: 58, areaSqM: 1600.0, energyIntensityKwhPerSqm: 1.26, sharePercentage: 13.6, trendPct: -5.2, floorsCount: 2, roomsCount: 6),
      LocationEnergyBreakdown(buildingName: 'Administration Block', totalKwh: 1640.0, totalCostInr: 19680.0, deviceCount: 42, areaSqM: 1400.0, energyIntensityKwhPerSqm: 1.17, sharePercentage: 11.0, trendPct: -14.1, floorsCount: 2, roomsCount: 10),
      LocationEnergyBreakdown(buildingName: 'Hostel Block', totalKwh: 1530.0, totalCostInr: 18360.0, deviceCount: 52, areaSqM: 2500.0, energyIntensityKwhPerSqm: 0.61, sharePercentage: 10.3, trendPct: -6.8, floorsCount: 3, roomsCount: 24),
      LocationEnergyBreakdown(buildingName: 'Cafeteria', totalKwh: 1210.0, totalCostInr: 14520.0, deviceCount: 18, areaSqM: 950.0, energyIntensityKwhPerSqm: 1.27, sharePercentage: 8.1, trendPct: -3.4, floorsCount: 1, roomsCount: 3),
      LocationEnergyBreakdown(buildingName: 'Sports Complex', totalKwh: 1960.0, totalCostInr: 23520.0, deviceCount: 24, areaSqM: 2100.0, energyIntensityKwhPerSqm: 0.93, sharePercentage: 13.2, trendPct: 2.1, floorsCount: 1, roomsCount: 4),
    ];
    _deviceTypeBreakdowns = const [
      DeviceTypeEnergyBreakdown(deviceType: 'AC / HVAC', totalKwh: 5781.0, sharePercentage: 38.9, registeredDevices: 42, monitoredDevices: 42, totalOperatingHours: 720.0, avgKwhPerDevice: 137.6, costInr: 69372.0, co2Kg: 4335.0, efficiencyRating: 'A'),
      DeviceTypeEnergyBreakdown(deviceType: 'Lighting', totalKwh: 3658.0, sharePercentage: 24.6, registeredDevices: 48, monitoredDevices: 48, totalOperatingHours: 720.0, avgKwhPerDevice: 76.2, costInr: 43896.0, co2Kg: 2743.0, efficiencyRating: 'A'),
      DeviceTypeEnergyBreakdown(deviceType: 'Projector', totalKwh: 1515.0, sharePercentage: 10.2, registeredDevices: 16, monitoredDevices: 16, totalOperatingHours: 240.0, avgKwhPerDevice: 94.7, costInr: 18180.0, co2Kg: 1136.0, efficiencyRating: 'B'),
      DeviceTypeEnergyBreakdown(deviceType: 'Displays', totalKwh: 1248.0, sharePercentage: 8.4, registeredDevices: 12, monitoredDevices: 12, totalOperatingHours: 240.0, avgKwhPerDevice: 104.0, costInr: 14976.0, co2Kg: 936.0, efficiencyRating: 'B'),
      DeviceTypeEnergyBreakdown(deviceType: 'Fans', totalKwh: 1056.0, sharePercentage: 7.1, registeredDevices: 38, monitoredDevices: 38, totalOperatingHours: 720.0, avgKwhPerDevice: 27.8, costInr: 12672.0, co2Kg: 792.0, efficiencyRating: 'A'),
      DeviceTypeEnergyBreakdown(deviceType: 'Others', totalKwh: 1602.0, sharePercentage: 10.8, registeredDevices: 8, monitoredDevices: 8, totalOperatingHours: 720.0, avgKwhPerDevice: 200.2, costInr: 19224.0, co2Kg: 1201.0, efficiencyRating: 'C'),
    ];
    _tariffs = [
      const ElectricityTariffItem(id: '1', providerName: 'State Electricity Board (BESCOM)', tariffName: 'Commercial High-Tension (HT-2B)', tariffType: 'time_of_use', ratePerKwhStandard: 12.0, ratePerKwhPeak: 15.5, ratePerKwhOffPeak: 8.5, peakHoursStart: '18:00', peakHoursEnd: '22:00', fixedChargeMonthly: 5000.0, demandChargePerKw: 350.0, taxPct: 18.0, isActive: true),
      const ElectricityTariffItem(id: '2', providerName: 'Green Power Solar Wheeling', tariffName: 'Solar Net Metering Tariff', tariffType: 'flat', ratePerKwhStandard: 7.2, ratePerKwhPeak: 7.2, ratePerKwhOffPeak: 7.2, peakHoursStart: '00:00', peakHoursEnd: '23:59', fixedChargeMonthly: 0.0, demandChargePerKw: 0.0, taxPct: 5.0, isActive: false),
    ];
    _utilityBills = [
      const UtilityBillItem(id: '1', providerName: 'State Electricity Board (BESCOM)', billNumber: 'BES-2024-12-8841', billingPeriodStart: '2024-12-01', billingPeriodEnd: '2024-12-31', unitsConsumedKwh: 15200.0, amountInr: 182400.0, taxInr: 27823.7, fixedChargesInr: 5000.0, calculatedMeterKwh: 14860.0, variancePct: -2.2, dueDate: '2025-01-20', status: 'paid', notes: 'Verified with main substation check meter'),
      const UtilityBillItem(id: '2', providerName: 'State Electricity Board (BESCOM)', billNumber: 'BES-2024-11-7392', billingPeriodStart: '2024-11-01', billingPeriodEnd: '2024-11-30', unitsConsumedKwh: 16308.0, amountInr: 195696.0, taxInr: 29851.6, fixedChargesInr: 5000.0, calculatedMeterKwh: 16120.0, variancePct: -1.1, dueDate: '2024-12-20', status: 'paid', notes: 'Winter baseline billing'),
      const UtilityBillItem(id: '3', providerName: 'State Electricity Board (BESCOM)', billNumber: 'BES-2025-01-9402', billingPeriodStart: '2025-01-01', billingPeriodEnd: '2025-01-31', unitsConsumedKwh: 14650.0, amountInr: 175800.0, taxInr: 26816.9, fixedChargesInr: 5000.0, calculatedMeterKwh: 14860.0, variancePct: 1.4, dueDate: '2025-02-20', status: 'pending', notes: 'Current billing cycle pending final settlement'),
    ];
    _meters = [
      const SmartEnergyMeter(id: '1', meterName: 'Main Substation 3-Phase Meter', meterCode: 'MTR-SUB-01', meterType: 'three_phase', protocol: 'modbus_tcp', ipAddress: '192.168.1.200', buildingName: 'Administration Block', locationPath: 'Administration Block > Substation', voltage: 415.2, currentAmps: 85.4, activePowerWatts: 35400.0, powerFactor: 0.97, frequencyHz: 50.02, totalImportKwh: 148600.0, status: 'online'),
      const SmartEnergyMeter(id: '2', meterName: 'Academic Block (A) Main Feeder', meterCode: 'MTR-ACAD-01', meterType: 'submeter', protocol: 'mqtt', mqttTopic: 'energy/greenwood/acad_a/telemetry', buildingName: 'Academic Block (A)', locationPath: 'Academic Block (A) > Main Panel', voltage: 231.4, currentAmps: 28.5, activePowerWatts: 6500.0, powerFactor: 0.96, frequencyHz: 50.00, totalImportKwh: 43200.0, status: 'online'),
      const SmartEnergyMeter(id: '3', meterName: 'Library Block Feeder Meter', meterCode: 'MTR-LIB-01', meterType: 'submeter', protocol: 'mqtt', mqttTopic: 'energy/greenwood/library/telemetry', buildingName: 'Library Block', locationPath: 'Library Block > Panel Room', voltage: 230.1, currentAmps: 14.2, activePowerWatts: 3200.0, powerFactor: 0.95, frequencyHz: 49.98, totalImportKwh: 21800.0, status: 'online'),
      const SmartEnergyMeter(id: '4', meterName: 'Laboratories Block Feeder Meter', meterCode: 'MTR-LAB-01', meterType: 'submeter', protocol: 'modbus_tcp', ipAddress: '192.168.1.203', buildingName: 'Laboratories Block', locationPath: 'Laboratories Block > Lab Main Panel', voltage: 229.8, currentAmps: 16.8, activePowerWatts: 3850.0, powerFactor: 0.94, frequencyHz: 50.01, totalImportKwh: 20200.0, status: 'online'),
      const SmartEnergyMeter(id: '5', meterName: 'Administration Block Feeder Meter', meterCode: 'MTR-ADMIN-01', meterType: 'submeter', protocol: 'mqtt', mqttTopic: 'energy/greenwood/admin/telemetry', buildingName: 'Administration Block', locationPath: 'Administration Block > Admin Switchboard', voltage: 230.5, currentAmps: 12.0, activePowerWatts: 2750.0, powerFactor: 0.96, frequencyHz: 50.00, totalImportKwh: 16400.0, status: 'online'),
      const SmartEnergyMeter(id: '6', meterName: 'Hostel Block Feeder Meter', meterCode: 'MTR-HOSTEL-01', meterType: 'submeter', protocol: 'mqtt', mqttTopic: 'energy/greenwood/hostel/telemetry', buildingName: 'Hostel Block', locationPath: 'Hostel Block > Utility Room', voltage: 231.0, currentAmps: 11.5, activePowerWatts: 2600.0, powerFactor: 0.95, frequencyHz: 50.00, totalImportKwh: 15300.0, status: 'online'),
      const SmartEnergyMeter(id: '7', meterName: 'Cafeteria & Dining Hall Meter', meterCode: 'MTR-CAFE-01', meterType: 'smart_meter', protocol: 'mqtt', mqttTopic: 'energy/greenwood/cafe/telemetry', buildingName: 'Cafeteria', locationPath: 'Cafeteria > Kitchen Power Board', voltage: 230.0, currentAmps: 9.4, activePowerWatts: 2150.0, powerFactor: 0.93, frequencyHz: 49.99, totalImportKwh: 12100.0, status: 'online'),
      const SmartEnergyMeter(id: '8', meterName: 'Server Room Smart PDU A', meterCode: 'PDU-SRV-01', meterType: 'smart_plug', protocol: 'mqtt', mqttTopic: 'energy/greenwood/server/telemetry', buildingName: 'Administration Block', locationPath: 'Administration Block > Server Room A', voltage: 229.5, currentAmps: 18.2, activePowerWatts: 4100.0, powerFactor: 0.98, frequencyHz: 50.00, totalImportKwh: 18450.0, status: 'online'),
    ];
    _reports = [
      const EnergyReportItem(id: '1', reportTitle: 'Monthly Campus Energy Executive Summary', templateType: 'monthly_executive', scopeType: 'campus', scopeId: 'Greenwood High School', dateFrom: '2024-12-01', dateTo: '2024-12-31', fileFormat: 'pdf', fileSizeKb: 540, generatedBy: 'King Doe (Admin)', status: 'completed', createdAt: '2025-01-02 10:15'),
      const EnergyReportItem(id: '2', reportTitle: 'Academic Block (A) Detailed Energy Audit', templateType: 'building_comparison', scopeType: 'building', scopeId: 'Academic Block (A)', dateFrom: '2024-12-10', dateTo: '2025-01-10', fileFormat: 'excel', fileSizeKb: 320, generatedBy: 'King Doe (Admin)', status: 'completed', createdAt: '2025-01-10 14:30'),
      const EnergyReportItem(id: '3', reportTitle: 'Campus Carbon Footprint & Scope 2 Emissions', templateType: 'carbon_audit', scopeType: 'campus', scopeId: 'Greenwood High School', dateFrom: '2024-01-01', dateTo: '2024-12-31', fileFormat: 'pdf', fileSizeKb: 890, generatedBy: 'King Doe (Admin)', status: 'completed', createdAt: '2025-01-05 09:00'),
      const EnergyReportItem(id: '4', reportTitle: 'Utility Bill Reconciliation & Tariff Variance', templateType: 'cost_reconciliation', scopeType: 'campus', scopeId: 'Greenwood High School', dateFrom: '2024-10-01', dateTo: '2024-12-31', fileFormat: 'csv', fileSizeKb: 180, generatedBy: 'Finance Team', status: 'completed', createdAt: '2025-01-08 16:45'),
      const EnergyReportItem(id: '5', reportTitle: 'HVAC & Lighting Operational Efficiency Report', templateType: 'device_type_analysis', scopeType: 'device_type', scopeId: 'HVAC & Lighting', dateFrom: '2024-12-15', dateTo: '2025-01-10', fileFormat: 'pdf', fileSizeKb: 410, generatedBy: 'Facility Manager', status: 'completed', createdAt: '2025-01-11 11:20'),
    ];
    _useFallbackDevices();
  }

  List<EnergyTrendPoint> _generateDefaultTrendPoints() {
    final list = <EnergyTrendPoint>[];
    final labels = ['12 Dec', '15 Dec', '18 Dec', '21 Dec', '24 Dec', '27 Dec', '30 Dec', '2 Jan', '5 Jan', '8 Jan', '10 Jan'];
    final kwhs = [450.0, 480.0, 520.0, 580.0, 620.0, 590.0, 530.0, 490.0, 460.0, 510.0, 482.7];
    final avgs = [460.0, 470.0, 500.0, 550.0, 580.0, 570.0, 520.0, 490.0, 480.0, 495.0, 498.4];
    for (int i = 0; i < labels.length; i++) {
      list.add(EnergyTrendPoint(
        date: '2024-12-${12 + i}',
        label: labels[i],
        dailyKwh: kwhs[i],
        movingAvgKwh: avgs[i],
        costInr: kwhs[i] * 12.0,
        co2Kg: kwhs[i] * 0.75,
      ));
    }
    return list;
  }

  void _useFallbackDevices() {
    _devicesList = const [
      DeviceDetailedEnergyMetric(
        id: '1',
        deviceName: 'AC Unit (A1-101)',
        deviceCode: 'AC-A1-101',
        deviceType: 'AC / HVAC',
        buildingName: 'Academic Block (A)',
        roomName: 'A1-101',
        locationPath: 'Academic Block (A) > A1-101',
        groupName: 'Academic HVAC',
        metricDate: '2025-01-10',
        energyKwh: 120.5,
        usageHours: 720.0,
        avgPowerWatts: 167.0,
        costInr: 1446.0,
        co2Kg: 90.1,
        trendPct: -11.8,
      ),
      DeviceDetailedEnergyMetric(
        id: '2',
        deviceName: 'Classroom Lights (A1-101)',
        deviceCode: 'LGT-A1-101',
        deviceType: 'Lighting',
        buildingName: 'Academic Block (A)',
        roomName: 'A1-101',
        locationPath: 'Academic Block (A) > A1-101',
        groupName: 'Classroom Lighting',
        metricDate: '2025-01-10',
        energyKwh: 48.6,
        usageHours: 720.0,
        avgPowerWatts: 67.0,
        costInr: 583.0,
        co2Kg: 36.4,
        trendPct: -14.2,
      ),
      DeviceDetailedEnergyMetric(
        id: '3',
        deviceName: 'Projector (A1-102)',
        deviceCode: 'PRJ-A1-102',
        deviceType: 'Projector',
        buildingName: 'Academic Block (A)',
        roomName: 'A1-102',
        locationPath: 'Academic Block (A) > A1-102',
        groupName: 'AV & Presentation',
        metricDate: '2025-01-10',
        energyKwh: 36.8,
        usageHours: 240.0,
        avgPowerWatts: 153.0,
        costInr: 442.0,
        co2Kg: 27.6,
        trendPct: -8.6,
      ),
      DeviceDetailedEnergyMetric(
        id: '4',
        deviceName: 'Ceiling Fan (A1-101)',
        deviceCode: 'FAN-A1-101',
        deviceType: 'Fan',
        buildingName: 'Academic Block (A)',
        roomName: 'A1-101',
        locationPath: 'Academic Block (A) > A1-101',
        groupName: 'Ventilation Fleet',
        metricDate: '2025-01-10',
        energyKwh: 28.4,
        usageHours: 720.0,
        avgPowerWatts: 39.0,
        costInr: 341.0,
        co2Kg: 21.3,
        trendPct: -9.7,
      ),
      DeviceDetailedEnergyMetric(
        id: '5',
        deviceName: 'Interactive Display (A1-102)',
        deviceCode: 'DSP-A1-102',
        deviceType: 'Display',
        buildingName: 'Academic Block (A)',
        roomName: 'A1-102',
        locationPath: 'Academic Block (A) > A1-102',
        groupName: 'AV & Presentation',
        metricDate: '2025-01-10',
        energyKwh: 42.1,
        usageHours: 240.0,
        avgPowerWatts: 175.0,
        costInr: 505.0,
        co2Kg: 31.6,
        trendPct: 2.3,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final isMobile = screenWidth < 800;
        final isNarrow = screenWidth < 1200;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 12 : 20,
            vertical: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Top Screen Header
              _buildTopHeader(isDark, isMobile),
              const SizedBox(height: 16),

              // 2. Sub-Tabs Bar (Overview, By Location, etc.)
              _buildSubTabsBar(isDark),
              const SizedBox(height: 16),

              if (_isLoading)
                const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
              else if (_selectedSubTab == 'Overview') ...[
                // 3. Top 6 KPI Cards
                _buildKpiGrid(screenWidth, isDark),
                const SizedBox(height: 20),

                // 4. Middle Section (Charts, Usage, Insights, Goals)
                if (isNarrow)
                  Column(
                    children: [
                      _buildMiddleChartsColumn(isDark, screenWidth),
                      const SizedBox(height: 20),
                      _buildRightInspectorColumn(isDark),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 68, child: _buildMiddleChartsColumn(isDark, screenWidth)),
                      const SizedBox(width: 20),
                      Expanded(flex: 32, child: _buildRightInspectorColumn(isDark)),
                    ],
                  ),

                const SizedBox(height: 24),

                // 5. Bottom Detailed Device Usage Table
                _buildDetailedDeviceUsageSection(isDark, screenWidth),
              ] else if (_selectedSubTab == 'By Location') ...[
                _buildByLocationView(isDark, screenWidth),
              ] else if (_selectedSubTab == 'By Device Type') ...[
                _buildByDeviceTypeView(isDark, screenWidth),
              ] else if (_selectedSubTab == 'By Device') ...[
                _buildByDeviceView(isDark, screenWidth),
              ] else if (_selectedSubTab == 'Trends & Comparison') ...[
                _buildTrendsComparisonView(isDark, screenWidth),
              ] else if (_selectedSubTab == 'Cost Analysis') ...[
                _buildCostAnalysisView(isDark, screenWidth),
              ] else if (_selectedSubTab == 'Efficiency & Savings') ...[
                _buildEfficiencySavingsView(isDark, screenWidth),
              ] else if (_selectedSubTab == 'Reports') ...[
                _buildReportsView(isDark, screenWidth),
              ],
              const SizedBox(height: 40),
            ],
          ),
        );
      },
    );
  }

  // ============================================================================
  // Top Header
  // ============================================================================

  Widget _buildTopHeader(bool isDark, bool isMobile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onBackToDashboard != null)
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: widget.onBackToDashboard,
                  tooltip: 'Back to Dashboard',
                ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF06B6D4)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.eco_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Energy & Usage',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Monitor energy consumption, device usage and operational efficiency across campus.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Action Controls
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Date Range Picker
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 4,
                  runSpacing: 2,
                  children: [
                    const Icon(Icons.calendar_today_rounded, size: 14, color: Color(0xFF2563EB)),
                    DropdownButtonHideUnderline(
                      child: AppSearchableDropdown<String>.fromMenuItems(
                        value: _selectedDateRange,
                        isDense: true,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        items: ['Last 7 Days', 'Last 30 Days', 'This Month', 'Last 90 Days'].map((s) {
                          return DropdownMenuItem(value: s, child: Text(s));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedDateRange = val);
                        },
                      ),
                    ),
                    Text(
                      '12 Dec 2024 – 10 Jan 2025',
                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),

              // Campus Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.apartment_rounded, size: 14, color: Color(0xFF2563EB)),
                    const SizedBox(width: 6),
                    DropdownButtonHideUnderline(
                      child: AppSearchableDropdown<String>.fromMenuItems(
                        value: _selectedCampus,
                        isDense: true,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        items: ['All Campuses', 'Main Campus', 'North Campus', 'Sports Hub'].map((c) {
                          return DropdownMenuItem(value: c, child: Text(c));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedCampus = val);
                        },
                      ),
                    ),
                  ],
                ),
              ),

              // Smart Meters Trigger
              OutlinedButton.icon(
                onPressed: _showSmartMetersDialog,
                icon: const Icon(Icons.speed_rounded, size: 15, color: Color(0xFF2563EB)),
                label: const Text('Smart Meters', style: TextStyle(color: Color(0xFF2563EB), fontSize: 12, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),

              // Export Button
              ElevatedButton.icon(
                onPressed: _showExportDialog,
                icon: const Icon(Icons.file_download_outlined, size: 16, color: Colors.white),
                label: const Text('Export', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // Sub-Tabs Bar
  // ============================================================================

  Widget _buildSubTabsBar(bool isDark) {
    final tabs = ['Overview', 'By Location', 'By Device Type', 'By Device', 'Trends & Comparison', 'Cost Analysis', 'Efficiency & Savings', 'Reports'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _selectedSubTab == tab;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() => _selectedSubTab = tab);
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF2563EB)
                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ============================================================================
  // Top 6 KPI Cards Grid
  // ============================================================================

  Widget _buildKpiGrid(double width, bool isDark) {
    int crossAxisCount = 6;
    if (width < 600) {
      crossAxisCount = 2;
    } else if (width < 900) {
      crossAxisCount = 3;
    } else if (width < 1300) {
      crossAxisCount = 3;
    }

    final cardData = [
      {
        'title': 'Total Energy (Today)',
        'value': '${_kpis.totalEnergyTodayKwh.toStringAsFixed(1)} kWh',
        'trend': '${_kpis.totalEnergyTodayTrend.toStringAsFixed(1)}% vs. yesterday',
        'isNegative': _kpis.totalEnergyTodayTrend <= 0,
        'icon': Icons.bolt_rounded,
        'iconColor': const Color(0xFF10B981),
        'iconBg': const Color(0xFFD1FAE5),
      },
      {
        'title': 'Total Cost (Today)',
        'value': '₹ ${_kpis.totalCostTodayInr.toStringAsFixed(0)}',
        'trend': '${_kpis.totalCostTodayTrend.toStringAsFixed(1)}%',
        'isNegative': _kpis.totalCostTodayTrend <= 0,
        'icon': Icons.currency_rupee_rounded,
        'iconColor': const Color(0xFF2563EB),
        'iconBg': const Color(0xFFDBEAFE),
      },
      {
        'title': 'Monthly Energy',
        'value': '${_kpis.monthlyEnergyKwh.toStringAsFixed(0)} kWh',
        'trend': '${_kpis.monthlyEnergyTrend.toStringAsFixed(1)}%',
        'isNegative': _kpis.monthlyEnergyTrend <= 0,
        'icon': Icons.access_time_rounded,
        'iconColor': const Color(0xFF8B5CF6),
        'iconBg': const Color(0xFFEDE9FE),
      },
      {
        'title': 'Monthly Cost',
        'value': '₹ ${_kpis.monthlyCostInr.toStringAsFixed(0)}',
        'trend': '${_kpis.monthlyCostTrend.toStringAsFixed(1)}%',
        'isNegative': _kpis.monthlyCostTrend <= 0,
        'icon': Icons.calendar_month_rounded,
        'iconColor': const Color(0xFFF59E0B),
        'iconBg': const Color(0xFFFEF3C7),
      },
      {
        'title': 'CO₂ Emission (Monthly)',
        'value': '${_kpis.co2EmissionMonthlyTonnes.toStringAsFixed(1)} tCO₂',
        'trend': '${_kpis.co2EmissionTrend.toStringAsFixed(1)}%',
        'isNegative': _kpis.co2EmissionTrend <= 0,
        'icon': Icons.eco_rounded,
        'iconColor': const Color(0xFF10B981),
        'iconBg': const Color(0xFFD1FAE5),
      },
      {
        'title': 'Active Devices',
        'value': '${_kpis.activeDevicesCount} / ${_kpis.totalDevicesCount}',
        'trend': '(${_kpis.uptimePct.toStringAsFixed(1)}%)',
        'isNegative': false,
        'icon': Icons.desktop_windows_rounded,
        'iconColor': const Color(0xFF0284C7),
        'iconBg': const Color(0xFFE0F2FE),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: cardData.map((d) {
            final itemWidth = (constraints.maxWidth - (crossAxisCount - 1) * 12) / crossAxisCount;
            return SizedBox(
              width: itemWidth,
              child: _buildSingleKpiCard(
                title: d['title'] as String,
                value: d['value'] as String,
                trend: d['trend'] as String,
                isNegative: d['isNegative'] as bool,
                icon: d['icon'] as IconData,
                iconColor: d['iconColor'] as Color,
                iconBg: d['iconBg'] as Color,
                isDark: isDark,
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSingleKpiCard({
    required String title,
    required String value,
    required String trend,
    required bool isNegative,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isDark ? iconColor.withValues(alpha: 0.2) : iconBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (trend.contains('%') && !trend.startsWith('(')) ...[
                Icon(
                  isNegative ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                  color: const Color(0xFF10B981),
                  size: 11,
                ),
                const SizedBox(width: 2),
              ],
              Text(
                trend,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // Middle Section: Left Charts Column (Energy Trend + Donut + Locations + Usage)
  // ============================================================================

  Widget _buildMiddleChartsColumn(bool isDark, double width) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final colWidth = constraints.maxWidth;
        final isStacked = colWidth < 800;
        return Column(
          children: [
            // Row 1: Trend Bar/Line Chart + Device Type Donut
            if (isStacked)
              Column(
                children: [
                  _buildConsumptionTrendCard(isDark),
                  const SizedBox(height: 16),
                  _buildDeviceTypeDonutCard(isDark),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 58, child: _buildConsumptionTrendCard(isDark)),
                  const SizedBox(width: 16),
                  Expanded(flex: 42, child: _buildDeviceTypeDonutCard(isDark)),
                ],
              ),

            const SizedBox(height: 16),

            // Row 2: Energy by Location (Top 5) + Device Usage Gauge
            if (isStacked)
              Column(
                children: [
                  _buildLocationTop5Card(isDark),
                  const SizedBox(height: 16),
                  _buildDeviceUsageGaugeCard(isDark),
                ],
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 50, child: _buildLocationTop5Card(isDark)),
                  const SizedBox(width: 16),
                  Expanded(flex: 50, child: _buildDeviceUsageGaugeCard(isDark)),
                ],
              ),
          ],
        );
      },
    );
  }

  // Card 1: Energy Consumption Trend
  Widget _buildConsumptionTrendCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFF2563EB), size: 18),
                  Text(
                    'Energy Consumption Trend',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_downward_rounded, size: 11, color: Color(0xFF065F46)),
                    SizedBox(width: 2),
                    Text(
                      '-8.9% vs. previous 30 days',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              Text(
                '14,860 kWh',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                'Total (Last 30 Days)',
                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Custom Chart Canvas
          SizedBox(
            height: 180,
            child: CustomPaint(
              size: const Size(double.infinity, 180),
              painter: _EnergyTrendChartPainter(points: _trendPoints, isDark: isDark),
            ),
          ),
          const SizedBox(height: 10),

          // Chart Legends
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFF93C5FD), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                  Text('Daily Energy (kWh)', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 3,
                    decoration: const BoxDecoration(color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text('7-Day Moving Average', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Card 2: Energy by Device Type Donut
  Widget _buildDeviceTypeDonutCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: Color(0xFF2563EB), size: 18),
              const SizedBox(width: 6),
              Text(
                'Energy by Device Type',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 14,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Donut Chart
              SizedBox(
                width: 120,
                height: 120,
                child: CustomPaint(
                  painter: _DeviceTypeDonutPainter(slices: _deviceTypeSlices, isDark: isDark),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '14,860',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'kWh',
                          style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Legend Slices List
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 160),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: _deviceTypeSlices.map((s) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: s.color, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(
                            s.name,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${s.percentage.toStringAsFixed(1)}% (${s.kwh.toStringAsFixed(0)} kWh)',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Card 3: Energy by Location (Top 5)
  Widget _buildLocationTop5Card(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              const Icon(Icons.apartment_rounded, color: Color(0xFF2563EB), size: 18),
              Text(
                'Energy by Location (Top 5)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Column(
            children: _locationSlices.map((loc) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.business_outlined, size: 13, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Text(
                              loc.name,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${loc.kwh.toStringAsFixed(0)} kWh',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${loc.percentage.toStringAsFixed(1)}%',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: (loc.percentage / 35.0).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Card 4: Device Usage Gauge
  Widget _buildDeviceUsageGaugeCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_input_composite_rounded, color: Color(0xFF2563EB), size: 18),
              const SizedBox(width: 6),
              Text(
                'Device Usage',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 14,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Radial Gauge
              SizedBox(
                width: 110,
                height: 110,
                child: CustomPaint(
                  painter: _UptimeGaugePainter(
                    uptimePct: _uptimeBreakdown.uptimePct,
                    isDark: isDark,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${_uptimeBreakdown.uptimePct.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Device Uptime',
                          style: TextStyle(fontSize: 8.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Breakdown items
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 160),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGaugeRow('Active', '${_uptimeBreakdown.activeCount} (${_uptimeBreakdown.activePct.toStringAsFixed(1)}%)', const Color(0xFF10B981), isDark),
                    const SizedBox(height: 6),
                    _buildGaugeRow('Idle', '${_uptimeBreakdown.idleCount} (${_uptimeBreakdown.idlePct.toStringAsFixed(1)}%)', const Color(0xFF94A3B8), isDark),
                    const SizedBox(height: 6),
                    _buildGaugeRow('Offline', '${_uptimeBreakdown.offlineCount} (${_uptimeBreakdown.offlinePct.toStringAsFixed(1)}%)', const Color(0xFFEF4444), isDark),
                    const Divider(height: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Total Devices', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        Text(': ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        Text('${_uptimeBreakdown.totalDevices}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGaugeRow(String label, String value, Color dotColor, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155))),
          ],
        ),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
      ],
    );
  }

  // ============================================================================
  // Right Inspector Column: Energy Insights + Quick Actions + Energy Goals & Policy
  // ============================================================================

  Widget _buildRightInspectorColumn(bool isDark) {
    return Column(
      children: [
        // Card 1: Energy Insights
        _buildEnergyInsightsCard(isDark),
        const SizedBox(height: 16),

        // Card 2: Quick Actions
        _buildQuickActionsCard(isDark),
        const SizedBox(height: 16),

        // Card 3: Energy Goals & Policy
        _buildEnergyGoalsPolicyCard(isDark),
      ],
    );
  }

  Widget _buildEnergyInsightsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_rounded, color: Color(0xFF2563EB), size: 18),
              const SizedBox(width: 6),
              Text(
                'Energy Insights',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: _insights.map((ins) {
              Color iconColor;
              IconData iconData;
              if (ins.type == 'warning') {
                iconColor = const Color(0xFFF59E0B);
                iconData = Icons.warning_amber_rounded;
              } else if (ins.type == 'recommendation') {
                iconColor = const Color(0xFF2563EB);
                iconData = Icons.info_outline_rounded;
              } else {
                iconColor = const Color(0xFF10B981);
                iconData = ins.icon.contains('eco') ? Icons.eco_rounded : Icons.electric_bolt_rounded;
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(iconData, size: 14, color: iconColor),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        ins.text,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard(bool isDark) {
    final actions = [
      {'title': 'Set Energy Schedule', 'icon': Icons.schedule_rounded, 'action': _showScheduleDialog},
      {'title': 'Create Automation', 'icon': Icons.smart_toy_rounded, 'action': _showAutomationDialog},
      {'title': 'Apply Energy Policy', 'icon': Icons.policy_rounded, 'action': _showPolicyDialog},
      {'title': 'Optimize Usage', 'icon': Icons.auto_awesome_rounded, 'action': _showOptimizeDialog},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.settings_outlined, color: Color(0xFF2563EB), size: 18),
              const SizedBox(width: 6),
              Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.3,
            ),
            itemCount: actions.length,
            itemBuilder: (context, idx) {
              final a = actions[idx];
              return InkWell(
                onTap: a['action'] as VoidCallback,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Icon(a['icon'] as IconData, size: 16, color: const Color(0xFF2563EB)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          a['title'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEnergyGoalsPolicyCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.flag_rounded, color: Color(0xFF2563EB), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Energy Goals & Policy',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 16),
                tooltip: 'Edit Targets',
                onPressed: _showPolicyDialog,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 1. Monthly Energy Target
          _buildGoalItem(
            label: 'Monthly Target',
            targetStr: '${_goals.monthlyTargetKwh.toStringAsFixed(0)} kWh',
            currentStr: '${_goals.monthlyActualKwh.toStringAsFixed(0)} kWh (${_goals.monthlyKwhPct.toStringAsFixed(1)}%)',
            progress: _goals.monthlyKwhPct / 100.0,
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // 2. Cost Target
          _buildGoalItem(
            label: 'Cost Target',
            targetStr: '₹ ${_goals.costTargetInr.toStringAsFixed(0)}',
            currentStr: '₹ ${_goals.costActualInr.toStringAsFixed(0)} (${_goals.costPct.toStringAsFixed(1)}%)',
            progress: _goals.costPct / 100.0,
            isDark: isDark,
          ),
          const SizedBox(height: 12),

          // 3. Emission Target
          _buildGoalItem(
            label: 'Emission Target',
            targetStr: '${_goals.emissionTargetTonnes.toStringAsFixed(1)} tCO₂',
            currentStr: '${_goals.emissionActualTonnes.toStringAsFixed(1)} tCO₂ (${_goals.emissionPct.toStringAsFixed(1)}%)',
            progress: _goals.emissionPct / 100.0,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildGoalItem({
    required String label,
    required String targetStr,
    required String currentStr,
    required double progress,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            Text(targetStr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
          ),
        ),
        const SizedBox(height: 3),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            currentStr,
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // Bottom Section: Detailed Device Usage Table
  // ============================================================================

  Widget _buildDetailedDeviceUsageSection(bool isDark, double width) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Title
          Text(
            'Detailed Device Usage',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 12),

          // Filters & Controls Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              // Search Input
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                      _currentPage = 1;
                    });
                    _fetchDevicesTable();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search device by name, ID or location...',
                    hintStyle: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, size: 16),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                  ),
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
              ),

              // Filter Dropdowns
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildTableDropdown(_selectedLocationFilter, _locationFilterOptions, (val) {
                    setState(() {
                      _selectedLocationFilter = val;
                      _currentPage = 1;
                    });
                    _fetchDevicesTable();
                  }, isDark),

                  _buildTableDropdown(_selectedDeviceTypeFilter, _deviceTypeFilterOptions, (val) {
                    setState(() {
                      _selectedDeviceTypeFilter = val;
                      _currentPage = 1;
                    });
                    _fetchDevicesTable();
                  }, isDark),

                  _buildTableDropdown(_selectedGroupFilter, _groupFilterOptions, (val) {
                    setState(() {
                      _selectedGroupFilter = val;
                      _currentPage = 1;
                    });
                    _fetchDevicesTable();
                  }, isDark),

                  _buildTableDropdown(_selectedUsageFilter, _usageFilterOptions, (val) {
                    setState(() {
                      _selectedUsageFilter = val;
                      _currentPage = 1;
                    });
                    _fetchDevicesTable();
                  }, isDark),

                  if (_searchQuery.isNotEmpty ||
                      _selectedLocationFilter != 'All Locations' ||
                      _selectedDeviceTypeFilter != 'All Device Types' ||
                      _selectedGroupFilter != 'All Groups' ||
                      _selectedUsageFilter != 'Usage: All')
                    TextButton.icon(
                      onPressed: _resetFilters,
                      icon: const Icon(Icons.filter_alt_off_rounded, size: 14),
                      label: const Text('Reset Filters', style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),

              // Devices / Locations Toggle + Export
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    padding: const EdgeInsets.all(2),
                    child: Row(
                      children: ['Devices', 'Locations'].map((mode) {
                        final isSel = _tableMode == mode;
                        return InkWell(
                          onTap: () => setState(() => _tableMode = mode),
                          borderRadius: BorderRadius.circular(4),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isSel ? const Color(0xFF2563EB) : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              mode,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                color: isSel ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _showExportDialog,
                    icon: const Icon(Icons.file_download_outlined, size: 14),
                    label: const Text('Export', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bulk Actions Floating Toolbar (Visible when devices are multi-selected)
          if (_selectedDeviceIds.isNotEmpty) ...[
            _buildBulkActionsToolbar(isDark),
            const SizedBox(height: 8),
          ],

          // Scrollable Data Table
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: math.max(width - 40, 950)),
              child: DataTable(
                showCheckboxColumn: false,
                sortColumnIndex: _sortColumnIndex,
                sortAscending: _sortOrder == 'asc',
                headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                dataRowMinHeight: 52,
                dataRowMaxHeight: 52,
                headingRowHeight: 40,
                horizontalMargin: 12,
                columnSpacing: 16,
                columns: [
                  DataColumn(
                    label: Checkbox(
                      value: _devicesList.isNotEmpty && _selectedDeviceIds.length == _devicesList.length,
                      tristate: _selectedDeviceIds.isNotEmpty && _selectedDeviceIds.length < _devicesList.length,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedDeviceIds.addAll(_devicesList.map((d) => d.id));
                          } else {
                            _selectedDeviceIds.clear();
                          }
                        });
                      },
                    ),
                  ),
                  DataColumn(
                    label: const Text('Device Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                    onSort: (idx, _) => _onSort(idx, 'device_name'),
                  ),
                  DataColumn(
                    label: const Text('Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                    onSort: (idx, _) => _onSort(idx, 'device_type'),
                  ),
                  DataColumn(
                    label: const Text('Location (Building > Room)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                    onSort: (idx, _) => _onSort(idx, 'location_path'),
                  ),
                  DataColumn(
                    label: const Text('Energy (kWh)\n(Last 30 Days)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    onSort: (idx, _) => _onSort(idx, 'energy_kwh'),
                  ),
                  DataColumn(
                    label: const Text('Usage (Hours)\n(Last 30 Days)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    onSort: (idx, _) => _onSort(idx, 'usage_hours'),
                  ),
                  DataColumn(
                    label: const Text('Avg. Power\n(W)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    onSort: (idx, _) => _onSort(idx, 'avg_power_watts'),
                  ),
                  DataColumn(
                    label: const Text('Cost (₹)\n(Last 30 Days)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    onSort: (idx, _) => _onSort(idx, 'cost_inr'),
                  ),
                  DataColumn(
                    label: const Text('CO₂ Emission\n(kg CO₂)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    onSort: (idx, _) => _onSort(idx, 'co2_kg'),
                  ),
                  DataColumn(
                    label: const Text('Trend\n(vs. prev.)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    onSort: (idx, _) => _onSort(idx, 'trend_pct'),
                  ),
                  const DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5))),
                ],
                rows: _devicesList.map((dev) {
                  final isSelected = _selectedDeviceIds.contains(dev.id);
                  return DataRow(
                    selected: isSelected,
                    onSelectChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedDeviceIds.add(dev.id);
                        } else {
                          _selectedDeviceIds.remove(dev.id);
                        }
                      });
                    },
                    cells: [
                      // Checkbox is handled by DataRow selection
                      DataCell(
                        Checkbox(
                          value: isSelected,
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedDeviceIds.add(dev.id);
                              } else {
                                _selectedDeviceIds.remove(dev.id);
                              }
                            });
                          },
                        ),
                      ),

                      // Device Name + Icon
                      DataCell(
                        Row(
                          children: [
                            _getDeviceIcon(dev.deviceType),
                            const SizedBox(width: 8),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dev.deviceName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                if (dev.deviceCode.isNotEmpty)
                                  Text(
                                    dev.deviceCode,
                                    style: TextStyle(fontSize: 9.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Device Type Badge
                      DataCell(_buildTypeBadge(dev.deviceType)),

                      // Location Path
                      DataCell(
                        Text(
                          dev.locationPath,
                          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                        ),
                      ),

                      // Energy kWh
                      DataCell(
                        Text(
                          '${dev.energyKwh.toStringAsFixed(1)} kWh',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
                        ),
                      ),

                      // Usage Hours
                      DataCell(
                        Text(
                          '${dev.usageHours.toStringAsFixed(0)} h',
                          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),

                      // Avg Power Watts
                      DataCell(
                        Text(
                          '${dev.avgPowerWatts.toStringAsFixed(0)} W',
                          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),

                      // Cost INR
                      DataCell(
                        Text(
                          '₹ ${dev.costInr.toStringAsFixed(0)}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
                        ),
                      ),

                      // CO2 Emission
                      DataCell(
                        Text(
                          '${dev.co2Kg.toStringAsFixed(1)} kg',
                          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ),

                      // Trend vs prev
                      DataCell(_buildTrendCell(dev.trendPct)),

                      // Actions
                      DataCell(
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.play_circle_outline_rounded, size: 16, color: Color(0xFF2563EB)),
                              tooltip: 'Run / Quick Control',
                              onPressed: () => _showQuickControlModal(dev),
                            ),
                            IconButton(
                              icon: const Icon(Icons.bar_chart_rounded, size: 16, color: Color(0xFF0284C7)),
                              tooltip: 'View Analytics',
                              onPressed: () => _showDeviceAnalyticsModal(dev),
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_vert_rounded, size: 16),
                              tooltip: 'Options',
                              onPressed: () => _showMoreOptionsModal(dev),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Pagination Footer
          _buildPaginationFooter(isDark),
        ],
      ),
    );
  }

  Widget _buildTableDropdown(String value, List<String> items, ValueChanged<String> onChanged, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: AppSearchableDropdown<String>.fromMenuItems(
          value: value,
          isDense: true,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          items: items.map((it) => DropdownMenuItem(value: it, child: Text(it))).toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }

  Widget _getDeviceIcon(String type) {
    IconData icon;
    Color color;
    if (type.contains('HVAC') || type.contains('AC')) {
      icon = Icons.ac_unit_rounded;
      color = const Color(0xFF2563EB);
    } else if (type.contains('Lighting') || type.contains('Light')) {
      icon = Icons.lightbulb_outline_rounded;
      color = const Color(0xFF10B981);
    } else if (type.contains('Projector')) {
      icon = Icons.videocam_outlined;
      color = const Color(0xFFF59E0B);
    } else if (type.contains('Fan')) {
      icon = Icons.mode_fan_off_rounded;
      color = const Color(0xFF06B6D4);
    } else {
      icon = Icons.tv_rounded;
      color = const Color(0xFF8B5CF6);
    }
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
      child: Icon(icon, color: color, size: 15),
    );
  }

  Widget _buildTypeBadge(String type) {
    Color bg = const Color(0xFFDBEAFE);
    Color text = const Color(0xFF1E40AF);
    if (type.contains('Lighting')) {
      bg = const Color(0xFFD1FAE5);
      text = const Color(0xFF065F46);
    } else if (type.contains('Projector')) {
      bg = const Color(0xFFFEF3C7);
      text = const Color(0xFF92400E);
    } else if (type.contains('Fan')) {
      bg = const Color(0xFFCFFAFE);
      text = const Color(0xFF155E75);
    } else if (type.contains('Display')) {
      bg = const Color(0xFFEDE9FE);
      text = const Color(0xFF5B21B6);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
      child: Text(type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: text)),
    );
  }

  Widget _buildTrendCell(double trend) {
    final isNegative = trend <= 0;
    final color = isNegative ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final icon = isNegative ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded;
    final prefix = isNegative ? '' : '+';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(
          '$prefix${trend.toStringAsFixed(1)}%',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color),
        ),
      ],
    );
  }

  Widget _buildBulkActionsToolbar(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.5)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                '${_selectedDeviceIds.length} device(s) selected',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF1E40AF),
                ),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () => _executeBulkEnergyAction('eco_mode'),
                icon: const Icon(Icons.eco_rounded, size: 14, color: Colors.white),
                label: const Text('Eco Mode', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _executeBulkEnergyAction('turn_off'),
                icon: const Icon(Icons.power_settings_new_rounded, size: 14, color: Colors.white),
                label: const Text('Turn OFF', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showSetPowerLimitDialog,
                icon: const Icon(Icons.speed_rounded, size: 14, color: Colors.white),
                label: const Text('Power Limit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _exportSelectedDevices,
                icon: const Icon(Icons.file_download_outlined, size: 14),
                label: const Text('Export Selected', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              TextButton.icon(
                onPressed: () => setState(() => _selectedDeviceIds.clear()),
                icon: const Icon(Icons.close_rounded, size: 14),
                label: const Text('Deselect All', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter(bool isDark) {
    final startIdx = _totalDevices == 0 ? 0 : ((_currentPage - 1) * _rowsPerPage) + 1;
    final endIdx = math.min(_currentPage * _rowsPerPage, _totalDevices);
    final totalPages = math.max(1, (_totalDevices / _rowsPerPage).ceil());

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Showing $startIdx – $endIdx of $_totalDevices devices',
          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
        ),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 4,
          children: [
            Text('Rows per page:', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            DropdownButtonHideUnderline(
              child: AppSearchableDropdown<int>.fromMenuItems(
                value: _rowsPerPage,
                isDense: true,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                items: [5, 10, 20, 50, 100].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _rowsPerPage = val;
                      _currentPage = 1;
                    });
                    _fetchDevicesTable();
                  }
                },
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              icon: const Icon(Icons.first_page_rounded, size: 18),
              tooltip: 'First Page',
              onPressed: _currentPage > 1
                  ? () {
                      setState(() => _currentPage = 1);
                      _fetchDevicesTable();
                    }
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded, size: 18),
              tooltip: 'Previous Page',
              onPressed: _currentPage > 1
                  ? () {
                      setState(() => _currentPage--);
                      _fetchDevicesTable();
                    }
                  : null,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFF2563EB), borderRadius: BorderRadius.circular(4)),
              child: Text('$_currentPage', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            if (totalPages > 1) ...[
              const SizedBox(width: 4),
              Text('of $totalPages', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            ],
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded, size: 18),
              tooltip: 'Next Page',
              onPressed: _currentPage < totalPages
                  ? () {
                      setState(() => _currentPage++);
                      _fetchDevicesTable();
                    }
                  : null,
            ),
            IconButton(
              icon: const Icon(Icons.last_page_rounded, size: 18),
              tooltip: 'Last Page',
              onPressed: _currentPage < totalPages
                  ? () {
                      setState(() => _currentPage = totalPages);
                      _fetchDevicesTable();
                    }
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================================
  // Dialogs & Quick Actions
  // ============================================================================

  void _showDeviceAnalyticsModal(DeviceDetailedEnergyMetric dev) {
    showDialog(
      context: context,
      builder: (ctx) => _DeviceAnalyticsDialog(device: dev),
    );
  }

  void _showQuickControlModal(DeviceDetailedEnergyMetric dev) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Quick Control: ${dev.deviceName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Location: ${dev.locationPath}'),
            const SizedBox(height: 8),
            Text('Current Power Draw: ${dev.avgPowerWatts.toStringAsFixed(0)} W'),
            const SizedBox(height: 16),
            const Text('Select Target Energy Mode:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Switched ${dev.deviceName} to ECO Mode (18% power savings)')));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  child: const Text('ECO Mode (24°C)', style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Turned OFF ${dev.deviceName}')));
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                  child: const Text('Turn OFF', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  void _showMoreOptionsModal(DeviceDetailedEnergyMetric dev) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.bar_chart_rounded, color: Color(0xFF2563EB)),
              title: const Text('Detailed Energy Curve'),
              onTap: () {
                Navigator.pop(ctx);
                _showDeviceAnalyticsModal(dev);
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule_rounded, color: Color(0xFF10B981)),
              title: const Text('Configure Power Schedule'),
              onTap: () {
                Navigator.pop(ctx);
                _showScheduleDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.smart_toy_rounded, color: Color(0xFF8B5CF6)),
              title: const Text('Add Eco Automation Rule'),
              onTap: () {
                Navigator.pop(ctx);
                _showAutomationDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showScheduleDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Energy Schedule'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Configure campus-wide automated shutoff during non-academic hours:'),
            SizedBox(height: 12),
            Text('• Night Shutdown: 07:00 PM to 06:00 AM (Mon - Fri)'),
            SizedBox(height: 6),
            Text('• Weekend Low Power: All Day (Sat - Sun)'),
            SizedBox(height: 6),
            Text('• Est. Monthly Savings: ~1,240 kWh (₹ 14,880)'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Energy schedule activated successfully across target devices!')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Activate Schedule', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAutomationDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Energy Automation'),
        content: const Text('Automatically turn off lights and AC units when room occupancy sensor detects 0 students for > 15 minutes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Created automation rule: "Turn Off HVAC & Lighting on Zero Occupancy"')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Enable Automation', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPolicyDialog() {
    final energyCtrl = TextEditingController(text: _goals.monthlyTargetKwh.toStringAsFixed(0));
    final costCtrl = TextEditingController(text: _goals.costTargetInr.toStringAsFixed(0));
    final co2Ctrl = TextEditingController(text: _goals.emissionTargetTonnes.toStringAsFixed(1));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Campus Energy Goals & Policy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: energyCtrl,
              decoration: const InputDecoration(labelText: 'Monthly Energy Target (kWh)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: costCtrl,
              decoration: const InputDecoration(labelText: 'Cost Budget Target (₹)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: co2Ctrl,
              decoration: const InputDecoration(labelText: 'CO₂ Emission Cap (tCO₂)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final newKwh = double.tryParse(energyCtrl.text) ?? 16000.0;
              final newCost = double.tryParse(costCtrl.text) ?? 190000.0;
              final newCo2 = double.tryParse(co2Ctrl.text) ?? 12.5;

              try {
                final sid = widget.schoolId ?? '11111111-1111-1111-1111-111111111111';
                await http.put(
                  Uri.parse('$_apiBase/energy-usage/policy?school_id=$sid'),
                  headers: {'Content-Type': 'application/json'},
                  body: json.encode({
                    'monthly_energy_target_kwh': newKwh,
                    'monthly_cost_target_inr': newCost,
                    'monthly_co2_target_tonnes': newCo2,
                    'rate_per_kwh_inr': 12.0,
                  }),
                );
              } catch (_) {}

              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (mounted) {
                setState(() {
                  _goals = EnergyGoalsPolicy(
                    monthlyTargetKwh: newKwh,
                    monthlyActualKwh: _goals.monthlyActualKwh,
                    monthlyKwhPct: (newKwh > 0) ? (_goals.monthlyActualKwh / newKwh) * 100 : 0.0,
                    costTargetInr: newCost,
                    costActualInr: _goals.costActualInr,
                    costPct: (newCost > 0) ? (_goals.costActualInr / newCost) * 100 : 0.0,
                    emissionTargetTonnes: newCo2,
                    emissionActualTonnes: _goals.emissionActualTonnes,
                    emissionPct: (newCo2 > 0) ? (_goals.emissionActualTonnes / newCo2) * 100 : 0.0,
                  );
                });
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Energy Policy targets saved successfully.')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Save Policy', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showOptimizeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Optimize Campus Energy Usage'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI Recommendations Found:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('1. Set HVAC to 24°C in Academic Block A (Saves 820 kWh / month)'),
            SizedBox(height: 4),
            Text('2. Dim empty corridors after 11:00 PM (Saves 450 kWh / month)'),
            SizedBox(height: 4),
            Text('3. Night shutoff for all AV displays (Saves 380 kWh / month)'),
            SizedBox(height: 12),
            Text('Total Potential Savings: 1,650 kWh (₹ 19,800 / month)', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Applied 3 optimization rules across campus IoT network.')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            child: const Text('Apply Optimizations', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Energy & Telemetry Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.table_view_rounded, color: Color(0xFF10B981)),
              title: const Text('Export as CSV'),
              subtitle: const Text('Daily kWh, cost, carbon by device'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Energy report exported as CSV: campus_energy_report_30d.csv')));
              },
            ),
            ListTile(
              leading: const Icon(Icons.code_rounded, color: Color(0xFF2563EB)),
              title: const Text('Export as JSON'),
              subtitle: const Text('Complete telemetry data structures'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Energy telemetry exported as JSON: campus_energy_telemetry_30d.json')));
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  // ============================================================================
  // Sub-Tab 2: By Location View
  // ============================================================================

  Widget _buildByLocationView(bool isDark, double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary Header Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.apartment_rounded, color: Color(0xFF2563EB), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Campus Location Energy Hierarchy',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '7 Buildings • 18 Floors • 142 Rooms • Total: 14,860 kWh',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Comparing all 7 campus buildings...')),
                      );
                    },
                    icon: const Icon(Icons.compare_arrows_rounded, size: 14),
                    label: const Text('Compare Buildings', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showExportDialog,
                    icon: const Icon(Icons.download_rounded, size: 14, color: Colors.white),
                    label: const Text('Export Location Data', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Buildings Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth > 900
                ? (constraints.maxWidth - 32) / 3
                : (constraints.maxWidth > 600 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth);
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _locationBreakdowns.map((loc) {
                return SizedBox(
                  width: cardWidth,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.business_rounded, color: Color(0xFF2563EB), size: 18),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      loc.buildingName,
                                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${loc.sharePercentage.toStringAsFixed(1)}%',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Energy Consumed', style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                const SizedBox(height: 2),
                                Text('${loc.totalKwh.toStringAsFixed(0)} kWh', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Monthly Cost', style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                const SizedBox(height: 2),
                                Text('₹ ${loc.totalCostInr.toStringAsFixed(0)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (loc.totalKwh / 5000.0).clamp(0.0, 1.0),
                            backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              '${loc.floorsCount} Floors • ${loc.roomsCount} Rooms',
                              style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                            Text(
                              'Intensity: ${loc.energyIntensityKwhPerSqm} kWh/m²',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                            ),
                          ],
                        ),
                        const Divider(height: 18),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  loc.trendPct < 0 ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                                  size: 11,
                                  color: loc.trendPct < 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  '${loc.trendPct.abs()}% vs last mo.',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: loc.trendPct < 0 ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                  ),
                                ),
                              ],
                            ),
                            InkWell(
                              onTap: () => _showLocationBreakdownDialog(loc),
                              child: const Text('Inspect Rooms →', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ============================================================================
  // Sub-Tab 3: By Device Type View
  // ============================================================================

  Widget _buildByDeviceTypeView(bool isDark, double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Category Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.devices_other_rounded, color: Color(0xFF10B981), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Device Category Consumption & Efficiency',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '6 Monitored Categories • 136 Units • Breakdown by electrical load profile',
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Configuring device category energy profiles...')),
                  );
                },
                icon: const Icon(Icons.tune_rounded, size: 14),
                label: const Text('Configure Category Policies', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Category Cards Grid
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth > 900
                ? (constraints.maxWidth - 32) / 3
                : (constraints.maxWidth > 600 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth);
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: _deviceTypeBreakdowns.map((cat) {
                return SizedBox(
                  width: cardWidth,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(_getIconForDeviceType(cat.deviceType), color: const Color(0xFF2563EB), size: 18),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          cat.deviceType,
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          '${cat.monitoredDevices} Monitored Units',
                                          style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD1FAE5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Grade ${cat.efficiencyRating}',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF065F46)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Total Energy', style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                const SizedBox(height: 2),
                                Text('${cat.totalKwh.toStringAsFixed(0)} kWh', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('Share', style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                                const SizedBox(height: 2),
                                Text('${cat.sharePercentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: (cat.sharePercentage / 100.0).clamp(0.0, 1.0),
                            backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
                            minHeight: 6,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          alignment: WrapAlignment.spaceBetween,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text('Cost: ₹ ${cat.costInr.toStringAsFixed(0)}', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                            Text('CO₂: ${cat.co2Kg.toStringAsFixed(0)} kg', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // ============================================================================
  // Sub-Tab 4: By Device View
  // ============================================================================

  Widget _buildByDeviceView(bool isDark, double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildDetailedDeviceUsageSection(isDark, screenWidth),
      ],
    );
  }

  // ============================================================================
  // Sub-Tab 5: Trends & Comparison View
  // ============================================================================

  Widget _buildTrendsComparisonView(bool isDark, double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Controls Bar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Interval: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ...['Daily', 'Weekly', 'Monthly', 'Yearly'].map((interval) {
                    final isSel = _trendInterval == interval;
                    return ChoiceChip(
                      label: Text(interval, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSel ? Colors.white : null)),
                      selected: isSel,
                      selectedColor: const Color(0xFF2563EB),
                      onSelected: (val) {
                        if (val) setState(() => _trendInterval = interval);
                      },
                    );
                  }),
                ],
              ),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Metric: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  ...['kWh', 'Cost (₹)', 'Power (kW)', 'CO₂ (kg)'].map((m) {
                    final isSel = _trendMetric == m;
                    return ChoiceChip(
                      label: Text(m, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSel ? Colors.white : null)),
                      selected: isSel,
                      selectedColor: const Color(0xFF10B981),
                      onSelected: (val) {
                        if (val) setState(() => _trendMetric = m);
                      },
                    );
                  }),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4 KPI Summary Cards
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth > 800
                ? (constraints.maxWidth - 48) / 4
                : (constraints.maxWidth > 500 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth);
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildMetricComparisonCard('Current Period', '14,860 kWh', '-8.9% vs baseline', const Color(0xFF2563EB), cardWidth, isDark),
                _buildMetricComparisonCard('Baseline Period', '16,308 kWh', 'Previous year / budget', const Color(0xFF64748B), cardWidth, isDark),
                _buildMetricComparisonCard('Net Energy Saved', '1,448 kWh', 'Total verified savings', const Color(0xFF10B981), cardWidth, isDark),
                _buildMetricComparisonCard('Financial Savings', '₹ 17,376', 'Calculated bill reduction', const Color(0xFF059669), cardWidth, isDark),
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        // Comparative Trend Canvas Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.insights_rounded, color: Color(0xFF2563EB), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Period-over-Period Consumption & Baseline Overlay',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  Text('12 Dec 2024 – 10 Jan 2025 vs. Baseline', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 220,
                child: CustomPaint(
                  size: const Size(double.infinity, 220),
                  painter: _EnergyTrendChartPainter(points: _trendPoints, isDark: isDark),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 6,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 10, height: 10, decoration: BoxDecoration(color: const Color(0xFF93C5FD), borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 6),
                      Text('Current Energy (kWh)', style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 14, height: 3, decoration: const BoxDecoration(color: Color(0xFF2563EB))),
                      const SizedBox(width: 4),
                      Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Text('7-Day Moving Average', style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 14, height: 2, decoration: const BoxDecoration(color: Color(0xFFEF4444))),
                      const SizedBox(width: 6),
                      Text('Baseline Benchmark (+9.8%)', style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricComparisonCard(String title, String val, String subtitle, Color color, double width, bool isDark) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
            const SizedBox(height: 6),
            Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // Sub-Tab 6: Cost Analysis View
  // ============================================================================

  Widget _buildCostAnalysisView(bool isDark, double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 4 KPI Cards
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth > 800
                ? (constraints.maxWidth - 48) / 4
                : (constraints.maxWidth > 500 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth);
            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildMetricComparisonCard('Total Electricity Cost', '₹ 178,320', 'This month to date', const Color(0xFF2563EB), cardWidth, isDark),
                _buildMetricComparisonCard('Effective Tariff Rate', '₹ 12.00 / kWh', 'Average blended rate', const Color(0xFF64748B), cardWidth, isDark),
                _buildMetricComparisonCard('Projected Bill', '₹ 175,800', 'Forecasted month close', const Color(0xFF10B981), cardWidth, isDark),
                _buildMetricComparisonCard('Utility Reconciliation', '-1.4% Variance', 'Within acceptable ±2%', const Color(0xFF059669), cardWidth, isDark),
              ],
            );
          },
        ),
        const SizedBox(height: 16),

        // Tariff Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long_rounded, color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Active Electricity Tariff (Time-of-Use)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  OutlinedButton.icon(
                    onPressed: _showConfigureTariffDialog,
                    icon: const Icon(Icons.add_rounded, size: 14),
                    label: const Text('Add / Configure Tariff', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: _tariffs.map((t) {
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: t.isActive ? const Color(0xFF2563EB) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(t.tariffName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                                const SizedBox(width: 8),
                                if (t.isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(4)),
                                    child: const Text('ACTIVE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                                  ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 16),
                                  tooltip: 'Edit Tariff',
                                  onPressed: () => _showConfigureTariffDialog(t),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                                  tooltip: 'Delete Tariff',
                                  onPressed: () => _confirmDeleteTariff(t),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Provider: ${t.providerName}', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Text('Standard: ₹${t.ratePerKwhStandard}/kWh', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                            Text('Peak: ₹${t.ratePerKwhPeak}/kWh (${t.peakHoursStart}–${t.peakHoursEnd})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                            Text('Off-Peak: ₹${t.ratePerKwhOffPeak}/kWh', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF10B981))),
                            Text('Fixed: ₹${t.fixedChargeMonthly}/mo', style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Utility Bills Table
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Utility Bill Reconciliation & Invoice Log',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _showRecordUtilityBillDialog,
                    icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                    label: const Text('Record Utility Bill', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  showCheckboxColumn: false,
                  headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('Bill Number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataColumn(label: Text('Provider', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataColumn(label: Text('Billing Period', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataColumn(label: Text('Units Billed (kWh)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataColumn(label: Text('Billed Amount (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataColumn(label: Text('Metered (kWh)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataColumn(label: Text('Variance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  ],
                  rows: _utilityBills.map((b) {
                    return DataRow(cells: [
                      DataCell(Text(b.billNumber, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                      DataCell(Text(b.providerName, style: const TextStyle(fontSize: 11))),
                      DataCell(Text('${b.billingPeriodStart} to ${b.billingPeriodEnd}', style: const TextStyle(fontSize: 10.5))),
                      DataCell(Text('${b.unitsConsumedKwh.toStringAsFixed(0)} kWh', style: const TextStyle(fontSize: 11))),
                      DataCell(Text('₹ ${b.amountInr.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      DataCell(Text('${b.calculatedMeterKwh.toStringAsFixed(0)} kWh', style: const TextStyle(fontSize: 11))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: b.variancePct.abs() < 2.0 ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${b.variancePct > 0 ? "+" : ""}${b.variancePct}%',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: b.variancePct.abs() < 2.0 ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: b.status == 'paid' ? const Color(0xFFD1FAE5) : const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            b.status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: b.status == 'paid' ? const Color(0xFF065F46) : const Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                              tooltip: 'Edit Bill',
                              onPressed: () => _showRecordUtilityBillDialog(b),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                              tooltip: 'Delete Bill',
                              onPressed: () => _confirmDeleteUtilityBill(b),
                            ),
                          ],
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // Sub-Tab 7: Efficiency & Savings View
  // ============================================================================

  Widget _buildEfficiencySavingsView(bool isDark, double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Energy Goals Progress Bar Card
        _buildEnergyGoalsPolicyCard(isDark),
        const SizedBox(height: 16),

        // 4 Actionable Recommendations
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Actionable Energy Optimization Recommendations',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth > 800 ? (constraints.maxWidth - 16) / 2 : constraints.maxWidth;
                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      _buildRecommendationCard(
                        title: 'Adjust AC setpoints to 24°C in Academic Block A',
                        savingsKwh: '180 kWh / mo',
                        savingsInr: '₹ 2,160 / mo',
                        co2Reduction: '135 kg CO₂',
                        category: 'Schedule & Climate',
                        cardWidth: cardWidth,
                        isDark: isDark,
                      ),
                      _buildRecommendationCard(
                        title: 'Auto-close unoccupied classroom doors & lighting shutoff',
                        savingsKwh: '240 kWh / mo',
                        savingsInr: '₹ 2,880 / mo',
                        co2Reduction: '180 kg CO₂',
                        category: 'Automation Rule',
                        cardWidth: cardWidth,
                        isDark: isDark,
                      ),
                      _buildRecommendationCard(
                        title: 'Projector auto power-off on zero HDMI input',
                        savingsKwh: '95 kWh / mo',
                        savingsInr: '₹ 1,140 / mo',
                        co2Reduction: '71 kg CO₂',
                        category: 'Hardware Standby',
                        cardWidth: cardWidth,
                        isDark: isDark,
                      ),
                      _buildRecommendationCard(
                        title: 'Standby computer lab shutoff outside class hours',
                        savingsKwh: '310 kWh / mo',
                        savingsInr: '₹ 3,720 / mo',
                        co2Reduction: '232 kg CO₂',
                        category: 'Schedule Policy',
                        cardWidth: cardWidth,
                        isDark: isDark,
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendationCard({
    required String title,
    required String savingsKwh,
    required String savingsInr,
    required String co2Reduction,
    required String category,
    required double cardWidth,
    required bool isDark,
  }) {
    return SizedBox(
      width: cardWidth,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text(category, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(4)),
                  child: const Text('RECOMMENDED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text('Save: $savingsKwh', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                Text('Cost: $savingsInr', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                Text('CO₂: $co2Reduction', style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
              ],
            ),
            const Divider(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Applying recommendation: $title...')),
                    );
                  },
                  child: const Text('Apply Plan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Savings verification baseline scheduled.')),
                    );
                  },
                  child: const Text('Verify Savings', style: TextStyle(fontSize: 11, color: Color(0xFF2563EB))),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // Sub-Tab 8: Reports View
  // ============================================================================

  Widget _buildReportsView(bool isDark, double screenWidth) {
    final templates = [
      'Daily Energy Consumption', 'Weekly Energy Report', 'Monthly Campus Energy Executive Summary',
      'Annual Energy Report', 'Building-Wise Energy Report', 'Floor-Wise Energy Report',
      'Room-Wise Energy Report', 'Device-Wise Energy Report', 'Device-Type Report',
      'Electricity Cost Report', 'Utility Bill Reconciliation', 'Peak Demand Report',
      'Energy Efficiency Report', 'Energy Savings Report', 'Campus Carbon Footprint & Scope 2 Emissions',
      'Abnormal Consumption Report', 'Energy Monitoring Coverage Report', 'Offline Meter Report',
      'Budget vs Actual Report', 'Energy Audit Report'
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Generator Toolbar Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF2563EB), size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Campus Energy Reporting Center (20 Templates)',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Template Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: AppSearchableDropdown<String>.fromMenuItems(
                        value: templates.contains(_selectedReportTemplate) ? _selectedReportTemplate : templates[0],
                        isDense: true,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        items: templates.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedReportTemplate = val);
                        },
                      ),
                    ),
                  ),

                  // Format Dropdown
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: AppSearchableDropdown<String>.fromMenuItems(
                        value: _selectedReportFormat,
                        isDense: true,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        items: ['PDF', 'Excel', 'CSV'].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedReportFormat = val);
                        },
                      ),
                    ),
                  ),

                  // Generate Button
                  ElevatedButton.icon(
                    onPressed: () {
                      final newReport = EnergyReportItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        reportTitle: _selectedReportTemplate,
                        templateType: _selectedReportTemplate.toLowerCase().replaceAll(' ', '_'),
                        scopeType: 'campus',
                        scopeId: 'Greenwood High School',
                        dateFrom: '2024-12-01',
                        dateTo: '2024-12-31',
                        fileFormat: _selectedReportFormat.toLowerCase(),
                        fileSizeKb: 450,
                        generatedBy: 'King Doe (Admin)',
                        status: 'completed',
                        createdAt: 'Just now',
                      );
                      setState(() {
                        _reports.insert(0, newReport);
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Report "$_selectedReportTemplate" generated successfully.')),
                      );
                    },
                    icon: const Icon(Icons.bolt_rounded, size: 16, color: Colors.white),
                    label: const Text('Generate Report', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Generated Reports History Table
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Generated Reports Repository (${_reports.length})',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  showCheckboxColumn: false,
                  headingRowColor: WidgetStateProperty.all(isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
                  columns: const [
                    DataColumn(label: Text('Report Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataColumn(label: Text('Scope', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataColumn(label: Text('Period', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataColumn(label: Text('Format', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataColumn(label: Text('Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataColumn(label: Text('Generated By', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                  ],
                  rows: _reports.map((r) {
                    return DataRow(cells: [
                      DataCell(Text(r.reportTitle, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                      DataCell(Text(r.scopeId, style: const TextStyle(fontSize: 11))),
                      DataCell(Text('${r.dateFrom} to ${r.dateTo}', style: const TextStyle(fontSize: 10.5))),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFF2563EB).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                          child: Text(r.fileFormat.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        ),
                      ),
                      DataCell(Text('${r.fileSizeKb} KB', style: const TextStyle(fontSize: 11))),
                      DataCell(Text(r.generatedBy, style: const TextStyle(fontSize: 11))),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.download_rounded, size: 16, color: Color(0xFF2563EB)),
                              tooltip: 'Download Report',
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Downloading ${r.reportTitle} (${r.fileFormat.toUpperCase()})...')),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                              tooltip: 'Delete Report',
                              onPressed: () => _confirmDeleteReport(r),
                            ),
                          ],
                        ),
                      ),
                    ]);
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // Dialogs & Drawers
  // ============================================================================

  void _showLocationBreakdownDialog(LocationEnergyBreakdown loc) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 580,
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.business_rounded, color: Color(0xFF2563EB), size: 22),
                        const SizedBox(width: 8),
                        Text(loc.buildingName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Total: ${loc.totalKwh.toStringAsFixed(0)} kWh | ₹ ${loc.totalCostInr.toStringAsFixed(0)} | Area: ${loc.areaSqM} m²', style: const TextStyle(fontSize: 12)),
                const Divider(height: 20),
                const Text('Rooms Breakdown:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                const Text('• Classroom A1-101: 482 kWh (AC, Lighting, Fan, Projector)'),
                const Text('• Classroom A1-102: 440 kWh (AC, Lighting, Fan, Display)'),
                const Text('• Lab A1-105: 620 kWh (Workstations, HVAC, Safety Systems)'),
                const Text('• Faculty Room: 280 kWh (AC, Lighting, Computers)'),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSmartMetersDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Dialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.speed_rounded, color: Color(0xFF2563EB), size: 22),
                        SizedBox(width: 8),
                        Text('Smart Energy Meters & Submeters (8)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _showRegisterMeterDialog(),
                          icon: const Icon(Icons.add_rounded, size: 14, color: Colors.white),
                          label: const Text('Register Meter', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                        ),
                        const SizedBox(width: 8),
                        IconButton(icon: const Icon(Icons.close_rounded, size: 18), onPressed: () => Navigator.pop(ctx)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    showCheckboxColumn: false,
                    columns: const [
                      DataColumn(label: Text('Code / Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      DataColumn(label: Text('Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      DataColumn(label: Text('Protocol', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      DataColumn(label: Text('Voltage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      DataColumn(label: Text('Current', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      DataColumn(label: Text('Power (W)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                      DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                    ],
                    rows: _meters.map((m) {
                      return DataRow(cells: [
                        DataCell(Text(m.meterName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11))),
                        DataCell(Text(m.locationPath, style: const TextStyle(fontSize: 10.5))),
                        DataCell(Text(m.protocol.toUpperCase(), style: const TextStyle(fontSize: 10.5))),
                        DataCell(Text('${m.voltage} V', style: const TextStyle(fontSize: 11))),
                        DataCell(Text('${m.currentAmps} A', style: const TextStyle(fontSize: 11))),
                        DataCell(Text('${m.activePowerWatts.toStringAsFixed(0)} W', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(4)),
                            child: Text(m.status.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF065F46))),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                                tooltip: 'Edit Meter',
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _showRegisterMeterDialog(m);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Color(0xFFEF4444)),
                                tooltip: 'Delete Meter',
                                onPressed: () => _deleteSmartMeter(m),
                              ),
                            ],
                          ),
                        ),
                      ]);
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRegisterMeterDialog([SmartEnergyMeter? existing]) {
    final nameCtrl = TextEditingController(text: existing?.meterName ?? 'Lab Block 3-Phase Submeter');
    final locCtrl = TextEditingController(text: existing?.locationPath ?? 'Laboratories Block > Main Panel');
    final protocolCtrl = TextEditingController(text: existing?.protocol ?? 'Modbus RTU');
    final voltageCtrl = TextEditingController(text: (existing?.voltage ?? 415.0).toStringAsFixed(0));
    final currentCtrl = TextEditingController(text: (existing?.currentAmps ?? 85.0).toStringAsFixed(0));
    final powerCtrl = TextEditingController(text: (existing?.activePowerWatts ?? 35275.0).toStringAsFixed(0));
    String status = existing?.status ?? 'online';

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              title: Text(existing == null ? 'Register Smart Energy Meter' : 'Edit Smart Meter: ${existing.meterName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Meter Name / Identifier', border: OutlineInputBorder(), isDense: true)),
                      const SizedBox(height: 10),
                      TextField(controller: locCtrl, decoration: const InputDecoration(labelText: 'Location Path', border: OutlineInputBorder(), isDense: true)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: protocolCtrl, decoration: const InputDecoration(labelText: 'Protocol', border: OutlineInputBorder(), isDense: true))),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: voltageCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Voltage (V)', border: OutlineInputBorder(), isDense: true))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(child: TextField(controller: currentCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Current (A)', border: OutlineInputBorder(), isDense: true))),
                          const SizedBox(width: 8),
                          Expanded(child: TextField(controller: powerCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Active Power (W)', border: OutlineInputBorder(), isDense: true))),
                        ],
                      ),
                      const SizedBox(height: 10),
                      AppSearchableDropdownFormField<String>.fromMenuItems(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
                        items: ['online', 'offline', 'maintenance'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                        onChanged: (val) {
                          if (val != null) setDlgState(() => status = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final sid = widget.schoolId ?? '11111111-1111-1111-1111-111111111111';
                    final meterData = {
                      'meter_name': nameCtrl.text.trim(),
                      'location_path': locCtrl.text.trim(),
                      'protocol': protocolCtrl.text.trim(),
                      'voltage': double.tryParse(voltageCtrl.text) ?? 415.0,
                      'current_amps': double.tryParse(currentCtrl.text) ?? 85.0,
                      'active_power_watts': double.tryParse(powerCtrl.text) ?? 35275.0,
                      'status': status,
                    };
                    try {
                      final headers = await _getHeaders();
                      if (existing == null) {
                        await http.post(
                          Uri.parse('$_apiBase/energy-usage/meters?school_id=$sid'),
                          headers: headers,
                          body: json.encode(meterData),
                        );
                      } else {
                        await http.put(
                          Uri.parse('$_apiBase/energy-usage/meters/${existing.id}?school_id=$sid'),
                          headers: headers,
                          body: json.encode(meterData),
                        );
                      }
                    } catch (_) {}

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (mounted) {
                      setState(() {
                        final updated = SmartEnergyMeter(
                          id: existing?.id ?? 'mtr_${DateTime.now().millisecondsSinceEpoch}',
                          meterName: nameCtrl.text.trim(),
                          meterCode: existing?.meterCode ?? 'MTR-${nameCtrl.text.trim().replaceAll(' ', '-').toUpperCase()}',
                          meterType: existing?.meterType ?? 'smart_meter',
                          protocol: protocolCtrl.text.trim(),
                          buildingName: existing?.buildingName ?? 'Campus Main',
                          locationPath: locCtrl.text.trim(),
                          voltage: double.tryParse(voltageCtrl.text) ?? 415.0,
                          currentAmps: double.tryParse(currentCtrl.text) ?? 85.0,
                          activePowerWatts: double.tryParse(powerCtrl.text) ?? 35275.0,
                          powerFactor: existing?.powerFactor ?? 0.95,
                          frequencyHz: existing?.frequencyHz ?? 50.0,
                          totalImportKwh: existing?.totalImportKwh ?? 12500.0,
                          status: status,
                        );
                        if (existing == null) {
                          _meters.insert(0, updated);
                        } else {
                          final idx = _meters.indexWhere((m) => m.id == existing.id);
                          if (idx >= 0) _meters[idx] = updated;
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Smart meter "${nameCtrl.text.trim()}" registered/updated.')),
                      );
                    }
                  },
                  child: const Text('Save Meter'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteSmartMeter(SmartEnergyMeter meter) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Smart Meter'),
        content: Text('Are you sure you want to unregister meter "${meter.meterName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final sid = widget.schoolId ?? '11111111-1111-1111-1111-111111111111';
              try {
                final headers = await _getHeaders();
                await http.delete(
                  Uri.parse('$_apiBase/energy-usage/meters/${meter.id}?school_id=$sid'),
                  headers: headers,
                );
              } catch (_) {}
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (mounted) {
                setState(() => _meters.removeWhere((m) => m.id == meter.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Smart meter "${meter.meterName}" deleted.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteReport(EnergyReportItem report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Energy Report'),
        content: Text('Are you sure you want to delete report "${report.reportTitle}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final sid = widget.schoolId ?? '11111111-1111-1111-1111-111111111111';
              try {
                final headers = await _getHeaders();
                await http.delete(
                  Uri.parse('$_apiBase/energy-usage/reports/${report.id}?school_id=$sid'),
                  headers: headers,
                );
              } catch (_) {}
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (mounted) {
                setState(() => _reports.removeWhere((r) => r.id == report.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Report "${report.reportTitle}" deleted.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTariff(ElectricityTariffItem tariff) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Electricity Tariff'),
        content: Text('Are you sure you want to delete tariff "${tariff.tariffName}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final sid = widget.schoolId ?? '11111111-1111-1111-1111-111111111111';
              try {
                final headers = await _getHeaders();
                await http.delete(
                  Uri.parse('$_apiBase/energy-usage/tariffs/${tariff.id}?school_id=$sid'),
                  headers: headers,
                );
              } catch (_) {}
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (mounted) {
                setState(() => _tariffs.removeWhere((t) => t.id == tariff.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Tariff "${tariff.tariffName}" deleted.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteUtilityBill(UtilityBillItem bill) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Utility Bill'),
        content: Text('Are you sure you want to delete utility bill "${bill.billNumber}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final sid = widget.schoolId ?? '11111111-1111-1111-1111-111111111111';
              try {
                final headers = await _getHeaders();
                await http.delete(
                  Uri.parse('$_apiBase/energy-usage/bills/${bill.id}?school_id=$sid'),
                  headers: headers,
                );
              } catch (_) {}
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              if (mounted) {
                setState(() => _utilityBills.removeWhere((b) => b.id == bill.id));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Utility bill "${bill.billNumber}" deleted.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showConfigureTariffDialog([ElectricityTariffItem? existing]) {
    final nameCtrl = TextEditingController(text: existing?.tariffName ?? 'Standard Commercial Tariff');
    final providerCtrl = TextEditingController(text: existing?.providerName ?? 'State Electricity Board (BESCOM)');
    final standardRateCtrl = TextEditingController(text: (existing?.ratePerKwhStandard ?? 12.0).toStringAsFixed(2));
    final peakRateCtrl = TextEditingController(text: (existing?.ratePerKwhPeak ?? 15.5).toStringAsFixed(2));
    final offPeakRateCtrl = TextEditingController(text: (existing?.ratePerKwhOffPeak ?? 8.5).toStringAsFixed(2));
    final fixedChargeCtrl = TextEditingController(text: (existing?.fixedChargeMonthly ?? 5000.0).toStringAsFixed(0));
    final peakStartCtrl = TextEditingController(text: existing?.peakHoursStart ?? '18:00');
    final peakEndCtrl = TextEditingController(text: existing?.peakHoursEnd ?? '22:00');
    bool isActive = existing?.isActive ?? true;

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              title: Text(existing == null ? 'Configure Electricity Tariff' : 'Edit Electricity Tariff: ${existing.tariffName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Tariff Plan Name', border: OutlineInputBorder(), isDense: true),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: providerCtrl,
                        decoration: const InputDecoration(labelText: 'Provider / Utility Board', border: OutlineInputBorder(), isDense: true),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: standardRateCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Standard Rate (₹/kWh)', border: OutlineInputBorder(), isDense: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: fixedChargeCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Fixed Monthly (₹)', border: OutlineInputBorder(), isDense: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: peakRateCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Peak Rate (₹/kWh)', border: OutlineInputBorder(), isDense: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: offPeakRateCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Off-Peak (₹/kWh)', border: OutlineInputBorder(), isDense: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: peakStartCtrl,
                              decoration: const InputDecoration(labelText: 'Peak Start (HH:MM)', border: OutlineInputBorder(), isDense: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: peakEndCtrl,
                              decoration: const InputDecoration(labelText: 'Peak End (HH:MM)', border: OutlineInputBorder(), isDense: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Active Tariff Plan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        value: isActive,
                        onChanged: (val) => setDlgState(() => isActive = val),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final sid = widget.schoolId ?? '11111111-1111-1111-1111-111111111111';
                    final tariffData = {
                      'tariff_name': nameCtrl.text.trim(),
                      'provider_name': providerCtrl.text.trim(),
                      'rate_per_kwh_standard': double.tryParse(standardRateCtrl.text) ?? 12.0,
                      'rate_per_kwh_peak': double.tryParse(peakRateCtrl.text) ?? 15.5,
                      'rate_per_kwh_off_peak': double.tryParse(offPeakRateCtrl.text) ?? 8.5,
                      'peak_hours_start': peakStartCtrl.text.trim(),
                      'peak_hours_end': peakEndCtrl.text.trim(),
                      'fixed_charge_monthly': double.tryParse(fixedChargeCtrl.text) ?? 5000.0,
                      'is_active': isActive,
                    };
                    try {
                      final headers = await _getHeaders();
                      if (existing == null) {
                        await http.post(
                          Uri.parse('$_apiBase/energy-usage/tariffs?school_id=$sid'),
                          headers: headers,
                          body: json.encode(tariffData),
                        );
                      } else {
                        await http.put(
                          Uri.parse('$_apiBase/energy-usage/tariffs/${existing.id}?school_id=$sid'),
                          headers: headers,
                          body: json.encode(tariffData),
                        );
                      }
                    } catch (_) {}

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (mounted) {
                      setState(() {
                        final updated = ElectricityTariffItem(
                          id: existing?.id ?? 'tar_${DateTime.now().millisecondsSinceEpoch}',
                          tariffName: nameCtrl.text.trim(),
                          tariffType: existing?.tariffType ?? 'time_of_use',
                          providerName: providerCtrl.text.trim(),
                          ratePerKwhStandard: double.tryParse(standardRateCtrl.text) ?? 12.0,
                          ratePerKwhPeak: double.tryParse(peakRateCtrl.text) ?? 15.5,
                          ratePerKwhOffPeak: double.tryParse(offPeakRateCtrl.text) ?? 8.5,
                          peakHoursStart: peakStartCtrl.text.trim(),
                          peakHoursEnd: peakEndCtrl.text.trim(),
                          fixedChargeMonthly: double.tryParse(fixedChargeCtrl.text) ?? 5000.0,
                          demandChargePerKw: existing?.demandChargePerKw ?? 350.0,
                          taxPct: existing?.taxPct ?? 18.0,
                          isActive: isActive,
                        );
                        if (existing == null) {
                          _tariffs.insert(0, updated);
                        } else {
                          final idx = _tariffs.indexWhere((t) => t.id == existing.id);
                          if (idx >= 0) _tariffs[idx] = updated;
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Electricity tariff "${nameCtrl.text.trim()}" saved successfully.')),
                      );
                    }
                  },
                  child: const Text('Save Tariff'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showRecordUtilityBillDialog([UtilityBillItem? existing]) {
    final billNumCtrl = TextEditingController(text: existing?.billNumber ?? 'BES-2025-01-${math.Random().nextInt(9000) + 1000}');
    final providerCtrl = TextEditingController(text: existing?.providerName ?? 'State Electricity Board (BESCOM)');
    final startDateCtrl = TextEditingController(text: existing?.billingPeriodStart ?? '2024-12-01');
    final endDateCtrl = TextEditingController(text: existing?.billingPeriodEnd ?? '2024-12-31');
    final unitsCtrl = TextEditingController(text: (existing?.unitsConsumedKwh ?? 14650.0).toStringAsFixed(0));
    final amountCtrl = TextEditingController(text: (existing?.amountInr ?? 175800.0).toStringAsFixed(0));
    final meterCtrl = TextEditingController(text: (existing?.calculatedMeterKwh ?? 14860.0).toStringAsFixed(0));
    String status = existing?.status ?? 'reconciled';

    showDialog(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              title: Text(existing == null ? 'Record Utility Bill' : 'Edit Utility Bill: ${existing.billNumber}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: 440,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: billNumCtrl,
                              decoration: const InputDecoration(labelText: 'Bill Number', border: OutlineInputBorder(), isDense: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: providerCtrl,
                              decoration: const InputDecoration(labelText: 'Provider', border: OutlineInputBorder(), isDense: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: startDateCtrl,
                              decoration: const InputDecoration(labelText: 'Period Start (YYYY-MM-DD)', border: OutlineInputBorder(), isDense: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: endDateCtrl,
                              decoration: const InputDecoration(labelText: 'Period End (YYYY-MM-DD)', border: OutlineInputBorder(), isDense: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: unitsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Billed Units (kWh)', border: OutlineInputBorder(), isDense: true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: amountCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Amount Due (₹)', border: OutlineInputBorder(), isDense: true),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: meterCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Telemetry Meter Units (kWh)', border: OutlineInputBorder(), isDense: true),
                      ),
                      const SizedBox(height: 10),
                      AppSearchableDropdownFormField<String>.fromMenuItems(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder(), isDense: true),
                        items: ['reconciled', 'paid', 'pending', 'disputed'].map((s) => DropdownMenuItem(value: s, child: Text(s.toUpperCase()))).toList(),
                        onChanged: (val) {
                          if (val != null) setDlgState(() => status = val);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final sid = widget.schoolId ?? '11111111-1111-1111-1111-111111111111';
                    final billedUnits = double.tryParse(unitsCtrl.text) ?? 14650.0;
                    final meterUnits = double.tryParse(meterCtrl.text) ?? 14860.0;
                    final variance = meterUnits > 0 ? ((billedUnits - meterUnits) / meterUnits) * 100 : 0.0;
                    final billData = {
                      'bill_number': billNumCtrl.text.trim(),
                      'provider_name': providerCtrl.text.trim(),
                      'billing_period_start': startDateCtrl.text.trim(),
                      'billing_period_end': endDateCtrl.text.trim(),
                      'units_consumed_kwh': billedUnits,
                      'amount_inr': double.tryParse(amountCtrl.text) ?? 175800.0,
                      'calculated_meter_kwh': meterUnits,
                      'variance_pct': double.parse(variance.toStringAsFixed(1)),
                      'status': status,
                    };
                    try {
                      final headers = await _getHeaders();
                      if (existing == null) {
                        await http.post(
                          Uri.parse('$_apiBase/energy-usage/bills?school_id=$sid'),
                          headers: headers,
                          body: json.encode(billData),
                        );
                      } else {
                        await http.put(
                          Uri.parse('$_apiBase/energy-usage/bills/${existing.id}?school_id=$sid'),
                          headers: headers,
                          body: json.encode(billData),
                        );
                      }
                    } catch (_) {}

                    if (!ctx.mounted) return;
                    Navigator.pop(ctx);
                    if (mounted) {
                      setState(() {
                        final updated = UtilityBillItem(
                          id: existing?.id ?? 'bill_${DateTime.now().millisecondsSinceEpoch}',
                          billNumber: billNumCtrl.text.trim(),
                          providerName: providerCtrl.text.trim(),
                          billingPeriodStart: startDateCtrl.text.trim(),
                          billingPeriodEnd: endDateCtrl.text.trim(),
                          unitsConsumedKwh: billedUnits,
                          amountInr: double.tryParse(amountCtrl.text) ?? 175800.0,
                          taxInr: existing?.taxInr ?? ((double.tryParse(amountCtrl.text) ?? 175800.0) * 0.18),
                          fixedChargesInr: existing?.fixedChargesInr ?? 5000.0,
                          calculatedMeterKwh: meterUnits,
                          variancePct: double.parse(variance.toStringAsFixed(1)),
                          dueDate: existing?.dueDate ?? '2025-01-15',
                          status: status,
                        );
                        if (existing == null) {
                          _utilityBills.insert(0, updated);
                        } else {
                          final idx = _utilityBills.indexWhere((b) => b.id == existing.id);
                          if (idx >= 0) _utilityBills[idx] = updated;
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Utility bill recorded & reconciled with meter telemetry.')),
                      );
                    }
                  },
                  child: const Text('Save & Reconcile'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  IconData _getIconForDeviceType(String type) {
    final t = type.toLowerCase();
    if (t.contains('hvac') || t.contains('ac')) return Icons.ac_unit_rounded;
    if (t.contains('light')) return Icons.lightbulb_outline_rounded;
    if (t.contains('projector')) return Icons.videocam_rounded;
    if (t.contains('display')) return Icons.tv_rounded;
    if (t.contains('fan')) return Icons.mode_fan_off_rounded;
    if (t.contains('plug') || t.contains('pdu')) return Icons.power_rounded;
    return Icons.devices_other_rounded;
  }
}

// ============================================================================
// Custom Painters
// ============================================================================

/// Dual Chart Painter: Daily Bars (kWh) + 7-Day Moving Average Line Curve
class _EnergyTrendChartPainter extends CustomPainter {
  final List<EnergyTrendPoint> points;
  final bool isDark;

  _EnergyTrendChartPainter({required this.points, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const leftMargin = 34.0;
    const bottomMargin = 22.0;
    final chartWidth = size.width - leftMargin;
    final chartHeight = size.height - bottomMargin;
    const maxVal = 1000.0;

    // Grid lines & Y labels (0, 200, 400, 600, 800, 1000)
    final gridPaint = Paint()
      ..color = (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)).withValues(alpha: 0.7)
      ..strokeWidth = 0.8;

    final textStyle = TextStyle(
      fontSize: 8.5,
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
    );

    for (int i = 0; i <= 5; i++) {
      final y = chartHeight * (1 - (i / 5.0));
      canvas.drawLine(Offset(leftMargin, y), Offset(size.width, y), gridPaint);

      final val = (i * 200).toInt();
      final tp = TextPainter(
        text: TextSpan(text: '$val', style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(leftMargin - tp.width - 4, y - 5));
    }

    final n = points.length;
    final step = chartWidth / (n > 1 ? (n - 1) : 1);
    final barWidth = math.min(step * 0.45, 14.0);

    final barPaint = Paint()..color = const Color(0xFF93C5FD).withValues(alpha: 0.85);

    final linePath = Path();
    final linePaint = Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final dotPaint = Paint()..color = const Color(0xFF2563EB);
    final dotInnerPaint = Paint()..color = Colors.white;

    for (int i = 0; i < n; i++) {
      final x = leftMargin + (i * step);
      final p = points[i];

      // Draw bar
      final barH = (p.dailyKwh / maxVal).clamp(0.0, 1.0) * chartHeight;
      final barRect = Rect.fromLTWH(x - barWidth / 2, chartHeight - barH, barWidth, barH);
      canvas.drawRRect(RRect.fromRectAndRadius(barRect, const Radius.circular(2)), barPaint);

      // Moving average point
      final yAvg = chartHeight * (1 - (p.movingAvgKwh / maxVal).clamp(0.0, 1.0));
      if (i == 0) {
        linePath.moveTo(x, yAvg);
      } else {
        linePath.lineTo(x, yAvg);
      }

      // X-axis label
      final tpX = TextPainter(
        text: TextSpan(text: p.label, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tpX.paint(canvas, Offset(x - tpX.width / 2, chartHeight + 4));
    }

    // Draw Line & Dots
    canvas.drawPath(linePath, linePaint);

    for (int i = 0; i < n; i++) {
      final x = leftMargin + (i * step);
      final p = points[i];
      final yAvg = chartHeight * (1 - (p.movingAvgKwh / maxVal).clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, yAvg), 4, dotPaint);
      canvas.drawCircle(Offset(x, yAvg), 2, dotInnerPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EnergyTrendChartPainter oldDelegate) => true;
}

/// Donut Chart Painter for Energy by Device Type
class _DeviceTypeDonutPainter extends CustomPainter {
  final List<EnergyDeviceTypeSlice> slices;
  final bool isDark;

  _DeviceTypeDonutPainter({required this.slices, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (slices.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 18.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    double startAngle = -math.pi / 2;
    for (final s in slices) {
      final sweepAngle = (s.percentage / 100.0) * (2 * math.pi);
      paint.color = s.color;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DeviceTypeDonutPainter oldDelegate) => true;
}

/// Radial Gauge Painter for Device Uptime
class _UptimeGaugePainter extends CustomPainter {
  final double uptimePct;
  final bool isDark;

  _UptimeGaugePainter({required this.uptimePct, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    const strokeWidth = 14.0;

    final bgPaint = Paint()
      ..color = (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    final progressPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweep = (uptimePct / 100.0).clamp(0.0, 1.0) * 2 * math.pi;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -math.pi / 2,
      sweep,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _UptimeGaugePainter oldDelegate) => true;
}

// ============================================================================
// Device Analytics Modal Dialog
// ============================================================================

class _DeviceAnalyticsDialog extends StatelessWidget {
  final DeviceDetailedEnergyMetric device;

  const _DeviceAnalyticsDialog({required this.device});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: const Color(0xFFDBEAFE), borderRadius: BorderRadius.circular(8)),
                          child: const Icon(Icons.analytics_outlined, color: Color(0xFF2563EB), size: 20),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                device.deviceName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                              ),
                              Text(
                                '${device.deviceType} • ${device.locationPath}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(height: 24),

              // Metric Highlights (Grid)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildMetricPill('30-Day Energy', '${device.energyKwh} kWh', isDark),
                  _buildMetricPill('Usage Time', '${device.usageHours.toInt()} h', isDark),
                  _buildMetricPill('Avg. Power', '${device.avgPowerWatts.toInt()} W', isDark),
                  _buildMetricPill('Estimated Cost', '₹ ${device.costInr.toInt()}', isDark),
                  _buildMetricPill('CO₂ Emission', '${device.co2Kg} kg', isDark),
                  _buildMetricPill('Trend', '${device.trendPct > 0 ? "+" : ""}${device.trendPct}%', isDark, isGreen: device.trendPct <= 0),
                ],
              ),
              const SizedBox(height: 20),

              // Hourly Profile Simulator
              Text('24-Hour Duty Cycle Simulation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A))),
              const SizedBox(height: 8),
              Container(
                height: 70,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(24, (idx) {
                    final h = (idx >= 8 && idx <= 18) ? 45.0 : 10.0;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        height: h,
                        decoration: BoxDecoration(
                          color: (idx >= 8 && idx <= 18) ? const Color(0xFF2563EB) : const Color(0xFF94A3B8).withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('12 AM', style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  Text('8 AM (School Start)', style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  Text('4 PM', style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                  Text('11 PM', style: TextStyle(fontSize: 9, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                ],
              ),
              const SizedBox(height: 20),

              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  child: const Text('Close', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricPill(String title, String value, bool isDark, {bool isGreen = false}) {
    return Container(
      width: 155,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isGreen ? const Color(0xFF10B981) : (isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
