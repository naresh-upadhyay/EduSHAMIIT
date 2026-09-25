import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/services/hr_lookup_helper.dart';

class ScheduleInterviewDialog extends StatefulWidget {
  final String applicationId;
  final String candidateName;
  final String jobTitle;
  final VoidCallback onScheduled;

  const ScheduleInterviewDialog({
    super.key,
    required this.applicationId,
    required this.candidateName,
    required this.jobTitle,
    required this.onScheduled,
  });

  @override
  State<ScheduleInterviewDialog> createState() => _ScheduleInterviewDialogState();
}

class _ScheduleInterviewDialogState extends State<ScheduleInterviewDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  String _round = 'Round 1 - Screening';
  String _mode = 'In Person';
  DateTime _scheduledDate = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 45);

  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  final List<Map<String, dynamic>> _selectedInterviewers = [];
  List<Map<String, dynamic>> _interviewerSuggestions = [];
  bool _isSearchingInterviewers = false;
  bool _showSuggestions = false;
  bool _isHoveringSuggestions = false;
  Timer? _debounceTimer;
  bool _isSubmitting = false;

  List<String> _rounds = HRLookupHelper.instance.getCachedLabels('INTERVIEW_ROUND');
  List<String> _modes = HRLookupHelper.instance.getCachedLabels('INTERVIEW_MODE');

  @override
  void initState() {
    super.initState();
    HRLookupHelper.instance.addListener(_onLookupsChanged);
    _loadLookups(true);
    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus) {
        if (_interviewerSuggestions.isEmpty) {
          _fetchInterviewers(_searchController.text);
        }
        setState(() {
          _showSuggestions = true;
        });
      } else {
        // Delayed check so clicks on suggestion items are processed before the popup is hidden
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted && !_searchFocusNode.hasFocus && !_isHoveringSuggestions) {
            setState(() {
              _showSuggestions = false;
            });
          }
        });
      }
    });
  }

  void _onLookupsChanged() {
    if (mounted) {
      _loadLookups(true);
    }
  }

  Future<void> _loadLookups([bool forceRefresh = true]) async {
    final rounds = await HRLookupHelper.instance.getLookupLabels('INTERVIEW_ROUND', forceRefresh: forceRefresh);
    final modes = await HRLookupHelper.instance.getLookupLabels('INTERVIEW_MODE', forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _rounds = rounds;
        if (!_rounds.contains(_round) && _rounds.isNotEmpty) {
          _round = _rounds.first;
        }
        _modes = modes;
        if (!_modes.contains(_mode) && _modes.isNotEmpty) {
          _mode = _modes.first;
        }
      });
    }
  }

  @override
  void dispose() {
    HRLookupHelper.instance.removeListener(_onLookupsChanged);
    _debounceTimer?.cancel();
    _locationController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _fetchInterviewers(query);
    });
  }

  Future<void> _fetchInterviewers([String query = '']) async {
    if (!mounted) return;
    setState(() => _isSearchingInterviewers = true);
    try {
      final endpoint = query.trim().isEmpty
          ? '/recruitment/interviewers'
          : '/recruitment/interviewers?q=${Uri.encodeComponent(query.trim())}';
      final res = await _apiService.get(endpoint);
      if (res['success'] == true && res['data'] is List) {
        if (mounted) {
          setState(() {
            _interviewerSuggestions = List<Map<String, dynamic>>.from(res['data']);
          });
        }
      }
    } catch (_) {
      // Handled gracefully
    } finally {
      if (mounted) {
        setState(() => _isSearchingInterviewers = false);
      }
    }
  }

  void _toggleInterviewer(Map<String, dynamic> user) {
    final userId = user['id']?.toString();
    if (userId == null) return;
    setState(() {
      final exists = _selectedInterviewers.any((i) => i['id']?.toString() == userId);
      if (exists) {
        _selectedInterviewers.removeWhere((i) => i['id']?.toString() == userId);
      } else {
        _selectedInterviewers.add(user);
      }
    });
  }

  void _removeInterviewer(String userId) {
    setState(() {
      _selectedInterviewers.removeWhere((i) => i['id']?.toString() == userId);
    });
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _scheduledDate = picked);
    }
  }

  Future<void> _selectStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _startTime,
    );
    if (picked != null) {
      setState(() {
        _startTime = picked;
        // Auto bump end time by 45 mins
        final totalMinutes = picked.hour * 60 + picked.minute + 45;
        _endTime = TimeOfDay(hour: (totalMinutes ~/ 60) % 24, minute: totalMinutes % 60);
      });
    }
  }

  Future<void> _selectEndTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _endTime,
    );
    if (picked != null) {
      setState(() => _endTime = picked);
    }
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  Color _getRoleColor(String? role) {
    switch (role?.toLowerCase()) {
      case 'teacher':
        return const Color(0xFF0284C7); // Sky
      case 'admin':
      case 'super_admin':
        return const Color(0xFF7C3AED); // Purple
      case 'hr':
        return const Color(0xFF059669); // Emerald
      case 'principal':
      case 'director':
        return const Color(0xFFD97706); // Amber
      default:
        return const Color(0xFF64748B); // Slate
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedInterviewers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Please assign at least one interviewer or panel member before scheduling.',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_scheduledDate);
      final startTimeStr = _formatTimeOfDay(_startTime);
      final endTimeStr = _formatTimeOfDay(_endTime);

      final panelIds = _selectedInterviewers.map((i) => i['id'].toString()).toList();

      final payload = {
        'application_id': widget.applicationId,
        'interview_round': _round,
        'scheduled_date': dateStr,
        'scheduled_time_start': startTimeStr,
        'scheduled_time_end': endTimeStr,
        'mode': _mode,
        'meeting_link_or_location': _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
        'interviewer_id': panelIds.isNotEmpty ? panelIds.first : null,
        'panel_member_ids': panelIds,
        'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      };

      await _apiService.post('/recruitment/interviews', payload);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Interview scheduled! Email invitation sent to ${widget.candidateName} & added to interviewer calendar.',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        widget.onScheduled();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error scheduling interview: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.of(context).size.height * 0.90,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF4F46E5), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Schedule Interview',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          Text(
                            '${widget.candidateName} • ${widget.jobTitle}',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 28),

                // Round & Mode
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _rounds.contains(_round) ? _round : (_rounds.isNotEmpty ? _rounds.first : null),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Interview Round',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: _rounds.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _round = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _modes.contains(_mode) ? _mode : (_modes.isNotEmpty ? _modes.first : null),
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Interview Mode',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: _modes.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _mode = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Date Picker
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.event_outlined),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    child: Text(
                      DateFormat('EEEE, MMM d, yyyy').format(_scheduledDate),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Time Pickers
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _selectStartTime,
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Start Time',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.access_time_outlined),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          child: Text(_startTime.format(context), style: const TextStyle(fontSize: 14)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: InkWell(
                        onTap: _selectEndTime,
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'End Time',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.access_time_outlined),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          child: Text(_endTime.format(context), style: const TextStyle(fontSize: 14)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // -------------------------------------------------------------
                // ADVANCED INTERVIEWER SELECTION WITH SEARCH & CALENDAR SYNC
                // -------------------------------------------------------------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.people_alt_outlined, size: 18, color: Color(0xFF4F46E5)),
                        SizedBox(width: 6),
                        Text(
                          'Assign Interviewer(s) / Panel',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                    if (_selectedInterviewers.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC7D2FE)),
                        ),
                        child: Text(
                          '${_selectedInterviewers.length} selected',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Search school staff or teachers to assign as interviewers. An event will be automatically booked in their calendar.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 10),

                // Search Input Field
                TextFormField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (val) {
                    _onSearchChanged(val);
                    if (!_showSuggestions) setState(() => _showSuggestions = true);
                  },
                  decoration: InputDecoration(
                    hintText: 'Type to search staff by name, email, department...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isSearchingInterviewers)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: Padding(
                              padding: EdgeInsets.all(12),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        if (_searchController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 18, color: Color(0xFF64748B)),
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchController.clear();
                              _fetchInterviewers('');
                            },
                          ),
                        IconButton(
                          icon: Icon(
                            _showSuggestions ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            size: 22,
                            color: const Color(0xFF64748B),
                          ),
                          tooltip: _showSuggestions ? 'Hide staff list' : 'View staff list',
                          onPressed: () {
                            if (_showSuggestions) {
                              setState(() => _showSuggestions = false);
                            } else {
                              if (_interviewerSuggestions.isEmpty) {
                                _fetchInterviewers(_searchController.text);
                              }
                              setState(() => _showSuggestions = true);
                              _searchFocusNode.requestFocus();
                            }
                          },
                        ),
                      ],
                    ),
                    border: const OutlineInputBorder(),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),

                // Suggestions Dropdown List
                if (_showSuggestions && _interviewerSuggestions.isNotEmpty)
                  MouseRegion(
                    onEnter: (_) => _isHoveringSuggestions = true,
                    onExit: (_) => _isHoveringSuggestions = false,
                    child: Container(
                      margin: const EdgeInsets.only(top: 4),
                      constraints: const BoxConstraints(maxHeight: 220),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFCBD5E1)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: _interviewerSuggestions.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, idx) {
                          final item = _interviewerSuggestions[idx];
                          final itemId = item['id']?.toString() ?? '';
                          final isAlreadySelected = _selectedInterviewers.any((i) => i['id']?.toString() == itemId);
                          final name = item['full_name'] ?? 'Staff Member';
                          final role = item['role'] ?? 'Staff';
                          final dept = item['department'] ?? item['designation'] ?? '';
                          final email = item['email'] ?? '';

                          return Material(
                            color: isAlreadySelected ? const Color(0xFFEEF2FF) : Colors.transparent,
                            child: InkWell(
                              onTap: () => _toggleInterviewer(item),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: _getRoleColor(role).withValues(alpha: 0.15),
                                      child: Text(
                                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _getRoleColor(role),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  name,
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: isAlreadySelected ? FontWeight.bold : FontWeight.w600,
                                                    color: isAlreadySelected ? const Color(0xFF4338CA) : const Color(0xFF1E293B),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: _getRoleColor(role).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  role.toUpperCase(),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: _getRoleColor(role),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          if (dept.isNotEmpty || email.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(
                                              [dept, email].where((s) => s.isNotEmpty).join(' • '),
                                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    isAlreadySelected
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.check_circle, color: Color(0xFF10B981), size: 14),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Added',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF047857),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : IconButton(
                                            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF4F46E5), size: 20),
                                            tooltip: 'Add to panel',
                                            onPressed: () => _toggleInterviewer(item),
                                          ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // Selected Interviewer Badges
                const SizedBox(height: 8),
                if (_selectedInterviewers.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedInterviewers.map((interviewer) {
                      final name = interviewer['full_name'] ?? 'Staff Member';
                      final role = interviewer['role'] ?? 'Staff';
                      final id = interviewer['id']?.toString() ?? '';

                      return Chip(
                        avatar: CircleAvatar(
                          radius: 12,
                          backgroundColor: _getRoleColor(role).withValues(alpha: 0.2),
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _getRoleColor(role),
                            ),
                          ),
                        ),
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 4),
                            Text(
                              '($role)',
                              style: TextStyle(fontSize: 11, color: _getRoleColor(role), fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        deleteIcon: const Icon(Icons.close, size: 14),
                        onDeleted: () => _removeInterviewer(id),
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      );
                    }).toList(),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Color(0xFF94A3B8)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No interviewers assigned yet. Click the search box above to select panel members.',
                            style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                // Location / Meeting Link
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    labelText: _mode == 'Online' ? 'Meeting Link (Google Meet / Zoom)' : 'Location / Room No.',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(_mode == 'Online' ? Icons.link_rounded : Icons.location_on_outlined, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                const SizedBox(height: 16),

                // Notes
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Instructions for Candidate & Panel (Optional)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),

                // Automated Action Notification Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.verified_outlined, size: 18, color: Color(0xFF16A34A)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Candidate will automatically receive a professional email with all interview details. An event will also be instantly created in the assigned interviewer\'s calendar schedule.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF15803D), height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: _isSubmitting
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.calendar_month_rounded, size: 18, color: Colors.white),
                      label: Text(
                        _isSubmitting ? 'Scheduling...' : 'Schedule Interview',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
