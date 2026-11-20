import 'package:flutter/material.dart';

class CampusHeaderBar extends StatelessWidget {
  final int activeTab;
  final VoidCallback onAddBuilding;
  final VoidCallback onBulkImport;
  final VoidCallback onExport;
  final VoidCallback? onAddFacility;
  final VoidCallback? onBookSpace;
  final VoidCallback? onRecurringBooking;
  final VoidCallback? onRaiseMaintenanceRequest;
  final VoidCallback? onMaintenancePlan;
  final VoidCallback? onReportSafetyIncident;
  final VoidCallback? onScheduleDrill;
  final VoidCallback? onAddDevice;
  final VoidCallback? onLogUtilityReading;
  final VoidCallback? onExportReport;

  const CampusHeaderBar({
    super.key,
    this.activeTab = 0,
    required this.onAddBuilding,
    required this.onBulkImport,
    required this.onExport,
    this.onAddFacility,
    this.onBookSpace,
    this.onRecurringBooking,
    this.onRaiseMaintenanceRequest,
    this.onMaintenancePlan,
    this.onReportSafetyIncident,
    this.onScheduleDrill,
    this.onAddDevice,
    this.onLogUtilityReading,
    this.onExportReport,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    String subtitle;
    List<Widget> actionButtons = [];

    Widget buildOutlinedBtn(String label, IconData icon, VoidCallback? onPressed) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5)),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? const Color(0xFF93C5FD) : primaryColor,
          side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }

    Widget buildElevatedBtn(String label, IconData icon, VoidCallback? onPressed) {
      return ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16, color: Colors.white),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }

    switch (activeTab) {
      case 1:
        subtitle = 'Track institutional grounds, auditoriums, sports facilities, labs & cafeterias';
        actionButtons = [
          buildOutlinedBtn('Export Facilities', Icons.file_download_outlined, onExport),
          buildElevatedBtn('Add Facility', Icons.add, onAddFacility),
        ];
        break;
      case 2:
        subtitle = 'Schedule class spaces, auditoriums, labs, and exam venues across campus';
        actionButtons = [
          buildOutlinedBtn('Export Bookings', Icons.file_download_outlined, onExport),
          buildElevatedBtn('Book a Space', Icons.calendar_month, onBookSpace),
        ];
        break;
      case 3:
        subtitle = 'Campus work orders, technician SLAs, breakdown tickets and preventative plans';
        actionButtons = [
          buildOutlinedBtn('Export Requests', Icons.file_download_outlined, onExport),
          if (onMaintenancePlan != null)
            buildOutlinedBtn('Maintenance Plan', Icons.assignment_turned_in_outlined, onMaintenancePlan),
          buildElevatedBtn('Raise Request', Icons.build_rounded, onRaiseMaintenanceRequest),
        ];
        break;
      case 4:
        subtitle = 'Fire safety audits, building structural clearances, statutory NOCs & evacuation drills';
        actionButtons = [
          buildOutlinedBtn('Export Safety Log', Icons.file_download_outlined, onExport),
          if (onScheduleDrill != null)
            buildOutlinedBtn('Schedule Drill', Icons.schedule_rounded, onScheduleDrill),
          buildElevatedBtn('Report Incident', Icons.warning_amber_rounded, onReportSafetyIncident),
        ];
        break;
      case 5:
        subtitle = 'Smart campus IoT automation, sensors, HVAC relays, surveillance & energy controllers';
        actionButtons = [
          buildOutlinedBtn('Export Devices', Icons.file_download_outlined, onExport),
          buildElevatedBtn('Add Device', Icons.add, onAddDevice),
        ];
        break;
      case 6:
        subtitle = 'Substation grid power, rooftop solar, diesel generators, water tanks & RO plants';
        actionButtons = [
          buildOutlinedBtn('Export Readings', Icons.file_download_outlined, onExport),
          buildElevatedBtn('Log Reading', Icons.bolt_rounded, onLogUtilityReading),
        ];
        break;
      case 7:
        subtitle = 'Executive campus analytics, space utilization audits, equipment health & ESG reports';
        actionButtons = [
          buildElevatedBtn('Export Report', Icons.file_download_outlined, onExportReport ?? onExport),
        ];
        break;
      default:
        subtitle = 'Manage campus infrastructure, facilities, spaces and resources of your institution';
        actionButtons = [
          buildOutlinedBtn('Export', Icons.file_download_outlined, onExport),
          buildOutlinedBtn('Bulk Import', Icons.file_upload_outlined, onBulkImport),
          buildElevatedBtn('Add Building', Icons.add, onAddBuilding),
        ];
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 750;

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.domain_rounded,
                        color: primaryColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Campus Management',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            overflow: TextOverflow.ellipsis,
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
                  children: actionButtons,
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.domain_rounded,
                  color: primaryColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Campus Management',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                children: actionButtons,
              ),
            ],
          );
        },
      ),
    );
  }
}
