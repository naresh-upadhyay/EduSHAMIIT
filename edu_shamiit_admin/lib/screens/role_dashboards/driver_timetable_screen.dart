import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_core/providers/auth_provider.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';

class DriverTimetableScreen extends ConsumerStatefulWidget {
  const DriverTimetableScreen({super.key});

  @override
  ConsumerState<DriverTimetableScreen> createState() =>
      _DriverTimetableScreenState();
}

class _DriverTimetableScreenState extends ConsumerState<DriverTimetableScreen> {
  DateTime _selectedDate = DateTime(2025, 5, 28);
  String _activeViewMode = "Day"; // "Day", "Week", "Month"
  String _selectedRouteFilter = "All Routes";
  bool _isLoading = true;

  Map<String, dynamic> _scheduleData = {};
  List<dynamic> _trips = [];
  List<dynamic> _reminders = [];

  @override
  void initState() {
    super.initState();
    _fetchTimetableData();
  }

  Future<void> _fetchTimetableData() async {
    setState(() => _isLoading = true);
    try {
      final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final routeParam = _selectedRouteFilter == "All Routes"
          ? ""
          : "&route_filter=${Uri.encodeComponent(_selectedRouteFilter)}";
      final res = await ApiService().get(
          '/transport/driver/timetable?schedule_date=$formattedDate$routeParam&view_mode=$_activeViewMode');

      if (res['success'] == true && res['data'] != null) {
        final data = res['data'];
        setState(() {
          _scheduleData = data['schedule'] ?? {};
          _trips = data['trips'] ?? [];
          _reminders = data['reminders'] ?? [];
          _isLoading = false;
        });
      } else {
        _loadFallbackData();
      }
    } catch (e) {
      debugPrint("[TIMETABLE_SCREEN] API Error: $e");
      _loadFallbackData();
    }
  }

