import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../models/hostel_models.dart';
import '../../../../utils/download_helper.dart';

class HostelIdCardDialog extends StatelessWidget {
  final HostelStudentDetail360 student;

  const HostelIdCardDialog({super.key, required this.student});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Hostel Resident ID Card',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Visual ID Card Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Card Top Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.apartment_rounded,
                              color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'EDUSHAMIIT RESIDENCE',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  student.hostelName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF16A34A),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('ACTIVE',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white)),
                          ),
                        ],
                      ),
                    ),

                    // Card Body
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          // Photo
                          Container(
                            width: 80,
                            height: 96,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Center(
                              child: Text(
                                student.studentName.isNotEmpty
                                    ? student.studentName[0]
                                    : 'S',
                                style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF2563EB)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.studentName,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Roll: ${student.rollNo}  |  Class: ${student.className}',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.9)),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Room: ${student.roomNumber} · Bed: ${student.bedNo}',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Blood: ${student.bloodGroup}  |  ${student.emergencyContact}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.white.withValues(alpha: 0.8)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Barcode / Footer Bar
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(14)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('ID: HST-${student.rollNo}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.white70)),
                          const Text('VALID: 2024 - 2025',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Print / Download Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _downloadIdCard(context),
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Download ID Card'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _downloadIdCard(context);
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    icon: const Icon(Icons.print_rounded,
                        size: 16, color: Colors.white),
                    label: const Text('Print Card',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _downloadIdCard(BuildContext context) async {
    final buffer = StringBuffer();
    buffer.writeln('==================================================');
    buffer.writeln('        EDUSHAMIIT RESIDENTIAL CAMPUS');
    buffer.writeln('          HOSTEL RESIDENT ID CARD');
    buffer.writeln('==================================================');
    buffer.writeln('Student Name   : ${student.studentName}');
    buffer.writeln('Enrollment No  : ${student.admissionNumber}');
    buffer.writeln('Hostel Name    : ${student.hostelName}');
    buffer.writeln(
        'Room / Bed     : Room ${student.roomNumber} (${student.bedNumber})');
    buffer.writeln('Class / Grade  : ${student.className}');
    buffer.writeln('Blood Group    : ${student.bloodGroup}');
    buffer.writeln('Emergency No   : ${student.emergencyContact}');
    buffer.writeln('Warden Contact : ${student.wardenContact}');
    buffer.writeln('Academic Year  : 2024 - 2025');
    buffer.writeln('Status         : ACTIVE RESIDENT');
    buffer.writeln('==================================================');
    buffer.writeln('Issued by: Chief Warden Office, EduSHAMIIT');
    buffer.writeln('Timestamp: ${DateTime.now().toIso8601String()}');
    buffer.writeln('==================================================');

    final bytes = Uint8List.fromList(utf8.encode(buffer.toString()));
    final filename =
        'Hostel_ID_${student.admissionNumber.replaceAll(RegExp(r'\W+'), '_')}.txt';
    await getDownloadHelper().downloadBytes(bytes, filename);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Downloaded Digital ID Card for ${student.studentName}'),
          backgroundColor: const Color(0xFF16A34A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
