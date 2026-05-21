import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/constants/parent_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/parent_provider.dart';
import 'package:edu_shamiit_ai/core/providers/auth_provider.dart';
import 'package:edu_shamiit_ai/core/services/api_service.dart';
import 'package:edu_shamiit_ai/shared/widgets/responsive_content.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';

class ParentProfile extends ConsumerStatefulWidget {
  const ParentProfile({super.key});

  @override
  ConsumerState<ParentProfile> createState() => _ParentProfileState();
}

class _ParentProfileState extends ConsumerState<ParentProfile> {
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _occupationController = TextEditingController();
  bool _isEditing = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _addressController.dispose();
    _occupationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final profileAsync = ref.watch(parentProfileProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [ParentColors.primaryDeep, ParentColors.primary],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'My Profile'.tr(ref),
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(_isEditing ? Icons.check : Icons.edit,
                      color: Colors.white),
                  onPressed: () {
                    if (_isEditing) {
                      _saveProfile();
                    } else {
                      setState(() => _isEditing = true);
                    }
                  },
                ),
              ],
            ),
          ),

          // ── Body ──
          Expanded(
            child: profileAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildError(ref, e.toString()),
              data: (data) => _buildContent(context, ref, data, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref,
      Map<String, dynamic> data, bool isDark) {
    final profile = data['profile'] as Map<String, dynamic>? ?? data;
    final children = data['children'] as List<dynamic>? ?? [];

    // Pre-fill controllers on first edit
    if (_isEditing && _phoneController.text.isEmpty) {
      _phoneController.text = profile['phone'] ?? '';
      _addressController.text = profile['address'] ?? '';
      _occupationController.text = profile['occupation'] ?? '';
    }

    return ResponsiveContent(
      child: ListView(
        padding:
            Responsive.contentPadding(context).copyWith(top: 16, bottom: 16),
        children: [
          // ── Avatar & Name ──
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [ParentColors.primaryDeep, ParentColors.primary],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Center(
                    child: Text('👨‍👩‍👧', style: TextStyle(fontSize: 36)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  profile['full_name'] ?? 'Parent',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: isDark ? ParentColors.darkText : ParentColors.text,
                  ),
                ),
                Text(
                  profile['email'] ?? '',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? ParentColors.darkText3 : ParentColors.text3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Personal Info ──
          _sectionTitle('Personal Information'.tr(ref), isDark),
          const SizedBox(height: 12),
          _infoTile('Full Name'.tr(ref), profile['full_name'] ?? '-',
              Icons.person, isDark),
          _infoTile(
              'Email'.tr(ref), profile['email'] ?? '-', Icons.email, isDark),
          _isEditing
              ? _editableTile(
                  'Phone'.tr(ref), _phoneController, Icons.phone, isDark)
              : _infoTile('Phone'.tr(ref), profile['phone'] ?? '-', Icons.phone,
                  isDark),
          _isEditing
              ? _editableTile('Occupation'.tr(ref), _occupationController,
                  Icons.work, isDark)
              : _infoTile('Occupation'.tr(ref), profile['occupation'] ?? '-',
                  Icons.work, isDark),
          _isEditing
              ? _editableTile('Address'.tr(ref), _addressController,
                  Icons.location_on, isDark)
              : _infoTile('Address'.tr(ref), profile['address'] ?? '-',
                  Icons.location_on, isDark),
          const SizedBox(height: 20),

          // ── Linked Children ──
          _sectionTitle('Linked Children'.tr(ref), isDark),
          const SizedBox(height: 12),
          if (children.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'No children linked'.tr(ref),
                  style: TextStyle(
                      color:
                          isDark ? ParentColors.darkText3 : ParentColors.text3),
                ),
              ),
            )
          else
            ...children.map((c) {
              final child = c as Map<String, dynamic>;
              return _buildChildCard(child, isDark);
            }),
          const SizedBox(height: 20),

          // ── Actions ──
          _sectionTitle('Account'.tr(ref), isDark),
          const SizedBox(height: 12),
          _actionTile('Change Password'.tr(ref), Icons.lock, isDark, () {
            // Navigate to change password
          }),
          _actionTile('Logout'.tr(ref), Icons.logout, isDark, () {
            ref.read(authProvider.notifier).signOut();
          }),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: isDark ? ParentColors.darkText : ParentColors.text,
      ),
    );
  }

  Widget _infoTile(String label, String value, IconData icon, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? ParentColors.darkSurface : ParentColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? ParentColors.darkBorder : ParentColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: ParentColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? ParentColors.darkText3 : ParentColors.text3,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? ParentColors.darkText : ParentColors.text,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _editableTile(String label, TextEditingController controller,
      IconData icon, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? ParentColors.darkSurface : ParentColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ParentColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: ParentColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: label,
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildCard(Map<String, dynamic> child, bool isDark) {
    final name = child['full_name'] ?? 'Student';
    final className = child['class'] ?? '';
    final rollNo = child['roll_no'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? ParentColors.darkSurface : ParentColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? ParentColors.darkBorder
              : ParentColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: ParentColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text('👶', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? ParentColors.darkText : ParentColors.text,
                  ),
                ),
                Text(
                  'Class $className • Roll $rollNo',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? ParentColors.darkText3 : ParentColors.text3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionTile(
      String label, IconData icon, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? ParentColors.darkSurface : ParentColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? ParentColors.darkBorder : ParentColors.border),
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: icon == Icons.logout
                    ? ParentColors.error
                    : ParentColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: icon == Icons.logout
                      ? ParentColors.error
                      : (isDark ? ParentColors.darkText : ParentColors.text),
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                color: isDark ? ParentColors.darkText3 : ParentColors.text3),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    try {
      await ApiService().put('/parent/profile', {
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'occupation': _occupationController.text.trim(),
      });
      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profile updated'.tr(ref))),
        );
        ref.invalidate(parentProfileProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
      }
    }
  }

  Widget _buildError(WidgetRef ref, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: ParentColors.error),
          const SizedBox(height: 16),
          Text(
            'Failed to load profile'.tr(ref),
            style: const TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(error,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(parentProfileProvider),
            icon: const Icon(Icons.refresh),
            label: Text('Retry'.tr(ref)),
          ),
        ],
      ),
    );
  }
}
