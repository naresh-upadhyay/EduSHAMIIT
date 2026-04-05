import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class StudentProfile extends ConsumerStatefulWidget {
  const StudentProfile({super.key});

  @override
  ConsumerState<StudentProfile> createState() => _StudentProfileState();
}

class _StudentProfileState extends ConsumerState<StudentProfile> {
  final Map<String, dynamic> _studentData = {
    'name': 'Arjun Kumar',
    'class': 'X-A',
    'rollNo': '18',
    'session': '2024–25',
    'avgScore': '91.4%',
    'attendance': '94%',
    'rank': '3rd',
    'badges': '18',
    'gender': 'Male',
    'dob': 'October 12, 2009',
    'bloodGroup': 'O+ (Positive)',
    'email': 'arjun.kumar@eduverse.in',
    'phone': '+91-9876543210',
    'admissionNo': 'EV/2024/1082',
    'nationality': 'Indian',
    'religion': 'Hindu',
    'category': 'General',
    'address': '42, Rajpur Road, Dehradun',
    'house': '🔵 Blue House',
    'fatherName': 'Rajesh Kumar',
    'fatherOccupation': 'Senior Manager, SBI',
    'fatherPhone': '+91-9876543210',
    'motherName': 'Sunita Kumar',
    'motherOccupation': 'Teacher, DPS School',
    'motherPhone': '+91-9876543211',
  };

  final List<Map<String, dynamic>> _documents = [
    {'name': 'Birth Certificate', 'status': '✅ Verified'},
    {'name': 'Aadhaar Card', 'status': '✅ Verified'},
    {'name': 'Previous Marksheet', 'status': '✅ Verified'},
    {'name': 'Domicile Certificate', 'status': '⏳ Pending Upload'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FF),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 0),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Profile',
                      style: TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white70),
                      onPressed: () => _showEditProfileSheet(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Avatar
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24, width: 3),
                  ),
                  child: const Center(
                    child: Text('🧑', style: TextStyle(fontSize: 30)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _studentData['name']!,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Class ${_studentData['class']} · Roll No. ${_studentData['rollNo']} · Session ${_studentData['session']}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 16),
                // Stats Row
                Row(
                  children: [
                    _buildStatItem(_studentData['avgScore']!, 'Avg Score'),
                    _buildStatItem(_studentData['attendance']!, 'Attend.'),
                    _buildStatItem(_studentData['rank']!, 'Rank'),
                    _buildStatItem(_studentData['badges']!, 'Badges'),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionTitle('Personal Info'),
                _buildInfoCard([
                  ['Gender', _studentData['gender']!],
                  ['Date of Birth', _studentData['dob']!],
                  ['Blood Group', _studentData['bloodGroup']!],
                  ['Email', _studentData['email']!],
                  ['Phone', _studentData['phone']!],
                  ['Admission No.', _studentData['admissionNo']!],
                  ['Nationality', _studentData['nationality']!],
                  ['Religion', _studentData['religion']!],
                  ['Category', _studentData['category']!],
                  ['Address', _studentData['address']!],
                  ['House', _studentData['house']!],
                ]),

                const SizedBox(height: 16),

                _buildSectionTitle('Father/Guardian'),
                _buildInfoCard([
                  ['Name', _studentData['fatherName']!],
                  ['Occupation', _studentData['fatherOccupation']!],
                  ['Phone', _studentData['fatherPhone']!],
                ]),

                const SizedBox(height: 16),

                _buildSectionTitle('Mother'),
                _buildInfoCard([
                  ['Name', _studentData['motherName']!],
                  ['Occupation', _studentData['motherOccupation']!],
                  ['Phone', _studentData['motherPhone']!],
                ]),

                const SizedBox(height: 16),

                _buildSectionTitle('📎 Documents'),
                _buildDocumentsCard(),

                const SizedBox(height: 50),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.white38,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: AppFonts.heading,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: StudentColors.text3,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _buildInfoCard(List<List<String>> items) {
    return Container(
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              border: index < items.length - 1
                  ? const Border(bottom: BorderSide(color: StudentColors.border))
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item[0],
                  style: const TextStyle(
                    fontSize: 11,
                    color: StudentColors.text3,
                  ),
                ),
                Text(
                  item[1],
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: StudentColors.text,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDocumentsCard() {
    return Container(
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: _documents.asMap().entries.map((entry) {
          final index = entry.key;
          final doc = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              border: index < _documents.length - 1
                  ? const Border(bottom: BorderSide(color: StudentColors.border))
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  doc['name']!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: StudentColors.text3,
                  ),
                ),
                Text(
                  doc['status']!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: doc['status']!.contains('Verified')
                        ? StudentColors.success
                        : StudentColors.warning,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showEditProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.85,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: StudentColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: StudentColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '✏️ Edit Profile',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              _buildEditField('Full Name', _studentData['name']!),
              _buildEditField('Email', _studentData['email']!),
              _buildEditField('Phone', _studentData['phone']!),
              _buildEditField('Address', _studentData['address']!),
              _buildEditField("Father's Name", _studentData['fatherName']!),
              _buildEditField("Father's Phone", _studentData['fatherPhone']!),
              _buildEditField("Mother's Name", _studentData['motherName']!),
              _buildEditField("Mother's Phone", _studentData['motherPhone']!),

              const SizedBox(height: 16),

              // Upload Documents Section
              const Text(
                '📎 Upload Documents',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: StudentColors.text3,
                  letterSpacing: 0.08,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: 'Domicile Certificate',
                decoration: InputDecoration(
                  filled: true,
                  fillColor: StudentColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: StudentColors.border),
                  ),
                ),
                items: [
                  'Domicile Certificate',
                  'Caste Certificate',
                  'Transfer Certificate (TC)',
                  'Character Certificate',
                  'Income Certificate',
                ].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (value) {},
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: StudentColors.border, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(14),
                  color: const Color(0xFFF8FAFC),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.upload_file, color: StudentColors.text3),
                    SizedBox(width: 8),
                    Text(
                      'Tap to upload file (PDF, JPG, PNG up to 5MB)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: StudentColors.successBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.attach_file, color: StudentColors.success, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Uploaded: Birth Certificate, Aadhaar Card, Previous Marksheet',
                      style: TextStyle(fontSize: 9, color: StudentColors.success, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Profile Updated Successfully!'),
                        backgroundColor: StudentColors.success,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StudentColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '💾 Save All Changes',
                    style: TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  backgroundColor: StudentColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: StudentColors.border),
                  ),
                ),
                child: const SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: Center(child: Text('Cancel')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: StudentColors.text3,
            marginBottom: 3,
          ),
        ),
        const SizedBox(height: 3),
        TextFormField(
          initialValue: value,
          decoration: InputDecoration(
            filled: true,
            fillColor: StudentColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: StudentColors.border),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}