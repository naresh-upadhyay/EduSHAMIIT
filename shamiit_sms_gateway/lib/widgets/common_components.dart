import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/sms_models.dart';

class SkyHeaderContainer extends StatelessWidget {
  final Widget child;
  final bool blueHeader;
  const SkyHeaderContainer({super.key, required this.child, this.blueHeader = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: blueHeader
              ? (isDark
                  ? [const Color(0xFF0E2B6B), const Color(0xFF0E1B33), AppColors.darkBackground]
                  : [AppColors.primaryBlue, const Color(0xFF4F93FF), AppColors.background])
              : (isDark
                  ? [const Color(0xFF0E1B33), AppColors.darkBackground]
                  : [AppColors.skyTop, AppColors.background]),
          stops: blueHeader ? const [0.0, 0.17, 0.30] : const [0.0, 0.28],
        ),
      ),
      child: child,
    );
  }
}

class AppTopBar extends StatelessWidget {
  final String title;
  final bool showBackButton;
  final bool isHomeHeader;
  final bool lightForeground;
  final IconData? leadingTitleIcon;
  final VoidCallback? onBack;
  final VoidCallback? onMenuPressed;
  final List<Widget>? actions;

  const AppTopBar({
    super.key,
    required this.title,
    this.showBackButton = false,
    this.isHomeHeader = false,
    this.lightForeground = false,
    this.leadingTitleIcon,
    this.onBack,
    this.onMenuPressed,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = lightForeground
        ? Colors.white
        : (isDark ? AppColors.darkPrimaryText : AppColors.primaryText);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Row(
          children: [
            if (showBackButton)
              IconButton(
                icon: Icon(Icons.arrow_back_rounded, color: titleColor),
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              )
            else
              Builder(
                builder: (ctx) => IconButton(
                  icon: Icon(Icons.menu_rounded, color: titleColor),
                  onPressed: onMenuPressed ?? () => Scaffold.of(ctx).openDrawer(),
                ),
              ),
            if (isHomeHeader) ...[
              const Spacer(),
              Container(
                width: 32,
                height: 32,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: AppShapes.softShadow,
                ),
                child: Image.asset(
                  'assets/images/shamiit_logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.sms_rounded,
                    color: AppColors.primaryBlue,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SHAMIIT',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                      color: lightForeground
                          ? Colors.white
                          : (isDark ? Colors.white : AppColors.darkBlue),
                      height: 1.0,
                    ),
                  ),
                  Text(
                    'SMS Gateway',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: lightForeground
                          ? Colors.white.withValues(alpha: 0.88)
                          : (isDark ? AppColors.darkSecondaryText : AppColors.secondaryText),
                    ),
                  ),
                ],
              ),
              const Spacer(),
            ] else ...[
              const SizedBox(width: 4),
              if (leadingTitleIcon != null) ...[
                Icon(leadingTitleIcon, color: AppColors.primaryBlue, size: 22),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
              ),
            ],
            if (actions != null) ...actions!,
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionLabel!),
          ),
      ],
    );
  }
}

class StatusCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final VoidCallback? onTap;

  const StatusCard({
    super.key,
    required this.child,
    this.padding,
    this.backgroundColor,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ?? (isDark ? AppColors.darkCard : AppColors.cardBackground);
    final brd = borderColor ?? (isDark ? AppColors.darkBorder : AppColors.border);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
        child: Container(
          padding: padding ?? const EdgeInsets.all(AppDimensions.cardPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(color: brd),
            boxShadow: isDark ? null : AppShapes.softShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color? cardTint;
  final String value;
  final String label;
  final VoidCallback? onTap;

  const MetricCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    this.cardTint,
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return StatusCard(
      onTap: onTap,
      backgroundColor: isDark ? null : cardTint,
      borderColor: isDark ? null : (cardTint != null ? iconColor.withValues(alpha: 0.16) : null),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: isDark ? iconColor.withValues(alpha: 0.16) : iconBgColor,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.primaryText,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final upper = status.toUpperCase();
    Color fg;
    Color bg;
    String label = status;

    if (upper == 'DELIVERED' || upper == 'ONLINE' || upper == 'ACTIVE' || upper == 'CONNECTED' || upper == 'GRANTED' || upper == 'RUNNING' || upper == 'UNRESTRICTED') {
      fg = AppColors.successGreen;
      bg = isDark ? AppColors.successGreen.withValues(alpha: 0.16) : AppColors.successGreenBg;
      if (upper == 'ONLINE') label = 'Online';
      if (upper == 'ACTIVE') label = 'Active';
      if (upper == 'DELIVERED') label = 'Delivered';
    } else if (upper == 'SENT' || upper == 'SENDING' || upper == 'RECEIVED' || upper == 'NEW' || upper == 'READ') {
      fg = AppColors.primaryBlue;
      bg = isDark ? AppColors.primaryBlue.withValues(alpha: 0.18) : AppColors.primaryBlueLight;
      if (upper == 'RECEIVED') label = 'Received';
      if (upper == 'SENDING') label = 'Sending';
      if (upper == 'SENT') label = 'Sent';
    } else if (upper == 'QUEUED' || upper == 'LEASED' || upper == 'SCHEDULED' || upper == 'CONNECTING' || upper == 'RESTRICTED' || upper == 'PAUSED') {
      fg = AppColors.warningOrange;
      bg = isDark ? AppColors.warningOrange.withValues(alpha: 0.16) : AppColors.warningOrangeBg;
    } else if (upper == 'FAILED' || upper == 'ERROR' || upper == 'AUTH_ERROR' || upper == 'OFFLINE' || upper == 'DENIED' || upper == 'STOPPED' || upper == 'UNREACHABLE') {
      fg = AppColors.errorRed;
      bg = isDark ? AppColors.errorRed.withValues(alpha: 0.16) : AppColors.errorRedBg;
    } else {
      fg = isDark ? AppColors.darkSecondaryText : AppColors.secondaryText;
      bg = isDark ? AppColors.darkSurfaceElevated : AppColors.background;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: fg,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class InfoMetricRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? statusIcon;
  final Color? statusColor;
  final bool monospace;
  final bool showDivider;

  const InfoMetricRow({
    super.key,
    required this.label,
    required this.value,
    this.statusIcon,
    this.statusColor,
    this.monospace = false,
    this.showDivider = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final labelColor = isDark ? AppColors.darkSecondaryText : AppColors.secondaryText;
    final valColor = isDark ? AppColors.darkPrimaryText : AppColors.primaryText;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: LayoutBuilder(
            builder: (context, constraints) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 12.5, color: labelColor),
                  ),
                ),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.56),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (statusIcon != null) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(
                            statusIcon,
                            size: 15,
                            color: statusColor ?? AppColors.primaryBlue,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: Text(
                          value,
                          textAlign: TextAlign.right,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            fontFamily: monospace ? 'monospace' : null,
                            color: valColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1),
      ],
    );
  }
}

class SignalBars extends StatelessWidget {
  final int level; // 0..4
  final Color? activeColor;
  const SignalBars({super.key, required this.level, this.activeColor});

  @override
  Widget build(BuildContext context) {
    final active = activeColor ?? AppColors.successGreen;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final filled = i < level;
        return Container(
          width: 3.5,
          height: 5.0 + (i * 3.0),
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: filled ? active : AppColors.border,
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      }),
    );
  }
}

class SimCard extends StatelessWidget {
  final SimInfo sim;
  final bool selected;
  final VoidCallback? onTap;

  const SimCard({
    super.key,
    required this.sim,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryBlue, AppColors.darkBlue],
                )
              : null,
          color: selected ? null : (isDark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primaryBlue : (isDark ? AppColors.darkBorder : AppColors.border),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.primaryBlue.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
              : (isDark ? null : AppShapes.softShadow),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.18)
                        : (isDark ? AppColors.warningOrange.withValues(alpha: 0.18) : AppColors.warningOrangeBg),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.sim_card_rounded,
                    color: selected ? Colors.white : AppColors.warningOrange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sim.slotLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: selected ? Colors.white : (isDark ? Colors.white : AppColors.primaryText),
                        ),
                      ),
                      Text(
                        '(${sim.carrierName})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: selected ? Colors.white70 : AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SignalBars(
                  level: sim.signalLevel,
                  activeColor: selected ? Colors.white : AppColors.successGreen,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: sim.isActive
                        ? (selected
                            ? AppColors.successGreen
                            : (isDark ? AppColors.successGreen.withValues(alpha: 0.18) : AppColors.successGreenBg))
                        : (isDark ? AppColors.darkSurfaceElevated : AppColors.background),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    sim.isActive ? 'Active' : 'Inactive',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: sim.isActive
                          ? (selected ? Colors.white : AppColors.successGreen)
                          : AppColors.secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MessageListItem extends StatelessWidget {
  final SmsMessageRecord message;
  final VoidCallback? onTap;

  const MessageListItem({super.key, required this.message, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final upper = message.status.toUpperCase();
    IconData icon;
    Color iconColor;
    Color iconBg;

    if (upper == 'FAILED') {
      icon = Icons.error_rounded;
      iconColor = AppColors.errorRed;
      iconBg = isDark ? AppColors.errorRed.withValues(alpha: 0.16) : AppColors.errorRedBg;
    } else if (message.isInbound) {
      icon = Icons.chat_bubble_rounded;
      iconColor = AppColors.successGreen;
      iconBg = isDark ? AppColors.successGreen.withValues(alpha: 0.16) : AppColors.successGreenBg;
    } else {
      icon = Icons.send_rounded;
      iconColor = AppColors.primaryBlue;
      iconBg = isDark ? AppColors.primaryBlue.withValues(alpha: 0.16) : AppColors.primaryBlueLight;
    }

    final prefix = message.isInbound ? 'From:' : 'To:';
    final simTag = message.effectiveSimSlot != null
        ? 'SIM ${message.effectiveSimSlot! + 1}${message.carrierName != null ? ' • ${message.carrierName}' : ''}'
        : message.applicationSource;

    return StatusCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$prefix ${message.counterparty}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: isDark ? Colors.white : AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.messageBody,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$simTag • ${message.applicationSource}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5, color: AppColors.mutedText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _shortTime(message.createdAt),
                style: const TextStyle(fontSize: 11, color: AppColors.secondaryText),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusBadge(status: message.status),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.mutedText),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _shortTime(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ap = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }
}

class AppSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;

  const AppSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Search number, text, ID, app...',
    this.onChanged,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  controller.clear();
                  onClear?.call();
                },
              )
            : null,
        filled: true,
        fillColor: isDark ? AppColors.darkCard : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      ),
    );
  }
}

