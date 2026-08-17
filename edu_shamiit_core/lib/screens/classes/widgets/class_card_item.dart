import 'package:flutter/material.dart';
import '../models/class_models.dart';

class ClassCardItem extends StatelessWidget {
  final AcademicClassModel academicClass;
  final bool isSelected;
  final VoidCallback onTap;

  const ClassCardItem({
    super.key,
    required this.academicClass,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Extract short numeric / alpha representation for the circular badge
    final match = RegExp(r'\d+').firstMatch(academicClass.name);
    final badgeText = match != null
        ? match.group(0)!
        : (academicClass.code.length > 3 ? academicClass.code.substring(0, 3) : academicClass.code);

    final badgeColor = academicClass.badgeColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC))
              : (isDark ? const Color(0xFF0F172A).withOpacity(0.6) : Colors.white),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF4F46E5)
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4F46E5).withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            // Circular Colored Badge with number
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: badgeColor.withOpacity(0.3)),
              ),
              alignment: Alignment.center,
              child: Text(
                badgeText,
                style: TextStyle(
                  color: badgeColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Class info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          academicClass.name,
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: academicClass.status.toUpperCase() == 'ARCHIVED'
                              ? const Color(0xFFF59E0B).withOpacity(0.15)
                              : (academicClass.isActive
                                  ? const Color(0xFF10B981).withOpacity(0.15)
                                  : const Color(0xFFEF4444).withOpacity(0.15)),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          academicClass.status.toUpperCase() == 'ARCHIVED'
                              ? 'Archived'
                              : (academicClass.isActive ? 'Active' : 'Inactive'),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: academicClass.status.toUpperCase() == 'ARCHIVED'
                                ? const Color(0xFFF59E0B)
                                : (academicClass.isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    academicClass.stage,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '${academicClass.sectionsCount} Sections',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '•',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${academicClass.studentsCount} Students',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (isSelected)
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Color(0xFF4F46E5),
              ),
          ],
        ),
      ),
    );
  }
}
