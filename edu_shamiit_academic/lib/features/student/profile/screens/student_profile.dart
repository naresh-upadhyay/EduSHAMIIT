import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:edu_shamiit_academic/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_core/constants/student_colors.dart';
import 'package:edu_shamiit_core/constants/app_fonts.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'package:edu_shamiit_core/widgets/image_preview_dialog.dart';
import 'package:edu_shamiit_core/utils/l10n.dart';

class StudentProfile extends ConsumerStatefulWidget {
  const StudentProfile({super.key});
  @override
  ConsumerState<StudentProfile> createState() => _StudentProfileState();
}

class _StudentProfileState extends ConsumerState<StudentProfile> {
  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1000, imageQuality: 90);
    if (picked == null) return;
    
    // 1. Crop the picked image
    final croppedBytes = await _cropImage(picked.path);
    if (croppedBytes == null) return; // User cancelled crop
    
    String filename = picked.name;
    if (!filename.contains('.')) {
      filename += '.jpg';
    }
    
    final ok = await ref.read(profileProvider.notifier).uploadAvatar(croppedBytes, filename);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? 'Photo updated!'.tr(ref) : 'Upload failed'.tr(ref)),
        backgroundColor: ok ? StudentColors.success : StudentColors.error,
      ));
    }
  }

  Future<Uint8List?> _cropImage(String sourcePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Square crop
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Photo'.tr(ref),
          toolbarColor: const Color(0xFF0F172A),
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
    final st = ref.watch(profileProvider);
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
    baseColor: const Color(0xFF1E293B),
    highlightColor: const Color(0xFF334155),
    child: Column(children: [
      Container(height: 260, color: const Color(0xFF1E293B)),
      const SizedBox(height: 16),
      ...List.generate(5, (_) => Container(
        height: 52, margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12)),
      )),
    ]),
  );

  Widget _error(String msg) => Column(children: [
    Container(
      height: 80,
      decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
      ),
      child: SafeArea(bottom: false, child: Row(children: [
        IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => safeGoBack(context, '/student/dashboard')),
      ])),
    ),
    Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline, size: 56, color: StudentColors.error),
      const SizedBox(height: 12),
      Text(msg, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? StudentColors.darkText2 : StudentColors.text2)),
      const SizedBox(height: 16),
      ElevatedButton.icon(onPressed: () => ref.read(profileProvider.notifier).loadProfile(),
        icon: const Icon(Icons.refresh), label: Text('Retry'.tr(ref))),
    ]))),
  ]);

  Widget _body(ProfileState st) {
    final p = st.profile!;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 310,
          pinned: true,
          backgroundColor: const Color(0xFF0F172A),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            onPressed: () => safeGoBack(context, '/student/dashboard'),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton.icon(
                onPressed: () => showModalBottomSheet(
                  context: context, isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _EditSheet(profile: p),
                ),
                icon: const Icon(Icons.edit, color: Colors.white, size: 14),
                label: Text('Edit'.tr(ref), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: 0.12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
          flexibleSpace: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final top = constraints.biggest.height;
              final isCollapsed = top <= kToolbarHeight + MediaQuery.of(context).padding.top + 20;

              return FlexibleSpaceBar(
                title: isCollapsed ? Text(p.name, style: const TextStyle(fontFamily: AppFonts.heading, fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)) : null,
                centerTitle: true,
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0F172A), Color(0xFF1E293B)]),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 36),
                        GestureDetector(
                          onTap: () {
                            if (p.avatarUrl != null && p.avatarUrl!.isNotEmpty) {
                              ImagePreviewDialog.show(context, p.avatarUrl!, title: p.name);
                            }
                          },
                          child: Stack(alignment: Alignment.bottomRight, children: [
                            Container(width: 72, height: 72,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)]),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 3),
                              ),
                              child: ClipOval(child: st.isUploadingAvatar
                                ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : p.avatarUrl != null && p.avatarUrl!.isNotEmpty
                                  ? CachedNetworkImage(imageUrl: p.avatarUrl!, fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) => _initials(p.name))
                                  : _initials(p.name))),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickAvatar,
                                child: Container(width: 26, height: 26,
                                  decoration: BoxDecoration(color: const Color(0xFF4F46E5), shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2)),
                                  child: const Icon(Icons.camera_alt, size: 14, color: Colors.white)),
                              ),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        Text(p.name, style: const TextStyle(fontFamily: AppFonts.heading, fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                        const SizedBox(height: 4),
                        Text(
                          [if (p.className.isNotEmpty) 'Class ${p.className}', if (p.rollNumber.isNotEmpty) 'Roll No. ${p.rollNumber}', if (p.session.isNotEmpty) 'Session ${p.session}'].join(' · '),
                          style: const TextStyle(fontSize: 11, color: Colors.white54),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(16)),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                            _stat('${p.avgScore}%', 'Avg Score'.tr(ref)),
                            _stat('${p.attendancePct}%', 'Attend.'.tr(ref)),
                            _stat(p.rank.isEmpty ? '—' : p.rank, 'Rank'.tr(ref)),
                            _stat(p.badges, 'Badges'.tr(ref)),
                          ]),
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
              _sectionLabel('Personal Info'.tr(ref)),
              _infoCard([
                ('Gender'.tr(ref), p.gender, false),
                ('Date of Birth'.tr(ref), p.dateOfBirth, false),
                ('Blood Group'.tr(ref), p.bloodGroup, false),
                ('Email'.tr(ref), p.email, true),
                ('Phone'.tr(ref), p.phone.isEmpty ? '' : '📞 ${p.phone}', true),
                ('Admission No.'.tr(ref), p.admissionNumber, false),
                ('Nationality'.tr(ref), p.nationality, false),
                ('Religion'.tr(ref), p.religion, false),
                ('Category'.tr(ref), p.category, false),
                ('Address'.tr(ref), p.address, false),
                ('House'.tr(ref), p.house, false),
              ]),
              const SizedBox(height: 12),
              _sectionLabel('Father/Guardian'.tr(ref)),
              _infoCard([
                ('Name'.tr(ref), p.fatherName, false),
                ('Occupation'.tr(ref), p.fatherOccupation, false),
                ('Phone'.tr(ref), p.fatherPhone.isEmpty ? '' : '📞 ${p.fatherPhone}', true),
              ]),
              const SizedBox(height: 12),
              _sectionLabel('Mother'.tr(ref)),
              _infoCard([
                ('Name'.tr(ref), p.motherName, false),
                ('Occupation'.tr(ref), p.motherOccupation, false),
                ('Phone'.tr(ref), p.motherPhone.isEmpty ? '' : '📞 ${p.motherPhone}', true),
              ]),
              const SizedBox(height: 12),
              _sectionLabel('📎 Documents'.tr(ref)),
              _docsCard(p),
              const SizedBox(height: 80),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _initials(String name) {
    final i = name.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
    return Center(child: Text(i, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)));
  }

  Widget _stat(String v, String l) => Column(children: [
    Text(v, style: const TextStyle(fontFamily: AppFonts.heading, fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
    const SizedBox(height: 2),
    Text(l, style: const TextStyle(fontSize: 9, color: Colors.white38)),
  ]);

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t.toUpperCase(), style: TextStyle(
      fontFamily: AppFonts.heading, 
      fontSize: 10, 
      fontWeight: FontWeight.w700, 
      color: Theme.of(context).brightness == Brightness.dark ? StudentColors.darkText3 : StudentColors.text3, 
      letterSpacing: 0.6
    )),
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
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
        ]
      ),
      child: Column(children: visible.asMap().entries.map((e) {
        final isLast = e.key == visible.length - 1;
        final (label, value, indigo) = e.value;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            border: isLast ? null : Border(bottom: BorderSide(color: isDark ? StudentColors.darkBorder : const Color(0xFFF8FAFC)))
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: TextStyle(fontSize: 11, color: isDark ? StudentColors.darkText3 : StudentColors.text3)),
            Flexible(child: Text(value.isEmpty ? '—' : value,
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.w600, 
                color: indigo ? const Color(0xFF4F46E5) : (isDark ? StudentColors.darkText : StudentColors.text)
              ),
              textAlign: TextAlign.right)),
          ]),
        );
      }).toList()),
    );
  }

  Widget _docsCard(StudentProfileModel p) {
    final requiredDocs = [
      'Birth Certificate',
      'Aadhaar Card',
      'Previous Marksheet',
      'Migration Certificate',
      'Character Certificate',
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
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)
        ]
      ),
      child: Column(children: allDocs.asMap().entries.map((e) {
        final isLast = e.key == allDocs.length - 1;
        final name = e.value.$1;
        final status = e.value.$2;

        String statusText;
        Color statusColor;
        if (status == 'verified') {
          statusText = '✅ Verified';
          statusColor = StudentColors.success;
        } else if (status == 'pending') {
          statusText = '⏳ In Review';
          statusColor = Colors.amber.shade700;
        } else {
          statusText = '⚠️ Pending Upload';
          statusColor = StudentColors.warning;
        }

        return GestureDetector(
          onTap: () {
            if (status != 'missing' && uploadedMap.containsKey(name)) {
              final doc = uploadedMap[name]!;
              final lowUrl = doc.fileUrl.toLowerCase();
              if (lowUrl.contains('.jpg') || lowUrl.contains('.jpeg') || lowUrl.contains('.png')) {
                ImagePreviewDialog.show(context, doc.fileUrl, title: name);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('📄 File is not an image (PDF/Doc)'.tr(ref))));
              }
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              border: isLast ? null : Border(bottom: BorderSide(color: isDark ? StudentColors.darkBorder : const Color(0xFFF8FAFC)))
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(name, style: TextStyle(fontSize: 11, color: isDark ? StudentColors.darkText3 : StudentColors.text3)),
              Text(statusText, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor)),
            ]),
          ),
        );
      }).toList()),
    );
  }
}

