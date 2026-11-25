import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/maintenance_models.dart';
import '../../../providers/maintenance_provider.dart';
import '../../../services/campus_lookup_helper.dart';
import '../widgets/location_multi_selector.dart';

class CreateEditMaintenanceDialog extends ConsumerStatefulWidget {
  final String? initialLocation;
  final String? initialBuildingId;
  final String? initialFloorId;
  final String? initialRoomId;
  final String? initialFacilityId;
  final String? initialFacilityName;
  final String? initialTitle;
  final VoidCallback? onSaved;

  const CreateEditMaintenanceDialog({
    super.key,
    this.initialLocation,
    this.initialBuildingId,
    this.initialFloorId,
    this.initialRoomId,
    this.initialFacilityId,
    this.initialFacilityName,
    this.initialTitle,
    this.onSaved,
  });

  @override
  ConsumerState<CreateEditMaintenanceDialog> createState() => _CreateEditMaintenanceDialogState();
}

class _CreateEditMaintenanceDialogState extends ConsumerState<CreateEditMaintenanceDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  final _descController = TextEditingController();
  late final TextEditingController _locationController;
  final _reporterController = TextEditingController(text: 'Campus Facility Desk');
  final _vendorNameController = TextEditingController();
  final _vendorPhoneController = TextEditingController();
  final _vendorEmailController = TextEditingController();

  String _requestType = 'Electrical & Power';
  String _priority = 'High';
  String _role = 'Faculty';
  final DateTime _preferredDate = DateTime.now().add(const Duration(days: 1));
  final String _preferredTime = '02:00 PM';
  bool _isSubmitting = false;
  bool _allowMultiLocation = false;
  bool _sendVendorEmail = false;
  String? _selectedVendorId;

  List<String> _requestTypes = [];
  List<String> _priorities = [];
  List<String> _roles = [];
  List<SelectedLocationItem> _selectedLocations = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _locationController = TextEditingController(
      text: widget.initialFacilityName?.isNotEmpty == true
          ? widget.initialFacilityName!
          : (widget.initialLocation?.isNotEmpty == true
              ? widget.initialLocation!
              : 'B1 / G-101'),
    );

    if (widget.initialFacilityId != null && widget.initialFacilityId!.isNotEmpty) {
      final facName = widget.initialFacilityName ?? widget.initialLocation ?? 'Facility';
      _selectedLocations = [
        SelectedLocationItem(
          facilityId: widget.initialFacilityId,
          facilityName: facName,
          displayName: facName,
          locationType: 'facility',
        )
      ];
    } else if (widget.initialLocation != null && widget.initialLocation!.isNotEmpty) {
      _selectedLocations = [
        SelectedLocationItem(
          buildingId: widget.initialBuildingId,
          floorId: widget.initialFloorId,
          roomId: widget.initialRoomId,
          displayName: widget.initialLocation!,
          locationType: 'room',
        )
      ];
    }

    _requestTypes = CampusLookupHelper.instance.getImmediateLabels('MAINTENANCE_CATEGORY');
    if (_requestTypes.isNotEmpty) _requestType = _requestTypes.first;
    _priorities = CampusLookupHelper.instance.getImmediateLabels('MAINTENANCE_PRIORITY');
    if (_priorities.isNotEmpty) _priority = _priorities.contains('High') ? 'High' : _priorities.first;
    _roles = CampusLookupHelper.instance.getImmediateLabels('ORGANIZER_ROLE');
    if (_roles.isNotEmpty) _role = _roles.first;

    _loadDynamicLookups();
  }

  Future<void> _loadDynamicLookups() async {
    final types = await CampusLookupHelper.instance.getLookupLabels('MAINTENANCE_CATEGORY');
    final prios = await CampusLookupHelper.instance.getLookupLabels('MAINTENANCE_PRIORITY');
    final roles = await CampusLookupHelper.instance.getLookupLabels('ORGANIZER_ROLE');
    if (mounted) {
      setState(() {
        if (types.isNotEmpty) {
          _requestTypes = types;
          if (!_requestTypes.contains(_requestType)) _requestType = _requestTypes.first;
        }
        if (prios.isNotEmpty) {
          _priorities = prios;
          if (!_priorities.contains(_priority)) _priority = _priorities.first;
        }
        if (roles.isNotEmpty) {
          _roles = roles;
          if (!_roles.contains(_role)) _role = _roles.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _locationController.dispose();
    _reporterController.dispose();
    _vendorNameController.dispose();
    _vendorPhoneController.dispose();
    _vendorEmailController.dispose();
    super.dispose();
  }

  void _onVendorChanged(String? vendorId, List<MaintenanceVendorItem> vendors) {
    setState(() {
      _selectedVendorId = vendorId;
      if (vendorId != null) {
        final v = vendors.where((x) => x.id == vendorId).firstOrNull;
        if (v != null) {
          _vendorNameController.text = v.vendorName;
          _vendorPhoneController.text = v.phone ?? '';
          _vendorEmailController.text = v.email ?? '';
        }
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    String effectiveLocationDisplay = _locationController.text.trim();
    String? bId = widget.initialBuildingId;
    String? fId = widget.initialFloorId;
    String? rId = widget.initialRoomId;
    String? facId;

    if (_selectedLocations.isNotEmpty) {
      if (_selectedLocations.length == 1) {
        final loc = _selectedLocations.first;
        effectiveLocationDisplay = loc.displayName;
        bId = loc.buildingId ?? bId;
        fId = loc.floorId ?? fId;
        rId = loc.roomId ?? rId;
        facId = loc.facilityId;
      } else {
        effectiveLocationDisplay = '${_selectedLocations.length} Selected Locations';
      }
    }

    final payload = {
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'request_type': _requestType,
      'priority': _priority,
      'location_display': effectiveLocationDisplay,
      if (bId != null) 'building_id': bId,
      if (fId != null) 'floor_id': fId,
      if (rId != null) 'room_id': rId,
      if (facId != null) 'facility_id': facId,
      'reported_by_name': _reporterController.text.trim(),
      'reported_by_role': _role,
      'preferred_date': '${_preferredDate.year}-${_preferredDate.month.toString().padLeft(2, '0')}-${_preferredDate.day.toString().padLeft(2, '0')}',
      'preferred_time': _preferredTime,
      if (_selectedLocations.length > 1)
        'target_locations': _selectedLocations.map((l) => l.toJson()).toList(),
      if (_selectedVendorId != null) 'vendor_id': _selectedVendorId,
      if (_vendorNameController.text.trim().isNotEmpty) 'vendor_name': _vendorNameController.text.trim(),
      if (_vendorPhoneController.text.trim().isNotEmpty) 'vendor_phone': _vendorPhoneController.text.trim(),
      if (_vendorEmailController.text.trim().isNotEmpty) 'vendor_email': _vendorEmailController.text.trim(),
      'send_vendor_email': _sendVendorEmail,
    };

    final success = await ref.read(maintenanceProvider.notifier).createRequest(payload);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      widget.onSaved?.call();
      Navigator.of(context).pop();
      final msg = _selectedLocations.length > 1
          ? 'Bulk maintenance work orders (${_selectedLocations.length}) generated successfully!'
          : 'Maintenance request raised successfully!';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: const Color(0xFF059669)),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to raise request. Please try again.'), backgroundColor: Color(0xFFEF4444)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(maintenanceProvider);
    final vendors = state.vendors;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogMaxWidth = math.min(640.0, screenWidth * 0.95);

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogMaxWidth, maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: Column(
          children: [
            // Dialog Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.build_circle_outlined, size: 20, color: Color(0xFF2563EB)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Raise Maintenance Work Order', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary)),
                        Text('Dispatch single or bulk multi-location work orders with vendor automation', style: TextStyle(fontSize: 11.5, color: textMuted)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // Dialog Scrollable Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section 1: Work Order Scope & Classification
                      _buildSectionHeader('1. Work Order Scope & Classification', Icons.assignment_outlined, textPrimary),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _titleController,
                        style: TextStyle(fontSize: 12.5, color: textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Title / Issue Summary *',
                          hintText: 'e.g. AC cooling low, refrigerant check and air filter cleaning',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (v) => v?.trim().isEmpty == true ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _requestTypes.contains(_requestType) ? _requestType : (_requestTypes.isNotEmpty ? _requestTypes.first : null),
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Category / Trade',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: _requestTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (v) => setState(() => _requestType = v ?? _requestType),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _priorities.contains(_priority) ? _priority : (_priorities.isNotEmpty ? _priorities.first : null),
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Priority Level',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (v) => setState(() => _priority = v ?? _priority),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Section 2: Location Selection (Single or Bulk Multi-Location)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: _buildSectionHeader('2. Location & Facility Mapping', Icons.domain_add, textPrimary),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Bulk Multi-Location', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _allowMultiLocation ? const Color(0xFF2563EB) : textMuted)),
                              const SizedBox(width: 4),
                              Switch(
                                value: _allowMultiLocation,
                                onChanged: (v) => setState(() => _allowMultiLocation = v),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LocationMultiSelector(
                        initialSelected: _selectedLocations,
                        initialSourceTab: widget.initialFacilityId != null ? 1 : 0,
                        allowMultiple: _allowMultiLocation,
                        onSelectionChanged: (locs) {
                          setState(() {
                            _selectedLocations = locs;
                            if (locs.isNotEmpty) {
                              _locationController.text = locs.length == 1
                                  ? locs.first.displayName
                                  : '${locs.length} Selected Locations';
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 18),

                      // Section 3: Vendor Routing & Contact Automation
                      _buildSectionHeader('3. Service Vendor Assignment & Mobile Contact', Icons.contact_phone_outlined, textPrimary),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _selectedVendorId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Assign Registered AMC Vendor (Optional)',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Internal Maintenance Team / No Vendor', style: TextStyle(fontSize: 12))),
                                ...vendors.map((v) => DropdownMenuItem(
                                      value: v.id,
                                      child: Text('${v.vendorName} (${v.serviceCategory} • ${v.phone ?? "No Phone"})', style: const TextStyle(fontSize: 12)),
                                    )),
                              ],
                              onChanged: (v) => _onVendorChanged(v, vendors),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: TextFormField(
                                    controller: _vendorNameController,
                                    style: TextStyle(fontSize: 12, color: textPrimary),
                                    decoration: InputDecoration(
                                      labelText: 'Vendor Name',
                                      hintText: 'e.g. CoolAir Solutions Pvt Ltd',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _vendorPhoneController,
                                    keyboardType: TextInputType.phone,
                                    style: TextStyle(fontSize: 12, color: textPrimary),
                                    decoration: InputDecoration(
                                      labelText: 'Vendor Mobile No',
                                      prefixIcon: const Icon(Icons.phone, size: 14, color: Color(0xFF10B981)),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _vendorEmailController,
                              keyboardType: TextInputType.emailAddress,
                              style: TextStyle(fontSize: 12, color: textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Vendor Dispatch Email ID',
                                prefixIcon: const Icon(Icons.email_outlined, size: 14, color: Color(0xFF2563EB)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Material(
                              color: Colors.transparent,
                              child: SwitchListTile(
                                value: _sendVendorEmail,
                                onChanged: (v) => setState(() => _sendVendorEmail = v),
                                title: Text('Send Automated Email Dispatch to Vendor', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary)),
                                subtitle: Text('Instantly dispatches work order instructions & location details to vendor email', style: TextStyle(fontSize: 10.5, color: textMuted)),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Section 4: Description & Reporter Details
                      _buildSectionHeader('4. Issue Description & Reporter Info', Icons.description_outlined, textPrimary),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _descController,
                        maxLines: 3,
                        style: TextStyle(fontSize: 12, color: textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Detailed Problem Description',
                          hintText: 'Enter specific diagnostic notes, symptoms, or instructions...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                          contentPadding: const EdgeInsets.all(10),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _reporterController,
                              style: TextStyle(fontSize: 12, color: textPrimary),
                              decoration: InputDecoration(
                                labelText: 'Reported By Name',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _roles.contains(_role) ? _role : (_roles.isNotEmpty ? _roles.first : null),
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Reporter Role',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              ),
                              items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 12)))).toList(),
                              onChanged: (v) => setState(() => _role = v ?? _role),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, thickness: 1),

            // Dialog Footer Actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check, size: 16, color: Colors.white),
                    label: Text(
                      _selectedLocations.length > 1
                          ? 'Generate ${_selectedLocations.length} Work Orders'
                          : 'Submit Work Order',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color textColor) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF2563EB)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: textColor),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
