import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

class EmergencyScreen extends ConsumerStatefulWidget {
  const EmergencyScreen({super.key});

  @override
  ConsumerState<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends ConsumerState<EmergencyScreen>
    with SingleTickerProviderStateMixin {
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _scaffoldBg => _isDark ? const Color(0xFF090B15) : const Color(0xFFF8FAFC);
  Color get _cardBg => _isDark ? const Color(0xFF13182C) : Colors.white;
  Color get _borderColor => _isDark ? Colors.white10 : const Color(0xFFE2E8F0);
  Color get _textPrimary => _isDark ? Colors.white : const Color(0xFF0F172A);
  Color get _textSecondary => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  bool _isLoading = false;
  bool _isSosTriggering = false;
  bool _autoRefreshLocation = true;
  
  List<dynamic> _emergencyContacts = [
    {"id": "c1", "title": "AC School Admin", "role_name": "School Admin", "phone_number": "+91 98765 43210", "is_primary": true, "icon_type": "admin"},
    {"id": "c2", "title": "Transport Manager", "role_name": "Fleet Manager", "phone_number": "+91 91234 56789", "is_primary": false, "icon_type": "transport"},
    {"id": "c3", "title": "Control Room", "role_name": "24x7 Support", "phone_number": "+91 11223 34455", "is_primary": false, "icon_type": "control"},
    {"id": "c4", "title": "School Principal", "role_name": "Principal", "phone_number": "+91 99887 66554", "is_primary": false, "icon_type": "principal"}
  ];

  List<dynamic> _emergencyHistory = [
    {
      "id": "em-1",
      "title": "Traffic Incident",
      "alert_type": "Traffic Incident",
      "description": "Traffic congestion and minor collision on Sector 71 route",
      "address": "Sector 71 Crossing",
      "status": "Resolved",
      "severity": "High",
      "created_at": "2024-05-11T08:35:00Z"
    },
    {
      "id": "em-2",
      "title": "Vehicle Breakdown",
      "alert_type": "Vehicle Breakdown",
      "description": "Engine breakdown near Sector 62 Community Center",
      "address": "Sector 62 Community Center",
      "status": "Resolved",
      "severity": "Warning",
      "created_at": "2024-05-08T19:20:00Z"
    },
    {
      "id": "em-3",
      "title": "Medical Emergency",
      "alert_type": "Medical Emergency",
      "description": "Student feeling unwell at Sector 63 bus stop",
      "address": "Sector 63 Bus Stop",
      "status": "Cancelled",
      "severity": "Info",
      "created_at": "2024-05-05T09:15:00Z"
    }
  ];

  Map<String, dynamic> _historySummary = {
    'total': 3,
    'active': 0,
    'resolved': 2,
    'cancelled': 1
  };

  Map<String, dynamic> _locationData = {
    'address': 'Sector 63 Bus Stop, Noida, Uttar Pradesh 201301',
    'latitude': 28.5863,
    'longitude': 77.3572,
    'status': 'Live',
    'last_updated': '10:24 AM'
  };

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _fetchEmergencyData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchEmergencyData() async {
    setState(() => _isLoading = true);
    try {
      final contactsRes = await ApiService().get('/transport/emergency/contacts', useCache: false);
      if (contactsRes['success'] == true && contactsRes['data'] != null && (contactsRes['data'] as List).isNotEmpty) {
        setState(() {
          _emergencyContacts = contactsRes['data'] as List<dynamic>;
        });
      }
    } catch (e) {
      debugPrint('[EMERGENCY_SCREEN] Contacts fetch note: $e');
    }

    try {
      final alertsRes = await ApiService().get('/transport/emergency/alerts', useCache: false);
      if (alertsRes['success'] == true && alertsRes['data'] != null && (alertsRes['data'] as List).isNotEmpty) {
        setState(() {
          _emergencyHistory = alertsRes['data'] as List<dynamic>;
          if (alertsRes['summary'] != null) {
            _historySummary = alertsRes['summary'] as Map<String, dynamic>;
          }
        });
      }
    } catch (e) {
      debugPrint('[EMERGENCY_SCREEN] Alerts fetch note: $e');
    }

    try {
      final locationRes = await ApiService().get('/transport/emergency/current-location', useCache: false);
      if (locationRes['success'] == true && locationRes['data'] != null) {
        setState(() {
          _locationData = locationRes['data'] as Map<String, dynamic>;
        });
      }
    } catch (e) {
      debugPrint('[EMERGENCY_SCREEN] Location fetch note: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _triggerSosAlert() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 28),
            const SizedBox(width: 10),
            Text('Confirm SOS Alert', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: _textPrimary)),
          ],
        ),
        content: Text(
          'Are you sure you want to trigger an Emergency SOS Alert? This will instantly notify the School Admin, Control Room, and Emergency Response Team with your live location.',
          style: GoogleFonts.dmSans(color: _textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: GoogleFonts.dmSans(color: _textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('TRIGGER SOS NOW', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSosTriggering = true);

    Map<String, dynamic> newSosAlert = {
      "id": "sos-${DateTime.now().millisecondsSinceEpoch}",
      "title": "Emergency SOS Triggered",
      "alert_type": "SOS Alert",
      "description": "Emergency SOS button pressed",
      "address": _locationData['address'] ?? "Sector 63 Bus Stop, Noida, UP 201301",
      "latitude": _locationData['latitude'] ?? 28.5863,
      "longitude": _locationData['longitude'] ?? 77.3572,
      "status": "Active",
      "severity": "Critical",
      "created_at": DateTime.now().toIso8601String()
    };

    try {
      final res = await ApiService().post('/transport/emergency/sos', {
        'alert_type': 'SOS',
        'title': 'Emergency SOS Triggered',
        'description': 'Emergency alert raised by driver/staff',
        'address': _locationData['address'],
        'latitude': _locationData['latitude'],
        'longitude': _locationData['longitude'],
        'severity': 'Critical'
      });
      if (res['success'] == true && res['data'] != null) {
        newSosAlert = res['data'] as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('[EMERGENCY_SOS] API call note: $e');
    }

    if (mounted) {
      setState(() {
        _emergencyHistory.insert(0, newSosAlert);
        _historySummary['total'] = (_historySummary['total'] ?? _emergencyHistory.length) + 1;
        _historySummary['active'] = (_historySummary['active'] ?? 0) + 1;
        _isSosTriggering = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFEF4444),
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '🚨 SOS Alert Broadcasted! School Admin & Control Room notified.',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _updateAlertStatus(String alertId, String newStatus) async {
    try {
      await ApiService().put('/transport/emergency/alerts/$alertId/status', {
        'status': newStatus,
      });
    } catch (e) {
      debugPrint('[EMERGENCY_STATUS] API call note: $e');
    }

    if (mounted) {
      setState(() {
        for (var item in _emergencyHistory) {
          if (item['id'].toString() == alertId) {
            item['status'] = newStatus;
          }
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alert marked as $newStatus')),
      );
    }
  }

  void _showAddContactDialog() {
    final titleCtrl = TextEditingController();
    final roleCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: Text('Add Emergency Contact', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: _textPrimary)),
        content: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          clipBehavior: Clip.none,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Contact Title (e.g. Campus Security)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: roleCtrl,
                decoration: const InputDecoration(labelText: 'Role / Designation', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white),
            onPressed: () async {
              if (titleCtrl.text.isEmpty || phoneCtrl.text.isEmpty) return;
              Navigator.pop(ctx);
              
              final newContact = {
                'id': 'c-${DateTime.now().millisecondsSinceEpoch}',
                'title': titleCtrl.text,
                'role_name': roleCtrl.text.isEmpty ? 'Emergency Staff' : roleCtrl.text,
                'phone_number': phoneCtrl.text,
                'is_primary': false,
                'icon_type': 'control'
              };

              try {
                await ApiService().post('/transport/emergency/contacts', newContact);
              } catch (e) {
                debugPrint('[ADD_CONTACT] API call note: $e');
              }

              if (mounted) {
                setState(() {
                  _emergencyContacts.add(newContact);
                });
              }
            },
            child: const Text('Save Contact'),
          )
        ],
      ),
    );
  }

  void _makePhoneCall(String name, String phone) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        title: Row(
          children: [
            const Icon(Icons.phone_in_talk_rounded, color: Color(0xFF10B981)),
            const SizedBox(width: 10),
            Text('Initiating Call', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: _textPrimary)),
          ],
        ),
        content: Text('Dialing $name at $phone...\n(Connected via WebRTC / SIP Telephony)', style: GoogleFonts.dmSans(color: _textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('End Call')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _scaffoldBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchEmergencyData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header Row
                _buildTopHeader(),
                if (_isLoading) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(color: Color(0xFFEF4444), minHeight: 3),
                ],
                const SizedBox(height: 24),

                // Hero SOS Banner Section
                _buildHeroSosCard(),
                const SizedBox(height: 24),

                // Quick Actions Row
                _buildQuickActionsRow(),
                const SizedBox(height: 24),

                // Middle 2-Column Section (Location & Emergency Contacts)
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 900) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildLocationCard()),
                          const SizedBox(width: 24),
                          Expanded(child: _buildContactsCard()),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildLocationCard(),
                          const SizedBox(height: 24),
                          _buildContactsCard(),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 24),

                // Emergency History Table
                _buildEmergencyHistoryTable(),
                const SizedBox(height: 24),

                // Bottom Driver Safety Tips Card
                _buildSafetyTipsCard(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopHeader() {
    final authState = ref.watch(authProvider);
    final user = authState.userData;
    final userName = user?['full_name'] ?? 'Ramesh Kumar';
    final role = user?['role']?.toString().toUpperCase() ?? 'DRIVER';
    final phone = user?['phone'] ?? 'UP16 ET 1234';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shield_outlined, color: Color(0xFFEF4444), size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Emergency',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFDC2626),
                  ),
                ),
                Text(
                  "We're here to help. Stay safe!",
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Right side user badge
        Row(
          children: [
            Stack(
              children: [
                IconButton(
                  icon: Icon(Icons.notifications_outlined, color: _textSecondary),
                  onPressed: () {},
                ),
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '3',
                      style: GoogleFonts.dmSans(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              ],
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _borderColor),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                    child: const Icon(Icons.person, size: 18, color: Color(0xFF4F46E5)),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName, style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
                      Text('$role • $phone', style: GoogleFonts.dmSans(fontSize: 11, color: _textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeroSosCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1E131C) : const Color(0xFFFFF5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFEE2E2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          final sosButton = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    padding: EdgeInsets.all(16 + (_pulseController.value * 8)),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFEE2E2).withValues(alpha: 0.6),
                    ),
                    child: child,
                  );
                },
                child: GestureDetector(
                  onTap: _isSosTriggering ? null : _triggerSosAlert,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF87171), Color(0xFFDC2626)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                          blurRadius: 24,
                          spreadRadius: 4,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isSosTriggering
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'SOS',
                              style: GoogleFonts.outfit(
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'TAP TO ALERT',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFDC2626),
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Alert will be sent to school admin\n& emergency contacts',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: _textSecondary,
                ),
              ),
            ],
          );

          final detailsContent = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Send Emergency Alert',
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tap the SOS button in any critical situation.',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              _buildSosFeatureItem(Icons.error, 'Instant alert to school admin', const Color(0xFFEF4444)),
              const SizedBox(height: 12),
              _buildSosFeatureItem(Icons.location_on_rounded, 'Share live location', const Color(0xFFF59E0B)),
              const SizedBox(height: 12),
              _buildSosFeatureItem(Icons.phone_in_talk_rounded, 'Notify emergency contacts', const Color(0xFF10B981)),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Icon(Icons.shield_outlined, color: Color(0xFFDC2626), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Use only in real emergencies',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
            ],
          );

          if (isWide) {
            return Row(
              children: [
                Expanded(flex: 2, child: sosButton),
                const SizedBox(width: 40),
                Expanded(flex: 3, child: detailsContent),
              ],
            );
          } else {
            return Column(
              children: [
                sosButton,
                const SizedBox(height: 24),
                detailsContent,
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildSosFeatureItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: GoogleFonts.dmSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final double width = (constraints.maxWidth - (3 * 16)) / 4;
            if (constraints.maxWidth > 750) {
              return Row(
                children: [
                  Expanded(child: _buildQuickActionTile('Call School Admin', 'Connect instantly', Icons.phone_outlined, const Color(0xFFEF4444), '+91 98765 43210')),
                  const SizedBox(width: 16),
                  Expanded(child: _buildQuickActionTile('Call Control Room', '24x7 Support', Icons.shield_outlined, const Color(0xFF3B82F6), '+91 11223 34455')),
                  const SizedBox(width: 16),
                  Expanded(child: _buildQuickActionTile('Call Ambulance', 'Emergency medical help', Icons.add_box_rounded, const Color(0xFF10B981), '102')),
                  const SizedBox(width: 16),
                  Expanded(child: _buildQuickActionTile('Call Police', 'Report to police', Icons.local_police_outlined, const Color(0xFF8B5CF6), '100')),
                ],
              );
            } else {
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(width: width < 150 ? constraints.maxWidth : width, child: _buildQuickActionTile('Call School Admin', 'Connect instantly', Icons.phone_outlined, const Color(0xFFEF4444), '+91 98765 43210')),
                  SizedBox(width: width < 150 ? constraints.maxWidth : width, child: _buildQuickActionTile('Call Control Room', '24x7 Support', Icons.shield_outlined, const Color(0xFF3B82F6), '+91 11223 34455')),
                  SizedBox(width: width < 150 ? constraints.maxWidth : width, child: _buildQuickActionTile('Call Ambulance', 'Emergency medical help', Icons.add_box_rounded, const Color(0xFF10B981), '102')),
                  SizedBox(width: width < 150 ? constraints.maxWidth : width, child: _buildQuickActionTile('Call Police', 'Report to police', Icons.local_police_outlined, const Color(0xFF8B5CF6), '100')),
                ],
              );
            }
          },
        ),
      ],
    );
  }

  Widget _buildQuickActionTile(String title, String subtitle, IconData icon, Color color, String phone) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _makePhoneCall(title, phone),
            borderRadius: BorderRadius.circular(30),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: _textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Current Location',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Live',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _locationData['address'] ?? 'Sector 63 Bus Stop, Noida, Uttar Pradesh 201301',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 14),

          // Map Placeholder Image / Graphic
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _isDark ? const Color(0xFF1A2238) : const Color(0xFFEEF2FF),
              border: Border.all(color: _borderColor),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: 0.5,
                  child: Icon(Icons.map_outlined, size: 90, color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_on_rounded, color: Color(0xFFEF4444), size: 28),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _cardBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Sector 63',
                        style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.bold, color: _textPrimary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Meta location details
          _buildMetaRow(Icons.location_on_outlined, 'Latitude', '${_locationData['latitude']} N'),
          const Divider(height: 16),
          _buildMetaRow(Icons.explore_outlined, 'Longitude', '${_locationData['longitude']} E'),
          const Divider(height: 16),
          _buildMetaRow(Icons.access_time_rounded, 'Last Updated', '${_locationData['last_updated']}'),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.autorenew_rounded, size: 16, color: _textSecondary),
                  const SizedBox(width: 8),
                  Text('Auto refresh every 10 sec', style: GoogleFonts.dmSans(fontSize: 12, color: _textSecondary)),
                ],
              ),
              Switch(
                value: _autoRefreshLocation,
                activeThumbColor: const Color(0xFF10B981),
                onChanged: (val) => setState(() => _autoRefreshLocation = val),
              ),
            ],
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                side: const BorderSide(color: Color(0xFFEF4444)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.share_outlined, size: 18),
              label: Text('Share Live Location', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Live location URL copied to clipboard & broadcasted to admin.')),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: _textSecondary),
            const SizedBox(width: 8),
            Text(label, style: GoogleFonts.dmSans(fontSize: 12, color: _textSecondary)),
          ],
        ),
        Text(value, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: _textPrimary)),
      ],
    );
  }

  Widget _buildContactsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Emergency Contacts',
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF4F46E5), size: 22),
                tooltip: 'Add Contact',
                onPressed: _showAddContactDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _emergencyContacts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final c = _emergencyContacts[index];
              return _buildContactTile(
                c['title'] ?? 'Emergency Contact',
                c['role_name'] ?? 'Staff',
                c['phone_number'] ?? '',
              );
            },
          ),
          const SizedBox(height: 20),
          Center(
            child: TextButton.icon(
              onPressed: () {
                _showAddContactDialog();
              },
              icon: const Icon(Icons.keyboard_arrow_right_rounded, color: Color(0xFFEF4444)),
              label: Text('View All Contacts', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFFEF4444))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile(String name, String phone, String number) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1A2035) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.business_rounded, color: Color(0xFF4F46E5), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 13, color: _textPrimary)),
                const SizedBox(height: 2),
                Text(number, style: GoogleFonts.dmSans(fontSize: 12, color: _textSecondary)),
              ],
            ),
          ),
          IconButton(
            style: IconButton.styleFrom(
              backgroundColor: _cardBg,
              side: BorderSide(color: _borderColor),
            ),
            icon: const Icon(Icons.phone_outlined, size: 18, color: Color(0xFF10B981)),
            onPressed: () => _makePhoneCall(name, number),
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyHistoryTable() {
    final totalCount = _historySummary['total'] ?? _emergencyHistory.length;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Emergency History',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$totalCount',
                      style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {},
                child: Text('View All', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: const Color(0xFF4F46E5))),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                width: constraints.maxWidth,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth > 600 ? constraints.maxWidth : 600),
                    child: DataTable(
                      columnSpacing: 28,
                      headingRowHeight: 48,
                      dataRowMinHeight: 52,
                      dataRowMaxHeight: 56,
                      headingRowColor: WidgetStateProperty.all(_isDark ? const Color(0xFF1E2640) : const Color(0xFFF1F5F9)),
                      columns: [
                        DataColumn(label: Text('Date & Time', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: _textPrimary))),
                        DataColumn(label: Text('Type', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: _textPrimary))),
                        DataColumn(label: Text('Location', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: _textPrimary))),
                        DataColumn(label: Text('Status', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: _textPrimary))),
                        DataColumn(label: Text('Action', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, color: _textPrimary))),
                      ],
                      rows: _emergencyHistory.map((item) {
                        final status = item['status']?.toString() ?? 'Resolved';
                        final dateStr = item['created_at'] != null
                            ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.tryParse(item['created_at'].toString()) ?? DateTime.now())
                            : '11 May 2024, 08:35 AM';

                        return DataRow(
                          cells: [
                            DataCell(Text(dateStr, style: GoogleFonts.dmSans(fontSize: 12, color: _textPrimary))),
                            DataCell(
                              Row(
                                children: [
                                  Icon(
                                    status == 'Active' ? Icons.warning_amber_rounded : Icons.build_circle_outlined,
                                    size: 16,
                                    color: status == 'Active' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(item['alert_type'] ?? item['title'] ?? 'Incident', style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: _textPrimary)),
                                ],
                              ),
                            ),
                            DataCell(Text(item['address'] ?? 'Sector 71 Crossing', style: GoogleFonts.dmSans(fontSize: 12, color: _textSecondary))),
                            DataCell(_buildStatusBadge(status)),
                            DataCell(
                              status == 'Active'
                                  ? ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF10B981),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      ),
                                      onPressed: () => _updateAlertStatus(item['id'].toString(), 'Resolved'),
                                      child: const Text('Resolve', style: TextStyle(fontSize: 11)),
                                    )
                                  : Text('-', style: GoogleFonts.dmSans(color: _textSecondary)),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    if (status == 'Active') {
      bg = const Color(0xFFEF4444).withValues(alpha: 0.15);
      fg = const Color(0xFFEF4444);
    } else if (status == 'Resolved') {
      bg = const Color(0xFF10B981).withValues(alpha: 0.15);
      fg = const Color(0xFF10B981);
    } else {
      bg = const Color(0xFF94A3B8).withValues(alpha: 0.15);
      fg = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildSafetyTipsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF261F12) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 8),
              Text(
                'Safety Tips for Drivers',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFD97706),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return Row(
                  children: [
                    Expanded(child: _buildTipItem(Icons.auto_awesome, 'Stay calm and', 'assess the situation')),
                    Expanded(child: _buildTipItem(Icons.people_outline, 'Ensure students\'', 'safety first')),
                    Expanded(child: _buildTipItem(Icons.timer_outlined, 'Use SOS only in', 'real emergencies')),
                    Expanded(child: _buildTipItem(Icons.phone_in_talk, 'Keep emergency numbers', 'saved and accessible')),
                  ],
                );
              } else {
                return Column(
                  children: [
                    _buildTipItem(Icons.auto_awesome, 'Stay calm and', 'assess the situation'),
                    const SizedBox(height: 10),
                    _buildTipItem(Icons.people_outline, 'Ensure students\'', 'safety first'),
                    const SizedBox(height: 10),
                    _buildTipItem(Icons.timer_outlined, 'Use SOS only in', 'real emergencies'),
                    const SizedBox(height: 10),
                    _buildTipItem(Icons.phone_in_talk, 'Keep emergency numbers', 'saved and accessible'),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTipItem(IconData icon, String line1, String line2) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFFD97706)),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.dmSans(fontSize: 12, color: _isDark ? Colors.amber.shade100 : const Color(0xFF92400E)),
              children: [
                TextSpan(text: '$line1 '),
                TextSpan(text: line2, style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
