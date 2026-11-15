import 'package:flutter/material.dart';

class DeviceQuickControlsCard extends StatelessWidget {
  final ValueChanged<String> onActionTriggered;

  const DeviceQuickControlsCard({
    super.key,
    required this.onActionTriggered,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final actions = [
      _QuickAction(
        title: 'Turn ON',
        subtitle: '(All / Selected)',
        icon: Icons.power_settings_new_rounded,
        color: const Color(0xFF16A34A),
      ),
      _QuickAction(
        title: 'Turn OFF',
        subtitle: '(All / Selected)',
        icon: Icons.power_settings_new_rounded,
        color: const Color(0xFFDC2626),
      ),
      _QuickAction(
        title: 'Set Level',
        subtitle: '(Brightness / Power)',
        icon: Icons.wb_sunny_outlined,
        color: const Color(0xFFEAB308),
      ),
      _QuickAction(
        title: 'Set Temperature',
        subtitle: '(AC / HVAC)',
        icon: Icons.thermostat_rounded,
        color: const Color(0xFF0284C7),
      ),
      _QuickAction(
        title: 'Apply Scene',
        subtitle: '(Class / Event / Exam)',
        icon: Icons.auto_awesome_rounded,
        color: const Color(0xFF9333EA),
      ),
      _QuickAction(
        title: 'Power Supply',
        subtitle: '(Low / Medium / High)',
        icon: Icons.bolt_rounded,
        color: const Color(0xFFD97706),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.flash_on_rounded, color: Color(0xFF2563EB), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Quick Controls (Entire Campus)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
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
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                itemCount: actions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 6,
                  mainAxisSpacing: 6,
                  childAspectRatio: 1.15,
                ),
                itemBuilder: (context, index) {
                  final a = actions[index];
                  return InkWell(
                    onTap: () => onActionTriggered(a.title),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(a.icon, color: a.color, size: 15),
                          const SizedBox(height: 2),
                          Text(
                            a.title,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            a.subtitle,
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  _QuickAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
