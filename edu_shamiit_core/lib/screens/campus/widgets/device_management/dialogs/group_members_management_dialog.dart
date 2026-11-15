import 'package:flutter/material.dart';
import '../../../models/device_management_models.dart';

class GroupMembersManagementDialog extends StatefulWidget {
  final DeviceGroupItem group;
  final List<Map<String, dynamic>> members;
  final List<DeviceItemModel> allAvailableDevices;
  final Function(String deviceId) onRemoveMember;
  final Function(List<String> deviceIds) onAddMembers;

  const GroupMembersManagementDialog({
    super.key,
    required this.group,
    required this.members,
    this.allAvailableDevices = const [],
    required this.onRemoveMember,
    required this.onAddMembers,
  });

  @override
  State<GroupMembersManagementDialog> createState() => _GroupMembersManagementDialogState();
}

class _GroupMembersManagementDialogState extends State<GroupMembersManagementDialog> {
  String _search = '';
  bool _isAddingMode = false;
  final Set<String> _selectedToAdd = {};

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);

    final currentMemberIds = widget.members.map((m) => m['id']?.toString()).toSet();
    final eligibleToAdd = widget.allAvailableDevices.where((d) => !currentMemberIds.contains(d.id)).toList();

    final filteredMembers = widget.members.where((m) {
      if (_search.isEmpty) return true;
      final q = _search.toLowerCase();
      final name = (m['device_name'] ?? m['name'] ?? '').toString().toLowerCase();
      final code = (m['device_code'] ?? m['code'] ?? '').toString().toLowerCase();
      final type = (m['type_name'] ?? '').toString().toLowerCase();
      return name.contains(q) || code.contains(q) || type.contains(q);
    }).toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: cardBg,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.people_outline, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Members: ${widget.group.name}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.group.deviceCount} Total Devices • Location: ${widget.group.locationScope}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
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
            ),

            // Sub-bar with search and + Add Devices button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search members by name, code or category...',
                        prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        isDense: true,
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    icon: Icon(_isAddingMode ? Icons.list : Icons.add, size: 16),
                    label: Text(_isAddingMode ? 'View Members' : 'Add Devices'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isAddingMode ? const Color(0xFF475569) : const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () {
                      setState(() {
                        _isAddingMode = !_isAddingMode;
                        _selectedToAdd.clear();
                      });
                    },
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isAddingMode
                  ? _buildAddDevicesView(eligibleToAdd, borderColor)
                  : _buildMembersList(filteredMembers, borderColor),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: borderColor))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  if (_isAddingMode && _selectedToAdd.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        widget.onAddMembers(_selectedToAdd.toList());
                        setState(() {
                          _isAddingMode = false;
                          _selectedToAdd.clear();
                        });
                      },
                      child: Text('Add ${_selectedToAdd.length} Selected'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersList(List<Map<String, dynamic>> members, Color borderColor) {
    if (members.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.device_unknown, size: 48, color: Color(0xFF94A3B8)),
              SizedBox(height: 12),
              Text('No members match the query.', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              SizedBox(height: 4),
              Text('Add devices to this group or clear the filter query.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: members.length,
      separatorBuilder: (_, __) => Divider(color: borderColor, height: 1),
      itemBuilder: (ctx, idx) {
        final m = members[idx];
        final id = m['id']?.toString() ?? '';
        final name = m['device_name'] ?? m['name'] ?? 'Unnamed Device';
        final code = m['device_code'] ?? m['code'] ?? 'DEV';
        final type = m['type_name'] ?? 'Generic';
        final isOnline = m['is_online'] == true;
        final power = m['power_state'] == true;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.devices, color: Color(0xFF2563EB), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text('$code • $type', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        const SizedBox(width: 10),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: isOnline ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isOnline ? 'Online' : 'Offline',
                          style: TextStyle(fontSize: 11, color: isOnline ? const Color(0xFF16A34A) : const Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: power ? const Color(0xFF16A34A).withValues(alpha: 0.1) : const Color(0xFF64748B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  power ? 'ON' : 'OFF',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: power ? const Color(0xFF16A34A) : const Color(0xFF64748B)),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Color(0xFFDC2626), size: 18),
                tooltip: 'Remove from group',
                onPressed: () {
                  widget.onRemoveMember(id);
                  setState(() {});
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddDevicesView(List<DeviceItemModel> eligible, Color borderColor) {
    if (eligible.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('All campus devices are already assigned to this group.', style: TextStyle(color: Color(0xFF64748B))),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      itemCount: eligible.length,
      separatorBuilder: (_, __) => Divider(color: borderColor, height: 1),
      itemBuilder: (ctx, idx) {
        final d = eligible[idx];
        final isChecked = _selectedToAdd.contains(d.id);

        return CheckboxListTile(
          value: isChecked,
          activeColor: const Color(0xFF2563EB),
          title: Text(d.deviceName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          subtitle: Text('${d.deviceCode} • ${d.typeName} • ${d.locationDisplay}', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          onChanged: (val) {
            setState(() {
              if (val == true) {
                _selectedToAdd.add(d.id);
              } else {
                _selectedToAdd.remove(d.id);
              }
            });
          },
        );
      },
    );
  }
}
