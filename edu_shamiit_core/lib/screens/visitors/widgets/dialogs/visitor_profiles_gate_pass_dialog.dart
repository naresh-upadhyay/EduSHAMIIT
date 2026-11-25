import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/visitor_models.dart';
import '../../providers/visitors_provider.dart';
import '../common/scannable_qr_widget.dart';
import '../../../../utils/js_helper.dart';

class VisitorProfilesGatePassDialog extends ConsumerStatefulWidget {
  const VisitorProfilesGatePassDialog({super.key});

  @override
  ConsumerState<VisitorProfilesGatePassDialog> createState() =>
      _VisitorProfilesGatePassDialogState();
}

class _VisitorProfilesGatePassDialogState
    extends ConsumerState<VisitorProfilesGatePassDialog> {
  int _currentStep = 0; // 0: Select Profiles, 1: Configure Pass, 2: View Passes

  // Search and filter
  final TextEditingController _searchCtrl = TextEditingController();
  String _selectedCategory = 'All';

  // Selection
  final Set<String> _selectedProfileIds = {};
  final Map<String, VisitorProfileItem> _selectedProfilesMap = {};

  // Inline Profile Creation
  bool _isCreatingProfile = false;
  final _newProfileFormKey = GlobalKey<FormState>();
  final TextEditingController _newNameCtrl = TextEditingController();
  final TextEditingController _newPhoneCtrl = TextEditingController();
  final TextEditingController _newEmailCtrl = TextEditingController();
  final TextEditingController _newCompanyCtrl = TextEditingController();
  final TextEditingController _newPhotoUrlCtrl = TextEditingController();
  String _newVisitorType = 'Parent';
  final String _newIdType = 'Aadhaar Card';

  // Step 2 Pass Configuration
  String _selectedLocation = 'Main Gate';
  final TextEditingController _hostNameCtrl =
      TextEditingController(text: 'General Administration');
  final TextEditingController _hostDeptCtrl =
      TextEditingController(text: 'Administration');
  String _purpose = 'Official Visit';
  int _durationHours = 4;
  final TextEditingController _vehicleNumCtrl = TextEditingController();
  final TextEditingController _remarksCtrl = TextEditingController();
  bool _autoCheckIn = false;
  bool _isGenerating = false;

  // Step 3 Generated Passes
  List<GeneratedGatePassItem> _generatedPasses = [];
  int _activePassIndex = 0;

  static const List<String> _categories = [
    'All',
    'Parent',
    'Official',
    'Vendor',
    'Relative',
    'Guest',
    'Alumni',
    'Other'
  ];

  static const List<String> _purposeOptions = [
    'Official Visit',
    'Meeting with Host',
    'Campus Inspection',
    'Vendor Delivery / Supply',
    'Fee Inquiry / Payment',
    'Student Academic Review',
    'Admission Inquiry',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(visitorsProvider.notifier).fetchProfiles();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _newNameCtrl.dispose();
    _newPhoneCtrl.dispose();
    _newEmailCtrl.dispose();
    _newCompanyCtrl.dispose();
    _newPhotoUrlCtrl.dispose();
    _hostNameCtrl.dispose();
    _hostDeptCtrl.dispose();
    _vehicleNumCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    ref.read(visitorsProvider.notifier).fetchProfiles(
          search: val,
          visitorType: _selectedCategory,
        );
  }

  void _onCategoryChanged(String cat) {
    setState(() => _selectedCategory = cat);
    ref.read(visitorsProvider.notifier).fetchProfiles(
          search: _searchCtrl.text,
          visitorType: cat,
        );
  }

  Future<void> _handleCreateProfile() async {
    if (!_newProfileFormKey.currentState!.validate()) return;
    final notifier = ref.read(visitorsProvider.notifier);
    final success = await notifier.createProfile({
      'full_name': _newNameCtrl.text.trim(),
      'phone': _newPhoneCtrl.text.trim(),
      'email': _newEmailCtrl.text.trim().isNotEmpty
          ? _newEmailCtrl.text.trim()
          : null,
      'company': _newCompanyCtrl.text.trim().isNotEmpty
          ? _newCompanyCtrl.text.trim()
          : null,
      'visitor_type': _newVisitorType,
      'id_type': _newIdType,
      'photo_url': _newPhotoUrlCtrl.text.trim().isNotEmpty
          ? _newPhotoUrlCtrl.text.trim()
          : null,
    });
    if (success && mounted) {
      setState(() {
        _isCreatingProfile = false;
        _newNameCtrl.clear();
        _newPhoneCtrl.clear();
        _newEmailCtrl.clear();
        _newCompanyCtrl.clear();
        _newPhotoUrlCtrl.clear();
      });
    }
  }

  Future<void> _handleGeneratePasses() async {
    if (_selectedProfileIds.isEmpty) return;
    setState(() => _isGenerating = true);
    final notifier = ref.read(visitorsProvider.notifier);

    final payload = {
      'visitor_ids': _selectedProfileIds.toList(),
      'location': _selectedLocation,
      'host_name': _hostNameCtrl.text.trim().isNotEmpty
          ? _hostNameCtrl.text.trim()
          : 'General Administration',
      'host_department': _hostDeptCtrl.text.trim().isNotEmpty
          ? _hostDeptCtrl.text.trim()
          : 'Administration',
      'purpose': _purpose,
      'duration_hours': _durationHours,
      'vehicle_number': _vehicleNumCtrl.text.trim().isNotEmpty
          ? _vehicleNumCtrl.text.trim()
          : null,
      'auto_check_in': _autoCheckIn,
      'remarks': _remarksCtrl.text.trim().isNotEmpty
          ? _remarksCtrl.text.trim()
          : null,
    };

    final passes = await notifier.generateBatchGatePasses(payload);
    setState(() {
      _isGenerating = false;
      if (passes.isNotEmpty) {
        _generatedPasses = passes;
        _currentStep = 2;
        _activePassIndex = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(visitorsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isNarrow = screenWidth < 700;
    final dialogWidth = isNarrow ? screenWidth * 0.95 : 680.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 8 : 24,
        vertical: 16,
      ),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.92),
        padding: EdgeInsets.all(isNarrow ? 16 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Bar: Icon, Title, Stepper Indicator, Close
            _buildTopBar(isDark),
            const SizedBox(height: 14),

            // Step Indicator Row
            _buildStepIndicator(isDark),
            const SizedBox(height: 16),

            // Body based on current step
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _currentStep == 0
                    ? _buildStep1Profiles(state, isDark)
                    : _currentStep == 1
                        ? _buildStep2Config(state, isDark)
                        : _buildStep3Passes(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: Color(0xFF2563EB),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Visitor Profiles & Gate Pass',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Select profiles, configure destination, and generate scannable QR gate passes',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded,
              size: 20, color: Color(0xFF64748B)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildStepIndicator(bool isDark) {
    return Row(
      children: [
        Flexible(
          child: _buildStepBadge(
              0, '1. Select Profiles', _currentStep >= 0, _currentStep == 0),
        ),
        Container(
          width: 24,
          height: 2,
          color: _currentStep >= 1
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        Flexible(
          child: _buildStepBadge(
              1, '2. Pass Details', _currentStep >= 1, _currentStep == 1),
        ),
        Container(
          width: 24,
          height: 2,
          color: _currentStep >= 2
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        Flexible(
          child: _buildStepBadge(
              2, '3. QR Passes', _currentStep >= 2, _currentStep == 2),
        ),
      ],
    );
  }

  Widget _buildStepBadge(
      int step, String label, bool isCompleted, bool isCurrent) {
    final activeColor =
        isCurrent || isCompleted ? const Color(0xFF2563EB) : const Color(0xFF94A3B8);
    return InkWell(
      onTap: _currentStep > step ? () => setState(() => _currentStep = step) : null,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isCurrent
              ? const Color(0xFF2563EB).withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 9,
              backgroundColor: activeColor,
              child: isCompleted && !isCurrent
                  ? const Icon(Icons.check, size: 11, color: Colors.white)
                  : Text(
                      '${step + 1}',
                      style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                          fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                  color: activeColor,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // STEP 1: Select Profiles & Inline Creation
  // =========================================================================
  Widget _buildStep1Profiles(VisitorsState state, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Search & Category Chips & "+ New Profile" button
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 38,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search by visitor name, phone, or company...',
                    prefixIcon: const Icon(Icons.search_rounded,
                        size: 18, color: Color(0xFF64748B)),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              _searchCtrl.clear();
                              _onSearchChanged('');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () =>
                  setState(() => _isCreatingProfile = !_isCreatingProfile),
              icon: Icon(
                _isCreatingProfile
                    ? Icons.expand_less_rounded
                    : Icons.person_add_rounded,
                size: 16,
                color: Colors.white,
              ),
              label: Text(
                _isCreatingProfile ? 'Close Form' : '+ New Profile',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // Category Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.map((cat) {
              final isSel = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text(cat, style: const TextStyle(fontSize: 11)),
                  selected: isSel,
                  onSelected: (_) => _onCategoryChanged(cat),
                  selectedColor: const Color(0xFF2563EB),
                  backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                  side: BorderSide(
                    color: isSel
                        ? const Color(0xFF2563EB)
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  labelStyle: TextStyle(
                    color: isSel
                        ? Colors.white
                        : (isDark
                            ? const Color(0xFFCBD5E1)
                            : const Color(0xFF475569)),
                    fontWeight: isSel ? FontWeight.w600 : FontWeight.w400,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),

        // Inline Creation Form (Collapsible)
        if (_isCreatingProfile) ...[
          _buildInlineProfileForm(isDark),
          const SizedBox(height: 10),
        ],

        // Profiles Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Checkbox(
                value: state.profiles.isNotEmpty &&
                    _selectedProfileIds.length == state.profiles.length,
                onChanged: (val) {
                  setState(() {
                    if (val == true) {
                      for (final p in state.profiles) {
                        if (!p.isBlacklisted) {
                          _selectedProfileIds.add(p.id);
                          _selectedProfilesMap[p.id] = p;
                        }
                      }
                    } else {
                      _selectedProfileIds.clear();
                      _selectedProfilesMap.clear();
                    }
                  });
                },
                activeColor: const Color(0xFF2563EB),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              const Expanded(
                flex: 3,
                child: Text('Visitor Profile',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B))),
              ),
              const Expanded(
                flex: 2,
                child: Text('Type & Org',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B))),
              ),
              const SizedBox(
                width: 70,
                child: Text('Visits',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B))),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Profiles List
        Expanded(
          child: state.isLoadingProfiles
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF2563EB)))
              : state.profiles.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_off_outlined,
                              size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          Text(
                            'No visitor profiles found.',
                            style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 6),
                          TextButton.icon(
                            onPressed: () => setState(() => _isCreatingProfile = true),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Create New Profile'),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: state.profiles.length,
                      itemBuilder: (context, idx) {
                        final profile = state.profiles[idx];
                        final isSelected =
                            _selectedProfileIds.contains(profile.id);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                    ? const Color(0xFF1E3A8A)
                                        .withValues(alpha: 0.25)
                                    : const Color(0xFFEFF6FF))
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF2563EB)
                                      .withValues(alpha: 0.5)
                                  : (isDark
                                      ? const Color(0xFF334155)
                                      : const Color(0xFFE2E8F0)),
                            ),
                          ),
                          child: InkWell(
                            onTap: profile.isBlacklisted
                                ? null
                                : () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedProfileIds.remove(profile.id);
                                        _selectedProfilesMap.remove(profile.id);
                                      } else {
                                        _selectedProfileIds.add(profile.id);
                                        _selectedProfilesMap[profile.id] =
                                            profile;
                                      }
                                    });
                                  },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 6),
                              child: Row(
                                children: [
                                  Checkbox(
                                    value: isSelected,
                                    onChanged: profile.isBlacklisted
                                        ? null
                                        : (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedProfileIds
                                                    .add(profile.id);
                                                _selectedProfilesMap[
                                                    profile.id] = profile;
                                              } else {
                                                _selectedProfileIds
                                                    .remove(profile.id);
                                                _selectedProfilesMap
                                                    .remove(profile.id);
                                              }
                                            });
                                          },
                                    activeColor: const Color(0xFF2563EB),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  const SizedBox(width: 6),
                                  // Avatar
                                  CircleAvatar(
                                    radius: 17,
                                    backgroundColor: const Color(0xFF2563EB)
                                        .withValues(alpha: 0.15),
                                    backgroundImage: profile.photoUrl != null &&
                                            profile.photoUrl!.isNotEmpty
                                        ? NetworkImage(profile.photoUrl!)
                                        : null,
                                    child: profile.photoUrl == null ||
                                            profile.photoUrl!.isEmpty
                                        ? Text(
                                            profile.fullName.isNotEmpty
                                                ? profile.fullName[0]
                                                    .toUpperCase()
                                                : 'V',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF2563EB)),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  // Name & Phone
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          profile.fullName,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: isDark
                                                ? Colors.white
                                                : const Color(0xFF0F172A),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          profile.phone,
                                          style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF64748B)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Type badge & Company
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            profile.visitorType,
                                            style: const TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF2563EB)),
                                          ),
                                        ),
                                        if (profile.company != null &&
                                            profile.company!.isNotEmpty)
                                          Text(
                                            profile.company!,
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: isDark
                                                  ? const Color(0xFF94A3B8)
                                                  : const Color(0xFF64748B),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                      ],
                                    ),
                                  ),
                                  // Visits count / blacklist badge
                                  SizedBox(
                                    width: 70,
                                    child: profile.isBlacklisted
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                                color: const Color(0xFFFEE2E2),
                                                borderRadius:
                                                    BorderRadius.circular(4)),
                                            child: const Text('BLOCKED',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFFDC2626))),
                                          )
                                        : Text(
                                            '${profile.totalVisits} visits',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark
                                                  ? const Color(0xFF94A3B8)
                                                  : const Color(0xFF64748B),
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
        ),
        const SizedBox(height: 12),

        // Bottom Action Bar for Step 1
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 10,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_selectedProfileIds.length} profile${_selectedProfileIds.length == 1 ? '' : 's'} selected',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2563EB)),
              ),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  onPressed: _selectedProfileIds.isEmpty
                      ? null
                      : () => setState(() => _currentStep = 1),
                  icon: const Icon(Icons.arrow_forward_rounded,
                      size: 16, color: Colors.white),
                  label: const Text('Next: Pass Details',
                      style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInlineProfileForm(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF16A34A).withValues(alpha: 0.3)),
      ),
      child: Form(
        key: _newProfileFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.add_circle_outline_rounded,
                    size: 16, color: Color(0xFF16A34A)),
                const SizedBox(width: 6),
                const Text(
                  'Quick New Visitor Profile Creation',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF16A34A)),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () => setState(() => _isCreatingProfile = false),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _newNameCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Full Name *',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 2) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _newPhoneCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Phone Number *',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().length < 7) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppSearchableDropdownFormField<String>.fromMenuItems(
                    initialValue: _newVisitorType,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Visitor Type',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      'Parent',
                      'Official',
                      'Vendor',
                      'Relative',
                      'Guest',
                      'Alumni',
                      'Other'
                    ]
                        .map((t) =>
                            DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _newVisitorType = v ?? 'Parent'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _newCompanyCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Company / Organization (Optional)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _newEmailCtrl,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Email Address (Optional)',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _handleCreateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  child: const Text('Save Profile',
                      style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // STEP 2: Configure Gate Pass & Destination Location
  // =========================================================================
  Widget _buildStep2Config(VisitorsState state, bool isDark) {
    final selectedProfiles = _selectedProfileIds
        .map((id) => _selectedProfilesMap[id])
        .whereType<VisitorProfileItem>()
        .toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Selected Visitors preview chips
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Selected Visitors (${selectedProfiles.length}):',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _currentStep = 0),
                      style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(50, 24)),
                      child: const Text('Change Selection',
                          style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: selectedProfiles.map((p) {
                    return Chip(
                      avatar: CircleAvatar(
                        backgroundColor: const Color(0xFF2563EB),
                        child: Text(
                          p.fullName.isNotEmpty ? p.fullName[0] : 'V',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white),
                        ),
                      ),
                      label: Text('${p.fullName} (${p.visitorType})',
                          style: const TextStyle(fontSize: 11)),
                      backgroundColor: isDark
                          ? const Color(0xFF1E293B)
                          : Colors.white,
                      padding: const EdgeInsets.all(2),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Location Dropdown (Main Gate, Library, Lab, Hostel, etc.)
          Text(
            'Target Checkpoint / Destination Location *',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          AppSearchableDropdownFormField<String>.fromMenuItems(
            initialValue: state.availableLocations.contains(_selectedLocation)
                ? _selectedLocation
                : state.availableLocations.first,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.location_on_outlined,
                  size: 18, color: Color(0xFF2563EB)),
              filled: true,
              fillColor:
                  isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFCBD5E1)),
              ),
            ),
            items: state.availableLocations
                .map((loc) => DropdownMenuItem(
                      value: loc,
                      child: Text(loc, style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedLocation = val);
            },
          ),
          const SizedBox(height: 12),

          // Host Name & Department
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Host Person / Office *',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _hostNameCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. Principal / Director',
                        prefixIcon: const Icon(Icons.person_outline, size: 18),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Host Department',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _hostDeptCtrl,
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'e.g. Directorate',
                        prefixIcon:
                            const Icon(Icons.business_outlined, size: 18),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Purpose Dropdown
          Text('Purpose of Visit *',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF0F172A))),
          const SizedBox(height: 4),
          AppSearchableDropdownFormField<String>.fromMenuItems(
            initialValue: _purposeOptions.contains(_purpose) ? _purpose : _purposeOptions.first,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.flag_outlined, size: 18),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              isDense: true,
            ),
            items: _purposeOptions
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(p, style: const TextStyle(fontSize: 13)),
                    ))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _purpose = val);
            },
          ),
          const SizedBox(height: 12),

          // Stay Duration Chips & Vehicle Number
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pass Validity Duration',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    Row(
                      children: [1, 2, 4, 8].map((h) {
                        final isSel = _durationHours == h;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text('${h}h',
                                style: const TextStyle(fontSize: 11)),
                            selected: isSel,
                            onSelected: (_) =>
                                setState(() => _durationHours = h),
                            selectedColor: const Color(0xFF2563EB),
                            backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            side: BorderSide(
                              color: isSel
                                  ? const Color(0xFF2563EB)
                                  : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                            ),
                            labelStyle: TextStyle(
                              color: isSel
                                  ? Colors.white
                                  : (isDark ? Colors.white : const Color(0xFF1E293B)),
                              fontWeight:
                                  isSel ? FontWeight.bold : FontWeight.w600,
                            ),
                            visualDensity: VisualDensity.compact,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vehicle Number (Optional)',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _vehicleNumCtrl,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        hintText: 'e.g. DL-01-AB-1234',
                        hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                        prefixIcon:
                            const Icon(Icons.directions_car_outlined, size: 18),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Auto Check-In Toggle
          SwitchListTile(
            value: _autoCheckIn,
            onChanged: (v) => setState(() => _autoCheckIn = v),
            title: const Text('Mark Checked-In Immediately (Inside Campus)',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: const Text(
                'When enabled, visitors will be marked inside campus immediately. Otherwise, pass remains scheduled until scanned at gate.',
                style: TextStyle(fontSize: 11)),
            activeTrackColor: const Color(0xFF16A34A),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),

          // Bottom Action Buttons
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: () => setState(() => _currentStep = 0),
                icon: const Icon(Icons.arrow_back_rounded, size: 16),
                label: const Text('Back to Profiles'),
              ),
              ElevatedButton.icon(
                onPressed: _isGenerating ? null : _handleGeneratePasses,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.qr_code_2_rounded,
                        size: 18, color: Colors.white),
                label: Text(
                  _isGenerating
                      ? 'Generating Passes...'
                      : 'Generate Gate Passes for Selected (${selectedProfiles.length})',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // STEP 3: Official Gate Passes Display (Genuine Scannable QR Cards)
  // =========================================================================
  Widget _buildStep3Passes(bool isDark) {
    if (_generatedPasses.isEmpty) {
      return const Center(child: Text('No gate passes generated.'));
    }

    final activePass = _generatedPasses[_activePassIndex.clamp(0, _generatedPasses.length - 1)];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Carousel Header if multiple passes
        if (_generatedPasses.length > 1) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gate Pass ${_activePassIndex + 1} of ${_generatedPasses.length}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2563EB)),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: _activePassIndex > 0
                        ? () => setState(() => _activePassIndex--)
                        : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: _activePassIndex < _generatedPasses.length - 1
                        ? () => setState(() => _activePassIndex++)
                        : null,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],

        // Official Gate Pass Card (Matches User's Screenshot Exactly!)
        Expanded(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                    width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Institute Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'EduSHAMIIT ERP',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          Text(
                            'Greenwood High International School',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'AUTHORIZED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF15803D),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(
                      height: 20, thickness: 1, color: Color(0xFFE2E8F0)),

                  // Pass Details & Scannable QR Code
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Genuine Scannable QR Code Widget
                      Column(
                        children: [
                          ScannableQrWidget(
                            passNumber: activePass.passNumber,
                            qrBase64: activePass.qrCodeBase64,
                            size: 110,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            activePass.passNumber,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? const Color(0xFF94A3B8)
                                  : const Color(0xFF475569),
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),

                      // Metadata Fields
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activePass.visitorName,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              'Type: ${activePass.visitorType} • ${activePass.phone}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildPassRow(
                                'Pass ID', activePass.passNumber, isDark),
                            _buildPassRow(
                                'Destination', activePass.destination, isDark),
                            _buildPassRow('Host', activePass.hostName, isDark),
                            _buildPassRow(
                                'Check In',
                                activePass.checkInAt != null
                                    ? activePass.checkInAt!.split('T')[0]
                                    : 'Pending Gate Scan',
                                isDark),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Security Notice Banner
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Security Notice: This gate pass must be presented upon campus exit. Valid for authorized locations only.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 9.5, color: Color(0xFF1D4ED8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Action Buttons: Print Badge & Pass (Single / All Together) + Done
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close & View Grid'),
            ),
            if (_generatedPasses.length > 1) ...[
              OutlinedButton.icon(
                onPressed: () {
                  printVisitorGatePassHtml(
                    passNumber: activePass.passNumber,
                    visitorName: activePass.visitorName,
                    visitorType: activePass.visitorType,
                    phone: activePass.phone,
                    destination: activePass.destination,
                    hostName: activePass.hostName,
                    checkInAt: activePass.checkInAt,
                    validUntil: 'Valid for ${_durationHours}h',
                    qrBase64: activePass.qrCodeBase64,
                  );
                },
                icon: const Icon(Icons.print_outlined, size: 16),
                label: Text('Print This Pass (${_activePassIndex + 1})'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  final allPassesData = _generatedPasses.map((p) => {
                    'passNumber': p.passNumber,
                    'visitorName': p.visitorName,
                    'visitorType': p.visitorType,
                    'phone': p.phone,
                    'destination': p.destination,
                    'hostName': p.hostName,
                    'checkInAt': p.checkInAt,
                    'validUntil': 'Valid for ${_durationHours}h',
                    'qrBase64': p.qrCodeBase64,
                  }).toList();

                  printMultipleVisitorGatePassesHtml(passes: allPassesData);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Printing all ${_generatedPasses.length} gate passes together.'),
                      backgroundColor: const Color(0xFF16A34A),
                    ),
                  );
                },
                icon: const Icon(Icons.print_rounded, size: 18, color: Colors.white),
                label: Text(
                  'Print All Passes (${_generatedPasses.length})',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ] else ...[
              ElevatedButton.icon(
                onPressed: () {
                  printVisitorGatePassHtml(
                    passNumber: activePass.passNumber,
                    visitorName: activePass.visitorName,
                    visitorType: activePass.visitorType,
                    phone: activePass.phone,
                    destination: activePass.destination,
                    hostName: activePass.hostName,
                    checkInAt: activePass.checkInAt,
                    validUntil: 'Valid for ${_durationHours}h',
                    qrBase64: activePass.qrCodeBase64,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Pass ${activePass.passNumber} sent to printer.'),
                      backgroundColor: const Color(0xFF16A34A),
                    ),
                  );
                },
                icon: const Icon(Icons.print_outlined, size: 18, color: Colors.white),
                label: const Text(
                  'Print Badge & Pass',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPassRow(String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          SizedBox(
            width: 75,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? const Color(0xFF64748B)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
