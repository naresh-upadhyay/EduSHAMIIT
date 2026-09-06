import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/member_models.dart';
import '../../providers/member_provider.dart';

class AddMemberDialog extends ConsumerStatefulWidget {
  const AddMemberDialog({super.key});

  @override
  ConsumerState<AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends ConsumerState<AddMemberDialog> {
  int _currentStep = 0; // 0: Search & Select Profile, 1: Configure Membership Parameters
  ProfileSearchResultModel? _selectedProfile;

  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _memberCodeCtrl = TextEditingController();
  final TextEditingController _borrowingLimitCtrl = TextEditingController(text: '3');
  final TextEditingController _maxDaysCtrl = TextEditingController(text: '14');
  final TextEditingController _notesCtrl = TextEditingController();

  String _membershipType = 'Student';
  DateTime _startDate = DateTime.now();
  DateTime _expiryDate = DateTime.now().add(const Duration(days: 365));
  bool _renewalAllowed = true;
  int _maxRenewals = 2;
  String _status = 'ACTIVE';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(memberProvider.notifier).searchProfiles('');
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _memberCodeCtrl.dispose();
    _borrowingLimitCtrl.dispose();
    _maxDaysCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _onProfileSelected(ProfileSearchResultModel profile) {
    if (profile.isAlreadyMember) return;

    setState(() {
      _selectedProfile = profile;
      _currentStep = 1;
      _membershipType = profile.role.toLowerCase() == 'teacher'
          ? 'Teacher'
          : (profile.role.toLowerCase() == 'library' ? 'Librarian' : (profile.role.toLowerCase() == 'student' ? 'Student' : 'Staff'));
      _borrowingLimitCtrl.text = profile.role.toLowerCase() == 'teacher' ? '5' : '3';
      _maxDaysCtrl.text = profile.role.toLowerCase() == 'teacher' ? '30' : '14';
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(memberProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Column(
          children: [
            // 1. Dialog Header
            Container(
              padding: const EdgeInsets.fromLTRB(22, 18, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF6366F1), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _currentStep == 0 ? 'Add Library Member — Select Profile' : 'Configure Membership Parameters',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          _currentStep == 0
                              ? 'Search active users from the central directory.'
                              : 'Assign borrowing limits and membership duration.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 2. Step Content Area
            Expanded(
              child: _currentStep == 0
                  ? _buildStep0ProfileSearch(state, isDark)
                  : _buildStep1ConfigureMembership(isDark),
            ),

            // 3. Footer Action Buttons
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_currentStep == 1)
                    TextButton.icon(
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Back to Search'),
                      onPressed: () => setState(() => _currentStep = 0),
                    ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  if (_currentStep == 1)
                    ElevatedButton.icon(
                      icon: state.isActionLoading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Create Member', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: state.isActionLoading ? null : _submitCreateMember,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep0ProfileSearch(MemberState state, bool isDark) {
    final existingMemberNames = state.members
        .where((m) => m.isActive)
        .map((m) => m.memberName.trim().toLowerCase())
        .toSet();
    final existingMemberEmails = state.members
        .where((m) => m.isActive && m.email != null && m.email!.trim().isNotEmpty)
        .map((m) => m.email!.trim().toLowerCase())
        .toSet();

    final eligibleCandidates = state.profileSearchResults.where((p) {
      if (p.isAlreadyMember) return false;
      if (existingMemberNames.contains(p.fullName.trim().toLowerCase())) return false;
      if (p.email != null && p.email!.trim().isNotEmpty && existingMemberEmails.contains(p.email!.trim().toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search Field
          TextField(
            controller: _searchCtrl,
            onChanged: (q) => ref.read(memberProvider.notifier).searchProfiles(q),
            decoration: InputDecoration(
              hintText: 'Search eligible non-members by name, email, phone, roll number...',
              hintStyle: const TextStyle(fontSize: 12.5),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          // Search Results List
          Expanded(
            child: state.isSearchingProfiles
                ? const Center(child: CircularProgressIndicator())
                : eligibleCandidates.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.person_search_rounded, size: 36, color: Color(0xFF94A3B8)),
                            const SizedBox(height: 8),
                            Text(
                              _searchCtrl.text.trim().isNotEmpty
                                  ? 'No eligible non-member profiles found matching search.'
                                  : 'All school profiles in the directory are already library members.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        itemCount: eligibleCandidates.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, idx) {
                          final p = eligibleCandidates[idx];
                          return _buildProfileCandidateCard(p, isDark);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileCandidateCard(ProfileSearchResultModel p, bool isDark) {
    return InkWell(
      onTap: p.isAlreadyMember ? null : () => _onProfileSelected(p),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: p.isAlreadyMember
                ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                : const Color(0xFF6366F1).withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.2 : 0.12),
              child: Text(
                p.fullName.isNotEmpty ? p.fullName[0].toUpperCase() : 'U',
                style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6366F1)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        p.fullName,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          p.role.toUpperCase(),
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF6366F1)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.classOrDeptSubtitle,
                    style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  ),
                  if (p.email != null)
                    Text(
                      p.email!,
                      style: TextStyle(fontSize: 10.5, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
                    ),
                ],
              ),
            ),
            if (p.isAlreadyMember)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Member (${p.existingMemberCode ?? "Active"})',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                ),
              )
            else
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF6366F1)),
          ],
        ),
      ),
    );
  }

  Widget _buildStep1ConfigureMembership(bool isDark) {
    final dateFormat = DateFormat('dd MMM yyyy');
    final memberState = ref.watch(memberProvider);
    final availableMemberTypes = memberState.filterOptions.memberTypes.isNotEmpty
        ? memberState.filterOptions.memberTypes
        : ['Student', 'Teacher', 'Staff', 'Librarian', 'Special / Research'];

    final effectiveMembershipType = availableMemberTypes.contains(_membershipType)
        ? _membershipType
        : availableMemberTypes.first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Read-Only Selected Profile Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.15 : 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: const Color(0xFF6366F1),
                  child: Text(
                    _selectedProfile!.fullName.isNotEmpty ? _selectedProfile!.fullName[0].toUpperCase() : 'U',
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedProfile!.fullName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${_selectedProfile!.role.toUpperCase()} • ${_selectedProfile!.classOrDeptSubtitle}',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF6366F1), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _currentStep = 0),
                  child: const Text('Change', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. Form Fields (Membership Type + Code)
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'Membership Type *',
                  child: DropdownButtonFormField<String>(
                    value: effectiveMembershipType,
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    decoration: _inputDecoration(isDark),
                    items: availableMemberTypes.map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Text(type),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _membershipType = val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFormField(
                  label: 'Member Code (Auto-assigned)',
                  child: TextField(
                    controller: _memberCodeCtrl,
                    decoration: _inputDecoration(isDark, hint: 'e.g. LIBM-0025 (Optional)'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Dates (Start Date + Expiry Date)
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'Membership Start Date *',
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setState(() => _startDate = picked);
                    },
                    child: InputDecorator(
                      decoration: _inputDecoration(isDark),
                      child: Text(dateFormat.format(_startDate), style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFormField(
                  label: 'Membership Expiry Date *',
                  child: InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _expiryDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) setState(() => _expiryDate = picked);
                    },
                    child: InputDecorator(
                      decoration: _inputDecoration(isDark),
                      child: Text(dateFormat.format(_expiryDate), style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Limits (Max Books Allowed + Max Days)
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'Max Books Allowed (Limit) *',
                  child: TextField(
                    controller: _borrowingLimitCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration(isDark),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFormField(
                  label: 'Issue Duration (Days) *',
                  child: TextField(
                    controller: _maxDaysCtrl,
                    keyboardType: TextInputType.number,
                    decoration: _inputDecoration(isDark),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Status Dropdown
          _buildFormField(
            label: 'Initial Membership Status',
            child: DropdownButtonFormField<String>(
              value: _status,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              decoration: _inputDecoration(isDark),
              items: const [
                DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                DropdownMenuItem(value: 'SUSPENDED', child: Text('Suspended')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _status = val);
              },
            ),
          ),
          const SizedBox(height: 14),

          // Notes
          _buildFormField(
            label: 'Notes / Remarks (Optional)',
            child: TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: _inputDecoration(isDark, hint: 'Special borrowing provisions or remarks...'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  InputDecoration _inputDecoration(bool isDark, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12.5),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
    );
  }

  Future<void> _submitCreateMember() async {
    if (_selectedProfile == null) return;

    final limit = int.tryParse(_borrowingLimitCtrl.text.trim()) ?? 3;
    final maxDays = int.tryParse(_maxDaysCtrl.text.trim()) ?? 14;

    final payload = {
      'profile_id': _selectedProfile!.id,
      if (_memberCodeCtrl.text.trim().isNotEmpty) 'member_code': _memberCodeCtrl.text.trim(),
      'membership_type': _membershipType,
      'membership_start_date': _startDate.toIso8601String().split('T').first,
      'membership_expiry_date': _expiryDate.toIso8601String().split('T').first,
      'borrowing_limit': limit,
      'max_issue_duration_days': maxDays,
      'renewal_allowed': _renewalAllowed,
      'max_renewals': _maxRenewals,
      'status': _status,
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };

    final success = await ref.read(memberProvider.notifier).createMember(payload);
    if (success && mounted) {
      Navigator.pop(context);
    }
  }
}
