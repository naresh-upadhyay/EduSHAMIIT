import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_academic/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:edu_shamiit_core/models/teacher_models.dart' as models;

class TeacherProfileScreen extends ConsumerStatefulWidget {
  const TeacherProfileScreen({super.key});

  @override
  ConsumerState<TeacherProfileScreen> createState() =>
      _TeacherProfileScreenState();
}

class _TeacherProfileScreenState extends ConsumerState<TeacherProfileScreen> {
  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      imageQuality: 90,
    );
    if (picked == null) return;

    // Crop the picked image to square
    final croppedBytes = await _cropImage(picked.path);
    if (croppedBytes == null) return;

    String filename = picked.name;
    if (!filename.contains('.')) {
      filename += '.jpg';
    }

    final ok = await ref
        .read(teacherProfileProvider.notifier)
        .uploadAvatar(croppedBytes, filename);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Photo updated!'.tr(ref) : 'Upload failed'.tr(ref)),
        backgroundColor: ok ? TeacherColors.success : TeacherColors.error,
      ));
    }
  }

  Future<Uint8List?> _cropImage(String sourcePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo'.tr(ref),
          toolbarColor: const Color(0xFF0C4A6E),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Photo'.tr(ref),
          aspectRatioLockEnabled: true,
        ),
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: const CropperSize(width: 220, height: 220),
          zoomable: true,
          rotatable: true,
          scalable: true,
        ),
      ],
    );
    if (croppedFile != null) {
      return await croppedFile.readAsBytes();
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(teacherProfileProvider);
    final theme = Theme.of(context);

    if (st.profile == null) {
      if (st.error != null) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: _error(st.error!),
        );
      }
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: _shimmer(),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: st.isLoading ? _shimmer() : _body(st),
    );
  }

  Widget _shimmer() => Shimmer.fromColors(
        baseColor: const Color(0xFFE2E8F0),
        highlightColor: const Color(0xFFF1F5F9),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              Container(height: 260, color: const Color(0xFFE2E8F0)),
              const SizedBox(height: 16),
              ...List.generate(
                5,
                (_) => Container(
                  height: 52,
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _error(String msg) => Column(
        children: [
          Container(
            height: 80,
            decoration: const BoxDecoration(
              gradient: AppGradients.teacherHeader,
            ),
            child: SafeArea(
              bottom: false,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: 20),
                    onPressed: () => safeGoBack(context, '/teacher/dashboard'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 56, color: TeacherColors.error),
                  const SizedBox(height: 12),
                  Text(
                    msg,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? TeacherColors.text3
                          : TeacherColors.text2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () =>
                        ref.read(teacherProfileProvider.notifier).loadProfile(),
                    icon: const Icon(Icons.refresh),
                    label: Text('Retry'.tr(ref)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: TeacherColors.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _body(TeacherProfileState st) {
    final p = st.profile!;
    final completion = _calculateCompletion(p);

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 310,
          pinned: true,
          backgroundColor: const Color(0xFF0C4A6E),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                color: Colors.white, size: 20),
            onPressed: () => safeGoBack(context, '/teacher/dashboard'),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _EditSheet(profile: p),
                ),
                icon: const Icon(Icons.edit, color: Colors.white, size: 14),
                label: Text(
                  'Edit'.tr(ref),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
          flexibleSpace: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final top = constraints.biggest.height;
              final isCollapsed = top <=
                  kToolbarHeight + MediaQuery.of(context).padding.top + 20;

              return FlexibleSpaceBar(
                title: isCollapsed
                    ? Text(
                        p.fullName,
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
                centerTitle: true,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: AppGradients.teacherHeader,
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 36),
                        GestureDetector(
                          onTap: () {
                            if (p.profileImageUrl != null &&
                                p.profileImageUrl!.isNotEmpty) {
                              ImagePreviewDialog.show(
                                  context, p.profileImageUrl!,
                                  title: p.fullName);
                            }
                          },
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  gradient: AppGradients.teacherPrimary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 3,
                                  ),
                                ),
                                child: ClipOval(
                                  child: st.isUploadingAvatar
                                      ? const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : p.profileImageUrl != null &&
                                              p.profileImageUrl!.isNotEmpty
                                          ? CachedNetworkImage(
                                              imageUrl: p.profileImageUrl!,
                                              fit: BoxFit.cover,
                                              errorWidget: (_, __, ___) =>
                                                  _initials(p.fullName),
                                            )
                                          : _initials(p.fullName),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: GestureDetector(
                                  onTap: _pickAvatar,
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: TeacherColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                    ),
                                    child: const Icon(Icons.camera_alt,
                                        size: 14, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p.fullName,
                          style: const TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (p.subject.isNotEmpty) p.subject,
                            if (p.qualification.isNotEmpty) p.qualification,
                            '${p.experienceYears}y Exp'
                          ].join(' · '),
                          style: const TextStyle(
                              fontSize: 11, color: Colors.white70),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _stat('${p.experienceYears} Years',
                                  'Experience'.tr(ref)),
                              _stat('${p.classes.length}', 'Classes'.tr(ref)),
                              _stat('${p.xpPoints}', 'XP Points'.tr(ref)),
                              _stat('${p.streak}', 'Streak'.tr(ref)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // 📊 Profile Completion meter
              _buildCompletionCard(completion, p),
              const SizedBox(height: 16),

              if (p.bio != null && p.bio!.isNotEmpty) ...[
                _buildBioCard(p),
                const SizedBox(height: 16),
              ],

              // 📚 Assigned subjects and classes visual chips
              _sectionLabel('Classes & Subjects'.tr(ref)),
              _buildClassesGrid(p),
              const SizedBox(height: 16),

              // Personal info card
              _sectionLabel('Personal Info'.tr(ref)),
              _infoCard([
                ('Gender'.tr(ref), p.gender, false),
                ('Date of Birth'.tr(ref), p.dateOfBirth, false),
                ('Blood Group'.tr(ref), p.bloodGroup, false),
                ('Email'.tr(ref), p.email, true),
                ('Phone'.tr(ref), p.phone ?? '', true),
                ('Nationality'.tr(ref), p.nationality, false),
                ('Religion'.tr(ref), p.religion, false),
                ('Category'.tr(ref), p.category, false),
                ('Address'.tr(ref), p.address, false),
              ]),
              const SizedBox(height: 16),

              // Father Details Card
              _sectionLabel('Father Details'.tr(ref)),
              _infoCard([
                ('Name'.tr(ref), p.fatherName, false),
                ('Occupation'.tr(ref), p.fatherOccupation, false),
                (
                  'Phone'.tr(ref),
                  p.fatherPhone.isEmpty ? '' : '📞 ${p.fatherPhone}',
                  true
                ),
              ]),
              const SizedBox(height: 16),

              // Mother Details Card
              _sectionLabel('Mother Details'.tr(ref)),
              _infoCard([
                ('Name'.tr(ref), p.motherName, false),
                ('Occupation'.tr(ref), p.motherOccupation, false),
                (
                  'Phone'.tr(ref),
                  p.motherPhone.isEmpty ? '' : '📞 ${p.motherPhone}',
                  true
                ),
              ]),
              const SizedBox(height: 16),

              // Career Timeline Milestones
              _sectionLabel('Career Timeline'.tr(ref)),
              _buildTimeline(p),
              const SizedBox(height: 16),

              // Required professional documents list
              _sectionLabel('📎 Professional Documents'.tr(ref)),
              _docsCard(p),
              const SizedBox(height: 16),

              // Quick action buttons panel
              _sectionLabel('Quick Operations'.tr(ref)),
              _buildQuickActionsPanel(),
              const SizedBox(height: 80),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _initials(String name) {
    final i = name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join()
        .toUpperCase();
    return Center(
      child: Text(
        i,
        style: const TextStyle(
            fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white),
      ),
    );
  }

  Widget _stat(String v, String l) => Column(
        children: [
          Text(
            v,
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            l,
            style: const TextStyle(fontSize: 9, color: Colors.white60),
          ),
        ],
      );

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          t.toUpperCase(),
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).brightness == Brightness.dark
                ? TeacherColors.text3
                : TeacherColors.text2,
            letterSpacing: 0.6,
          ),
        ),
      );

  Widget _infoCard(List<(String, String, bool)> rows) {
    final visible = rows.where((r) => r.$2.isNotEmpty).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (Theme.of(context).brightness != Brightness.dark)
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        children: visible.asMap().entries.map((e) {
          final isLast = e.key == visible.length - 1;
          final (label, value, indigo) = e.value;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF8FAFC),
                      ),
                    ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? TeacherColors.text3 : TeacherColors.text2,
                  ),
                ),
                Flexible(
                  child: Text(
                    value.isEmpty ? '—' : value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: indigo
                          ? TeacherColors.primary
                          : (isDark ? Colors.white : TeacherColors.text),
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Completion calculations
  int _calculateCompletion(models.TeacherProfile p) {
    int score = 0;
    // Basic Details: name, email, phone, bio, qualification (8% each = 40%)
    if (p.fullName.isNotEmpty) score += 8;
    if (p.email.isNotEmpty) score += 8;
    if (p.phone != null && p.phone!.isNotEmpty) score += 8;
    if (p.bio != null && p.bio!.isNotEmpty) score += 8;
    if (p.qualification.isNotEmpty) score += 8;

    // Personal & Parent Info: gender, DOB, bloodGroup, fatherName, motherName, address (5% each = 30%)
    if (p.gender.isNotEmpty) score += 5;
    if (p.dateOfBirth.isNotEmpty) score += 5;
    if (p.bloodGroup.isNotEmpty) score += 5;
    if (p.fatherName.isNotEmpty) score += 5;
    if (p.motherName.isNotEmpty) score += 5;
    if (p.address.isNotEmpty) score += 5;

    // Documents (5 required documents: Resume, Aadhaar, PAN, Marksheet, Experience Certificate. Each is 6% = 30%)
    final requiredDocs = [
      'Resume',
      'Aadhaar Card',
      'PAN Card',
      'Highest Degree Marksheet',
      'Experience Certificate'
    ];
    final uploadedTypes = p.documents.map((d) => d.type).toSet();
    for (final doc in requiredDocs) {
      if (uploadedTypes.contains(doc)) {
        score += 6;
      }
    }
    return score > 100 ? 100 : score;
  }

  Widget _buildCompletionCard(int completion, models.TeacherProfile p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Find missing fields or docs to suggest action
    String suggestion = "Your profile is 100% complete! High five! 🎉";
    if (completion < 100) {
      final requiredDocs = [
        'Resume',
        'Aadhaar Card',
        'PAN Card',
        'Highest Degree Marksheet',
        'Experience Certificate'
      ];
      final uploadedTypes = p.documents.map((d) => d.type).toSet();
      String? missingDoc;
      for (final doc in requiredDocs) {
        if (!uploadedTypes.contains(doc)) {
          missingDoc = doc;
          break;
        }
      }
      if (missingDoc != null) {
        suggestion = "Upload your $missingDoc to reach ${completion + 6}%!";
      } else if (p.bio == null || p.bio!.isEmpty) {
        suggestion = "Add a brief Bio about yourself to level up your profile!";
      } else if (p.phone == null || p.phone!.isEmpty) {
        suggestion = "Provide a Contact Phone Number to enhance security.";
      } else {
        suggestion = "Complete your Personal and Parent Details to hit 100%!";
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Profile Completion'.tr(ref),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                '$completion%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: completion == 100
                      ? TeacherColors.success
                      : TeacherColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: completion / 100.0,
              minHeight: 8,
              backgroundColor:
                  isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(
                completion == 100
                    ? TeacherColors.success
                    : TeacherColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.tips_and_updates, size: 14, color: Colors.amber),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  suggestion.tr(ref),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark ? TeacherColors.text3 : TeacherColors.text2,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBioCard(models.TeacherProfile p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notes, size: 18, color: TeacherColors.primary),
              const SizedBox(width: 8),
              Text(
                'Bio / About Me'.tr(ref),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : TeacherColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            p.bio ?? '',
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              fontWeight: FontWeight.normal,
              color: isDark ? TeacherColors.text3 : TeacherColors.text,
            ),
          ),
        ],
      ),
    );
  }

  // Beautiful visual grid of Subjects & Classes visual badges
  Widget _buildClassesGrid(models.TeacherProfile p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final classesList = p.classes.isEmpty ? ['No Classes Assigned'] : p.classes;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('📚', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                'Teaching Assignments'.tr(ref),
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Subject tag
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: TeacherColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: TeacherColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bookmark_outline,
                        size: 12, color: TeacherColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      p.subject,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: TeacherColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              // Specialization tag (if present)
              if (p.specialization != null && p.specialization!.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: TeacherColors.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: TeacherColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.psychology_outlined,
                          size: 12, color: TeacherColors.accent),
                      const SizedBox(width: 4),
                      Text(
                        p.specialization!,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: TeacherColors.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              // Classes tags
              ...classesList.map(
                (cls) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.class_outlined,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        cls,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : TeacherColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Interactive timeline of professional career
  Widget _buildTimeline(models.TeacherProfile p) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final joinDateStr = p.joiningDate != null
        ? '${p.joiningDate!.day.toString().padLeft(2, '0')}/${p.joiningDate!.month.toString().padLeft(2, '0')}/${p.joiningDate!.year}'
        : 'Not provided';

    final timelineItems = [
      (
        Icons.calendar_today,
        'Joined School'.tr(ref),
        joinDateStr,
        TeacherColors.primary
      ),
      (
        Icons.school,
        'Academic Credentials'.tr(ref),
        p.qualification,
        TeacherColors.accent
      ),
      (
        Icons.star,
        'Total Teaching Experience'.tr(ref),
        '${p.experienceYears} Years',
        Colors.amber.shade700
      ),
      (
        Icons.book,
        'Department Specalization'.tr(ref),
        (p.specialization != null && p.specialization!.isNotEmpty)
            ? p.specialization!
            : (p.subject.isNotEmpty ? p.subject : '—'),
        Colors.purple
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        children: timelineItems.asMap().entries.map((e) {
          final idx = e.key;
          final (icon, title, value, color) = e.value;
          final isLast = idx == timelineItems.length - 1;

          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: color.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: Icon(icon, size: 14, color: color),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? TeacherColors.text3
                                : TeacherColors.text2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          value.isEmpty ? '—' : value,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // Documents status card
  Widget _docsCard(models.TeacherProfile p) {
    final requiredDocs = [
      'Resume',
      'Aadhaar Card',
      'PAN Card',
      'Highest Degree Marksheet',
      'Experience Certificate',
    ];

    final uploadedMap = {for (var d in p.documents) d.type: d};
    final allDocs = <(String, String)>[];

    for (final docType in requiredDocs) {
      if (uploadedMap.containsKey(docType)) {
        allDocs.add((docType, uploadedMap[docType]!.status));
      } else {
        allDocs.add((docType, 'missing'));
      }
    }

    for (final doc in p.documents) {
      if (!requiredDocs.contains(doc.type)) {
        allDocs.add((doc.type, doc.status));
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!isDark)
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: Column(
        children: allDocs.asMap().entries.map((e) {
          final isLast = e.key == allDocs.length - 1;
          final name = e.value.$1;
          final status = e.value.$2;

          String statusText;
          Color statusColor;
          if (status == 'verified') {
            statusText = '✅ Verified'.tr(ref);
            statusColor = TeacherColors.success;
          } else if (status == 'pending') {
            statusText = '⏳ In Review'.tr(ref);
            statusColor = Colors.amber.shade700;
          } else {
            statusText = '⚠️ Pending Upload'.tr(ref);
            statusColor = TeacherColors.warning;
          }

          return GestureDetector(
            onTap: () {
              if (status != 'missing' && uploadedMap.containsKey(name)) {
                final doc = uploadedMap[name]!;
                final lowUrl = doc.fileUrl.toLowerCase();
                if (lowUrl.contains('.jpg') ||
                    lowUrl.contains('.jpeg') ||
                    lowUrl.contains('.png')) {
                  ImagePreviewDialog.show(context, doc.fileUrl, title: name);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('📄 File is not an image (PDF/Doc)'.tr(ref)),
                    backgroundColor: Colors.amber.shade800,
                  ));
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: isDark
                              ? const Color(0xFF1E293B)
                              : const Color(0xFFF8FAFC),
                        ),
                      ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? TeacherColors.text3 : TeacherColors.text2,
                    ),
                  ),
                  Text(
                    statusText,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: statusColor),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Visual Quick Action Buttons Panel
  Widget _buildQuickActionsPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final operations = [
      (Icons.payments_outlined, 'Salary History'.tr(ref), '/teacher/salary'),
      (Icons.beach_access_outlined, 'Apply Leave'.tr(ref), '/teacher/leave'),
      (Icons.settings_outlined, 'App Settings'.tr(ref), '/teacher/settings'),
    ];

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          if (!isDark)
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            ...operations.map((op) {
              final (icon, title, route) = op;
              return Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF8FAFC),
                    ),
                  ),
                ),
                child: ListTile(
                  leading: Icon(icon, color: TeacherColors.primary, size: 20),
                  title: Text(
                    title,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios,
                      size: 12, color: Colors.grey),
                  dense: true,
                  onTap: () => context.go(route),
                ),
              );
            }),
            // Logout item
            ListTile(
              leading: const Icon(Icons.logout,
                  color: TeacherColors.error, size: 20),
              title: Text(
                'Logout'.tr(ref),
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: TeacherColors.error),
              ),
              trailing: const Icon(Icons.arrow_forward_ios,
                  size: 12, color: Colors.grey),
              dense: true,
              onTap: () => _showLogoutDialog(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Logout?'.tr(ref),
          style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to logout from EduSHAMIIT?'.tr(ref),
          style: TextStyle(
              color: isDark ? TeacherColors.text2 : TeacherColors.text2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text('Cancel'.tr(ref),
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TeacherColors.error,
              foregroundColor: Colors.white,
            ),
            child: Text('Logout'.tr(ref)),
          ),
        ],
      ),
    );
  }
}

// ── Edit Sheet ────────────────────────────────────────────────────────────────

class _EditSheet extends ConsumerStatefulWidget {
  final models.TeacherProfile profile;
  const _EditSheet({required this.profile});

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name,
      _email,
      _phone,
      _address,
      _nationality,
      _fatherName,
      _fatherOcc,
      _fatherPhone,
      _motherName,
      _motherOcc,
      _motherPhone,
      _guardian,
      _bio,
      _qualification,
      _expYears,
      _specialization;

  String _gender = 'Male';
  String _bloodGroup = 'O+';
  String _religion = 'Hindu';
  String _category = 'General';
  String _docType = 'Resume';
  String? _uploadedFileName;
  Uint8List? _uploadedFileBytes;
  DateTime? _dob;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name = TextEditingController(text: p.fullName);
    _email = TextEditingController(text: p.email);
    _phone = TextEditingController(text: p.phone ?? '');
    _address = TextEditingController(text: p.address);
    _nationality = TextEditingController(
        text: p.nationality.isEmpty ? 'Indian' : p.nationality);
    _fatherName = TextEditingController(text: p.fatherName);
    _fatherOcc = TextEditingController(text: p.fatherOccupation);
    _fatherPhone = TextEditingController(text: p.fatherPhone);
    _motherName = TextEditingController(text: p.motherName);
    _motherOcc = TextEditingController(text: p.motherOccupation);
    _motherPhone = TextEditingController(text: p.motherPhone);
    _guardian = TextEditingController(text: p.localGuardian);
    _bio = TextEditingController(text: p.bio ?? '');
    _qualification = TextEditingController(text: p.qualification);
    _expYears = TextEditingController(text: p.experienceYears.toString());
    _specialization = TextEditingController(text: p.specialization ?? '');

    if (['Male', 'Female', 'Other'].contains(p.gender)) _gender = p.gender;
    if (['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-']
        .contains(p.bloodGroup)) _bloodGroup = p.bloodGroup;
    if (['Hindu', 'Muslim', 'Christian', 'Sikh', 'Buddhist', 'Jain', 'Other']
        .contains(p.religion)) _religion = p.religion;
    if (['General', 'OBC', 'SC', 'ST', 'EWS'].contains(p.category))
      _category = p.category;
    if (p.dateOfBirth.isNotEmpty) _dob = DateTime.tryParse(p.dateOfBirth);
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _email,
      _phone,
      _address,
      _nationality,
      _fatherName,
      _fatherOcc,
      _fatherPhone,
      _motherName,
      _motherOcc,
      _motherPhone,
      _guardian,
      _bio,
      _qualification,
      _expYears,
      _specialization
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDoc() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (res != null && res.files.isNotEmpty) {
      final file = res.files.first;
      String filename = file.name;
      if (!filename.contains('.')) {
        filename += '.jpg';
      }
      setState(() {
        _uploadedFileName = filename;
        _uploadedFileBytes = file.bytes;
      });
    }
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(1988, 1, 1),
      firstDate: DateTime(1955),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Create updates payload
    final data = <String, dynamic>{
      'full_name': _name.text.trim(),
      'email': _email.text.trim(),
      'phone': _phone.text.trim(),
      'address': _address.text.trim(),
      'nationality': _nationality.text.trim(),
      'gender': _gender,
      'blood_group': _bloodGroup,
      'religion': _religion,
      'category': _category,
      'father_name': _fatherName.text.trim(),
      'father_occupation': _fatherOcc.text.trim(),
      'father_phone': _fatherPhone.text.trim(),
      'mother_name': _motherName.text.trim(),
      'mother_occupation': _motherOcc.text.trim(),
      'mother_phone': _motherPhone.text.trim(),
      'local_guardian': _guardian.text.trim(),
      'bio': _bio.text.trim(),
      'qualification': _qualification.text.trim(),
      'experience_years':
          int.tryParse(_expYears.text.trim()) ?? widget.profile.experienceYears,
      'specialization': _specialization.text.trim(),
    };
    if (_dob != null) {
      data['date_of_birth'] =
          '${_dob!.year}-${_dob!.month.toString().padLeft(2, '0')}-${_dob!.day.toString().padLeft(2, '0')}';
    }

    // 1. Upload document if selected
    if (_uploadedFileBytes != null && _uploadedFileName != null) {
      await ref.read(teacherProfileProvider.notifier).uploadDocument(
            _uploadedFileBytes!,
            _uploadedFileName!,
            _docType,
          );
    }

    // 2. Update text profile fields
    final ok =
        await ref.read(teacherProfileProvider.notifier).updateProfile(data);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          ok ? '✅ Profile Updated Successfully!' : '❌ Save failed. Try again.'),
      backgroundColor: ok ? TeacherColors.success : TeacherColors.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(teacherProfileProvider);
    final saving = state.isSaving || state.isUploadingDocument;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Form(
          key: _formKey,
          child: ListView(
            controller: sc,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color:
                        isDark ? const Color(0xFF1E293B) : TeacherColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                '✏️ Edit Profile',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 20),
              _groupLabel('TEACHER DETAILS'),
              _tf('Full Name', _name, Icons.person_outline),
              _tf('Bio / About Me', _bio, Icons.description_outlined, lines: 2),
              Row(
                children: [
                  Expanded(
                    child: _drop(
                      'Gender',
                      _gender,
                      ['Male', 'Female', 'Other'],
                      (v) => setState(() => _gender = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _dobField()),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _drop(
                      'Blood Group',
                      _bloodGroup,
                      ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'],
                      (v) => setState(() => _bloodGroup = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _tf(
                          'Nationality', _nationality, Icons.flag_outlined)),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _drop(
                      'Religion',
                      _religion,
                      [
                        'Hindu',
                        'Muslim',
                        'Christian',
                        'Sikh',
                        'Buddhist',
                        'Jain',
                        'Other'
                      ],
                      (v) => setState(() => _religion = v!),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _drop(
                      'Category',
                      _category,
                      ['General', 'OBC', 'SC', 'ST', 'EWS'],
                      (v) => setState(() => _category = v!),
                    ),
                  ),
                ],
              ),
              _tf('Email', _email, Icons.email_outlined,
                  type: TextInputType.emailAddress),
              _tf('Phone', _phone, Icons.phone_outlined,
                  type: TextInputType.phone),
              _tf('Address', _address, Icons.home_outlined, lines: 2),
              _groupLabel('PROFESSIONAL PROFILE'),
              _tf('Highest Qualification', _qualification,
                  Icons.school_outlined),
              _tf('Years of Experience', _expYears, Icons.work_history_outlined,
                  type: TextInputType.number),
              _tf('Department Specialization', _specialization,
                  Icons.psychology_outlined),
              _groupLabel('FATHER / GUARDIAN'),
              _tf("Father's Name", _fatherName, Icons.person_outline),
              _tf('Occupation', _fatherOcc, Icons.work_outline),
              _tf("Father's Phone", _fatherPhone, Icons.phone_outlined,
                  type: TextInputType.phone),
              _groupLabel('MOTHER'),
              _tf("Mother's Name", _motherName, Icons.person_outline),
              _tf('Occupation', _motherOcc, Icons.work_outline),
              _tf("Mother's Phone", _motherPhone, Icons.phone_outlined,
                  type: TextInputType.phone),
              _tf('Local Guardian', _guardian,
                  Icons.supervised_user_circle_outlined),
              _groupLabel('📎 UPLOAD DOCUMENTS'),
              _drop(
                'Document Type',
                _docType,
                [
                  'Resume',
                  'Aadhaar Card',
                  'PAN Card',
                  'Highest Degree Marksheet',
                  'Experience Certificate',
                  'Domicile Certificate',
                  'Caste Certificate',
                  'Passport Photo',
                ],
                (v) => setState(() => _docType = v!),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickDoc,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : TeacherColors.border,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.02)
                        : const Color(0xFFF8FAFC),
                  ),
                  child: Column(
                    children: [
                      const Text('📁', style: TextStyle(fontSize: 24)),
                      const SizedBox(height: 4),
                      Text(
                        'Tap to upload file'.tr(ref),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Text(
                        'PDF, JPG, PNG up to 5MB'.tr(ref),
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark
                              ? TeacherColors.text3
                              : TeacherColors.text3,
                        ),
                      ),
                      if (_uploadedFileName != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '📎 $_uploadedFileName',
                          style: const TextStyle(
                            fontSize: 10,
                            color: TeacherColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (widget.profile.documents.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TeacherColors.successBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📎 Uploaded Documents',
                        style: TextStyle(
                          fontSize: 11,
                          color: TeacherColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ...widget.profile.documents.map((doc) {
                        final isVerified = doc.status == 'verified';
                        final icon = isVerified ? '✅' : '⏳';
                        final color = isVerified
                            ? TeacherColors.success
                            : Colors.amber.shade700;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '$icon ${doc.type} (${doc.status})',
                            style: TextStyle(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              const SizedBox(height: 20),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TeacherColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          '💾 Save All Changes',
                          style: TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : const Color(0xFFF1F5F9),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDark ? TeacherColors.text2 : TeacherColors.text2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupLabel(String t) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        t,
        style: TextStyle(
          fontFamily: AppFonts.heading,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isDark ? TeacherColors.text3 : TeacherColors.text3,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  Widget _tf(
    String label,
    TextEditingController c,
    IconData icon, {
    TextInputType type = TextInputType.text,
    int lines = 1,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        keyboardType: type,
        maxLines: lines,
        style: TextStyle(
            fontSize: 13, color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
              color: isDark ? TeacherColors.text3 : TeacherColors.text2),
          prefixIcon: Icon(icon,
              size: 18,
              color: isDark ? TeacherColors.text3 : TeacherColors.text2),
          filled: true,
          fillColor:
              isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: isDark ? const Color(0xFF1E293B) : TeacherColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: isDark ? const Color(0xFF1E293B) : TeacherColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: TeacherColors.primary, width: 1.5),
          ),
        ),
        validator: (value) {
          if (label == 'Full Name' && (value == null || value.trim().isEmpty)) {
            return 'Full Name is required';
          }
          if (label == 'Email' && (value == null || value.trim().isEmpty)) {
            return 'Email is required';
          }
          return null;
        },
      ),
    );
  }

  Widget _drop(
    String label,
    String val,
    List<String> items,
    ValueChanged<String?> onChange,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: val,
        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        style: TextStyle(
            fontSize: 13, color: isDark ? Colors.white : Colors.black),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
              color: isDark ? TeacherColors.text3 : TeacherColors.text2),
          filled: true,
          fillColor:
              isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: isDark ? const Color(0xFF1E293B) : TeacherColors.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: isDark ? const Color(0xFF1E293B) : TeacherColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: TeacherColors.primary, width: 1.5),
          ),
        ),
        isExpanded: true,
        items: items
            .map((e) => DropdownMenuItem(
                  value: e,
                  child: Text(
                    e,
                    style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black),
                  ),
                ))
            .toList(),
        onChanged: onChange,
      ),
    );
  }

  Widget _dobField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = _dob != null
        ? '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}'
        : 'Select date';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: _pickDob,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'Date of Birth',
            labelStyle: TextStyle(
                color: isDark ? TeacherColors.text3 : TeacherColors.text2),
            prefixIcon: Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: isDark ? TeacherColors.text3 : TeacherColors.text2,
            ),
            filled: true,
            fillColor:
                isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color:
                      isDark ? const Color(0xFF1E293B) : TeacherColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                  color:
                      isDark ? const Color(0xFF1E293B) : TeacherColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: TeacherColors.primary, width: 1.5),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: _dob != null
                  ? (isDark ? Colors.white : TeacherColors.text)
                  : (isDark ? TeacherColors.text3 : TeacherColors.text2),
            ),
          ),
        ),
      ),
    );
  }
}
