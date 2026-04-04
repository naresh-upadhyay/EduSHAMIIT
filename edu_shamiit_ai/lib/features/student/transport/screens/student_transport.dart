import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class StudentTransport extends ConsumerStatefulWidget {
  const StudentTransport({super.key});

  @override
  ConsumerState<StudentTransport> createState() => _StudentTransportState();
}

class _StudentTransportState extends ConsumerState<StudentTransport> {
  Map<String, dynamic>? _transportData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTransport();
  }

  Future<void> _loadTransport() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 300));

    setState(() {
      _transportData = {
        "route": {
          "name": "Route 5 - Dehradun",
          "bus_number": "UK 07 AB 1234",
          "driver_name": "Mr. Singh",
          "driver_phone": "+91-9876543210"
        },
        "your_stop": "ISBT Dehradun",
        "live_location": {
          "latitude": 30.3165,
          "longitude": 78.0322,
          "speed": 35.5,
          "eta_minutes": 12,
          "updated_at": "2026-04-02T17:30:00Z"
        },
      };
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    final data = _transportData!;
    final route = data['route'];
    final live = data['live_location'];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F8FF),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0C4A6E), Color(0xFF0369A1)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Transport',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ETA Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0C4A6E), Color(0xFF0369A1)],
                    ),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Estimated Arrival',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${live['eta_minutes']} Minutes',
                              style: const TextStyle(
                                fontFamily: AppFonts.heading,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Your Stop: ${data['your_stop']}',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Center(child: Text('🚌', style: TextStyle(fontSize: 32))),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Live Map
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(live['latitude'], live['longitude']),
                        initialZoom: 14.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.shamiit.edu',
                        ),
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(live['latitude'], live['longitude']),
                              width: 40,
                              height: 40,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: StudentColors.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: StudentColors.primary.withOpacity(0.4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Center(child: Text('🚌', style: TextStyle(fontSize: 20))),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Bus Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: StudentColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow('Route', route['name']),
                      const Divider(height: 24),
                      _buildInfoRow('Bus Number', route['bus_number']),
                      const Divider(height: 24),
                      _buildInfoRow('Driver', route['driver_name']),
                      const Divider(height: 24),
                      _buildInfoRow('Contact', route['driver_phone']),
                      const Divider(height: 24),
                      _buildInfoRow('Current Speed', '${live['speed']} km/h'),
                    ],
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

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 14,
            color: StudentColors.text2,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}