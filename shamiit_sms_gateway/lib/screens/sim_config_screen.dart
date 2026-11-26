import 'package:flutter/material.dart';
import '../core/platform_bridge.dart';
import '../core/theme.dart';
import '../models/sms_models.dart';
import '../services/api_service.dart';
import '../widgets/common_components.dart';

class SimConfigScreen extends StatefulWidget {
  const SimConfigScreen({super.key});

  @override
  State<SimConfigScreen> createState() => _SimConfigScreenState();
}

class _SimConfigScreenState extends State<SimConfigScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<SimInfo> _sims = [];
  int _selectedSimIndex = 0;

  String _preferredSimMode = 'SIM_1';
  int? _preferredSubId;
  int? _secondarySubId;
  bool _autoFallbackEnabled = false;
  bool _switchOnUnavailable = true;
  bool _switchOnNetworkError = false;
  bool _switchBackOnRecover = true;
  int _messageExpirationSeconds = 86400;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService().getSimConfiguration();
      final sims = (data['sims'] as List<SimInfo>?) ?? [];
      final cfg = (data['configuration'] as Map<String, dynamic>?) ?? {};
      if (!mounted) return;
      setState(() {
        _sims = sims;
        final rawMode = (cfg['preferred_sim_mode'] as String?) ?? 'SIM_1';
        if (rawMode == 'SIM_2' && sims.length < 2) {
          _preferredSimMode = sims.isNotEmpty ? 'SIM_1' : 'MANUAL';
        } else if (rawMode == 'SIM_1' && sims.isEmpty) {
          _preferredSimMode = 'MANUAL';
        } else {
          _preferredSimMode = rawMode;
        }
        final rawPrefSub = (cfg['preferred_subscription_id'] as num?)?.toInt();
        _preferredSubId = sims.any((s) => s.subscriptionId == rawPrefSub)
            ? rawPrefSub
            : (sims.isNotEmpty ? sims.first.subscriptionId : null);
        final rawSecSub = (cfg['secondary_subscription_id'] as num?)?.toInt();
        _secondarySubId = sims.any((s) => s.subscriptionId == rawSecSub)
            ? rawSecSub
            : (sims.length > 1 ? sims[1].subscriptionId : null);
        _autoFallbackEnabled = _asBool(cfg['auto_fallback_enabled'], false);
        _switchOnUnavailable = _asBool(cfg['switch_on_unavailable'], true);
        _switchOnNetworkError = _asBool(cfg['switch_on_network_error'], false);
        _switchBackOnRecover = _asBool(cfg['switch_back_on_recover'], true);
        _messageExpirationSeconds = (cfg['message_expiration_seconds'] as num?)?.toInt() ?? 86400;
        if (_selectedSimIndex >= _sims.length) _selectedSimIndex = 0;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _asBool(dynamic v, bool def) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    return def;
  }

  Future<void> _saveConfiguration() async {
    setState(() => _isSaving = true);
    try {
      final prefSim = _sims.where((s) => s.subscriptionId == _preferredSubId).firstOrNull;
      final secSim = _sims.where((s) => s.subscriptionId == _secondarySubId).firstOrNull;

      final res = await ApiService().saveSimConfiguration(
        sims: _sims,
        configuration: {
          'preferred_sim_mode': _preferredSimMode,
          'preferred_subscription_id': _preferredSubId,
          'preferred_sim_slot': prefSim?.simSlotIndex,
          'secondary_subscription_id': _secondarySubId,
          'secondary_sim_slot': secSim?.simSlotIndex,
          'auto_fallback_enabled': _autoFallbackEnabled,
          'switch_on_unavailable': _switchOnUnavailable,
          'switch_on_network_error': _switchOnNetworkError,
          'switch_back_on_recover': _switchBackOnRecover,
          'message_expiration_seconds': _messageExpirationSeconds,
        },
      );
      if (!mounted) return;
      final conflicts = (res['conflicts'] as List<dynamic>? ?? []);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            conflicts.isNotEmpty
                ? 'Saved with conflict resolution: ${conflicts.join(' ')}'
                : 'SIM configuration saved & synchronized!',
          ),
          backgroundColor: conflicts.isNotEmpty ? AppColors.warningOrange : AppColors.successGreen,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AppDialogFrame(
        icon: Icons.sim_card_outlined,
        iconColor: AppColors.primaryBlue,
        title: 'Dual-SIM Behavior',
        subtitle: 'How Android handles multi-SIM SMS routing',
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HelpBullet(
              icon: Icons.send_rounded,
              color: AppColors.primaryBlue,
              title: 'Exact Outgoing Subscription',
              body: 'Outgoing SMS uses the exact Android Subscription ID of your chosen SIM.',
            ),
            SizedBox(height: 12),
            _HelpBullet(
              icon: Icons.inbox_rounded,
              color: AppColors.successGreen,
              title: 'Carrier-Delivered Inbound',
              body: 'Incoming SMS arrives on the SIM targeted by the mobile network and records the receiving subscription.',
            ),
            SizedBox(height: 12),
            _HelpBullet(
              icon: Icons.shield_outlined,
              color: AppColors.warningOrange,
              title: 'Safe Fallback Policy',
              body: 'SIMs never switch silently unless explicitly enabled, and ambiguous submissions are never auto-retried.',
            ),
          ],
        ),
        actions: [
          ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Understood')),
        ],
      ),
    );
  }

  void _showAdvancedSettings() {
    showAppBottomSheet(
      context: context,
      icon: Icons.tune_rounded,
      iconColor: AppColors.primaryBlue,
      title: 'Advanced SIM Settings',
      subtitle: 'Fallback triggers & message expiration',
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_sims.length > 1) ...[
                DropdownButtonFormField<int>(
                  initialValue: _sims.any((s) => s.subscriptionId == _secondarySubId) ? _secondarySubId : null,
                  decoration: const InputDecoration(labelText: 'Secondary Fallback SIM'),
                  items: _sims
                      .map((s) => DropdownMenuItem(
                            value: s.subscriptionId,
                            child: Text('${s.displayTitle} (SubID ${s.subscriptionId})'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    setSheetState(() => _secondarySubId = v);
                    setState(() => _secondarySubId = v);
                  },
                ),
                const SizedBox(height: 12),
              ],
              StatusCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Switch when preferred SIM unavailable', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      value: _switchOnUnavailable,
                      onChanged: (v) {
                        setSheetState(() => _switchOnUnavailable = v);
                        setState(() => _switchOnUnavailable = v);
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Switch on SIM/network error', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      value: _switchOnNetworkError,
                      onChanged: (v) {
                        setSheetState(() => _switchOnNetworkError = v);
                        setState(() => _switchOnNetworkError = v);
                      },
                    ),
                    const Divider(height: 1),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Switch back when preferred recovers', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      value: _switchBackOnRecover,
                      onChanged: (v) {
                        setSheetState(() => _switchBackOnRecover = v);
                        setState(() => _switchBackOnRecover = v);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _messageExpirationSeconds,
                decoration: const InputDecoration(labelText: 'Default Message Expiration'),
                items: const [
                  DropdownMenuItem(value: 3600, child: Text('1 Hour')),
                  DropdownMenuItem(value: 21600, child: Text('6 Hours')),
                  DropdownMenuItem(value: 86400, child: Text('24 Hours')),
                  DropdownMenuItem(value: 259200, child: Text('72 Hours')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setSheetState(() => _messageExpirationSeconds = v);
                    setState(() => _messageExpirationSeconds = v);
                  }
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Refresh SIMs'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedSim = _sims.isNotEmpty ? _sims[_selectedSimIndex] : null;

    return Scaffold(
      body: SkyHeaderContainer(
        child: Column(
          children: [
            AppTopBar(
              title: 'SIM Configuration',
              showBackButton: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.help_outline_rounded),
                  onPressed: _showHelpDialog,
                ),
              ],
            ),
            Expanded(
              child: _isLoading
                  ? const LoadingState(message: 'Discovering SIM subscriptions...')
                  : _sims.isEmpty
                      ? EmptyState(
                          icon: Icons.sim_card_alert_outlined,
                          title: 'No SIM Cards Detected',
                          subtitle:
                              'Ensure READ_PHONE_STATE & SEND_SMS permissions are granted and at least one active SIM is inserted.',
                          action: ElevatedButton.icon(
                            onPressed: () async {
                              await PlatformBridge.requestCorePermissions();
                              await _load();
                            },
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Refresh / Grant Permission'),
                          ),
                        )
                      : ListView(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            4,
                            16,
                            28 + MediaQuery.viewPaddingOf(context).bottom,
                          ),
                          children: [
                            // Discovered SIM Cards
                            Row(
                              children: _sims.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final sim = entry.value;
                                return Expanded(
                                  child: Padding(
                                    padding: EdgeInsets.only(right: idx < _sims.length - 1 ? 10 : 0),
                                    child: SimCard(
                                      sim: sim,
                                      selected: _selectedSimIndex == idx,
                                      onTap: () => setState(() => _selectedSimIndex = idx),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 18),

                            if (selectedSim != null) ...[
                              Text(
                                'Usage Mode • ${selectedSim.slotLabel}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _UsageModeCard(
                                    icon: Icons.swap_horiz_rounded,
                                    label: 'Send &\nReceive',
                                    active: selectedSim.usageMode == 'SEND_RECEIVE',
                                    onTap: () => setState(() => selectedSim.usageMode = 'SEND_RECEIVE'),
                                  ),
                                  const SizedBox(width: 8),
                                  _UsageModeCard(
                                    icon: Icons.send_rounded,
                                    label: 'Send\nOnly',
                                    active: selectedSim.usageMode == 'SEND_ONLY',
                                    onTap: () => setState(() => selectedSim.usageMode = 'SEND_ONLY'),
                                  ),
                                  const SizedBox(width: 8),
                                  _UsageModeCard(
                                    icon: Icons.inbox_rounded,
                                    label: 'Receive\nOnly',
                                    active: selectedSim.usageMode == 'RECEIVE_ONLY',
                                    onTap: () => setState(() => selectedSim.usageMode = 'RECEIVE_ONLY'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                            ],

                            const Text(
                              'Preferred SIM for Sending',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: StatusCard(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: [
                                          if (_sims.isNotEmpty) 'SIM_1',
                                          if (_sims.length > 1) 'SIM_2',
                                          'MANUAL',
                                          'AUTO_RULE',
                                        ].contains(_preferredSimMode)
                                            ? _preferredSimMode
                                            : 'MANUAL',
                                        isExpanded: true,
                                        items: [
                                          if (_sims.isNotEmpty)
                                            DropdownMenuItem(
                                              value: 'SIM_1',
                                              child: Text('Always use ${_sims[0].displayTitle}', overflow: TextOverflow.ellipsis),
                                            ),
                                          if (_sims.length > 1)
                                            DropdownMenuItem(
                                              value: 'SIM_2',
                                              child: Text('Always use ${_sims[1].displayTitle}', overflow: TextOverflow.ellipsis),
                                            ),
                                          const DropdownMenuItem(
                                            value: 'MANUAL',
                                            child: Text('Manual selection per message', overflow: TextOverflow.ellipsis),
                                          ),
                                          const DropdownMenuItem(
                                            value: 'AUTO_RULE',
                                            child: Text('Automatic routing rules', overflow: TextOverflow.ellipsis),
                                          ),
                                        ],
                                        onChanged: (v) {
                                          if (v == null) return;
                                          setState(() {
                                            _preferredSimMode = v;
                                            if (v == 'SIM_1' && _sims.isNotEmpty) {
                                              _preferredSubId = _sims[0].subscriptionId;
                                            } else if (v == 'SIM_2' && _sims.length > 1) {
                                              _preferredSubId = _sims[1].subscriptionId;
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                StatusCard(
                                  onTap: () {
                                    if (_sims.length > 1) {
                                      setState(() {
                                        if (_preferredSimMode == 'SIM_1') {
                                          _preferredSimMode = 'SIM_2';
                                          _preferredSubId = _sims[1].subscriptionId;
                                          _selectedSimIndex = 1;
                                        } else {
                                          _preferredSimMode = 'SIM_1';
                                          _preferredSubId = _sims[0].subscriptionId;
                                          _selectedSimIndex = 0;
                                        }
                                      });
                                    } else {
                                      _load();
                                    }
                                  },
                                  padding: const EdgeInsets.all(14),
                                  child: const Icon(Icons.sync_alt_rounded, color: AppColors.primaryBlue),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            StatusCard(
                              child: SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text(
                                  'Automatic SIM Switching',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                                ),
                                subtitle: Text(
                                  'Switch to secondary SIM if preferred is unavailable',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                                  ),
                                ),
                                value: _autoFallbackEnabled,
                                onChanged: (v) => setState(() => _autoFallbackEnabled = v),
                              ),
                            ),
                            const SizedBox(height: 10),

                            StatusCard(
                              onTap: _showAdvancedSettings,
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isDark
                                        ? AppColors.primaryBlue.withValues(alpha: 0.18)
                                        : AppColors.primaryBlueLight,
                                    child: const Icon(Icons.tune_rounded, color: AppColors.primaryBlue),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Advanced Settings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                                        Text(
                                          'Fallback rules, network diagnostics, message expiration',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, color: AppColors.secondaryText),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            if (selectedSim != null) ...[
                              Text(
                                'SIM Details • ${selectedSim.slotLabel}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 8),
                              StatusCard(
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(child: _DetailCell('Carrier', selectedSim.carrierName)),
                                        const SizedBox(width: 10),
                                        Expanded(child: _DetailCell('Phone Number', selectedSim.phoneNumber ?? 'Not Available')),
                                      ],
                                    ),
                                    const Divider(height: 18),
                                    Row(
                                      children: [
                                        Expanded(child: _DetailCell('Network', selectedSim.networkType)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text('Signal Strength', style: TextStyle(fontSize: 11.5, color: AppColors.secondaryText)),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  SignalBars(level: selectedSim.signalLevel),
                                                  const SizedBox(width: 6),
                                                  Flexible(
                                                    child: Text(
                                                      selectedSim.signalLabel,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 18),
                                    Row(
                                      children: [
                                        Expanded(child: _DetailCell('Subscription ID', '${selectedSim.subscriptionId}')),
                                        const SizedBox(width: 10),
                                        Expanded(child: _DetailCell('SIM State', selectedSim.simState)),
                                      ],
                                    ),
                                    const Divider(height: 18),
                                    Row(
                                      children: [
                                        Expanded(child: _DetailCell('Balance / Validity', selectedSim.balanceInfo)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: _DetailCell(
                                            'Usage Stats',
                                            'S:${selectedSim.sentCount}  R:${selectedSim.receivedCount}  F:${selectedSim.failedCount}',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 18),
                            SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _isSaving ? null : _saveConfiguration,
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                icon: _isSaving
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      )
                                    : const Icon(Icons.save_rounded),
                                label: const Text('Save Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
}

class _HelpBullet extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String body;

  const _HelpBullet({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: isDark ? color.withValues(alpha: 0.18) : color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                body,
                style: TextStyle(
                  fontSize: 12.2,
                  height: 1.4,
                  color: isDark ? AppColors.darkSecondaryText : AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _UsageModeCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _UsageModeCard({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          decoration: BoxDecoration(
            color: active ? AppColors.primaryBlue : (isDark ? AppColors.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: active ? AppColors.primaryBlue : (isDark ? AppColors.darkBorder : AppColors.border),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: active ? Colors.white : AppColors.primaryBlue, size: 20),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : (isDark ? AppColors.darkPrimaryText : AppColors.primaryText),
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailCell extends StatelessWidget {
  final String title;
  final String value;
  const _DetailCell(this.title, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 11.5, color: AppColors.secondaryText)),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
        ),
      ],
    );
  }
}