// ── Edit Sheet ────────────────────────────────────────────────────────────────

class _EditSheet extends ConsumerStatefulWidget {
  final StudentProfileModel profile;
  const _EditSheet({required this.profile});
  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name, _email, _phone, _address, _nationality,
      _fatherName, _fatherOcc, _fatherPhone, _motherName, _motherOcc, _motherPhone, _guardian;

  String _gender = 'Male';
  String _bloodGroup = 'O+';
  String _religion = 'Hindu';
  String _category = 'General';
  String _docType = 'Migration Certificate';
  String? _uploadedFileName;
  Uint8List? _uploadedFileBytes;
  DateTime? _dob;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _name        = TextEditingController(text: p.name);
    _email       = TextEditingController(text: p.email);
    _phone       = TextEditingController(text: p.phone);
    _address     = TextEditingController(text: p.address);
    _nationality = TextEditingController(text: p.nationality.isEmpty ? 'Indian' : p.nationality);
    _fatherName  = TextEditingController(text: p.fatherName);
    _fatherOcc   = TextEditingController(text: p.fatherOccupation);
    _fatherPhone = TextEditingController(text: p.fatherPhone);
    _motherName  = TextEditingController(text: p.motherName);
    _motherOcc   = TextEditingController(text: p.motherOccupation);
    _motherPhone = TextEditingController(text: p.motherPhone);
    _guardian    = TextEditingController(text: p.localGuardian);

