import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/role_provider.dart';
import '../../../providers/auth_provider.dart';
import '../providers/class_provider.dart';
import '../services/academic_lookup_helper.dart';
import 'dialogs/create_edit_class_dialog.dart';
import 'dialogs/create_edit_section_dialog.dart';
import 'dialogs/create_edit_subject_dialog.dart';
import 'dialogs/create_edit_room_dialog.dart';
import 'dialogs/csv_import_export_dialog.dart';

class ClassHeaderBar extends ConsumerStatefulWidget {
  const ClassHeaderBar({super.key});

  @override
  ConsumerState<ClassHeaderBar> createState() => _ClassHeaderBarState();
}

class _ClassHeaderBarState extends ConsumerState<ClassHeaderBar> {
  List<AcademicLookupItem> _academicYears = [];

  @override
  void initState() {
    super.initState();
    _loadAcademicYears();
  }

  Future<void> _loadAcademicYears() async {
    final list = await AcademicLookupHelper.instance.getActiveLookup('FINANCIAL_YEAR');
    if (mounted) {
      setState(() {
        _academicYears = list;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(classProvider);
    final notifier = ref.read(classProvider.notifier);
    final roleState = ref.watch(roleProvider);
    final authState = ref.watch(authProvider);
    final isTeacher = roleState.isTeacher || authState.role == UserRole.teacher;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final availableYearLabels = _academicYears.map((y) => y.label).toList();

    final selectedYear = availableYearLabels.contains(state.academicYear)
        ? state.academicYear
        : (availableYearLabels.isNotEmpty ? availableYearLabels.first : state.academicYear);

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
          final isMobile = constraints.maxWidth < 750;

          String titleText = 'Academic Management';
          String subtitleText = 'Create and manage classes, sections, subjects and rooms.';

          if (isTeacher) {
            titleText = 'My Academic Classes';
            subtitleText = 'View and manage your assigned classes, sections and subjects.';
          } else {
            if (state.activeTab == 0) {
              titleText = 'Class Management';
              subtitleText = 'Manage grade levels, streams, student rosters and class teachers.';
            } else if (state.activeTab == 1) {
              titleText = 'Sections & Batches';
              subtitleText = 'Configure section capacities, room assignments, and student distribution.';
            } else if (state.activeTab == 2) {
              titleText = 'Subjects Management';
              subtitleText = 'Create and manage all subjects used in teaching and learning.';
            } else if (state.activeTab == 3) {
              titleText = 'Rooms & Facilities';
              subtitleText = 'Manage classrooms, laboratories, computer labs, and physical spaces.';
            }
          }

          final titleWidget = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      titleText,
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
                      selectedYear,
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
                subtitleText,
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
              // Dynamic Academic Year Picker
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
                    value: selectedYear,
                    icon: const Icon(Icons.calendar_today_outlined, size: 14),
                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                    items: availableYearLabels.map((yr) {
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
                const SizedBox(width: 8),

                // Import / Export Action Button
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => CsvImportExportDialog(initialEntityIndex: state.activeTab),
                    );
                  },
                  icon: const Icon(Icons.import_export_rounded, size: 16),
                  label: const Text('CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),

                const SizedBox(width: 8),

                // Dynamic Primary Action based on active tab
                ElevatedButton.icon(
                  onPressed: () {
                    if (state.activeTab == 0) {
                      showDialog(
                        context: context,
                        builder: (ctx) => CreateEditClassDialog(
                          academicYear: state.academicYear,
                          onSave: (payload) => notifier.createClass(
                            name: payload['name'] as String,
                            code: payload['code'] as String,
                            stage: payload['stage'] as String? ?? 'Secondary',
                            displayOrder: payload['display_order'] as int? ?? 1,
                            academicYear: state.academicYear,
                            sections: (payload['sections'] as List<dynamic>?)
                                    ?.map((e) => Map<String, dynamic>.from(e as Map))
                                    .toList() ??
                                const [],
                          ),
                        ),
                      );
                    } else if (state.activeTab == 1) {
                      showDialog(
                        context: context,
                        builder: (ctx) => CreateEditSectionDialog(
                          availableClasses: state.availableClasses,
                          availableRooms: state.rooms,
                          academicYear: state.academicYear,
                          onSave: (payload) => notifier.createSection(
                            classId: payload['class_id'] as String,
                            name: payload['name'] as String,
                            code: payload['code'] as String,
                            capacity: payload['capacity'] as int? ?? 40,
                            roomNumber: payload['room_number'] as String?,
                            roomId: payload['room_id'] as String?,
                            academicYear: state.academicYear,
                          ),
                        ),
                      );
                    } else if (state.activeTab == 2) {
                      showDialog(
                        context: context,
                        builder: (ctx) => CreateEditSubjectDialog(
                          availableClasses: state.availableClasses,
                          onSave: (payload) => notifier.createSubject(
                            name: payload['name'] as String,
                            code: payload['code'] as String,
                            type: payload['type'] as String? ?? 'Core',
                            color: payload['color'] as String? ?? '#4F46E5',
                            description: payload['description'] as String?,
                            status: payload['status'] as String? ?? 'ACTIVE',
                            isOptional: payload['is_optional'] as bool? ?? false,
                            classIds: const [],
                          ),
                        ),
                      );
                    } else if (state.activeTab == 3) {
                      showDialog(
                        context: context,
                        builder: (ctx) => CreateEditRoomDialog(
                          availableBuildings: state.availableBuildings,
                          availableFloors: state.availableFloors,
                          onSave: (payload) => notifier.createRoom(
                            name: payload['name'] as String,
                            code: payload['code'] as String,
                            type: payload['type'] as String? ?? 'Classroom',
                            building: payload['building'] as String? ?? 'Academic Block',
                            floor: payload['floor'] as String? ?? 'Ground Floor',
                            capacity: payload['capacity'] as int? ?? 40,
                            facilities: (payload['facilities'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
                            status: payload['status'] as String? ?? 'AVAILABLE',
                            description: payload['description'] as String?,
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: Text(
                    state.activeTab == 0
                        ? 'Add Class'
                        : state.activeTab == 1
                            ? 'Add Section'
                            : state.activeTab == 2
                                ? 'Add Subject'
                                : 'Add Room',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ],
          );

          if (isMobile) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                titleWidget,
                const SizedBox(height: 14),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: actionsWidget,
                ),
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: titleWidget),
              const SizedBox(width: 16),
              actionsWidget,
            ],
          );
        },
      ),
    );
  }
}
