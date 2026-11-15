import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/broadcast_models.dart';
import '../providers/broadcast_provider.dart';

class BroadcastSettingsTabView extends StatefulWidget {
  final BroadcastProvider provider;

  const BroadcastSettingsTabView({super.key, required this.provider});

  @override
  State<BroadcastSettingsTabView> createState() => _BroadcastSettingsTabViewState();
}

class _BroadcastSettingsTabViewState extends State<BroadcastSettingsTabView> {
  bool _isSaving = false;
  bool _hideStreamKey = true;

  String _quality = '1080p (Full HD)';
  String _bitrate = 'Auto (Recommended)';
  String _privacy = 'Public';
  String _category = 'Education';
  bool _autoRecord = true;
  bool _lowLatency = true;
  bool _dvr = true;
  bool _chatRelay = true;
  final _customRtmpController = TextEditingController(text: 'rtmp://live.edushamiit.internal/stream');
  final _customKeyController = TextEditingController(text: 'shamiit_live_key_sec_884920');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await widget.provider.loadSettings();
    final s = widget.provider.settings;
    if (s != null && mounted) {
      setState(() {
        _quality = s.defaultQuality;
        _bitrate = s.defaultBitrateMode;
        _privacy = s.defaultPrivacy;
        _category = s.defaultCategory;
        _autoRecord = s.autoRecordBroadcasts;
        _lowLatency = s.lowLatencyMode;
        _dvr = s.dvrEnabled;
        _chatRelay = s.enableChatRelay;
        _customRtmpController.text = s.customRtmpUrl;
        _customKeyController.text = s.customStreamKey;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final updated = BroadcastSettingsData(
      id: widget.provider.settings?.id ?? 1,
      defaultQuality: _quality,
      defaultBitrateMode: _bitrate,
      defaultPrivacy: _privacy,
      defaultCategory: _category,
      autoRecordBroadcasts: _autoRecord,
      lowLatencyMode: _lowLatency,
      dvrEnabled: _dvr,
      enableChatRelay: _chatRelay,
      customRtmpUrl: _customRtmpController.text.trim(),
      customStreamKey: _customKeyController.text.trim(),
    );

    final ok = await widget.provider.updateSettings(updated);
    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Broadcast settings saved!'), backgroundColor: Color(0xFF16A34A)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save settings.'), backgroundColor: Color(0xFFDC2626)),
        );
      }
    }
  }

  @override
  void dispose() {
    _customRtmpController.dispose();
    _customKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.tune, color: Color(0xFF2563EB), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Broadcast Stream Configuration & Encoder Defaults',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Manage default settings applied when launching new live broadcast sessions.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                ),
                const Divider(height: 32),

                // Defaults row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Default Stream Quality', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _quality,
                            items: const [
                              DropdownMenuItem(value: '1080p (Full HD)', child: Text('1080p (Full HD)')),
                              DropdownMenuItem(value: '720p (HD)', child: Text('720p (HD)')),
                              DropdownMenuItem(value: '4K (Ultra HD)', child: Text('4K (Ultra HD)')),
                            ],
                            onChanged: (v) => setState(() => _quality = v!),
                            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Bitrate Mode', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _bitrate,
                            items: const [
                              DropdownMenuItem(value: 'Auto (Recommended)', child: Text('Auto (Recommended)')),
                              DropdownMenuItem(value: 'Constant (CBR)', child: Text('Constant (CBR)')),
                              DropdownMenuItem(value: 'Variable (VBR)', child: Text('Variable (VBR)')),
                            ],
                            onChanged: (v) => setState(() => _bitrate = v!),
                            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Default Privacy', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _privacy,
                            items: const [
                              DropdownMenuItem(value: 'Public', child: Text('Public')),
                              DropdownMenuItem(value: 'Unlisted', child: Text('Unlisted')),
                              DropdownMenuItem(value: 'Private', child: Text('Private')),
                            ],
                            onChanged: (v) => setState(() => _privacy = v!),
                            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Default Category', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _category,
                            items: const [
                              DropdownMenuItem(value: 'Education', child: Text('Education')),
                              DropdownMenuItem(value: 'Science', child: Text('Science')),
                              DropdownMenuItem(value: 'Language', child: Text('Language')),
                            ],
                            onChanged: (v) => setState(() => _category = v!),
                            decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),

                // Toggles
                SwitchListTile(
                  title: const Text('Auto-record broadcasts', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Automatically save live broadcast to Recordings tab upon stream completion.', style: TextStyle(fontSize: 11)),
                  value: _autoRecord,
                  activeThumbColor: const Color(0xFF2563EB),
                  onChanged: (v) => setState(() => _autoRecord = v),
                ),
                SwitchListTile(
                  title: const Text('Low-Latency Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Reduces broadcast delay to under 2 seconds for real-time Q&A interaction.', style: TextStyle(fontSize: 11)),
                  value: _lowLatency,
                  activeThumbColor: const Color(0xFF2563EB),
                  onChanged: (v) => setState(() => _lowLatency = v),
                ),
                SwitchListTile(
                  title: const Text('DVR Time-Shift Buffer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Allows students and viewers to pause and seek back during live stream.', style: TextStyle(fontSize: 11)),
                  value: _dvr,
                  activeThumbColor: const Color(0xFF2563EB),
                  onChanged: (v) => setState(() => _dvr = v),
                ),
                SwitchListTile(
                  title: const Text('Live Chat & Reactions Relay', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Relays YouTube and Facebook comments directly into classroom chat.', style: TextStyle(fontSize: 11)),
                  value: _chatRelay,
                  activeThumbColor: const Color(0xFF2563EB),
                  onChanged: (v) => setState(() => _chatRelay = v),
                ),
                const Divider(height: 32),

                // Custom RTMP Ingest & Stream Key
                const Text('Custom RTMP Ingest URL', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customRtmpController,
                        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: 'Copy RTMP URL',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _customRtmpController.text));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('RTMP URL copied!')));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Text('Stream Key (Secret)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _customKeyController,
                        obscureText: _hideStreamKey,
                        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(_hideStreamKey ? Icons.visibility : Icons.visibility_off, size: 20),
                      onPressed: () => setState(() => _hideStreamKey = !_hideStreamKey),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      tooltip: 'Copy Stream Key',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _customKeyController.text));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Stream key copied!')));
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Save Button
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check, size: 16),
                    label: const Text('Save Changes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
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
