import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/campus_models.dart';
import '../../services/campus_api_service.dart';
import '../../services/campus_lookup_helper.dart';

class RoomEquipmentDialog extends StatefulWidget {
  final RoomModel room;
  final VoidCallback onUpdated;

  const RoomEquipmentDialog({
    super.key,
    required this.room,
    required this.onUpdated,
  });

  @override
  State<RoomEquipmentDialog> createState() => _RoomEquipmentDialogState();
}

class _RoomEquipmentDialogState extends State<RoomEquipmentDialog> {
  List<RoomEquipmentModel> _equipment = [];
  bool _isLoading = true;
  String? _error;
  bool _isAdding = false;

  final _nameCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  String _category = 'General Fixture';
  String _condition = 'Good';
  String _status = 'Operational';

  List<String> _categories = [];
  List<String> _conditions = [];
  List<String> _statuses = [];

  @override
  void initState() {
    super.initState();
    _categories = CampusLookupHelper.instance.getImmediateLabels('EQUIPMENT_CATEGORY');
    _conditions = CampusLookupHelper.instance.getImmediateLabels('EQUIPMENT_CONDITION');
    _statuses = CampusLookupHelper.instance.getImmediateLabels('EQUIPMENT_STATUS');
    _loadLookups();
    _loadEquipment();
  }

  Future<void> _loadLookups() async {
    final cats = await CampusLookupHelper.instance.getLookupLabels('EQUIPMENT_CATEGORY');
    final conds = await CampusLookupHelper.instance.getLookupLabels('EQUIPMENT_CONDITION');
    final stats = await CampusLookupHelper.instance.getLookupLabels('EQUIPMENT_STATUS');
    if (mounted) {
      setState(() {
        _categories = cats;
        _conditions = conds;
        _statuses = stats;
        if (!_categories.contains(_category) && _categories.isNotEmpty) {
          _category = _categories.first;
        }
        if (!_conditions.contains(_condition) && _conditions.isNotEmpty) {
          _condition = _conditions.first;
        }
        if (!_statuses.contains(_status) && _statuses.isNotEmpty) {
          _status = _statuses.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEquipment() async {
    setState(() => _isLoading = true);
    final res = await CampusApiService.instance.getRoomDetails(widget.room.id);
    if (mounted) {
      if (res != null && res['equipment'] != null) {
        final raw = res['equipment'] as List;
        setState(() {
          _equipment = raw.map((e) => RoomEquipmentModel.fromJson(e as Map<String, dynamic>)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveNewEquipment() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Equipment name is required');
      return;
    }

    final payload = {
      'room_id': widget.room.id,
      'equipment_name': name,
      'equipment_category': _category,
      'quantity': int.tryParse(_qtyCtrl.text) ?? 1,
      'condition': _condition,
      'operational_status': _status,
      'remarks': 'Added via quick equipment panel',
    };

    final res = await CampusApiService.instance.saveEquipment(widget.room.id, payload);
    if (mounted) {
      if (res['success'] == true) {
        _nameCtrl.clear();
        _qtyCtrl.text = '1';
        setState(() {
          _isAdding = false;
          _error = null;
        });
        _loadEquipment();
        widget.onUpdated();
      } else {
        setState(() => _error = res['message'] ?? 'Failed to save equipment.');
      }
    }
  }

  Future<void> _updateStatus(RoomEquipmentModel item, String newStatus) async {
    final payload = {
      'equipment_name': item.equipmentName,
      'equipment_category': item.equipmentCategory,
      'quantity': item.quantity,
      'condition': item.condition,
      'operational_status': newStatus,
      'remarks': item.remarks,
    };
    await CampusApiService.instance.saveEquipment(widget.room.id, payload, equipmentId: item.id);
    _loadEquipment();
    widget.onUpdated();
  }

  Future<void> _deleteItem(String id) async {
    await CampusApiService.instance.deleteEquipment(widget.room.id, id);
    _loadEquipment();
    widget.onUpdated();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = math.min(650.0, screenWidth * 0.95);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.build_circle_outlined, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Facilities & Equipment: Room ${widget.room.roomNumber}',
                          style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.of(context).pop()),
              ],
            ),
            const Divider(height: 16),

            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),

            // Add button toggle
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Text(
                  '${_equipment.length} Items Configured',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                ),
                ElevatedButton.icon(
                  onPressed: () => setState(() => _isAdding = !_isAdding),
                  icon: Icon(_isAdding ? Icons.close : Icons.add, size: 15, color: Colors.white),
                  label: Text(_isAdding ? 'Cancel' : 'Add Equipment', style: const TextStyle(fontSize: 12, color: Colors.white)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), elevation: 0),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Inline Add Form
            if (_isAdding)
              Container(
                padding: const EdgeInsets.all(14),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF2563EB).withValues(alpha: 0.4)),
                ),
                child: LayoutBuilder(
                  builder: (context, formConstraints) {
                    final isCompact = formConstraints.maxWidth < 520;
                    return Column(
                      children: [
                        if (isCompact) ...[
                          TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(labelText: 'Equipment Name *', hintText: 'e.g. Smart Board, AC, Projector'),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _qtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Quantity', hintText: '1'),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _nameCtrl,
                                  decoration: const InputDecoration(labelText: 'Equipment Name *', hintText: 'e.g. Smart Board, AC, Projector'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: _qtyCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Quantity', hintText: '1'),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),

                        // Dropdowns: Stacked on compact, Row on wide
                        if (isCompact) ...[
                          DropdownButtonFormField<String>(
                            initialValue: _category,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Category'),
                            items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) => setState(() => _category = v ?? _category),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _condition,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Condition'),
                            items: _conditions.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) => setState(() => _condition = v ?? _condition),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            initialValue: _status,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Status'),
                            items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                            onChanged: (v) => setState(() => _status = v ?? _status),
                          ),
                        ] else ...[
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _category,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Category'),
                                  items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (v) => setState(() => _category = v ?? _category),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _condition,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Condition'),
                                  items: _conditions.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (v) => setState(() => _condition = v ?? _condition),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _status,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Status'),
                                  items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (v) => setState(() => _status = v ?? _status),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton(
                              onPressed: _saveNewEquipment,
                              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                              child: const Text('Save Item'),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),

            // Equipment List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _equipment.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inventory_2_outlined, size: 40, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                              const SizedBox(height: 8),
                              const Text('No equipment added to this room yet.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          itemCount: _equipment.length,
                          separatorBuilder: (_, __) => const Divider(height: 8),
                          itemBuilder: (context, index) {
                            final item = _equipment[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.devices_other_rounded, color: Color(0xFF2563EB), size: 20),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.equipmentName,
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('Qty: ${item.quantity}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                              subtitle: Row(
                                children: [
                                  Text(
                                    '${item.equipmentCategory} • Cond: ${item.condition}',
                                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  DropdownButton<String>(
                                    value: _statuses.contains(item.operationalStatus) ? item.operationalStatus : (_statuses.isNotEmpty ? _statuses.first : 'Operational'),
                                    underline: const SizedBox(),
                                    items: _statuses
                                        .map((s) => DropdownMenuItem(
                                              value: s,
                                              child: Text(s, style: TextStyle(fontSize: 11.5, color: _getStatusColor(s))),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) _updateStatus(item, val);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                    onPressed: () => _deleteItem(item.id),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String s) {
    switch (s) {
      case 'Operational':
        return const Color(0xFF059669);
      case 'Under Maintenance':
        return const Color(0xFFD97706);
      case 'Decommissioned':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFF64748B);
    }
  }
}
