import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/in_app_live_room_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/role_provider.dart';

class JoinClassDialog extends ConsumerStatefulWidget {
  final String? initialCode;
  const JoinClassDialog({super.key, this.initialCode});

  @override
  ConsumerState<JoinClassDialog> createState() => _JoinClassDialogState();
}

class _JoinClassDialogState extends ConsumerState<JoinClassDialog> {
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isMicMuted = false;
  bool _isCamOff = false;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _codeCtrl.text = widget.initialCode!;
    }
    final authState = ref.read(authProvider);
    final user = authState.userData;
    final userName = (user?['full_name'] as String?)?.trim().isNotEmpty == true
        ? (user!['full_name'] as String).trim()
        : ((user?['name'] as String?)?.trim().isNotEmpty == true
            ? (user!['name'] as String).trim()
            : (authState.role == UserRole.superAdmin ? 'King Doe' : 'User'));
    _nameCtrl.text = userName;
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleJoin() async {
    final code = _codeCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid class code or meeting link.')),
      );
      return;
    }

    setState(() => _isJoining = true);
    try {
      final authState = ref.read(authProvider);
      final user = authState.userData;
      final userId = (user?['id'] as String?)?.trim().isNotEmpty == true
          ? (user!['id'] as String).trim()
          : '5198c4b0-f1cb-45db-9649-41688d0438ba';
      final userRole = (user?['role'] as String?)?.trim().isNotEmpty == true
          ? (user!['role'] as String).trim()
          : (authState.role == UserRole.superAdmin ? 'super_admin' : 'teacher');

      final roomService = ref.read(liveRoomServiceProvider);
      roomService.initRoomConfig(
        liveClassId: code,
        currentUserId: userId,
        currentUserName: _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'User',
        currentUserRole: userRole,
      );

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Text('Connecting to live class room $code...'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: Colors.redAccent, content: Text('Failed to join room: $e')),
      );
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBorder = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: cardBg,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.4) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.videocam_rounded, color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Join Live Classroom',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary),
                        ),
                        Text(
                          'Enter room code or paste class link',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 20, color: textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Room Code Field
              Text('Meeting Code / Link', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _codeCtrl,
                textCapitalization: TextCapitalization.characters,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2, color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. 10A-MATH or https://meet.edushamiit.com/c/10a-math',
                  hintStyle: TextStyle(fontSize: 12, color: textSecondary, letterSpacing: 0),
                  prefixIcon: const Icon(Icons.vpn_key_rounded, size: 16, color: Color(0xFF2563EB)),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              // Display Name
              Text('Your Display Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _nameCtrl,
                style: TextStyle(fontSize: 13, color: textPrimary),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.person_outline_rounded, size: 16, color: textSecondary),
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: cardBorder)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),

              // Audio / Video Pre-join Toggles
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: inputBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildDeviceToggle(
                      icon: _isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: _isMicMuted ? 'Mic Muted' : 'Mic Active',
                      isActive: !_isMicMuted,
                      onTap: () => setState(() => _isMicMuted = !_isMicMuted),
                    ),
                    Container(height: 32, width: 1, color: cardBorder),
                    _buildDeviceToggle(
                      icon: _isCamOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                      label: _isCamOff ? 'Cam Off' : 'Cam Active',
                      isActive: !_isCamOff,
                      onTap: () => setState(() => _isCamOff = !_isCamOff),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel', style: TextStyle(color: textSecondary)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _isJoining ? null : _handleJoin,
                    icon: _isJoining
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.login_rounded, size: 16),
                    label: Text(_isJoining ? 'Joining...' : 'Join Classroom', style: const TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceToggle({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Icon(icon, size: 18, color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444)),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isActive ? textPrimary : textSecondary)),
          ],
        ),
      ),
    );
  }
}
