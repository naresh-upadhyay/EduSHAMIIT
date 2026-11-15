import 'package:flutter/material.dart';
import '../../models/visitor_models.dart';
import '../common/scannable_qr_widget.dart';
import '../../../../utils/js_helper.dart';

class VisitorGatePassDialog extends StatefulWidget {
  final VisitorItem visitor;
  final VisitorDetail360? detail;

  VisitorGatePassDialog({
    super.key,
    VisitorItem? visitor,
    VisitorItem? visit,
    this.detail,
  }) : visitor = (visitor ?? visit)!;

  @override
  State<VisitorGatePassDialog> createState() => _VisitorGatePassDialogState();
}

class _VisitorGatePassDialogState extends State<VisitorGatePassDialog> {
  bool _isThermal = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visitor = widget.visitor;
    final passNumber = visitor.passReference ?? 'GP-2024-001';

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isNarrow = screenWidth < 520;
    final dialogWidth = isNarrow ? screenWidth * 0.95 : 500.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 24, vertical: 16),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.90),
        padding: EdgeInsets.all(isNarrow ? 16 : 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(Icons.badge_outlined, color: Color(0xFF2563EB), size: 20),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Official Gate Pass',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Print Mode Selector (A4 Badge vs 80mm POS Thermal Slip)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isThermal = false),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: !_isThermal ? const Color(0xFF2563EB) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.credit_card, size: 16, color: !_isThermal ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700])),
                              const SizedBox(width: 6),
                              Text(
                                'Standard Badge (A4)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: !_isThermal ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _isThermal = true),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _isThermal ? const Color(0xFF0D9488) : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long, size: 16, color: _isThermal ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700])),
                              const SizedBox(width: 6),
                              Text(
                                'Thermal Slip (80mm)',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _isThermal ? Colors.white : (isDark ? Colors.grey[400] : Colors.grey[700]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Printable Pass Card Preview
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isThermal ? const Color(0xFF0D9488).withValues(alpha: 0.5) : const Color(0xFF2563EB).withValues(alpha: 0.4),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  // Institute Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EduSHAMIIT ERP',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: _isThermal ? const Color(0xFF0D9488) : const Color(0xFF2563EB),
                              ),
                            ),
                            Text(
                              _isThermal ? 'POS Thermal Gate Pass (80mm)' : 'Greenwood High International School',
                              style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                        child: const Text('AUTHORIZED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF15803D))),
                      ),
                    ],
                  ),
                  const Divider(height: 20, thickness: 1, color: Color(0xFFE2E8F0)),

                  // Pass Details
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Genuine Scannable QR Code
                      Column(
                        children: [
                          ScannableQrWidget(
                            passNumber: passNumber,
                            size: 104,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            passNumber,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Pass metadata
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              visitor.visitorName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Type: ${visitor.category} • ${visitor.phone}',
                              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 8),
                            _buildPassField('Pass ID', passNumber, isDark),
                            _buildPassField('Destination', visitor.location, isDark),
                            _buildPassField('Host', visitor.hostName, isDark),
                            _buildPassField('Check In', visitor.checkInAt.isNotEmpty ? visitor.checkInAt.split('T')[0] : 'Today', isDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : (_isThermal ? const Color(0xFFF0FDFA) : const Color(0xFFEFF6FF)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _isThermal
                          ? 'Thermal POS Slip: Keep securely. Escort required in residential / hostel zones.'
                          : 'Security Notice: This gate pass must be presented upon campus exit. Valid for authorized locations only.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9.5, color: _isThermal ? const Color(0xFF0F766E) : const Color(0xFF1D4ED8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Print Action
            Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    printVisitorGatePassHtml(
                      passNumber: passNumber,
                      visitorName: visitor.visitorName,
                      visitorType: visitor.category,
                      phone: visitor.phone,
                      destination: visitor.location,
                      hostName: visitor.hostName,
                      hostDepartment: visitor.hostDepartment,
                      checkInAt: visitor.checkInAt,
                      validUntil: visitor.expectedOutAt,
                      isThermal: _isThermal,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          _isThermal
                              ? '80mm Thermal Pass $passNumber sent to printer!'
                              : 'Gate Pass Badge $passNumber sent to printer!',
                        ),
                        backgroundColor: _isThermal ? const Color(0xFF0D9488) : const Color(0xFF16A34A),
                      ),
                    );
                  },
                  icon: Icon(_isThermal ? Icons.receipt_long : Icons.print_outlined, size: 18, color: Colors.white),
                  label: Text(
                    _isThermal ? 'Print 80mm POS Slip' : 'Print Badge & Pass',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isThermal ? const Color(0xFF0D9488) : const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildPassField(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF0F172A)),
            ),
          ),
        ],
      ),
    );
  }
}
