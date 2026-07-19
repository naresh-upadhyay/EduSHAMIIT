import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

class VehicleLiveDashboardScreen extends StatefulWidget {
  const VehicleLiveDashboardScreen({super.key});

  @override
  State<VehicleLiveDashboardScreen> createState() =>
      _VehicleLiveDashboardScreenState();
}

class _VehicleLiveDashboardScreenState
    extends State<VehicleLiveDashboardScreen> {
  // ═══════════════════ State ═══════════════════
  Map<String, dynamic> _summary = {};
  List<dynamic> _vehicles = [];
  List<dynamic> _alerts = [];
  List<dynamic> _trips = [];
  List<dynamic> _topDelayed = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  dynamic _popupVehicle; // vehicle shown in map popup
  DateTime _lastUpdated = DateTime.now();
  Timer? _refreshTimer;
  final MapController _mapController = MapController();

  // ═══════════════════ Lifecycle ═══════════════════
  @override
  void initState() {
    super.initState();
    _loadAll();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadAll(silent: true);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // ═══════════════════ Data ═══════════════════
  Future<void> _loadAll({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    if (silent) setState(() => _isRefreshing = true);
    try {
      final results = await Future.wait([
        _fetch('/transport/dashboard/summary'),
        _fetch('/transport/vehicles?page_size=100'),
        _fetch('/transport/alerts?is_resolved=false&page_size=50'),
        _fetch('/transport/trips?page_size=50'),
        _fetch('/transport/top-delayed?limit=5'),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = (results[0]?['data'] as Map<String, dynamic>?) ?? {};
        _vehicles =
            (results[1]?['data']?['vehicles'] as List<dynamic>?) ?? [];
        _alerts = (results[2]?['data']?['alerts'] as List<dynamic>?) ?? [];
        _trips = (results[3]?['data']?['trips'] as List<dynamic>?) ?? [];
        _topDelayed = (results[4]?['data'] as List<dynamic>?) ?? [];
        _isLoading = false;
        _isRefreshing = false;
        _lastUpdated = DateTime.now();
        if (_popupVehicle == null && _vehicles.isNotEmpty) {
          _popupVehicle = _vehicles.first;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _fetch(String path) async {
    try {
      return await ApiService().get(path, useCache: false);
    } catch (_) {
      return null;
    }
  }

  Future<void> _resolveAlert(String id) async {
    try {
      await ApiService()
          .put('/transport/alerts/$id/resolve', {'resolved_by': 'Admin'});
      _loadAll(silent: true);
    } catch (_) {}
  }

  // ═══════════════════ Computed ═══════════════════
  int get _totalVehicles => _asInt(_summary['total_vehicles']);
  int get _onRoute => _asInt(_summary['on_route']);
  int get _atSchool => _asInt(_summary['at_school']);
  int get _returning => _asInt(_summary['returning']);
  int get _delayed => _asInt(_summary['delayed']);
  int get _offline => _asInt(_summary['offline']);
  int get _studentsOnBoard => _asInt(_summary['students_on_board']);

  List<dynamic> get _upcomingTrips =>
      _trips.where((t) => t['status'] == 'scheduled').toList();
  List<dynamic> get _completedTrips =>
      _trips.where((t) => t['status'] == 'completed').toList();
  List<dynamic> get _ongoingTrips =>
      _trips.where((t) => t['status'] == 'in_progress').toList();

  int _asInt(dynamic v) => (v is int) ? v : int.tryParse('$v') ?? 0;

  String _pct(int part, int total) {
    if (total == 0) return '0%';
    return '${(part / total * 100).toStringAsFixed(2)}%';
  }

  // ═══════════════════ Helpers ═══════════════════
  static const _accent = Color(0xFF6366F1);
  static const _green = Color(0xFF22C55E);
  static const _blue = Color(0xFF3B82F6);
  static const _orange = Color(0xFFF59E0B);
  static const _red = Color(0xFFEF4444);
  static const _gray = Color(0xFF94A3B8);
  static const _bg = Color(0xFFF8FAFC);
  static const _cardBg = Colors.white;
  static const _border = Color(0xFFE2E8F0);
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);

  Color _statusColor(String? s) {
    switch (s) {
      case 'on_route':
        return _green;
      case 'at_school':
        return _blue;
      case 'returning':
        return _orange;
      case 'delayed':
        return _red;
      default:
        return _gray;
    }
  }

  IconData _statusIcon(String? s) {
    switch (s) {
      case 'on_route':
        return Icons.directions_bus_rounded;
      case 'at_school':
        return Icons.school_rounded;
      case 'returning':
        return Icons.u_turn_left_rounded;
      case 'delayed':
        return Icons.timer_outlined;
      default:
        return Icons.wifi_off_rounded;
    }
  }

  String _statusLabel(String? s) {
    switch (s) {
      case 'on_route':
        return 'On Route';
      case 'at_school':
        return 'Arrived';
      case 'returning':
        return 'Returning';
      case 'delayed':
        return 'Delayed';
      case 'offline':
        return 'Offline';
      default:
        return s ?? 'Unknown';
    }
  }

  String _fmtTime(String? iso) {
    if (iso == null) return '—';
    try {
      return DateFormat('hh:mm a').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return '—';
    }
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '—';
    try {
      return DateFormat('dd MMM, hh:mm a').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return '—';
    }
  }

  // ═══════════════════ BUILD ═══════════════════
  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 768;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: _accent),
            const SizedBox(height: 16),
            Text('Loading Vehicle Dashboard…',
                style: GoogleFonts.inter(color: _textSecondary)),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      body: RefreshIndicator(
        onRefresh: _loadAll,
        color: _accent,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(isMobile ? 16 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isMobile),
              const SizedBox(height: 20),
              _buildMetricsRow(w),
              const SizedBox(height: 20),
              isMobile
                  ? Column(children: [
                      _buildMapPanel(400),
                      const SizedBox(height: 16),
                      _buildAlertsPanel(),
                      const SizedBox(height: 16),
                      _buildVehicleStatusPanel(),
                      const SizedBox(height: 16),
                      _buildQuickActionsPanel(),
                      const SizedBox(height: 16),
                      _buildTopDelayedPanel(),
                    ])
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildMapPanel(500)),
                        const SizedBox(width: 16),
                        Expanded(
                            flex: 2,
                            child: Column(children: [
                              _buildAlertsPanel(),
                              const SizedBox(height: 16),
                              _buildVehicleStatusPanel(),
                              const SizedBox(height: 16),
                              _buildQuickActionsPanel(),
                              const SizedBox(height: 16),
                              _buildTopDelayedPanel(),
                            ])),
                      ],
                    ),
              const SizedBox(height: 20),
              isMobile
                  ? Column(children: [
                      _buildTripsSummary(),
                      const SizedBox(height: 16),
                      _buildUpcomingTrips(),
                    ])
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildTripsSummary()),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: _buildUpcomingTrips()),
                      ],
                    ),
              const SizedBox(height: 24),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  // ─────── HEADER ───────
  Widget _buildHeader(bool isMobile) {
    final lastStr = DateFormat('hh:mm:ss a').format(_lastUpdated);
    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Live Dashboard',
              style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary)),
          const SizedBox(height: 4),
          Text('Real-time overview of all vehicles and transport operations',
              style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
          const SizedBox(height: 12),
          Row(children: [
            _refreshButton(),
            const SizedBox(width: 8),
            if (_isRefreshing)
              const SizedBox(
                  width: 16,
                  height: 16,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: _accent)),
            const Spacer(),
            Text('Last updated: $lastStr',
                style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
          ]),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Live Dashboard',
                  style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary)),
              const SizedBox(height: 4),
              Text(
                  'Real-time overview of all vehicles and transport operations',
                  style:
                      GoogleFonts.inter(fontSize: 13, color: _textSecondary)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border.all(color: _border),
            borderRadius: BorderRadius.circular(8),
            color: _cardBg,
          ),
          child: Row(children: [
            Text('All Routes',
                style: GoogleFonts.inter(fontSize: 13, color: _textPrimary)),
            const SizedBox(width: 6),
            const Icon(Icons.keyboard_arrow_down_rounded,
                size: 18, color: _textSecondary),
          ]),
        ),
        const SizedBox(width: 8),
        _iconBtn(Icons.fullscreen_rounded),
        const SizedBox(width: 8),
        _refreshButton(),
        const SizedBox(width: 12),
        if (_isRefreshing)
          const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: _accent))),
        Text('Last updated: $lastStr',
            style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
      ],
    );
  }

  Widget _refreshButton() {
    return ElevatedButton.icon(
      onPressed: _loadAll,
      icon: const Icon(Icons.refresh_rounded, size: 16),
      label: const Text('Refresh'),
      style: ElevatedButton.styleFrom(
        backgroundColor: _accent,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _iconBtn(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        border: Border.all(color: _border),
        borderRadius: BorderRadius.circular(8),
        color: _cardBg,
      ),
      child: IconButton(
        onPressed: () {},
        icon: Icon(icon, size: 18, color: _textSecondary),
        padding: EdgeInsets.zero,
      ),
    );
  }

  // ─────── METRICS ROW ───────
  Widget _buildMetricsRow(double w) {
    final metrics = [
      _M('Total Vehicles', _totalVehicles, _pct(_totalVehicles, _totalVehicles),
          Icons.directions_bus_rounded, _accent),
      _M('On Route', _onRoute, _pct(_onRoute, _totalVehicles),
          Icons.location_on_rounded, _green),
      _M('Arrived at School', _atSchool, _pct(_atSchool, _totalVehicles),
          Icons.school_rounded, _blue),
      _M('Returning', _returning, _pct(_returning, _totalVehicles),
          Icons.u_turn_left_rounded, _orange),
      _M('Delayed', _delayed, _pct(_delayed, _totalVehicles),
          Icons.timer_outlined, _red),
      _M('Offline', _offline, _pct(_offline, _totalVehicles),
          Icons.wifi_off_rounded, _gray),
    ];

    if (w < 768) {
      return Column(children: [
        GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 2.0,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: metrics.map(_buildMetricCard).toList(),
        ),
        const SizedBox(height: 10),
        _buildStudentsCard(),
      ]);
    } else if (w < 1250) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GridView.count(
            crossAxisCount: 3,
            childAspectRatio: 2.6,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: metrics.map(_buildMetricCard).toList(),
          ),
          const SizedBox(height: 12),
          _buildStudentsCard(),
        ],
      );
    }

    return Row(
      children: [
        ...metrics.map(
            (m) => Expanded(child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _buildMetricCard(m),
            ))),
        SizedBox(width: 150, child: _buildStudentsCard()),
      ],
    );
  }

  Widget _buildMetricCard(_M m) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: m.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(m.icon, color: m.color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Text('${m.value}',
                        style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                            height: 1)),
                    Text(m.pct,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: m.color)),
                  ],
                ),
                const SizedBox(height: 3),
                Text(m.label,
                    style: GoogleFonts.inter(
                        fontSize: 10, color: _textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.people_rounded, color: _accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Students on Board',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: _textSecondary)),
                Text(NumberFormat('#,###').format(_studentsOnBoard),
                    style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _accent,
                        height: 1.2)),
                Text('View details',
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color: _accent,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────── LIVE MAP (OSM) ───────
  Widget _buildMapPanel(double height) {
    // Gather LatLng points from vehicles for map bounds
    final markers = <Marker>[];
    double latSum = 0, lngSum = 0;
    int gpsCount = 0;
    for (int i = 0; i < _vehicles.length; i++) {
      final v = _vehicles[i];
      final loc = v['latest_location'];
      final color = _statusColor(v['live_status']);
      double lat, lng;
      if (loc != null && loc['latitude'] != null && loc['longitude'] != null) {
        lat = (loc['latitude'] is num)
            ? (loc['latitude'] as num).toDouble()
            : double.tryParse('${loc['latitude']}') ?? 28.58;
        lng = (loc['longitude'] is num)
            ? (loc['longitude'] as num).toDouble()
            : double.tryParse('${loc['longitude']}') ?? 77.33;
      } else {
        // Fallback: spread vehicles across Noida
        lat = 28.53 + (i * 0.015);
        lng = 77.33 + ((i % 4) * 0.03);
      }
      latSum += lat;
      lngSum += lng;
      gpsCount++;
      markers.add(Marker(
        point: LatLng(lat, lng),
        width: 36,
        height: 44,
        child: GestureDetector(
          onTap: () => setState(() => _popupVehicle = v),
          child: _VehiclePin(
              color: color,
              isSelected: _popupVehicle?['id'] == v['id']),
        ),
      ));
    }
    final center = gpsCount > 0
        ? LatLng(latSum / gpsCount, lngSum / gpsCount)
        : const LatLng(28.5855, 77.3910); // default Noida

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          // Map header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              Text('Live Map - All Vehicles',
                  style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary)),
              const SizedBox(width: 12),
              _mapTab('Map', true),
              _mapTab('Satellite', false),
              const Spacer(),
              _iconBtn(Icons.fullscreen_rounded),
            ]),
          ),
          const Divider(height: 1, color: _border),
          // OSM Map content
          Expanded(
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12)),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 13.0,
                      maxZoom: 18.0,
                      minZoom: 5.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.edushamiit.admin',
                        maxZoom: 19,
                        tileProvider: CancellableNetworkTileProvider(),
                      ),
                      MarkerLayer(markers: markers),
                    ],
                  ),
                ),
                // Vehicle info popup card
                if (_popupVehicle != null) _buildVehiclePopup(),
                // Legend bar at bottom
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _cardBg.withValues(alpha: 0.92),
                      border:
                          const Border(top: BorderSide(color: _border)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _legendDot(_green, 'On Route'),
                        const SizedBox(width: 16),
                        _legendDot(_blue, 'Arrived'),
                        const SizedBox(width: 16),
                        _legendDot(_orange, 'Returning'),
                        const SizedBox(width: 16),
                        _legendDot(_red, 'Delayed'),
                        const SizedBox(width: 16),
                        _legendDot(_gray, 'Offline'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapTab(String label, bool active) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: active ? _accent : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: active ? _accent : _border),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: active ? Colors.white : _textSecondary)),
    );
  }

  Widget _legendDot(Color c, String label) {
    return Row(children: [
      Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
    ]);
  }

  Widget _buildVehiclePopup() {
    final v = _popupVehicle!;
    final loc = v['latest_location'];
    final color = _statusColor(v['live_status']);
    return Positioned(
      left: 20,
      bottom: 48,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Expanded(
                child: Text(
                    v['registration_no'] ?? v['bus_number'] ?? 'Vehicle',
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(12)),
                child: Text(_statusLabel(v['live_status']),
                    style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ),
            ]),
            const SizedBox(height: 6),
            _popupRow('Route', v['route_name'] ?? '—'),
            _popupRow('Driver', v['driver_name'] ?? '—'),
            _popupRow(
                'Speed', '${loc?['speed']?.toStringAsFixed(0) ?? '0'} km/h'),
            _popupRow(
                'ETA',
                loc?['eta_minutes'] != null
                    ? '${loc['eta_minutes']} min'
                    : '—'),
            _popupRow('Students', '${v['students_on_board'] ?? 0}'),
            const SizedBox(height: 6),
            Text('View Details',
                style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _accent,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline)),
          ],
        ),
      ),
    );
  }

  Widget _popupRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        SizedBox(
            width: 60,
            child: Text('$label:',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500))),
        Expanded(
            child: Text(value,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    color: _textPrimary,
                    fontWeight: FontWeight.w600))),
      ]),
    );
  }

  // ─────── LIVE ALERTS ───────
  Widget _buildAlertsPanel() {
    return _card(
      header: Row(children: [
        const Icon(Icons.notifications_active_rounded,
            size: 16, color: _red),
        const SizedBox(width: 6),
        Text('Live Alerts & Notifications',
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _textPrimary)),
        const Spacer(),
        Text('View All',
            style: GoogleFonts.inter(
                fontSize: 12,
                color: _accent,
                fontWeight: FontWeight.w600)),
      ]),
      child: _alerts.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_outline_rounded,
                          color: _green, size: 28),
                      const SizedBox(height: 6),
                      Text('All clear',
                          style: GoogleFonts.inter(
                              color: _textSecondary, fontSize: 12)),
                    ]),
              ),
            )
          : Column(
              children: _alerts
                  .take(4)
                  .map((a) => _alertTile(a))
                  .toList()),
    );
  }

  Widget _alertTile(dynamic a) {
    final sev = a['severity'] ?? 'info';
    final sevColor =
        sev == 'critical' ? _red : (sev == 'warning' ? _orange : _blue);
    return InkWell(
      onTap: () => _resolveAlert(a['id']),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: _border, width: 0.5))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                  color: sevColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6)),
              child:
                  Icon(Icons.warning_amber_rounded, color: sevColor, size: 14),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a['title'] ?? 'Alert',
                        style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                        a['bus_routes']?['route_name'] ?? a['message'] ?? '',
                        style: GoogleFonts.inter(
                            fontSize: 10, color: _textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ]),
            ),
            const SizedBox(width: 8),
            Text(_fmtTime(a['created_at']),
                style: GoogleFonts.inter(fontSize: 10, color: _textSecondary)),
          ],
        ),
      ),
    );
  }

  // ─────── VEHICLE STATUS (DONUT CHART) ───────
  Widget _buildVehicleStatusPanel() {
    final segments = [
      _DonutSeg('On Route', _onRoute, _green),
      _DonutSeg('Arrived', _atSchool, _blue),
      _DonutSeg('Returning', _returning, _orange),
      _DonutSeg('Delayed', _delayed, _red),
      _DonutSeg('Offline', _offline, _gray),
    ];
    return _card(
      header: Row(children: [
        Text('Vehicle Status',
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _textPrimary)),
        const Spacer(),
        Text('View Report',
            style: GoogleFonts.inter(
                fontSize: 12,
                color: _accent,
                fontWeight: FontWeight.w600)),
      ]),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Donut chart
            SizedBox(
              width: 120,
              height: 120,
              child: CustomPaint(
                painter: _DonutChartPainter(
                    segments: segments, total: _totalVehicles),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$_totalVehicles',
                          style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: _textPrimary)),
                      Text('Total',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: _textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Legend
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: segments
                    .map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(children: [
                            Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: s.color,
                                    shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(s.label,
                                    style: GoogleFonts.inter(
                                        fontSize: 11,
                                        color: _textSecondary))),
                            Text('${s.value}',
                                style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: _textPrimary)),
                            const SizedBox(width: 4),
                            Text(
                                '(${_pct(s.value, _totalVehicles)})',
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: _textSecondary)),
                          ]),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────── QUICK ACTIONS ───────
  Widget _buildQuickActionsPanel() {
    final actions = [
      const _QA(Icons.directions_bus_rounded, 'Add Vehicle', _accent),
      const _QA(Icons.person_add_alt_1_rounded, 'Add Driver', _accent),
      const _QA(Icons.route_rounded, 'Add Route', _accent),
      const _QA(Icons.location_on_rounded, 'Add Stop', _accent),
      const _QA(Icons.notifications_rounded, 'Send Notification', _accent),
      const _QA(Icons.add_road_rounded, 'Create Trip', _accent),
      const _QA(Icons.bar_chart_rounded, 'View Reports', _accent),
      const _QA(Icons.emergency_rounded, 'Emergency Alert', _red),
    ];
    return _card(
      header: Text('Quick Actions',
          style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textPrimary)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.1,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: actions
              .map((a) => InkWell(
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('${a.label} — Coming soon'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 1)));
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: _border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(a.icon, color: a.color, size: 20),
                          const SizedBox(height: 4),
                          Text(a.label,
                              style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }

  // ─────── TOP DELAYED ───────
  Widget _buildTopDelayedPanel() {
    return _card(
      header: Text('Top Delayed Vehicles',
          style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textPrimary)),
      child: _topDelayed.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No delays detected 🎉',
                  style: GoogleFonts.inter(
                      color: _textSecondary, fontSize: 12)))
          : Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(children: [
                    Expanded(
                        flex: 2,
                        child: Text('Vehicle',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _textSecondary))),
                    Expanded(
                        flex: 2,
                        child: Text('Route',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: _textSecondary))),
                    Text('Delay Time',
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _textSecondary)),
                  ]),
                ),
                ..._topDelayed.take(3).map((v) {
                  final delay = v['delay_minutes'] ?? 0;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: const BoxDecoration(
                        border: Border(
                            top: BorderSide(color: _border, width: 0.5))),
                    child: Row(children: [
                      Expanded(
                          flex: 2,
                          child: Text(
                              v['registration_no'] ??
                                  v['bus_number'] ??
                                  '—',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary))),
                      Expanded(
                          flex: 2,
                          child: Text(v['route_name'] ?? '—',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: _textSecondary))),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: _red.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('$delay mins',
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _red)),
                      ),
                    ]),
                  );
                }),
              ],
            ),
    );
  }

  // ─────── TRIPS SUMMARY ───────
  Widget _buildTripsSummary() {
    final totalTrips = _trips.length;
    final completed = _completedTrips.length;
    final ongoing = _ongoingTrips.length;
    final upcoming = _upcomingTrips.length;
    return _card(
      header: Row(children: [
        Text("Today's Trips Summary",
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _textPrimary)),
        const Spacer(),
        Text('View All',
            style: GoogleFonts.inter(
                fontSize: 12,
                color: _accent,
                fontWeight: FontWeight.w600)),
      ]),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            _tripStatRow(Icons.circle, const Color(0xFF6366F1), 'Total Trips',
                totalTrips, ''),
            _tripStatRow(Icons.circle, _green, 'Completed Trips', completed,
                totalTrips > 0 ? _pct(completed, totalTrips) : '0%'),
            _tripStatRow(Icons.circle, _blue, 'Ongoing Trips', ongoing,
                totalTrips > 0 ? _pct(ongoing, totalTrips) : '0%'),
            _tripStatRow(Icons.circle, _orange, 'Upcoming Trips', upcoming,
                totalTrips > 0 ? _pct(upcoming, totalTrips) : '0%'),
            const SizedBox(height: 12),
            // QR code section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _accent.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _accent.withValues(alpha: 0.15)),
              ),
              child: Row(children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: _cardBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: _border),
                  ),
                  child: const Icon(Icons.qr_code_2_rounded,
                      size: 40, color: _accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Transport App',
                          style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary)),
                      Text(
                          'Scan to download the driver / parent mobile app',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: _textSecondary)),
                    ],
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tripStatRow(
      IconData icon, Color color, String label, int value, String pct) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(children: [
        Container(
            width: 8,
            height: 8,
            decoration:
                BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12, color: _textSecondary))),
        Text('$value',
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _textPrimary)),
        if (pct.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(pct,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ],
      ]),
    );
  }

  // ─────── UPCOMING TRIPS TABLE ───────
  Widget _buildUpcomingTrips() {
    final trips = _upcomingTrips.take(5).toList();
    // Also show starting_soon (in_progress) trips
    final allUpcoming = [
      ..._ongoingTrips.take(2),
      ...trips,
    ];
    return _card(
      header: Row(children: [
        Text('Upcoming Trips',
            style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _textPrimary)),
        const Spacer(),
        Text('View All',
            style: GoogleFonts.inter(
                fontSize: 12,
                color: _accent,
                fontWeight: FontWeight.w600)),
      ]),
      child: allUpcoming.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text('No upcoming trips',
                  style: GoogleFonts.inter(
                      color: _textSecondary, fontSize: 12)))
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 36,
                dataRowMinHeight: 38,
                dataRowMaxHeight: 42,
                columnSpacing: 16,
                horizontalMargin: 14,
                headingTextStyle: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _textSecondary),
                dataTextStyle: GoogleFonts.inter(
                    fontSize: 11, color: _textPrimary),
                columns: const [
                  DataColumn(label: Text('Route')),
                  DataColumn(label: Text('Vehicle')),
                  DataColumn(label: Text('Driver')),
                  DataColumn(label: Text('Start Time')),
                  DataColumn(label: Text('Status')),
                ],
                rows: allUpcoming.map((t) {
                  final route = t['bus_routes'];
                  final status = t['status'] ?? 'scheduled';
                  final isStarting = status == 'in_progress';
                  return DataRow(cells: [
                    DataCell(Text(route?['route_name'] ?? '—',
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w600))),
                    DataCell(Text(
                        route?['registration_no'] ??
                            route?['bus_number'] ??
                            '—')),
                    DataCell(Text(route?['driver_name'] ?? '—')),
                    DataCell(Text(_fmtTime(t['scheduled_start']))),
                    DataCell(
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isStarting
                              ? _orange.withValues(alpha: 0.1)
                              : _blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                            isStarting ? 'Starting Soon' : 'Scheduled',
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color:
                                    isStarting ? _orange : _blue)),
                      ),
                    ),
                  ]);
                }).toList(),
              ),
            ),
    );
  }

  // ─────── FOOTER ───────
  Widget _buildFooter() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
            '© ${DateTime.now().year} EduSHAMIIT ERP. All rights reserved.',
            style: GoogleFonts.inter(fontSize: 12, color: _textSecondary)),
      ),
    );
  }

  // ─────── SHARED CARD ───────
  Widget _card({required Widget header, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: header,
          ),
          const Divider(height: 1, color: _border),
          child,
        ],
      ),
    );
  }
}