class FilterChips extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  const FilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((opt) {
          final active = opt == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(opt),
              selected: active,
              onSelected: (_) => onSelected(opt),
              selectedColor: AppColors.primaryBlue,
              labelStyle: TextStyle(
                color: active
                    ? Colors.white
                    : (isDark ? AppColors.darkPrimaryText : AppColors.primaryText),
                fontWeight: FontWeight.w600,
                fontSize: 12.5,
              ),
              backgroundColor: isDark ? AppColors.darkCard : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
                side: BorderSide(
                  color: active
                      ? AppColors.primaryBlue
                      : (isDark ? AppColors.darkBorder : AppColors.border),
                ),
              ),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isDark ? AppColors.primaryBlue.withValues(alpha: 0.16) : AppColors.primaryBlueLight,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.primaryBlue, size: 30),
            ),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class LoadingState extends StatelessWidget {
  final String message;
  const LoadingState({super.key, this.message = 'Loading telemetry...'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.primaryBlue),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(fontSize: 13, color: AppColors.secondaryText)),
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const ErrorState({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Unable to Load Data',
      subtitle: message,
      action: ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Retry'),
      ),
    );
  }
}

class AppDialogFrame extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color? iconBg;
  final String title;
  final String? subtitle;
  final Widget content;
  final List<Widget>? actions;

  const AppDialogFrame({
    super.key,
    required this.icon,
    this.iconColor = AppColors.primaryBlue,
    this.iconBg,
    required this.title,
    this.subtitle,
    required this.content,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final resolvedBg = iconBg ??
        (isDark ? iconColor.withValues(alpha: 0.18) : iconColor.withValues(alpha: 0.12));

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.border),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: resolvedBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(child: content),
              ),
              if (actions != null && actions!.isNotEmpty) ...[
                const SizedBox(height: 18),
                Row(
                  children: actions!
                      .asMap()
                      .entries
                      .map((e) => Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(left: e.key > 0 ? 10 : 0),
                              child: e.value,
                            ),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required IconData icon,
  Color iconColor = AppColors.primaryBlue,
  required String title,
  String? subtitle,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) {
      final isDark = Theme.of(ctx).brightness == Brightness.dark;
      final viewInsetsBottom = MediaQuery.viewInsetsOf(ctx).bottom;
      final viewPaddingBottom = MediaQuery.viewPaddingOf(ctx).bottom;
      final effectiveBottom = math.max(viewInsetsBottom, viewPaddingBottom);
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.88,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + effectiveBottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isDark
                          ? iconColor.withValues(alpha: 0.18)
                          : iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 21),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Flexible(
                child: SingleChildScrollView(child: builder(ctx)),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<bool> showConfirmationDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  Color confirmColor = AppColors.primaryBlue,
  IconData icon = Icons.help_outline_rounded,
}) async {
  final resolvedIcon = confirmColor == AppColors.errorRed
      ? Icons.warning_amber_rounded
      : icon;
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AppDialogFrame(
      icon: resolvedIcon,
      iconColor: confirmColor,
      title: title,
      content: Text(
        message,
        style: const TextStyle(fontSize: 13.5, height: 1.45),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return res ?? false;
}
