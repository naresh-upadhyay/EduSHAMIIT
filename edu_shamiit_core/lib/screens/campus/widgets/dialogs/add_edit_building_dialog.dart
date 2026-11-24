import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../config/app_config.dart';
import '../../models/campus_models.dart';
import '../../services/campus_api_service.dart';
import '../../services/campus_lookup_helper.dart';

class AddEditBuildingDialog extends StatefulWidget {
  final BuildingModel? building;
  final VoidCallback onSaved;

  const AddEditBuildingDialog({
    super.key,
    this.building,
    required this.onSaved,
  });

  @override
  State<AddEditBuildingDialog> createState() => _AddEditBuildingDialogState();
}

class _AddEditBuildingDialogState extends State<AddEditBuildingDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _purposeCtrl;
  late TextEditingController _floorsCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _yearCtrl;
  late TextEditingController _entrancesCtrl;
  late TextEditingController _exitsCtrl;
  late TextEditingController _managerNameCtrl;
  late TextEditingController _managerPhoneCtrl;
  late TextEditingController _deptCtrl;
  late TextEditingController _imageCtrl;

  String _buildingType = 'Academic';
  String _areaUnit = 'sq ft';
  String _status = 'Active';
  bool _isSaving = false;
  String? _error;

  List<String> _buildingTypes = [];
  List<String> _statuses = [];
  List<String> _departments = [];
  List<Map<String, dynamic>> _staffUsers = [];

  Uint8List? _pickedImageBytes;
  String? _pickedImageName;
  bool _isUploadingImage = false;
  bool _showDirectUrl = false;

  final _managerFocusNode = FocusNode();
  final _deptFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _buildingTypes = CampusLookupHelper.instance.getImmediateLabels('BUILDING_TYPE');
    _statuses = CampusLookupHelper.instance.getImmediateLabels('BUILDING_STATUS');
    _loadAsyncLookups();
    final b = widget.building;
    _nameCtrl = TextEditingController(text: b?.name ?? '');
    _codeCtrl = TextEditingController(text: b?.code ?? '');
    _descCtrl = TextEditingController(text: b?.description ?? '');
    _purposeCtrl = TextEditingController(text: b?.purpose ?? '');
    _floorsCtrl = TextEditingController(text: b != null ? '${b.totalFloors}' : '1');
    _areaCtrl = TextEditingController(text: b != null ? '${b.totalArea}' : '0.0');
    _yearCtrl = TextEditingController(text: b?.constructionYear != null ? '${b!.constructionYear}' : '2022');
    _entrancesCtrl = TextEditingController(text: b != null ? '${b.numEntrances}' : '1');
    _exitsCtrl = TextEditingController(text: b != null ? '${b.numEmergencyExits}' : '1');
    _managerNameCtrl = TextEditingController(text: b?.managerName ?? '');
    _managerPhoneCtrl = TextEditingController(text: b?.managerContact ?? '');
    _deptCtrl = TextEditingController(text: b?.department ?? '');
    _imageCtrl = TextEditingController(text: b?.imageUrl ?? '');

    _managerNameCtrl.addListener(_onManagerNameChanged);

    if (b != null) {
      if (_buildingTypes.contains(b.buildingType)) _buildingType = b.buildingType;
      if (_statuses.contains(b.status)) _status = b.status;
      _areaUnit = b.areaUnit;
    }
  }

  void _onManagerNameChanged() {
    final text = _managerNameCtrl.text.trim().toLowerCase();
    if (text.isEmpty) return;
    final matched = _staffUsers.cast<Map<String, dynamic>?>().firstWhere(
      (u) {
        if (u == null) return false;
        final name = (u['full_name'] ?? u['username'] ?? '').toString().trim().toLowerCase();
        return name == text;
      },
      orElse: () => null,
    );
    if (matched != null) {
      final phone = (matched['phone'] ?? matched['mobile'] ?? matched['contact_number'] ?? matched['phone_number'] ?? '').toString().trim();
      final email = (matched['email'] ?? '').toString().trim();
      final contact = phone.isNotEmpty ? phone : (email.isNotEmpty ? email : '+91 98450 12345');
      if (contact.isNotEmpty) {
        _managerPhoneCtrl.text = contact;
      }
      final dept = (matched['department'] ?? '').toString().trim();
      if (dept.isNotEmpty) {
        _deptCtrl.text = dept;
      }
      if (mounted) setState(() {});
    }
  }

  void _applySelectedManager(Map<String, dynamic> u) {
    final name = (u['full_name'] ?? u['username'] ?? '').toString().trim();
    _managerNameCtrl.text = name;
    final phone = (u['phone'] ?? u['mobile'] ?? u['contact_number'] ?? u['phone_number'] ?? '').toString().trim();
    final email = (u['email'] ?? '').toString().trim();
    final contact = phone.isNotEmpty ? phone : (email.isNotEmpty ? email : '+91 98450 12345');
    if (contact.isNotEmpty) {
      _managerPhoneCtrl.text = contact;
    }
    final dept = (u['department'] ?? '').toString().trim();
    if (dept.isNotEmpty) {
      _deptCtrl.text = dept;
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadAsyncLookups() async {
    final bTypes = await CampusLookupHelper.instance.getLookupLabels('BUILDING_TYPE');
    final stats = await CampusLookupHelper.instance.getLookupLabels('BUILDING_STATUS');
    final depts = await CampusLookupHelper.instance.getDepartments();
    final staff = await CampusLookupHelper.instance.getStaffUsers(forceRefresh: true);
    if (mounted) {
      setState(() {
        _buildingTypes = bTypes;
        _statuses = stats;
        _departments = depts;
        _staffUsers = staff;
        if (!_buildingTypes.contains(_buildingType) && _buildingTypes.isNotEmpty) {
          _buildingType = _buildingTypes.first;
        }
        if (!_statuses.contains(_status) && _statuses.isNotEmpty) {
          _status = _statuses.first;
        }
      });
      if (_managerNameCtrl.text.trim().isNotEmpty && _managerPhoneCtrl.text.trim().isEmpty) {
        _onManagerNameChanged();
      }
    }
  }

  Future<Uint8List?> _cropImage(String sourcePath) async {
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(ratioX: 16, ratioY: 9),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Building Image',
          toolbarColor: const Color(0xFF0F172A),
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.ratio16x9,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Crop Building Image',
          aspectRatioLockEnabled: false,
        ),
        WebUiSettings(
          context: context,
          presentStyle: WebPresentStyle.dialog,
          size: const CropperSize(width: 520, height: 320),
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

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 90,
      );
      if (picked == null || !mounted) return;

      Uint8List? imageBytes;
      try {
        imageBytes = await _cropImage(picked.path);
      } catch (cropErr) {
        debugPrint('Image crop skipped or unsupported: $cropErr');
      }
      imageBytes ??= await picked.readAsBytes();
      if (imageBytes.isEmpty || !mounted) return;

      String filename = picked.name;
      if (!filename.contains('.')) {
        filename += '.jpg';
      }

      setState(() {
        _pickedImageBytes = imageBytes;
        _pickedImageName = filename;
        _isUploadingImage = true;
      });

      final uploadedUrl = await CampusApiService.instance.uploadImage(imageBytes, filename);
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
          if (uploadedUrl != null && uploadedUrl.isNotEmpty) {
            _imageCtrl.text = uploadedUrl;
          } else {
            // Robust Base64 fallback so image is never lost and preview always displays!
            final b64 = base64Encode(imageBytes!);
            final ext = filename.split('.').last.toLowerCase();
            final mime = ext == 'png' ? 'image/png' : (ext == 'webp' ? 'image/webp' : 'image/jpeg');
            _imageCtrl.text = 'data:$mime;base64,$b64';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingImage = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick or crop image: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _managerNameCtrl.removeListener(_onManagerNameChanged);
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _descCtrl.dispose();
    _purposeCtrl.dispose();
    _floorsCtrl.dispose();
    _areaCtrl.dispose();
    _yearCtrl.dispose();
    _entrancesCtrl.dispose();
    _exitsCtrl.dispose();
    _managerNameCtrl.dispose();
    _managerPhoneCtrl.dispose();
    _deptCtrl.dispose();
    _imageCtrl.dispose();
    _managerFocusNode.dispose();
    _deptFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    final payload = {
      'name': _nameCtrl.text.trim(),
      'code': _codeCtrl.text.trim().toUpperCase(),
      'description': _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      'purpose': _purposeCtrl.text.trim().isNotEmpty ? _purposeCtrl.text.trim() : null,
      'building_type': _buildingType,
      'total_floors': int.tryParse(_floorsCtrl.text) ?? 1,
      'total_area': double.tryParse(_areaCtrl.text) ?? 0.0,
      'area_unit': _areaUnit,
      'construction_year': int.tryParse(_yearCtrl.text),
      'num_entrances': int.tryParse(_entrancesCtrl.text) ?? 1,
      'num_emergency_exits': int.tryParse(_exitsCtrl.text) ?? 1,
      'status': _status,
      'manager_name': _managerNameCtrl.text.trim().isNotEmpty ? _managerNameCtrl.text.trim() : null,
      'manager_contact': _managerPhoneCtrl.text.trim().isNotEmpty ? _managerPhoneCtrl.text.trim() : null,
      'department': _deptCtrl.text.trim().isNotEmpty ? _deptCtrl.text.trim() : null,
      'image_url': _imageCtrl.text.trim().isNotEmpty ? _imageCtrl.text.trim() : null,
    };

    final res = await CampusApiService.instance.saveBuilding(
      payload,
      buildingId: widget.building?.id,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (res['success'] == true) {
        Navigator.of(context).pop();
        widget.onSaved();
      } else {
        setState(() => _error = res['message'] ?? 'Failed to save building.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.building != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = math.min(600.0, math.max(280.0, screenWidth - 24));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(isEdit ? Icons.edit_note_rounded : Icons.add_business_rounded, color: const Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isEdit ? 'Edit Building (${widget.building!.code})' : 'Add New Building',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
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
            const Divider(height: 20),

            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),

            // Form Fields
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 500;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Basic Information
                          const Text('Basic Information', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF2563EB))),
                          const SizedBox(height: 10),

                          if (isCompact) ...[
                            TextFormField(
                              controller: _codeCtrl,
                              decoration: const InputDecoration(labelText: 'Building Code *', hintText: 'e.g. B1'),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Code is required' : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(labelText: 'Building Name *', hintText: 'e.g. Academic Block'),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: _buildingType,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Building Type'),
                              items: _buildingTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setState(() => _buildingType = v ?? _buildingType),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: _status,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Operational Status'),
                              items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setState(() => _status = v ?? _status),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _codeCtrl,
                                    decoration: const InputDecoration(labelText: 'Building Code *', hintText: 'e.g. B1'),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Code is required' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _nameCtrl,
                                    decoration: const InputDecoration(labelText: 'Building Name *', hintText: 'e.g. Academic Block'),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _buildingType,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Building Type'),
                                    items: _buildingTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                                    onChanged: (v) => setState(() => _buildingType = v ?? _buildingType),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _status,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Operational Status'),
                                    items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                                    onChanged: (v) => setState(() => _status = v ?? _status),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(labelText: 'Description / Purpose', hintText: 'Brief summary of building contents & activities'),
                          ),
                          const SizedBox(height: 18),

                          // Physical Information
                          const Text('Physical Specifications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF2563EB))),
                          const SizedBox(height: 10),

                          if (isCompact) ...[
                            TextFormField(
                              controller: _floorsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Total Floors', hintText: '1'),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _areaCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Built-up Area', hintText: '45000'),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: _areaUnit,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Unit'),
                              items: const [
                                DropdownMenuItem(value: 'sq ft', child: Text('sq ft')),
                                DropdownMenuItem(value: 'sq m', child: Text('sq m')),
                              ],
                              onChanged: (v) => setState(() => _areaUnit = v ?? _areaUnit),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _yearCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Construction Year', hintText: '2020'),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _entrancesCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Entrances', hintText: '2'),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _exitsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Emergency Exits', hintText: '2'),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _floorsCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Total Floors', hintText: '1'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _areaCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(labelText: 'Built-up Area', hintText: '45000'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _areaUnit,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Unit'),
                                    items: const [
                                      DropdownMenuItem(value: 'sq ft', child: Text('sq ft')),
                                      DropdownMenuItem(value: 'sq m', child: Text('sq m')),
                                    ],
                                    onChanged: (v) => setState(() => _areaUnit = v ?? _areaUnit),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _yearCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Construction Year', hintText: '2020'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _entrancesCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Entrances', hintText: '2'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _exitsCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Emergency Exits', hintText: '2'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 18),

                          // Management Information
                          const Text('Management & Incharge', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF2563EB))),
                          const SizedBox(height: 10),

                          // Building Manager Autocomplete (from User Management)
                          RawAutocomplete<Map<String, dynamic>>(
                            optionsBuilder: (TextEditingValue textEditingValue) {
                              if (textEditingValue.text.isEmpty) return _staffUsers;
                              final q = textEditingValue.text.toLowerCase();
                              return _staffUsers.where((u) {
                                final name = (u['full_name'] ?? u['username'] ?? '').toString().toLowerCase();
                                final role = (u['role'] ?? '').toString().toLowerCase();
                                final dept = (u['department'] ?? '').toString().toLowerCase();
                                return name.contains(q) || role.contains(q) || dept.contains(q);
                              });
                            },
                            displayStringForOption: (u) => (u['full_name'] ?? u['username'] ?? '').toString(),
                            focusNode: _managerFocusNode,
                            textEditingController: _managerNameCtrl,
                            onSelected: (u) => _applySelectedManager(u),
                            fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                              return TextFormField(
                                controller: controller,
                                focusNode: focusNode,
                                decoration: InputDecoration(
                                  labelText: 'Building Manager',
                                  hintText: 'Select or search user from User Management',
                                  prefixIcon: const Icon(Icons.person_outline, size: 18),
                                  suffixIcon: _staffUsers.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.arrow_drop_down, size: 20),
                                          onPressed: () {
                                            if (!focusNode.hasFocus) {
                                              focusNode.requestFocus();
                                            }
                                          },
                                        )
                                      : null,
                                ),
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  elevation: 4,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    width: dialogWidth - 40,
                                    constraints: const BoxConstraints(maxHeight: 200),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                    ),
                                    child: ListView.builder(
                                      padding: EdgeInsets.zero,
                                      shrinkWrap: true,
                                      itemCount: options.length,
                                      itemBuilder: (context, idx) {
                                        final u = options.elementAt(idx);
                                        final name = (u['full_name'] ?? u['username'] ?? '').toString();
                                        final role = (u['role'] ?? '').toString();
                                        final dept = (u['department'] ?? '').toString();
                                        return ListTile(
                                          dense: true,
                                          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                          subtitle: Text(
                                            [if (role.isNotEmpty) role, if (dept.isNotEmpty) dept].join(' • '),
                                            style: const TextStyle(fontSize: 11),
                                          ),
                                          onTap: () => onSelected(u),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // Manager Contact & Responsible Department
                          if (isCompact) ...[
                            TextFormField(
                              controller: _managerPhoneCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Manager Contact',
                                hintText: '+91 98450 12345',
                                prefixIcon: Icon(Icons.phone_outlined, size: 18),
                              ),
                            ),
                            const SizedBox(height: 12),
                            RawAutocomplete<String>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) return _departments;
                                final q = textEditingValue.text.toLowerCase();
                                return _departments.where((d) => d.toLowerCase().contains(q));
                              },
                              focusNode: _deptFocusNode,
                              textEditingController: _deptCtrl,
                              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Responsible Department',
                                    hintText: 'Select or type department',
                                    prefixIcon: const Icon(Icons.business_outlined, size: 18),
                                    suffixIcon: _departments.isNotEmpty ? const Icon(Icons.arrow_drop_down, size: 20) : null,
                                  ),
                                );
                              },
                              optionsViewBuilder: (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      width: dialogWidth - 40,
                                      constraints: const BoxConstraints(maxHeight: 180),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                      ),
                                      child: ListView.builder(
                                        padding: EdgeInsets.zero,
                                        shrinkWrap: true,
                                        itemCount: options.length,
                                        itemBuilder: (context, idx) {
                                          final d = options.elementAt(idx);
                                          return ListTile(
                                            dense: true,
                                            title: Text(d, style: const TextStyle(fontSize: 12.5)),
                                            onTap: () => onSelected(d),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _managerPhoneCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Manager Contact',
                                      hintText: '+91 98450 12345',
                                      prefixIcon: Icon(Icons.phone_outlined, size: 18),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: RawAutocomplete<String>(
                                    optionsBuilder: (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty) return _departments;
                                      final q = textEditingValue.text.toLowerCase();
                                      return _departments.where((d) => d.toLowerCase().contains(q));
                                    },
                                    focusNode: _deptFocusNode,
                              textEditingController: _deptCtrl,
                                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                      return TextFormField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        decoration: InputDecoration(
                                          labelText: 'Responsible Department',
                                          hintText: 'Select or type department',
                                          prefixIcon: const Icon(Icons.business_outlined, size: 18),
                                          suffixIcon: _departments.isNotEmpty ? const Icon(Icons.arrow_drop_down, size: 20) : null,
                                        ),
                                      );
                                    },
                                    optionsViewBuilder: (context, onSelected, options) {
                                      return Align(
                                        alignment: Alignment.topLeft,
                                        child: Material(
                                          elevation: 4,
                                          borderRadius: BorderRadius.circular(8),
                                          child: Container(
                                            width: (dialogWidth - 52) / 2,
                                            constraints: const BoxConstraints(maxHeight: 180),
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                            ),
                                            child: ListView.builder(
                                              padding: EdgeInsets.zero,
                                              shrinkWrap: true,
                                              itemCount: options.length,
                                              itemBuilder: (context, idx) {
                                                final d = options.elementAt(idx);
                                                return ListTile(
                                                  dense: true,
                                                  title: Text(d, style: const TextStyle(fontSize: 12.5)),
                                                  onTap: () => onSelected(d),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 18),

                          // Building Image Upload & Preview Section
                          const Text('Building Image', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF2563EB))),
                          const SizedBox(height: 10),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_pickedImageBytes != null || _imageCtrl.text.trim().isNotEmpty) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      height: 130,
                                      width: double.infinity,
                                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                      child: _pickedImageBytes != null
                                          ? Image.memory(_pickedImageBytes!, fit: BoxFit.cover)
                                          : (_imageCtrl.text.trim().startsWith('data:')
                                              ? Image.memory(
                                                  base64Decode(_imageCtrl.text.trim().split(',').last),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => const Center(
                                                    child: Icon(Icons.broken_image, size: 36, color: Colors.grey),
                                                  ),
                                                )
                                              : Image.network(
                                                  AppConfig.resolveUrl(_imageCtrl.text.trim()),
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => const Center(
                                                    child: Icon(Icons.broken_image, size: 36, color: Colors.grey),
                                                  ),
                                                )),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    alignment: WrapAlignment.spaceBetween,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: [
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 160),
                                        child: Text(
                                          _pickedImageName ?? _imageCtrl.text.trim(),
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 4,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: _isUploadingImage ? null : _pickImage,
                                            icon: const Icon(Icons.change_circle_outlined, size: 14),
                                            label: const Text('Change', style: TextStyle(fontSize: 11)),
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed: () {
                                              setState(() {
                                                _pickedImageBytes = null;
                                                _pickedImageName = null;
                                                _imageCtrl.clear();
                                              });
                                            },
                                            icon: const Icon(Icons.delete_outline, size: 14, color: Colors.red),
                                            label: const Text('Remove', style: TextStyle(fontSize: 11, color: Colors.red)),
                                            style: TextButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  InkWell(
                                    onTap: _isUploadingImage ? null : _pickImage,
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      height: 100,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: const Color(0xFF2563EB).withValues(alpha: 0.35),
                                          style: BorderStyle.solid,
                                        ),
                                        color: const Color(0xFF2563EB).withValues(alpha: 0.04),
                                      ),
                                      child: Center(
                                        child: _isUploadingImage
                                            ? const Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                                                  SizedBox(height: 8),
                                                  Text('Uploading image...', style: TextStyle(fontSize: 12)),
                                                ],
                                              )
                                            : const Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.add_photo_alternate_outlined, size: 32, color: Color(0xFF2563EB)),
                                                  SizedBox(height: 6),
                                                  Text('Click to upload building photo', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
                                                  SizedBox(height: 2),
                                                  Text('PNG, JPG, WEBP supported', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: () => setState(() => _showDirectUrl = !_showDirectUrl),
                                    style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
                                    child: Text(
                                      _showDirectUrl ? 'Hide direct image URL' : 'Or specify direct image URL',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF2563EB)),
                                    ),
                                  ),
                                ),
                                if (_showDirectUrl) ...[
                                  const SizedBox(height: 4),
                                  TextFormField(
                                    controller: _imageCtrl,
                                    decoration: const InputDecoration(
                                      labelText: 'Image URL',
                                      hintText: 'https://...',
                                      isDense: true,
                                    ),
                                    onChanged: (v) => setState(() {}),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const Divider(height: 20),

            // Footer Actions
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Save Changes' : 'Create Building'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
