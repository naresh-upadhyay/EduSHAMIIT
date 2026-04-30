import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/student_api_service.dart';
import 'package:edu_shamiit_ai/core/models/student_models.dart';

class StudentTransport extends ConsumerStatefulWidget {
  const StudentTransport({super.key});

  @override
  ConsumerState<StudentTransport> createState() => _StudentTransportState();
}

class _StudentTransportState extends ConsumerState<StudentTransport> {
  final StudentApiService _apiService = StudentApiService();
  
  TransportRoute? _transportRoute;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTransport();
  }

  Future<void> _loadTransport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final route = await _apiService.getTransportRoute();
      setState(() {
        _transportRoute = route;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  String _getRouteName() {
    if (_transportRoute == null) return 'N/A';
    return 'Route ${_transportRoute!.routeName}';
  }

  String _getStopName() {
    if (_transportRoute == null) return 'N/A';
    // Find the student's stop from the route
    return _transportRoute!.studentStopName ?? 'N/A';
  }

  String _getSeatNumber() {
    if (_transportRoute == null) return 'N/A';
    return 'Seat ${_transportRoute!.seatNumber ?? 'N/A'}';
  }

  String _getBusNumber() {
    if (_transportRoute == null) return 'N/A';
    return _transportRoute!.vehicleNumber ?? 'N/A';
  }

  int _getEtaMinutes() {
    if (_transportRoute == null || _transportRoute!.estimatedArrival == null) return 0;
    final now = DateTime.now();
    final arrival = _transportRoute!.estimatedArrival!;
    return arrival.difference(now).inMinutes.clamp(0, 60);
  }

  List<Map<String, dynamic>> _getStopsList() {
    if (_transportRoute == null) return [];
    
    final stops = <Map<String, dynamic>>[];
    final routeStops = _transportRoute!.stops;
    
    for (int i = 0; i < routeStops.length; i++) {
      final stop = routeStops[i];
      final isStudentStop = stop.stopName == _transportRoute!.studentStopName;
      final status = i < routeStops.length ~/ 2 ? 'done' : (isStudentStop ? 'current' : 'pending');
      
      stops.add({
        'name': isStudentStop ? '${stop.stopName} (YOURS)' : stop.stopName,
        'time': status == 'done' ? '✅ ${stop.arrivalTime}' : (status == 'current' ? '🔜 ~${stop.arrivalTime}' : '⏳ ${stop.arrivalTime}'),
        'status': status,
        'icon': i == 0 ? '🏫' : '📍',
      });
    }
    
    return stops;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error loading transport: $_error'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadTransport,
                child: Text('Retry'.tr(ref)),
              ),
            ],
          ),
        ),
      );
    }

    if (_transportRoute == null) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_bus, size: 48, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                'No transport route assigned',
                style: TextStyle(color: StudentColors.text3, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }

    final data = {
      "route": _getRouteName(),
      "stop": _getStopName(),
      "seat": _getSeatNumber(),
      "bus_number": _getBusNumber(),
      "eta": _getEtaMinutes(),
      "students_onboard": _transportRoute!.stops.length,
      "stops_left": _getStopsList().where((s) => s['status'] != 'done').length,
      "live": true,
      "stops": _getStopsList(),
    };

    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0C4A6E), Color(0xFF0369A1)],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => safeGoBack(context, '/student/dashboard'),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Transport',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildInfoChip('🚌 ${data['route']}'),
                    const SizedBox(width: 6),
                    _buildInfoChip('📍 ${data['stop']}'),
                    const SizedBox(width: 6),
                    _buildInfoChip('🎒 ${data['seat']}'),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Map placeholder
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFBAE6FD), width: 1.5),
                  ),
                  child: Stack(
                    children: [
                      // Map background
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F4E8),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: CustomPaint(
                          painter: _MapPainter(),
                        ),
                      ),
                      // ETA badge
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: StudentColors.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${data['eta']} min',
                                style: const TextStyle(
                                  fontFamily: AppFonts.heading,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const Text(
                                'ETA at your stop',
                                style: TextStyle(fontSize: 9, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Bus info card
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: StudentColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🚌 Bus ${data['bus_number']}',
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildStatBox('${data['eta']} Min', 'ETA Your Stop', const Color(0xFF1D4ED8)),
                          const SizedBox(width: 8),
                          _buildStatBox('${data['students_onboard']}', 'Students Onboard', const Color(0xFF059669)),
                          const SizedBox(width: 8),
                          _buildStatBox('${data['stops_left']}', 'Stops Left', const Color(0xFFD97706)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Route stops
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: StudentColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Route Stops',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(
                        (data['stops'] as List?)?.length ?? 0,
                        (index) => _buildStopItem((data['stops'] as List)[index], index < (data['stops'] as List).length - 1),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Call driver button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showAlertModal(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0369A1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '📞 Call Driver · 🔔 Set Alert',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ),

                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
      

    );
  }

  Widget _buildInfoChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 10, color: Colors.white70),
      ),
    );
  }

  Widget _buildStatBox(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 9, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStopItem(Map<String, dynamic> stop, bool showLine) {
    final isCurrent = stop['status'] == 'current';
    final isDone = stop['status'] == 'done';

    return Row(
      children: [
        // Dot and line
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCurrent ? StudentColors.primary : isDone ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                  width: 2.5,
                ),
                color: isCurrent ? const Color(0xFFEEF2FF) : isDone ? const Color(0xFF059669) : const Color(0xFFF8FAFC),
              ),
            ),
            if (showLine)
              Container(
                width: 2,
                height: 20,
                color: const Color(0xFFE2E8F0),
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stop['name'],
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w600,
                  color: isCurrent ? StudentColors.primary : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                stop['time'],
                style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ),
      ],
    );
  }


  void _showAlertModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text('🔔', style: TextStyle(fontSize: 50)),
            const SizedBox(height: 8),
            const Text(
              'Bus Alert Set!',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: StudentColors.text,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "You'll be notified when the bus is 2 minutes away from Rajpur Stop.",
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: StudentColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text('OK, Got it!'.tr(ref)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Simple map painter for visual representation
class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF4F46E5)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.06, size.height * 0.93);
    path.lineTo(size.width * 0.35, size.height * 0.93);
    path.lineTo(size.width * 0.35, size.height * 0.5);
    path.lineTo(size.width * 0.73, size.height * 0.5);
    path.lineTo(size.width * 0.73, size.height * 0.07);

    canvas.drawPath(path, paint);

    // Bus marker
    final busPaint = Paint()..color = const Color(0xFFF59E0B);
    canvas.drawCircle(Offset(size.width * 0.58, size.height * 0.35), 8, busPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
