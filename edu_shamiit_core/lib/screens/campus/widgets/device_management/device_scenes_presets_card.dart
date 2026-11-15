import 'package:flutter/material.dart';
import '../../models/device_management_models.dart';

class DeviceScenesPresetsCard extends StatelessWidget {
  final List<DeviceSceneItem> scenes;
  final Function(DeviceSceneItem) onSelectScene;
  final VoidCallback onCreateCustomScene;
  final VoidCallback onManageScenes;

  const DeviceScenesPresetsCard({
    super.key,
    required this.scenes,
    required this.onSelectScene,
    required this.onCreateCustomScene,
    required this.onManageScenes,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final defaultScenes = [
      const DeviceSceneItem(
        id: '1',
        name: 'Classroom',
        code: 'classroom',
        description: 'AC + Lights + Projector',
        icon: 'school',
        colorHex: '#2563EB',
        isPreset: true,
      ),
      const DeviceSceneItem(
        id: '2',
        name: 'Lecture',
        code: 'lecture',
        description: 'AC + Lights + AV',
        icon: 'podium',
        colorHex: '#2563EB',
        isPreset: true,
        isActive: true,
      ),
      const DeviceSceneItem(
        id: '3',
        name: 'Examination',
        code: 'examination',
        description: 'Controlled & Quiet',
        icon: 'edit_note',
        colorHex: '#8B5CF6',
        isPreset: true,
      ),
      const DeviceSceneItem(
        id: '4',
        name: 'Event',
        code: 'event',
        description: 'Lights + Audio + Display',
        icon: 'theater_comedy',
        colorHex: '#EC4899',
        isPreset: true,
      ),
      const DeviceSceneItem(
        id: '5',
        name: 'Energy Save',
        code: 'energy_save',
        description: 'Optimized Mode',
        icon: 'eco',
        colorHex: '#10B981',
        isPreset: true,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Color(0xFF2563EB), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Scenes & Presets',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: onManageScenes,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Manage',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 13,
                        color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),

          // 3x2 Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    childAspectRatio: 1.15,
                    children: [
                      ...defaultScenes.map((s) => _buildSceneTile(s, isDark)),
                      _buildCustomSceneButton(isDark),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSceneTile(DeviceSceneItem s, bool isDark) {
    final isActive = s.isActive;

    IconData icon = Icons.auto_awesome;
    if (s.code == 'classroom') icon = Icons.meeting_room_outlined;
    if (s.code == 'lecture') icon = Icons.co_present_outlined;
    if (s.code == 'examination') icon = Icons.edit_note_rounded;
    if (s.code == 'event') icon = Icons.theater_comedy_rounded;
    if (s.code == 'energy_save') icon = Icons.eco_rounded;

    return InkWell(
      onTap: () => onSelectScene(s),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? const Color(0xFF2563EB)
              : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isActive
                ? const Color(0xFF2563EB)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive
                    ? Colors.white
                    : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB)),
              ),
              const SizedBox(height: 2),
              Text(
                s.name,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                s.description,
                style: TextStyle(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w500,
                  color: isActive ? Colors.white.withValues(alpha: 0.85) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomSceneButton(bool isDark) {
    return InkWell(
      onTap: onCreateCustomScene,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
            style: BorderStyle.solid,
            width: 1,
          ),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_rounded,
                size: 16,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
              const SizedBox(height: 2),
              Text(
                'Custom',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Text(
                '(Create New)',
                style: TextStyle(
                  fontSize: 8.5,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