    if (['Male','Female','Other'].contains(p.gender)) _gender = p.gender;
    if (['A+','A-','B+','B-','O+','O-','AB+','AB-'].contains(p.bloodGroup)) _bloodGroup = p.bloodGroup;
    if (['Hindu','Muslim','Christian','Sikh','Buddhist','Jain','Other'].contains(p.religion)) _religion = p.religion;
    if (['General','OBC','SC','ST','EWS'].contains(p.category)) _category = p.category;
    if (p.dateOfBirth.isNotEmpty) _dob = DateTime.tryParse(p.dateOfBirth);
  }

  @override
  void dispose() {
    for (final c in [_name,_email,_phone,_address,_nationality,_fatherName,_fatherOcc,
        _fatherPhone,_motherName,_motherOcc,_motherPhone,_guardian]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pickDoc() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf','jpg','jpeg','png'], withData: true);
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
      initialDate: _dob ?? DateTime(2009, 1, 1),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
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
    };
    if (_dob != null) {
      data['date_of_birth'] = '${_dob!.year}-${_dob!.month.toString().padLeft(2,'0')}-${_dob!.day.toString().padLeft(2,'0')}';
    }

    // 1. Upload document if selected
    if (_uploadedFileBytes != null && _uploadedFileName != null) {
      await ref.read(profileProvider.notifier).uploadDocument(_uploadedFileBytes!, _uploadedFileName!, _docType);
    }

    // 2. Update text profile fields
    final ok = await ref.read(profileProvider.notifier).updateProfile(data);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '✅ Profile Updated Successfully!' : '❌ Save failed. Try again.'),
      backgroundColor: ok ? StudentColors.success : StudentColors.error,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final saving = ref.watch(profileProvider).isSaving;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DraggableScrollableSheet(
      initialChildSize: 0.92, maxChildSize: 0.95, minChildSize: 0.5,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))
        ),
        child: Form(
          key: _formKey,
          child: ListView(controller: sc, padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
            Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(color: isDark ? StudentColors.darkBorder : StudentColors.border, borderRadius: BorderRadius.circular(2)))),
            Text('✏️ Edit Profile', textAlign: TextAlign.center,
              style: TextStyle(fontFamily: AppFonts.heading, fontSize: 17, fontWeight: FontWeight.w800, color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 20),

            _groupLabel('STUDENT DETAILS'),
            _tf('Full Name', _name, Icons.person_outline),
            Row(children: [
              Expanded(child: _drop('Gender', _gender, ['Male','Female','Other'], (v) => setState(() => _gender = v!))),
              const SizedBox(width: 10),
              Expanded(child: _dobField()),
            ]),
            Row(children: [
              Expanded(child: _drop('Blood Group', _bloodGroup, ['A+','A-','B+','B-','O+','O-','AB+','AB-'], (v) => setState(() => _bloodGroup = v!))),
              const SizedBox(width: 10),
              Expanded(child: _tf('Nationality', _nationality, Icons.flag_outlined)),
            ]),
            Row(children: [
              Expanded(child: _drop('Religion', _religion, ['Hindu','Muslim','Christian','Sikh','Buddhist','Jain','Other'], (v) => setState(() => _religion = v!))),
              const SizedBox(width: 10),
              Expanded(child: _drop('Category', _category, ['General','OBC','SC','ST','EWS'], (v) => setState(() => _category = v!))),
            ]),
            _tf('Email', _email, Icons.email_outlined, type: TextInputType.emailAddress),
            _tf('Phone', _phone, Icons.phone_outlined, type: TextInputType.phone),
            _tf('Address', _address, Icons.home_outlined, lines: 2),

            _groupLabel('FATHER / GUARDIAN'),
            _tf("Father's Name", _fatherName, Icons.person_outline),
            _tf('Occupation', _fatherOcc, Icons.work_outline),
            _tf("Father's Phone", _fatherPhone, Icons.phone_outlined, type: TextInputType.phone),

            _groupLabel('MOTHER'),
            _tf("Mother's Name", _motherName, Icons.person_outline),
            _tf('Occupation', _motherOcc, Icons.work_outline),
            _tf("Mother's Phone", _motherPhone, Icons.phone_outlined, type: TextInputType.phone),
            _tf('Local Guardian', _guardian, Icons.supervised_user_circle_outlined),

            _groupLabel('📎 UPLOAD DOCUMENTS'),
            _drop('Document Type', _docType, [
              'Domicile Certificate','Caste Certificate','Transfer Certificate (TC)',
              'Character Certificate','Migration Certificate','Birth Certificate',
              'Aadhaar Card','Passport Photo','Income Certificate','Medical Certificate','Previous Marksheet',
            ], (v) => setState(() => _docType = v!)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickDoc,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: isDark ? StudentColors.darkBorder : StudentColors.border, width: 2),
                  borderRadius: BorderRadius.circular(14),
                  color: isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFF8FAFC),
                ),
                child: Column(children: [
                  const Text('📁', style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 4),
                  Text('Tap to upload file', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                  Text('PDF, JPG, PNG up to 5MB', style: TextStyle(fontSize: 9, color: isDark ? StudentColors.darkText3 : StudentColors.text3)),
                  if (_uploadedFileName != null) ...[
                    const SizedBox(height: 6),
                    Text('📎 $_uploadedFileName', style: const TextStyle(fontSize: 10, color: StudentColors.success, fontWeight: FontWeight.w600)),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 8),
            if (widget.profile.documents.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: StudentColors.successBg, borderRadius: BorderRadius.circular(10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('📎 Uploaded Documents', style: TextStyle(fontSize: 11, color: StudentColors.success, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    ...widget.profile.documents.map((doc) {
                      final isVerified = doc.status == 'verified';
                      final icon = isVerified ? '✅' : '⏳';
                      final color = isVerified ? StudentColors.success : Colors.amber.shade700;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('$icon ${doc.type} (${doc.status})', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
                      );
                    }),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            SizedBox(height: 50, child: ElevatedButton(
              onPressed: saving ? null : _save,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('💾 Save All Changes', style: TextStyle(fontFamily: AppFonts.heading, fontSize: 14, fontWeight: FontWeight.w700)),
            )),
            const SizedBox(height: 8),
            TextButton(onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(backgroundColor: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Text('Cancel', style: TextStyle(color: isDark ? StudentColors.darkText2 : StudentColors.text2))),
          ]),
        ),
      ),
    );
  }

  Widget _groupLabel(String t) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(t, style: TextStyle(
        fontFamily: AppFonts.heading, 
        fontSize: 10, 
        fontWeight: FontWeight.w700, 
        color: isDark ? StudentColors.darkText3 : StudentColors.text3, 
        letterSpacing: 0.6
      )),
    );
  }

  Widget _tf(String label, TextEditingController c, IconData icon, {TextInputType type = TextInputType.text, int lines = 1}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: TextFormField(
      controller: c, keyboardType: type, maxLines: lines,
      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? StudentColors.darkText3 : StudentColors.text3),
        prefixIcon: Icon(icon, size: 18, color: isDark ? StudentColors.darkText3 : StudentColors.text3),
        filled: true, fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? StudentColors.darkBorder : StudentColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? StudentColors.darkBorder : StudentColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
      ),
    ));
  }

  Widget _drop(String label, String val, List<String> items, ValueChanged<String?> onChange) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: DropdownButtonFormField<String>(
      initialValue: val,
      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? StudentColors.darkText3 : StudentColors.text3),
        filled: true, fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? StudentColors.darkBorder : StudentColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? StudentColors.darkBorder : StudentColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
      ),
      isExpanded: true,
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black)))).toList(),
      onChanged: onChange,
    ));
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
            labelStyle: TextStyle(color: isDark ? StudentColors.darkText3 : StudentColors.text3),
            prefixIcon: Icon(Icons.calendar_today_outlined, size: 18, color: isDark ? StudentColors.darkText3 : StudentColors.text3),
            filled: true, fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? StudentColors.darkBorder : StudentColors.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? StudentColors.darkBorder : StudentColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5)),
          ),
          child: Text(label, style: TextStyle(fontSize: 13, color: _dob != null ? (isDark ? Colors.white : StudentColors.text) : (isDark ? StudentColors.darkText3 : StudentColors.text3))),
        ),
      ),
    );
  }
}
