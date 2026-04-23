import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/profile_provider.dart';

class StudentProfile extends ConsumerStatefulWidget {
  const StudentProfile({super.key});

  @override
  ConsumerState<StudentProfile> createState() => _StudentProfileState();
}

class _StudentProfileState extends ConsumerState<StudentProfile> {
  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);

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
                      onPressed: () => safeGoBack(context, '/student/dashboard'),
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
                    child: Text('??', style: TextStyle(fontSize: 30)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  profileState.profile?.name ?? 'Loading...',
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Class ${profileState.profile?.className ?? ''} � Roll No. ${profileState.profile?.rollNo ?? ''} � Session ${profileState.profile?.session ?? ''}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 16),
                // Stats Row
                Row(
                  children: [
                    _buildStatItem(profileState.profile?.avgScore ?? '-', 'Avg Score'),
                    _buildStatItem(profileState.profile?.attendance ?? '-', 'Attend.'),
                    _buildStatItem(profileState.profile?.rank ?? '-', 'Rank'),
                    _buildStatItem(profileState.profile?.badges ?? '-', 'Badges'),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          Expanded(
            child: profileState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : profileState.error != null
                    ? Center(child: Text('Error: ${profileState.error}'))
                    : ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildSectionTitle('Personal Info'),
                          _buildInfoCard([
                            ['Gender', profileState.profile?.gender ?? '-'],
                            ['Date of Birth', profileState.profile?.dob ?? '-'],
                            ['Blood Group', profileState.profile?.bloodGroup ?? '-'],
                            ['Email', profileState.profile?.email ?? '-'],
                            ['Phone', profileState.profile?.phone ?? '-'],
                            ['Admission No.', profileState.profile?.admissionNo ?? '-'],
                            ['Nationality', profileState.profile?.nationality ?? '-'],
                            ['Religion', profileState.profile?.religion ?? '-'],
                            ['Category', profileState.profile?.category ?? '-'],
                            ['Address', profileState.profile?.address ?? '-'],
                            ['House', profileState.profile?.house ?? '-'],
                          ]),

                          const SizedBox(height: 16),

                          _buildSectionTitle('Father/Guardian'),
                          _buildInfoCard([
                            ['Name', profileState.profile?.fatherName ?? '-'],
                            ['Occupation', profileState.profile?.fatherOccupation ?? '-'],
                            ['Phone', profileState.profile?.fatherPhone ?? '-'],
                          ]),

                          const SizedBox(height: 16),

                          _buildSectionTitle('Mother'),
                          _buildInfoCard([
                            ['Name', profileState.profile?.motherName ?? '-'],
                            ['Occupation', profileState.profile?.motherOccupation ?? '-'],
                            ['Phone', profileState.profile?.motherPhone ?? '-'],
                          ]),

                          const SizedBox(height: 16),

                          _buildSectionTitle('?? Documents'),
                          _buildDocumentsCard(profileState.profile?.documents ?? []),

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
          color: Colors.white.withValues(alpha: 0.06),
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
            color: Colors.black.withValues(alpha: 0.04),
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

  Widget _buildDocumentsCard(List<DocumentModel> documents) {
    if (documents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: StudentColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('No documents uploaded yet.'),
      );
    }

    return Container(
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
        children: documents.asMap().entries.map((entry) {
          final index = entry.key;
          final doc = entry.value;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              border: index < documents.length - 1
                  ? const Border(bottom: BorderSide(color: StudentColors.border))
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  doc.name,
                  style: const TextStyle(
                    fontSize: 11,
                    color: StudentColors.text3,
                  ),
                ),
                Text(
                  doc.status,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: doc.status.contains('Verified')
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
    final profileState = ref.read(profileProvider);
    final profile = profileState.profile;
    if (profile == null) return;

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
                '?? Edit Profile',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              _buildEditField('Full Name', profile.name),
              _buildEditField('Email', profile.email),
              _buildEditField('Phone', profile.phone),
              _buildEditField('Address', profile.address),
              _buildEditField("Father's Name", profile.fatherName),
              _buildEditField("Father's Phone", profile.fatherPhone),
              _buildEditField("Mother's Name", profile.motherName),
              _buildEditField("Mother's Phone", profile.motherPhone),

              const SizedBox(height: 16),

              // Upload Documents Section
              const Text(
                '?? Upload Documents',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: StudentColors.text3,
                  letterSpacing: 0.08,
                ),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: 'Domicile Certificate',
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
              if (profile.documents.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: StudentColors.successBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Uploaded: ${profile.documents.map((d) => d.name).join(', ')}',
                    style: const TextStyle(fontSize: 9, color: StudentColors.success, fontWeight: FontWeight.w600),
                  ),
                ),

              const SizedBox(height: 20),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('? Profile Updated Successfully!'),
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
                    '?? Save All Changes',
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
