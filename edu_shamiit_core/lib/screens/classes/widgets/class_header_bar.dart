import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/role_provider.dart';
import '../../../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import 'dialogs/create_edit_class_dialog.dart';
import 'dialogs/create_edit_section_dialog.dart';
import 'dialogs/create_edit_subject_dialog.dart';

class ClassHeaderBar extends ConsumerWidget {
  const ClassHeaderBar({super.key});

  final List<String> _academicYears = const [
    '2026-27',
    '2025-26',
    '2024-25',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(classProvider);
    final notifier = ref.read(classProvider.notifier);
    final roleState = ref.watch(roleProvider);
    final authState = ref.watch(authProvider);
    final isTeacher = roleState.isTeacher || authState.role == UserRole.teacher;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;

          final titleWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      isTeacher ? 'My Classes' : 'Class Management',
                      style: TextStyle(
                        fontSize: isMobile ? 18 : 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3)),
                    ),
                    child: Text(
                      state.academicYear,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                isTeacher
                    ? 'View and manage your assigned classes, sections and subjects.'
                    : 'Create and manage classes, sections and subjects.',
                style: TextStyle(
                  fontSize: isMobile ? 11.5 : 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          );

          final actionsWidget = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Academic Year Picker
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: state.academicYear,
                    icon: const Icon(Icons.calendar_today_outlined, size: 14),
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                    items: _academicYears.map((yr) {
                      return DropdownMenuItem(
                        value: yr,
                        child: Text('AY $yr'),
                      );
                    }).toList(),
                    onChanged: (yr) {
                      if (yr != null) notifier.setAcademicYear(yr);
                    },
                  ),
                ),
              ),
              if (!isTeacher) ...[
                const SizedBox(width: 10),

                // Dynamic Primary Action based on active tab
                ElevatedButton.icon(
                  onPressed: () {
                    if (state.activeTab == 0) {
                      showDialog(
                        context: context,
                        builder: (ctx) => CreateEditClassDialog(
                          academicYear: state.academicYear,
                          onSave: (payload) => notifier.createClass(
                            name: payload['name'],
                            code: payload['code'],
                            stage: payload['stage'],
                            academicYear: payload['academic_year'],
                            displayOrder: payload['display_order'],
                            status: payload['status'],
                            sections: List<Map<String, dynamic>>.from(payload['sections'] ?? []),
                          ),
                        ),
                      );
                    } else if (state.activeTab == 1) {
                      showDialog(
                        context: context,
                        builder: (ctx) => CreateEditSectionDialog(
                          availableClasses: state.classes,
                          academicYear: state.academicYear,
                          defaultClassId: state.selectedClass?.id,
                          onSave: (payload) => notifier.createSection(
                            classId: payload['class_id'],
                            name: payload['name'],
                            code: payload['code'],
                            capacity: payload['capacity'],
                            roomNumber: payload['room_number'],
                            academicYear: payload['academic_year'],
                            status: payload['status'],
                          ),
                        ),
                      );
                    } else {
                      showDialog(
                        context: context,
                        builder: (ctx) => CreateEditSubjectDialog(
                          availableClasses: state.classes,
                          onSave: (payload) => notifier.createSubject(
                            name: payload['name'],
                            code: payload['code'],
                            type: payload['type'],
                            description: payload['description'],
                            periodsPerWeek: payload['periods_per_week'],
                            color: payload['color'],
                            status: payload['status'],
                            classIds: List<String>.from(payload['class_ids'] ?? []),
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: Text(
                    state.activeTab == 0
                        ? 'Add Class'
                        : state.activeTab == 1
                            ? 'Add Section'
                            : 'Add Subject',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          );

          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleWidget,
                const SizedBox(height: 12),
                actionsWidget,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: titleWidget),
              actionsWidget,
            ],
          );
        },
      ),
    );
  }
}
