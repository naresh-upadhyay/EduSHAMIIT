import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'driver_management_tab.dart';

class DriverManagementScreen extends ConsumerStatefulWidget {
  const DriverManagementScreen({super.key});

  @override
  ConsumerState<DriverManagementScreen> createState() => _DriverManagementScreenState();
}

class _DriverManagementScreenState extends ConsumerState<DriverManagementScreen> {
  final GlobalKey<DriverManagementTabState> _driverTabKey = GlobalKey<DriverManagementTabState>();

  static const _accent = Color(0xFF4F46E5);
  static const _border = Color(0xFFE2E8F0);
  static const _cardBg = Colors.white;
  static const _textPrimary = Color(0xFF0F172A);
  static const _textSecondary = Color(0xFF64748B);
  static const _bg = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.userData;
    final schoolId = user?['school_id']?.toString();

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Header
          Container(
            decoration: const BoxDecoration(
              color: _cardBg,
              border: Border(
                bottom: BorderSide(color: _border, width: 1),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: _buildHeader(),
          ),

          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: DriverManagementTab(
                key: _driverTabKey,
                schoolId: schoolId,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Left: Breadcrumb + Title
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Breadcrumb
              Row(
                children: [
                  Icon(Icons.directions_bus_rounded, size: 12, color: _textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Fleet Management',
                    style: GoogleFonts.inter(fontSize: 11, color: _textSecondary),
                  ),
                  const Icon(Icons.chevron_right, size: 14, color: _textSecondary),
                  Text(
                    'Driver Management',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _accent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Title + Description
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.people_alt_rounded,
                      color: _accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Driver Management',
                        style: GoogleFonts.inter(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      Text(
                        'Manage driver information, licenses, documents, assignments & performance',
                        style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),

        // Right: Action Buttons
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Export Button
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Preparing driver export...'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.file_download_outlined, size: 16),
              label: Text(
                'Export',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _textPrimary,
                side: const BorderSide(color: _border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(width: 10),

            // Import Button
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Import drivers via CSV...'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(Icons.upload_file_outlined, size: 16),
              label: Text(
                'Import',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _textPrimary,
                side: const BorderSide(color: _border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(width: 10),

            // Add Driver Button (primary action)
            ElevatedButton.icon(
              onPressed: () => _driverTabKey.currentState?.showAddDriverDialog(),
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: Text(
                'Add Driver',
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