  void _loadFallbackData() {
    setState(() {
      _scheduleData = {
        "routes_assigned": 2,
        "total_trips": 4,
        "total_stops": 24,
        "total_students": 78,
        "total_duty_time": "4h 30m",
        "completed_trips": 1,
        "upcoming_trips": 3,
        "pending_trips": 0,
        "skipped_trips": 0,
      };
      _trips = [
        {
          "route_code": "Route 101",
          "route_name": "Morning Route",
          "duty_type": "Pickup Duty",
          "trip_title": "Trip 1 (Pickup)",
          "time_window": "06:20 AM - 08:00 AM",
          "status": "Ongoing",
          "badge_color": "purple",
          "total_stops": 7,
          "total_students": 32,
          "stops": [
            {
              "stop_name": "Start Point\nSector 62 Comm. Center",
              "stop_time": "06:20 AM",
              "student_count": 4,
              "is_start": true,
              "status": "completed"
            },
            {
              "stop_name": "Fortune\nResidency",
              "stop_time": "06:35 AM",
              "student_count": 5,
              "status": "completed"
            },
            {
              "stop_name": "Sector 63\nBus Stop",
              "stop_time": "06:50 AM",
              "student_count": 6,
              "status": "completed"
            },
            {
              "stop_name": "Sunrise\nApartments",
              "stop_time": "07:05 AM",
              "student_count": 7,
              "status": "ongoing"
            },
            {
              "stop_name": "Sector 71\nCrossing",
              "stop_time": "07:20 AM",
              "student_count": 6,
              "status": "pending"
            },
            {
              "stop_name": "Sector 72\nMetro Station",
              "stop_time": "07:35 AM",
              "student_count": 4,
              "status": "pending"
            },
            {
              "stop_name": "Greenfield\nInternational School",
              "stop_time": "07:50 AM",
              "student_count": 0,
              "is_end": true,
              "status": "pending"
            },
          ]
        },
        {
          "route_code": "Route 102",
          "route_name": "Evening Route",
          "duty_type": "Drop Duty",
          "trip_title": "Trip 1 (Drop)",
          "time_window": "02:15 PM - 04:45 PM",
          "status": "Upcoming",
          "badge_color": "blue",
          "total_stops": 7,
          "total_students": 0,
          "stops": [
            {
              "stop_name": "Greenfield\nInternational School",
              "stop_time": "02:15 PM",
              "student_count": 0,
              "is_start": true,
              "status": "pending"
            },
            {
              "stop_name": "Sector 72\nMetro Station",
              "stop_time": "02:30 PM",
              "student_count": 0,
              "status": "pending"
            },
            {
              "stop_name": "Sunrise\nApartments",
              "stop_time": "02:45 PM",
              "student_count": 0,
              "status": "pending"
            },
            {
              "stop_name": "Sector 63\nBus Stop",
              "stop_time": "03:05 PM",
              "student_count": 0,
              "status": "pending"
            },
            {
              "stop_name": "Fortune\nResidency",
              "stop_time": "03:20 PM",
              "student_count": 0,
              "status": "pending"
            },
            {
              "stop_name": "Sector 62\nComm. Center",
              "stop_time": "03:40 PM",
              "student_count": 0,
              "status": "pending"
            },
            {
              "stop_name": "End Point",
              "stop_time": "04:00 PM",
              "student_count": 0,
              "is_end": true,
              "status": "pending"
            },
          ]
        },
        {
          "route_code": "Route 103",
          "route_name": "School Special Duty",
          "duty_type": "Pickup Duty",
          "trip_title": "Trip 1 (Pickup)",
          "time_window": "11:30 AM - 12:30 PM",
          "status": "Upcoming",
          "badge_color": "green",
          "total_stops": 5,
          "total_students": 0,
          "stops": [
            {
              "stop_name": "Coaching Center\nSector 18",
              "stop_time": "11:30 AM",
              "student_count": 0,
              "is_start": true,
              "status": "pending"
            },
            {
              "stop_name": "City Center\nMarket",
              "stop_time": "11:45 AM",
              "student_count": 0,
              "status": "pending"
            },
            {
              "stop_name": "Mayur Vihar\nPhase 1",
              "stop_time": "12:00 PM",
              "student_count": 0,
              "status": "pending"
            },
            {
              "stop_name": "Sector 50\nCommunity Hall",
              "stop_time": "12:15 PM",
              "student_count": 0,
              "status": "pending"
            },
            {
              "stop_name": "Greenfield\nInternational School",
              "stop_time": "12:30 PM",
              "student_count": 0,
              "is_end": true,
              "status": "pending"
            },
          ]
        },
        {
          "route_code": "Route 104",
          "route_name": "Activity Duty",
          "duty_type": "Drop Duty",
          "trip_title": "Trip 1 (Drop)",
          "time_window": "05:30 PM - 06:30 PM",
          "status": "Upcoming",
          "badge_color": "orange",
          "total_stops": 5,
          "total_students": 0,
          "stops": [
            {
              "stop_name": "Greenfield\nInternational School",
              "stop_time": "05:30 PM",
              "student_count": 0,
              "is_start": true,
              "status": "pending"
            },
            {
              "stop_name": "Mayur Vihar\nPhase 1",
              "stop_time": "05:45 PM",
              "student_count": 0,
              "status": "pending"
            },
            {
              "stop_name": "City Center\nMarket",
              "stop_time": "06:00 PM",
              "student_count": 0,
              "status": "pending"
            },
            {
              "stop_name": "Sector 18\nCoaching Center",
              "stop_time": "06:15 PM",
              "student_count": 0,
              "status": "pending"
            },
            {
              "stop_name": "End Point\nHome",
              "stop_time": "06:30 PM",
              "student_count": 0,
              "is_end": true,
              "status": "pending"
            },
          ]
        }
      ];
      _reminders = [
        {
          "route_code": "Route 102",
          "trip_title": "Trip 1 (Drop)",
          "starts_in": "Starts in 2h 15m"
        },
        {
          "route_code": "Route 103",
          "trip_title": "Trip 1 (Pickup)",
          "starts_in": "Starts in 4h 15m"
        },
      ];
      _isLoading = false;
    });
  }

