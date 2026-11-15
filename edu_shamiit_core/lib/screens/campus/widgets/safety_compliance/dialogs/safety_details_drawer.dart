import 'package:flutter/material.dart';
import '../../../models/safety_compliance_models.dart';

class SafetyDetailsDrawer extends StatelessWidget {
  final dynamic item;
  final VoidCallback onClose;
  final VoidCallback? onEdit;

  const SafetyDetailsDrawer({
    super.key,
    required this.item,
    required this.onClose,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drawerBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      width: 420,
      color: drawerBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drawer Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _getTitle(),
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textPrimary),
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    tooltip: 'Edit Record',
                    onPressed: () {
                      onClose();
                      onEdit!();
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: onClose,
                ),
              ],
            ),
          ),

          // Drawer Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: _buildDetailsBody(isDark, textPrimary, textMuted, borderColor),
            ),
          ),
        ],
      ),
    );
  }

  String _getTitle() {
    if (item is SafetyInspectionItem) return 'Inspection: ${(item as SafetyInspectionItem).inspectionCode}';
    if (item is SafetyIncidentItem) return 'Incident: ${(item as SafetyIncidentItem).incidentCode}';
    if (item is ComplianceCertificateItem) return 'Certificate: ${(item as ComplianceCertificateItem).certificateCode}';
    if (item is SafetyDrillItem) return 'Drill: ${(item as SafetyDrillItem).drillCode}';
    return 'Safety Record Details';
  }

  Widget _buildDetailsBody(bool isDark, Color textPrimary, Color textMuted, Color borderColor) {
    if (item is SafetyInspectionItem) {
      final insp = item as SafetyInspectionItem;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildField('Title', insp.title, textPrimary, textMuted),
          _buildField('Category', insp.category, textPrimary, textMuted),
          _buildField('Status', insp.status, textPrimary, textMuted),
          _buildField('Compliance Score', '${insp.complianceScore.toStringAsFixed(1)}%', textPrimary, textMuted),
          _buildField('Location', insp.locationDisplay, textPrimary, textMuted),
          _buildField('Inspector', '${insp.inspectorName} (${insp.inspectorRole})', textPrimary, textMuted),
          _buildField('Inspection Date', '${insp.inspectionDate.day}/${insp.inspectionDate.month}/${insp.inspectionDate.year}', textPrimary, textMuted),
          if (insp.findings != null && insp.findings!.isNotEmpty)
            _buildField('Findings', insp.findings!, textPrimary, textMuted),
        ],
      );
    } else if (item is SafetyIncidentItem) {
      final inc = item as SafetyIncidentItem;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildField('Title', inc.title, textPrimary, textMuted),
          _buildField('Severity', inc.severity, textPrimary, textMuted),
          _buildField('Type', inc.incidentType, textPrimary, textMuted),
          _buildField('Status', inc.status, textPrimary, textMuted),
          _buildField('Location', inc.locationDisplay, textPrimary, textMuted),
          _buildField('Reported By', '${inc.reportedByName} (${inc.reportedByRole})', textPrimary, textMuted),
          _buildField('Incident Time', '${inc.incidentTime.day}/${inc.incidentTime.month}/${inc.incidentTime.year} ${inc.incidentTime.hour}:${inc.incidentTime.minute.toString().padLeft(2, '0')}', textPrimary, textMuted),
          _buildField('First Aid Provided', inc.firstAidProvided ? 'Yes (Administered On-site)' : 'No', textPrimary, textMuted),
          if (inc.description != null && inc.description!.isNotEmpty)
            _buildField('Description', inc.description!, textPrimary, textMuted),
          if (inc.immediateActionTaken != null && inc.immediateActionTaken!.isNotEmpty)
            _buildField('Immediate Action Taken', inc.immediateActionTaken!, textPrimary, textMuted),
          if (inc.preventiveMeasures != null && inc.preventiveMeasures!.isNotEmpty)
            _buildField('Preventive Measures', inc.preventiveMeasures!, textPrimary, textMuted),
        ],
      );
    } else if (item is ComplianceCertificateItem) {
      final cert = item as ComplianceCertificateItem;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildField('Certificate Title', cert.title, textPrimary, textMuted),
          _buildField('Category', cert.category, textPrimary, textMuted),
          _buildField('Issuing Authority', cert.issuingAuthority, textPrimary, textMuted),
          _buildField('Registration Number', cert.certificateNumber, textPrimary, textMuted),
          _buildField('Validity Status', cert.status, textPrimary, textMuted),
          _buildField('Days Until Expiry', '${cert.daysToExpiry} days', textPrimary, textMuted),
          _buildField('Issue Date', '${cert.issueDate.day}/${cert.issueDate.month}/${cert.issueDate.year}', textPrimary, textMuted),
          _buildField('Expiry Date', '${cert.expiryDate.day}/${cert.expiryDate.month}/${cert.expiryDate.year}', textPrimary, textMuted),
          if (cert.notes != null && cert.notes!.isNotEmpty)
            _buildField('Compliance Notes', cert.notes!, textPrimary, textMuted),
        ],
      );
    } else if (item is SafetyDrillItem) {
      final drill = item as SafetyDrillItem;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildField('Drill Title', drill.title, textPrimary, textMuted),
          _buildField('Drill Type', drill.drillType, textPrimary, textMuted),
          _buildField('Location', drill.locationDisplay, textPrimary, textMuted),
          _buildField('Scheduled Date', '${drill.scheduledDate.day}/${drill.scheduledDate.month}/${drill.scheduledDate.year}', textPrimary, textMuted),
          _buildField('Participants', '${drill.participantsCount} persons', textPrimary, textMuted),
          _buildField('Evacuation Time', '${drill.evacuationTimeSeconds}s (Target: ${drill.targetTimeSeconds}s)', textPrimary, textMuted),
          _buildField('Rating & Status', '${drill.performanceRating} (${drill.status})', textPrimary, textMuted),
          _buildField('Coordinator', drill.coordinatorName, textPrimary, textMuted),
          if (drill.observations != null && drill.observations!.isNotEmpty)
            _buildField('Observations', drill.observations!, textPrimary, textMuted),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildField(String label, String value, Color textPrimary, Color textMuted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textMuted)),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textPrimary)),
        ],
      ),
    );
  }
}
