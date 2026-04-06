import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';

class TeacherProfile extends StatefulWidget {
  const TeacherProfile({super.key});

  @override
  State<TeacherProfile> createState() => _TeacherProfileState();
}

class _TeacherProfileState extends State<TeacherProfile> {
  final Map<String, dynamic> _teacher = {
    'name': 'Dr. Priya Sharma',
    'id': 'TCH-2024-001',
    'email': 'priya.sharma@edushamiit.edu',
    'phone': '+91 98765 43210',
    'subject': 'Mathematics',
    'qualification': 'Ph.D. in Applied Mathematics',
    'experience': '12 years',
    'classes': ['X-A', 'X-B', 'X-C', 'IX-A', 'IX-B'],
    'totalStudents': 191,
    'joinDate': 'April 2018',
    'address': 'Civil Lines, New Delhi',
    'salary': '₹85,000/month',
    'rating': 4.8,
    'reviews': 156,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF0369A1)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 12),
                const Text(
                  'My Profile',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.white),
                  onPressed: () {},
                ),
              ],
            ),
          ),

          // Profile content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Profile card
                  _buildProfileCard(),
                  const SizedBox(height: 16),

                  // Quick stats
                  _buildQuickStats(),
                  const SizedBox(height: 16),

                  // Personal information
                  _buildSectionTitle('Personal Information'),
                  _buildInfoCard(_buildPersonalInfo()),
                  const SizedBox(height: 16),

                  // Professional information
                  _buildSectionTitle('Professional Details'),
                  _buildInfoCard(_buildProfessionalInfo()),
                  const SizedBox(height: 16),

                  // Classes
                  _buildSectionTitle('My Classes'),
                  _buildClassesCard(),
                  const SizedBox(height: 16),

                  // Actions
                  _buildActionButtons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0EA5E9), Color(0xFF0369A1)],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white38, width: 3),
            ),
            child: const Center(
              child: Text(
                'PS',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0EA5E9),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Name and title
          Text(
            _teacher['name'] as String,
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _teacher['subject'] as String,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 8),
          // Rating
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: Colors.amber, size: 16),
              const SizedBox(width: 4),
              Text(
                '${_teacher['rating']} (${_teacher['reviews']} reviews)',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('${_teacher['classes'].length}', 'Classes', Colors.blue)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard('${_teacher['totalStudents']}', 'Students', Colors.green)),
        const SizedBox(width: 12),
        Expanded(child: _buildStatCard(_teacher['experience'] as String, 'Experience', Colors.purple)),
      ],
    );
  }

  Widget _buildStatCard(String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: child,
    );
  }

  Widget _buildPersonalInfo() {
    return Column(
      children: [
        _buildInfoRow('Teacher ID', _teacher['id'] as String),
        const SizedBox(height: 12),
        _buildInfoRow('Email', _teacher['email'] as String),
        const SizedBox(height: 12),
        _buildInfoRow('Phone', _teacher['phone'] as String),
        const SizedBox(height: 12),
        _buildInfoRow('Address', _teacher['address'] as String),
      ],
    );
  }

  Widget _buildProfessionalInfo() {
    return Column(
      children: [
        _buildInfoRow('Qualification', _teacher['qualification'] as String),
        const SizedBox(height: 12),
        _buildInfoRow('Experience', _teacher['experience'] as String),
        const SizedBox(height: 12),
        _buildInfoRow('Join Date', _teacher['joinDate'] as String),
        const SizedBox(height: 12),
        _buildInfoRow('Salary', _teacher['salary'] as String),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClassesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: ( _teacher['classes'] as List<String>).map((cls) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              cls,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0EA5E9),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.edit, color: Colors.white),
            label: const Text(
              'Edit Profile',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EA5E9),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.download, color: Color(0xFF0EA5E9)),
            label: const Text(
              'Download ID Card',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0EA5E9),
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: const BorderSide(color: Color(0xFF0EA5E9)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: TextButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text(
              'Logout',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.red,
              ),
            ),
          ),
        ),
      ],
    );
  }
}