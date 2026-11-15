import 'package:flutter/material.dart';
import '../../../models/maintenance_models.dart';

class MaintenanceDetailsDrawer extends StatelessWidget {
  final MaintenanceRequestItem request;
  final VoidCallback onClose;
  final VoidCallback? onUpdateStatus;
  final VoidCallback? onAssign;

  const MaintenanceDetailsDrawer({
    super.key,
    required this.request,
    required this.onClose,
    this.onUpdateStatus,
    this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    return Container(
      width: 440,
      decoration: BoxDecoration(
        color: bg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(-5, 0),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drawer Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.build_rounded, size: 18, color: Color(0xFF2563EB)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.requestCode,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      Text(
                        request.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1),

          // Drawer Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Status & Priority Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textMuted)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              request.status,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0284C7)),
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 30, color: borderColor),
                      Column(
                        children: [
                          Text('PRIORITY', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textMuted)),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              request.priority,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFDC2626)),
                            ),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 30, color: borderColor),
                      Column(
                        children: [
                          Text('TYPE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: textMuted)),
                          const SizedBox(height: 4),
                          Text(
                            request.requestType,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textPrimary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Section: Location & Reporter
                Text('LOCATION & REPORTER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textMuted)),
                const SizedBox(height: 8),
                _fieldRow('Location', request.locationDisplay, textPrimary, textMuted),
                _fieldRow('Reported By', '${request.reportedByName} (${request.reportedByRole})', textPrimary, textMuted),
                _fieldRow('Reported Date', '20 Mar 2026, 10:24 AM', textPrimary, textMuted),
                _fieldRow('Due Date', '21 Mar 2026, 10:24 AM (SLA: 24h)', textPrimary, textMuted),
                const SizedBox(height: 18),

                // Section: Technician & Assignment
                Text('ASSIGNMENT & SERVICE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textMuted)),
                const SizedBox(height: 8),
                _fieldRow('Assigned Technician', request.assignedToName ?? 'Not Assigned', textPrimary, textMuted),
                _fieldRow('Assigned Vendor', request.assignedVendorName ?? 'Internal Staff', textPrimary, textMuted),
                _fieldRow('Estimated Cost', '₹${request.estimatedCost.toStringAsFixed(2)}', textPrimary, textMuted),
                _fieldRow('Actual Cost', '₹${request.actualCost.toStringAsFixed(2)}', textPrimary, textMuted),
                const SizedBox(height: 18),

                // Section: Description
                Text('DESCRIPTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: textMuted)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: borderColor),
                  ),
                  child: Text(
                    request.description.isNotEmpty ? request.description : 'Classroom split AC is blowing warm air even at 18 degrees.',
                    style: TextStyle(fontSize: 12, color: textPrimary, height: 1.4),
                  ),
                ),
                const SizedBox(height: 20),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onUpdateStatus,
                        icon: const Icon(Icons.sync_rounded, size: 16, color: Colors.white),
                        label: const Text('Update Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onAssign,
                        icon: const Icon(Icons.person_outline, size: 16, color: Color(0xFF2563EB)),
                        label: const Text('Assign', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
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

  Widget _fieldRow(String label, String value, Color textPrimary, Color textMuted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: textMuted)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
