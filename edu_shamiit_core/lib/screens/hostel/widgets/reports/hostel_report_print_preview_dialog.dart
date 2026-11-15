import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../utils/js_helper.dart';

class HostelReportPrintPreviewDialog extends StatelessWidget {
  final String reportTitle;
  final String academicYear;
  final List<String> columns;
  final List<Map<String, dynamic>> records;

  const HostelReportPrintPreviewDialog({
    super.key,
    required this.reportTitle,
    required this.academicYear,
    required this.columns,
    required this.records,
  });

  dynamic _resolveCellValue(String columnLabel, Map<String, dynamic> r) {
    if (r.containsKey(columnLabel) && r[columnLabel] != null) return r[columnLabel];
    final snake = columnLabel.toLowerCase().replaceAll(' ', '_').replaceAll('#', 'number').replaceAll('&', 'and');
    if (r.containsKey(snake) && r[snake] != null) return r[snake];

    switch (columnLabel.toLowerCase().trim()) {
      case 'building':
      case 'hostel':
        return r['building_name'] ?? r['hostel_name'] ?? '-';
      case 'floor':
        return r['floor_name'] ?? '-';
      case 'room no':
      case 'room':
      case 'room number':
        return r['room_number'] ?? '-';
      case 'building & room':
        final b = r['building_name'] ?? r['hostel_name'] ?? '-';
        final rm = r['room_number'] ?? '-';
        return '$b ($rm)';
      case 'type':
        return r['room_type'] ?? r['request_type'] ?? '-';
      case 'subtype':
        return r['request_subtype'] ?? '-';
      case 'capacity':
        return r['capacity'] ?? '-';
      case 'occupied':
        return r['occupied_beds'] ?? '-';
      case 'vacant':
        return r['vacant_beds'] ?? '-';
      case 'status':
        return r['room_status'] ?? r['status'] ?? r['payment_status'] ?? r['resident_status'] ?? '-';
      case 'monthly fee':
        final fee = r['monthly_fee'];
        return fee != null ? '₹${NumberFormat('#,##,###').format(fee)}' : '-';
      case 'restriction':
        return r['gender_restriction'] ?? '-';
      case 'roll no':
      case 'admission no':
        return r['roll_no'] ?? r['admission_no'] ?? '-';
      case 'student name':
      case 'resident':
      case 'reported by':
        return r['student_name'] ?? '-';
      case 'class':
        return r['class_name'] ?? '-';
      case 'bed':
        return r['bed_label'] ?? '-';
      case 'admission date':
        return r['admission_date'] ?? '-';
      case 'fee status':
        return r['fee_status'] ?? '-';
      case 'resident status':
        return r['resident_status'] ?? '-';
      case 'guardian phone':
      case 'contact':
        return r['guardian_phone'] ?? r['student_phone'] ?? '-';
      case 'parent name':
        return r['father_name'] ?? r['mother_name'] ?? 'Guardian';
      case 'invoice #':
      case 'invoice number':
        return r['invoice_number'] ?? '-';
      case 'total billed':
      case 'billed':
      case 'billed (₹)':
        final amt = r['billed_amount'];
        return amt != null ? '₹${NumberFormat('#,##,###').format(amt)}' : '-';
      case 'paid':
      case 'paid (₹)':
        final amt = r['paid_amount'];
        return amt != null ? '₹${NumberFormat('#,##,###').format(amt)}' : '-';
      case 'balance due':
      case 'pending due':
      case 'pending due (₹)':
        final amt = r['pending_due'];
        return amt != null ? '₹${NumberFormat('#,##,###').format(amt)}' : '-';
      case 'due date':
        return r['due_date'] ?? '-';
      case 'overdue days':
        final od = r['overdue_days'];
        return od != null ? '$od days' : '0 days';
      case 'gate pass #':
      case 'gate pass':
        return r['gate_pass_code'] ?? '-';
      case 'reason':
      case 'purpose':
        return r['purpose'] ?? r['reason'] ?? '-';
      case 'destination':
        return r['destination'] ?? '-';
      case 'departure':
      case 'departure date':
        return r['departure_date'] ?? '-';
      case 'return':
      case 'expected return':
        return r['expected_return'] ?? '-';
      case 'ticket #':
      case 'ticket number':
        return r['ticket_number'] ?? '-';
      case 'title':
        return r['title'] ?? '-';
      case 'category':
        return r['category'] ?? '-';
      case 'priority':
        return r['priority'] ?? '-';
      case 'assigned staff':
      case 'assigned to':
        return r['assigned_staff'] ?? 'Unassigned';
      case 'lodged date':
        return r['lodged_date'] ?? '-';
      case 'resolved date':
        return r['resolved_date'] ?? '-';
    }
    return r[columnLabel] ?? '-';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nowFormatted = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 850),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Action Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.print_rounded, color: Color(0xFF2563EB), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Print Preview — $reportTitle',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Standard A4 Document Format • ${records.length} total rows',
                                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          printHostelReportHtml(
                            reportTitle: reportTitle,
                            academicYear: academicYear,
                            columns: columns,
                            records: records,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.print_rounded, color: Colors.white, size: 18),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text('Opened $reportTitle print window.'),
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF16A34A),
                            ),
                          );
                        },
                        icon: const Icon(Icons.print_rounded, size: 16),
                        label: const Text('Print / Save PDF', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Simulated A4 Printable Sheet (Scrollable)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Official Institutional Letterhead
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2563EB),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.school_rounded, color: Colors.white, size: 28),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'EduSHAMIIT INSTITUTION OF TECHNOLOGY',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF0F172A),
                                            letterSpacing: -0.2,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const Text(
                                          'Office of the Chief Warden & Hostel Administration',
                                          style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Academic Year: $academicYear',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2563EB)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: const Text(
                                    'OFFICIAL AUDIT REPORT',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF475569)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Generated: $nowFormatted',
                                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(thickness: 1.5, color: Color(0xFF0F172A)),
                        const SizedBox(height: 12),

                        // Document Title
                        Center(
                          child: Text(
                            reportTitle.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Printable Data Table
                        if (records.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Text('No records available for print export.', style: TextStyle(color: Color(0xFF64748B))),
                            ),
                          )
                        else
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 800),
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                headingRowHeight: 38,
                                dataRowMinHeight: 40,
                                dataRowMaxHeight: 48,
                                horizontalMargin: 12,
                                columnSpacing: 16,
                                columns: columns.map((c) {
                                  return DataColumn(
                                    label: Text(
                                      c.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  );
                                }).toList(),
                                rows: records.take(100).map((r) {
                                  return DataRow(
                                    cells: columns.map((c) {
                                      final val = _resolveCellValue(c, r);
                                      return DataCell(
                                        Text(
                                          val.toString(),
                                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF1E293B)),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        const SizedBox(height: 36),

                        // Signatory Section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(width: 140, height: 1, color: const Color(0xFF94A3B8)),
                                const SizedBox(height: 6),
                                const Text('Prepared By', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                const Text('Hostel System Administrator', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(width: 140, height: 1, color: const Color(0xFF94A3B8)),
                                const SizedBox(height: 6),
                                const Text('Verified & Approved', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569))),
                                const Text('Chief Hostel Warden', style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Center(
                          child: Text(
                            'Page 1 of 1 • EduSHAMIIT Automated Intelligence & Residence ERP',
                            style: TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
