import 'package:flutter/material.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class StudentTransport extends StatefulWidget {
  const StudentTransport({super.key});

  @override
  State<StudentTransport> createState() => _StudentTransportState();
}

class _StudentTransportState extends State<StudentTransport> {
  final List<Map<String, dynamic>> _stops = [
    {
      'name': 'School Gate',
      'time': '3:30 PM',
      'status': 'completed',
      'eta': null,
    },
    {
      'name': 'Civil Lines',
      'time': '3:42 PM',
      'status': 'completed',
      'eta': null,
    },
    {
      'name': 'Rajpur Stop (YOURS)',
      'time': '~3:50 PM',
      'status': 'current',
      'eta': '8 min',
    },
    {
      'name': 'Shastri Nagar',
      'time': '4:00 PM',
      'status': 'pending',
      'eta': null,
    },
  ];

  @override
  Widget build(BuildContext context) {
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
                    const Text(
                      'Transport',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: StudentColors.error.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: StudentColors.error.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        children: [
                          _buildLiveDot(),
                          const SizedBox(width: 4),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                              color: StudentColors.error,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Info chips
                Row(
                  children: [
                    _buildInfoChip('??', 'Route 7B'),
                    const SizedBox(width: 8),
                    _buildInfoChip('??', 'Rajpur Stop'),
                    const SizedBox(width: 8),
                    _buildInfoChip('??', 'Seat 14'),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Map mock
                  _buildMapWidget(),
                  const SizedBox(height: 16),

                  // Bus info card
                  _buildBusInfoCard(),
                  const SizedBox(height: 16),

                  // Route stops
                  _buildRouteStops(),
                  const SizedBox(height: 16),

                  // Call driver button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Calling driver...')),
                        );
                      },
                      icon: const Icon(Icons.call, color: Colors.white),
                      label: const Text(
                        '?? Call Driver � ?? Set Alert',
                        style: TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0369A1),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveDot() {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: StudentColors.error,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildInfoChip(String icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapWidget() {
    return GestureDetector(
      onTap: () => _showFullScreenMap(),
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFBAE6FD), width: 1.5),
        ),
        child: Stack(
          children: [
            // Map background
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: const Color(0xFFE8F4E8),
              ),
              child: CustomPaint(
                painter: _MapPainter(),
                size: const Size(double.infinity, 180),
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
                  children: [
                    const Text(
                      '8 min',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ETA at your stop',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Tap hint
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '?? Tap for full map',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '?? Bus HR-29-3847',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: StudentColors.text,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatBox('8 Min', 'ETA Your Stop', const Color(0xFF1D4ED8)),
              const SizedBox(width: 10),
              _buildStatBox('38', 'Students Onboard', const Color(0xFF059669)),
              const SizedBox(width: 10),
              _buildStatBox('4', 'Stops Left', const Color(0xFFD97706)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatBox(String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
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
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteStops() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Route Stops',
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: StudentColors.text,
            ),
          ),
          const SizedBox(height: 12),
          ..._stops.asMap().entries.map((entry) {
            final index = entry.key;
            final stop = entry.value;
            return _buildStopItem(stop, index == _stops.length - 1);
          }),
        ],
      ),
    );
  }

  Widget _buildStopItem(Map<String, dynamic> stop, bool isLast) {
    final status = stop['status'] as String;
    Color dotColor;
    Color bgColor;

    switch (status) {
      case 'completed':
        dotColor = const Color(0xFF059669);
        bgColor = const Color(0xFF059669);
        break;
      case 'current':
        dotColor = StudentColors.primary;
        bgColor = const Color(0xFFEEF2FF);
        break;
      default:
        dotColor = const Color(0xFFCBD5E1);
        bgColor = const Color(0xFFF8FAFC);
    }

    return Column(
      children: [
        Row(
          children: [
            // Dot
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: bgColor,
                border: Border.all(color: dotColor, width: 2.5),
              ),
            ),
            const SizedBox(width: 12),
            // Stop info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop['name'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: status == 'current' ? FontWeight.w700 : FontWeight.w600,
                      color: status == 'current' ? StudentColors.primary : StudentColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stop['time'] as String,
                    style: const TextStyle(
                      fontSize: 10,
                      color: StudentColors.text3,
                    ),
                  ),
                ],
              ),
            ),
            // Status icon
            if (status == 'completed')
              const Icon(Icons.check_circle, size: 16, color: Color(0xFF059669))
            else if (status == 'current')
              const Text(
                '??',
                style: TextStyle(fontSize: 14),
              ),
          ],
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 5.5, top: 4),
            child: Container(
              width: 2,
              height: 20,
              color: const Color(0xFFE2E8F0),
            ),
          ),
      ],
    );
  }

  void _showFullScreenMap() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: StudentColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    '?? Live Tracking',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: StudentColors.text,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Bus HR-29-3847 � Route 7B',
                    style: TextStyle(
                      fontSize: 11,
                      color: StudentColors.text3,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Full map
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: const Color(0xFFE8F4E8),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.map, size: 64, color: Color(0xFFA7F3D0)),
                      SizedBox(height: 16),
                      Text(
                        'Live Bus Tracking Map',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF065F46),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Bus is currently 1.2 km away',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom info
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: StudentColors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: StudentColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '8',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Arriving at Rajpur Stop',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: StudentColors.text,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '1.2 km away � 38 students onboard',
                          style: TextStyle(
                            fontSize: 11,
                            color: StudentColors.text3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: StudentColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: StudentColors.success,
                      ),
                    ),
                  ),
                ],
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
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(size.width * 0.1, size.height * 0.9);
    path.lineTo(size.width * 0.1, size.height * 0.6);
    path.lineTo(size.width * 0.5, size.height * 0.6);
    path.lineTo(size.width * 0.5, size.height * 0.3);
    path.lineTo(size.width * 0.8, size.height * 0.3);
    path.lineTo(size.width * 0.8, size.height * 0.05);
    canvas.drawPath(path, paint);

    // Bus icon (moving)
    final busPaint = Paint()..color = const Color(0xFFF59E0B);
    canvas.drawCircle(Offset(size.width * 0.65, size.height * 0.4), 6, busPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}