// ═══════════════════ DATA MODELS ═══════════════════
class _M {
  final String label;
  final int value;
  final String pct;
  final IconData icon;
  final Color color;
  const _M(this.label, this.value, this.pct, this.icon, this.color);
}

class _QA {
  final IconData icon;
  final String label;
  final Color color;
  const _QA(this.icon, this.label, this.color);
}

class _DonutSeg {
  final String label;
  final int value;
  final Color color;
  const _DonutSeg(this.label, this.value, this.color);
}

// ═══════════════════ VEHICLE PIN WIDGET ═══════════════════
class _VehiclePin extends StatelessWidget {
  final Color color;
  final bool isSelected;
  const _VehiclePin({required this.color, this.isSelected = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isSelected ? 32 : 26,
          height: isSelected ? 32 : 26,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: isSelected ? 10 : 6,
                  spreadRadius: isSelected ? 2 : 0),
            ],
          ),
          child: Icon(Icons.directions_bus_rounded,
              color: Colors.white, size: isSelected ? 16 : 13),
        ),
        // Pin tail
        CustomPaint(
          size: const Size(10, 8),
          painter: _PinTailPainter(color),
        ),
      ],
    );
  }
}

class _PinTailPainter extends CustomPainter {
  final Color color;
  _PinTailPainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ═══════════════════ DONUT CHART PAINTER ═══════════════════
class _DonutChartPainter extends CustomPainter {
  final List<_DonutSeg> segments;
  final int total;
  _DonutChartPainter({required this.segments, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 18.0;
    const gapAngle = 0.04;

    // Background circle
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFFF1F5F9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (total == 0) return;

    double startAngle = -pi / 2;
    for (final seg in segments) {
      if (seg.value == 0) continue;
      final sweepAngle = (seg.value / total) * 2 * pi - gapAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..color = seg.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
      startAngle += sweepAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