  void _exportScheduleCSV() {
    try {
      final buffer = StringBuffer();
      buffer.writeln("Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}");
      buffer.writeln(
          "Route Code,Route Name,Duty Type,Trip Title,Time Window,Status,Stops,Students");
      for (final t in _trips) {
        buffer.writeln(
            "${t['route_code']},${t['route_name']},${t['duty_type']},${t['trip_title']},${t['time_window']},${t['status']},${t['total_stops']},${t['total_students']}");
      }
      final bytes = utf8.encode(buffer.toString());
      final base64Str = base64Encode(bytes);
      final uri = 'data:text/csv;charset=utf-8;base64,$base64Str';
      launchUrl(Uri.parse(uri));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "Schedule for ${DateFormat('dd MMM yyyy').format(_selectedDate)} exported to CSV!"),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } catch (e) {
      debugPrint("CSV export error: $e");
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024, 1, 1),
      lastDate: DateTime(2028, 12, 31),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _fetchTimetableData();
    }
  }

  void _showRoutesDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.alt_route, color: Color(0xFF4F46E5)),
            const SizedBox(width: 8),
            Text(
                "Assigned Routes (${DateFormat('dd MMM yyyy').format(_selectedDate)})"),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _trips.map((t) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFFEEF2FF),
                  child: Text(
                      t['route_code'].toString().replaceAll('Route ', ''),
                      style: const TextStyle(
                          color: Color(0xFF4F46E5),
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                ),
                title: Text("${t['route_code']} - ${t['route_name']}",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${t['duty_type']} • ${t['time_window']}"),
                trailing: Chip(
                  label: Text("${t['total_stops']} Stops",
                      style:
                          const TextStyle(fontSize: 10, color: Colors.white)),
                  backgroundColor: const Color(0xFF4F46E5),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  void _showStopsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.pin_drop_outlined, color: Color(0xFF4F46E5)),
            SizedBox(width: 8),
            Text("All Route Stops List"),
          ],
        ),
        content: SizedBox(
          width: 550,
          height: 380,
          child: ListView.builder(
            itemCount: _trips.length,
            itemBuilder: (context, index) {
              final trip = _trips[index];
              final stops = trip['stops'] as List<dynamic>? ?? [];
              return ExpansionTile(
                title: Text("${trip['route_code']} (${stops.length} Stops)",
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(trip['route_name']),
                children: stops.map<Widget>((s) {
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.location_on_outlined,
                        size: 18, color: Color(0xFF64748B)),
                    title:
                        Text(s['stop_name'].toString().replaceAll('\n', ' ')),
                    trailing: Text(s['stop_time'] ?? '',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 11)),
                  );
                }).toList(),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  void _showHistoryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.history, color: Color(0xFF4F46E5)),
            SizedBox(width: 8),
            Text("Completed Trip History"),
          ],
        ),
        content: const SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.check_circle, color: Color(0xFF10B981)),
                title: Text("Route 101 - Morning Pickup"),
                subtitle: Text("Completed at 07:55 AM • 32 Students Dropped"),
              ),
              ListTile(
                leading: Icon(Icons.check_circle, color: Color(0xFF10B981)),
                title: Text("Route 102 - Morning Drop"),
                subtitle: Text(
                    "Completed yesterday at 04:30 PM • 28 Students Dropped"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Close")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopHeader(),
            const SizedBox(height: 20),
            _buildMetricsRow(),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: Today's Schedule Cards List / Week View / Month View
                Expanded(
                  flex: 7,
                  child: _activeViewMode == "Week"
                      ? _buildWeekViewSchedule()
                      : _activeViewMode == "Month"
                          ? _buildMonthViewSchedule()
                          : _buildScheduleList(),
                ),
                const SizedBox(width: 20),
                // Right Column: Calendar, Summary, Quick Actions & Reminders
                Expanded(
                  flex: 3,
                  child: _buildRightSidebar(),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // ─── TOP HEADER BAR ────────────────────────────────────────────────────────
  Widget _buildTopHeader() {
    final authState = ref.watch(authProvider);
    final user = authState.userData ?? {};
    final fullName = user['full_name'] ?? 'Ramesh Kumar';
    final avatarUrl = user['avatar_url'];

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Timetable",
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A)),
                ),
                SizedBox(height: 4),
                Text(
                  "View your daily schedule and all assigned routes",
                  style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined,
                      color: Color(0xFF64748B)),
                  onPressed: () {},
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.chat_bubble_outline,
                      color: Color(0xFF64748B)),
                  onPressed: () {},
                ),
                const SizedBox(width: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: const Color(0xFF4F46E5),
                        backgroundImage:
                            avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? Text(fullName.isNotEmpty ? fullName[0] : 'R',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold))
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fullName,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A))),
                          const Text("Driver • UP16 ET 1234",
                              style: TextStyle(
                                  fontSize: 10, color: Color(0xFF64748B))),
                        ],
                      )
                    ],
                  ),
                )
              ],
            )
          ],
        ),
        const SizedBox(height: 16),
        // Filter Controls Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                // Date Navigator Button
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today,
                            size: 14, color: Color(0xFF4F46E5)),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd MMM yyyy, EEEE').format(_selectedDate),
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1E293B)),
                        ),
                        const SizedBox(width: 12),
                        InkWell(
                          onTap: () {
                            setState(() => _selectedDate = _selectedDate
                                .subtract(const Duration(days: 1)));
                            _fetchTimetableData();
                          },
                          child: const Icon(Icons.chevron_left,
                              size: 18, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () {
                            setState(() => _selectedDate =
                                _selectedDate.add(const Duration(days: 1)));
                            _fetchTimetableData();
                          },
                          child: const Icon(Icons.chevron_right,
                              size: 18, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () {
                    setState(() => _selectedDate = DateTime.now());
                    _fetchTimetableData();
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text("Today",
                      style: TextStyle(
                          color: Color(0xFF4F46E5),
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 16),
                // View Mode Toggle Segment
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: ["Day", "Week", "Month"].map((mode) {
                      final isActive = _activeViewMode == mode;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _activeViewMode = mode);
                          _fetchTimetableData();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(0xFF4F46E5)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            mode,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isActive
                                  ? Colors.white
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(width: 16),
                // Route Dropdown Filter
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedRouteFilter,
                      icon: const Icon(Icons.keyboard_arrow_down,
                          size: 18, color: Color(0xFF64748B)),
                      items: [
                        "All Routes",
                        "Route 101",
                        "Route 102",
                        "Route 103",
                        "Route 104"
                      ].map((r) {
                        return DropdownMenuItem(
                            value: r,
                            child: Text(r,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500)));
                      }).toList(),
                      onChanged: (val) {
                        setState(
                            () => _selectedRouteFilter = val ?? "All Routes");
                        _fetchTimetableData();
                      },
                    ),
                  ),
                )
              ],
            ),
            ElevatedButton.icon(
              onPressed: _exportScheduleCSV,
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: const Text("Export Schedule",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF4F46E5),
                elevation: 0,
                side: const BorderSide(color: Color(0xFF4F46E5)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            )
          ],
        )
      ],
    );
  }

  // ─── 5 METRICS KPI ROW (DYNAMIC FROM DB QUERY RESULT) ──────────────────────
  Widget _buildMetricsRow() {
    final metrics = [
      {
        "icon": Icons.alt_route_rounded,
        "color": const Color(0xFF4F46E5),
        "val": "${_scheduleData['routes_assigned'] ?? 0}",
        "label": "Routes Assigned"
      },
      {
        "icon": Icons.directions_bus_rounded,
        "color": const Color(0xFF0EA5E9),
        "val": "${_scheduleData['total_trips'] ?? 0}",
        "label": "Trips / Duties"
      },
      {
        "icon": Icons.location_on_rounded,
        "color": const Color(0xFF10B981),
        "val": "${_scheduleData['total_stops'] ?? 0}",
        "label": "Stops"
      },
      {
        "icon": Icons.people_alt_rounded,
        "color": const Color(0xFF8B5CF6),
        "val": "${_scheduleData['total_students'] ?? 0}",
        "label": "Students"
      },
      {
        "icon": Icons.access_time_filled_rounded,
        "color": const Color(0xFFF59E0B),
        "val": "${_scheduleData['total_duty_time'] ?? '0h 0m'}",
        "label": "Total Duty Time"
      },
    ];

    return Row(
      children: metrics.map((m) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x05000000),
                    blurRadius: 4,
                    offset: Offset(0, 2))
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: (m['color'] as Color).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(m['icon'] as IconData,
                      color: m['color'] as Color, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(m['val'] as String,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A))),
                    Text(m['label'] as String,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500)),
                  ],
                )
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─── SCHEDULE LIST (DAY VIEW) ──────────────────────────────────────────────
  Widget _buildScheduleList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Schedule for ${DateFormat('dd MMM yyyy, EEEE').format(_selectedDate)}",
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A)),
            ),
            Text(
              "${_trips.length} Trips Found",
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF64748B)),
            )
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator()))
        else if (_trips.isEmpty)
          Container(
            padding: const EdgeInsets.all(30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Column(
                children: [
                  Icon(Icons.event_busy, size: 36, color: Color(0xFF94A3B8)),
                  SizedBox(height: 8),
                  Text("No trips scheduled for this date",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748B))),
                ],
              ),
            ),
          )
        else
          ..._trips.map((trip) => _buildTripCard(trip)),
      ],
    );
  }

  Widget _buildWeekViewSchedule() {
    // Calculate 7 days of the week starting from Monday of selectedDate
    final firstDayOfWeek =
        _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final weekDays =
        List.generate(7, (i) => firstDayOfWeek.add(Duration(days: i)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Weekly Schedule (${DateFormat('dd MMM').format(weekDays.first)} - ${DateFormat('dd MMM yyyy').format(weekDays.last)})",
          style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 12),
        ...weekDays.map((day) {
          final isSelectedDay = day.year == _selectedDate.year &&
              day.month == _selectedDate.month &&
              day.day == _selectedDate.day;
          final isSunday = (day.weekday == 7);
          final dayName = DateFormat('EEEE, dd MMM').format(day);

          return GestureDetector(
            onTap: () {
              setState(() => _selectedDate = day);
              _fetchTimetableData();
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelectedDay ? const Color(0xFFEEF2FF) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: isSelectedDay
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFFE2E8F0),
                    width: isSelectedDay ? 2 : 1),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      dayName,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isSelectedDay
                              ? const Color(0xFF4F46E5)
                              : const Color(0xFF0F172A)),
                    ),
                  ),
                  Expanded(
                    child: isSunday
                        ? const Text("Weekend Off - No Duty",
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                                fontStyle: FontStyle.italic))
                        : Wrap(
                            spacing: 8,
                            children: _trips.map((t) {
                              return Chip(
                                label: Text(
                                    "${t['route_code']} (${t['time_window']})",
                                    style: const TextStyle(fontSize: 10)),
                                backgroundColor: isSelectedDay
                                    ? const Color(0xFF4F46E5)
                                    : const Color(0xFFF1F5F9),
                                labelStyle: TextStyle(
                                    color: isSelectedDay
                                        ? Colors.white
                                        : const Color(0xFF1E293B)),
                              );
                            }).toList(),
                          ),
                  )
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildMonthViewSchedule() {
    final daysInMonth =
        DateUtils.getDaysInMonth(_selectedDate.year, _selectedDate.month);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              "Monthly Overview (${DateFormat('MMMM yyyy').format(_selectedDate)})",
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, childAspectRatio: 1.2),
            itemCount: daysInMonth,
            itemBuilder: (ctx, idx) {
              final dNum = idx + 1;
              final iterDate =
                  DateTime(_selectedDate.year, _selectedDate.month, dNum);
              final isTarget = dNum == _selectedDate.day;
              final isSun = (iterDate.weekday == 7);

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedDate = iterDate);
                  _fetchTimetableData();
                },
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isTarget
                        ? const Color(0xFF4F46E5)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: isTarget
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("$dNum",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isTarget
                                  ? Colors.white
                                  : const Color(0xFF0F172A))),
                      const SizedBox(height: 2),
                      Text(isSun ? "Off" : "${_trips.length} Duties",
                          style: TextStyle(
                              fontSize: 8,
                              color: isTarget
                                  ? Colors.white70
                                  : const Color(0xFF64748B))),
                    ],
                  ),
                ),
              );
            },
          )
        ],
      ),
    );
  }

  Widget _buildTripCard(Map<String, dynamic> trip) {
    final badgeColorStr = trip['badge_color'] ?? 'purple';
    Color themeColor;
    Color lightBg;
    switch (badgeColorStr) {
      case 'blue':
        themeColor = const Color(0xFF2563EB);
        lightBg = const Color(0xFFEFF6FF);
        break;
      case 'green':
        themeColor = const Color(0xFF059669);
        lightBg = const Color(0xFFECFDF5);
        break;
      case 'orange':
        themeColor = const Color(0xFFEA580C);
        lightBg = const Color(0xFFFFF7ED);
        break;
      default:
        themeColor = const Color(0xFF4F46E5);
        lightBg = const Color(0xFFEEF2FF);
    }

    final stops = trip['stops'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x05000000), blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left Pill Header Badge
          Container(
            width: 170,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: lightBg,
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: themeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    trip['route_code'] ?? '',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 8),
                Text(trip['route_name'] ?? '',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A))),
                Text(trip['duty_type'] ?? '',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF64748B))),
                const SizedBox(height: 12),
                Text(trip['time_window'] ?? '',
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF334155))),
                const SizedBox(height: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: trip['status'] == 'Ongoing'
                        ? const Color(0xFFD1FAE5)
                        : const Color(0xFFDBEAFE),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    trip['status'] ?? 'Upcoming',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: trip['status'] == 'Ongoing'
                          ? const Color(0xFF065F46)
                          : const Color(0xFF1E40AF),
                    ),
                  ),
                )
              ],
            ),
          ),
          // Right Content: Trip Stepper
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        trip['trip_title'] ?? '',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF0F172A)),
                      ),
                      Text(
                        "${trip['total_stops'] ?? stops.length} Stops      ${trip['total_students'] ?? 0} Students",
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Horizontal Stepper Line
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(stops.length, (index) {
                        final stop = stops[index];
                        final isStart = stop['is_start'] == true;
                        final isEnd = stop['is_end'] == true;
                        final isLast = index == stops.length - 1;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Column(
                              children: [
                                // Time
                                Text(stop['stop_time'] ?? '',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B))),
                                const SizedBox(height: 6),
                                // Stop Node Icon
                                isStart
                                    ? Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: const Color(0xFF10B981),
                                            borderRadius:
                                                BorderRadius.circular(4)),
                                        child: const Text("Start",
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold)),
                                      )
                                    : isEnd
                                        ? const Icon(Icons.location_on,
                                            color: Colors.redAccent, size: 18)
                                        : Container(
                                            width: 10,
                                            height: 10,
                                            decoration: BoxDecoration(
                                                color: themeColor,
                                                shape: BoxShape.circle),
                                          ),
                                const SizedBox(height: 6),
                                // Stop Name
                                SizedBox(
                                  width: 95,
                                  child: Text(
                                    stop['stop_name'] ?? '',
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF475569)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Student count
                                Text(
                                  (stop['student_count'] ?? 0) > 0
                                      ? "${stop['student_count']} Students"
                                      : "-",
                                  style: const TextStyle(
                                      fontSize: 9, color: Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                            if (!isLast)
                              Container(
                                width: 30,
                                height: 2,
                                margin: const EdgeInsets.only(top: 22),
                                color: themeColor.withValues(alpha: 0.3),
                              ),
                          ],
                        );
                      }),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  // ─── RIGHT SIDEBAR ────────────────────────────────────────────────────────
  Widget _buildRightSidebar() {
    return Column(
      children: [
        _buildCalendarCard(),
        const SizedBox(height: 16),
        _buildSummaryCard(),
        const SizedBox(height: 16),
        _buildQuickActionsGrid(),
        const SizedBox(height: 16),
        _buildRemindersCard(),
      ],
    );
  }

  Widget _buildCalendarCard() {
    final daysInMonth =
        DateUtils.getDaysInMonth(_selectedDate.year, _selectedDate.month);
    final firstWeekday =
        DateTime(_selectedDate.year, _selectedDate.month, 1).weekday % 7;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left,
                    size: 20, color: Color(0xFF64748B)),
                onPressed: () {
                  setState(() => _selectedDate =
                      DateTime(_selectedDate.year, _selectedDate.month - 1, 1));
                  _fetchTimetableData();
                },
              ),
              Text(
                DateFormat('MMMM yyyy').format(_selectedDate),
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A)),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right,
                    size: 20, color: Color(0xFF64748B)),
                onPressed: () {
                  setState(() => _selectedDate =
                      DateTime(_selectedDate.year, _selectedDate.month + 1, 1));
                  _fetchTimetableData();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children:
                ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"].map((d) {
              return SizedBox(
                width: 28,
                child: Text(d,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8))),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7, mainAxisSpacing: 4, crossAxisSpacing: 4),
            itemCount: daysInMonth + firstWeekday,
            itemBuilder: (ctx, idx) {
              if (idx < firstWeekday) {
                return const SizedBox.shrink();
              }
              final dayNum = idx - firstWeekday + 1;
              final isSelected = dayNum == _selectedDate.day;

              return GestureDetector(
                onTap: () {
                  setState(() => _selectedDate = DateTime(
                      _selectedDate.year, _selectedDate.month, dayNum));
                  _fetchTimetableData();
                },
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF4F46E5)
                        : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      "$dayNum",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color:
                            isSelected ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ),
              );
            },
          )
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Schedule Summary",
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
          _buildSummaryRow(Colors.green, "Completed",
              "${_scheduleData['completed_trips'] ?? 0}"),
          _buildSummaryRow(Colors.blue, "Upcoming",
              "${_scheduleData['upcoming_trips'] ?? 0}"),
          _buildSummaryRow(Colors.orange, "Pending",
              "${_scheduleData['pending_trips'] ?? 0}"),
          _buildSummaryRow(
              Colors.red, "Skipped", "${_scheduleData['skipped_trips'] ?? 0}"),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(Color dotColor, String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: dotColor, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
          const Spacer(),
          Text(val,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildQuickActionsGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Quick Actions",
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.5,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _buildActionBtn(Icons.alt_route, "View Routes", "All Assigned",
                  _showRoutesDialog),
              _buildActionBtn(Icons.pin_drop_outlined, "View Stops",
                  "All Stops List", _showStopsDialog),
              _buildActionBtn(Icons.history, "Route History", "Past Schedules",
                  _showHistoryDialog),
              _buildActionBtn(Icons.file_download_outlined, "Export Schedule",
                  "CSV / Excel", _exportScheduleCSV),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildActionBtn(
      IconData icon, String title, String sub, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF4F46E5), size: 18),
            const SizedBox(height: 4),
            Text(title,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A))),
            Text(sub,
                style: const TextStyle(fontSize: 8, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }

  Widget _buildRemindersCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Upcoming Reminders",
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 12),
          if (_reminders.isEmpty)
            const Text("No pending reminders",
                style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))
          else
            ..._reminders.map((r) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 16, color: Color(0xFF4F46E5)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("${r['route_code']} - ${r['trip_title']}",
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A))),
                          Text(r['starts_in'] ?? '',
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xFF64748B))),
                        ],
                      ),
                    )
                  ],
                ),
              );
            }),
          Center(
            child: TextButton(
              onPressed: () {},
              child: const Text("View All Reminders",
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4F46E5))),
            ),
          )
        ],
      ),
    );
  }
}
