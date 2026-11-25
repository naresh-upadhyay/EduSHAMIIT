import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import '../providers/broadcast_provider.dart';

class AddDestinationDialog extends StatefulWidget {
  final BroadcastProvider provider;

  const AddDestinationDialog({super.key, required this.provider});

  @override
  State<AddDestinationDialog> createState() => _AddDestinationDialogState();
}

class _AddDestinationDialogState extends State<AddDestinationDialog> {
  final _formKey = GlobalKey<FormState>();
  String _selectedPlatform = 'youtube';
  final _nameController = TextEditingController(text: 'YouTube Live Stream');
  final _rtmpController = TextEditingController(text: 'rtmp://a.rtmp.youtube.com/live2');
  final _keyController = TextEditingController();
  bool _isSubmitting = false;

  void _onPlatformChanged(String? platform) {
    if (platform == null) return;
    setState(() {
      _selectedPlatform = platform;
      if (platform == 'youtube') {
        _nameController.text = 'YouTube Live Stream';
        _rtmpController.text = 'rtmp://a.rtmp.youtube.com/live2';
      } else if (platform == 'facebook') {
        _nameController.text = 'Facebook Live Stream';
        _rtmpController.text = 'rtmps://live-api-s.facebook.com:443/rtmp/';
      } else if (platform == 'teams') {
        _nameController.text = 'Microsoft Teams Relay';
        _rtmpController.text = 'rtmp://teams.edushamiit.org/live';
      } else if (platform == 'zoom') {
        _nameController.text = 'Zoom Webinar Feed';
        _rtmpController.text = 'rtmp://zoom.edushamiit.org/live';
      } else {
        _nameController.text = 'Custom RTMP Relay';
        _rtmpController.text = 'rtmp://live.customcdn.com/stream';
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final success = await widget.provider.addDestination(
      platformKey: _selectedPlatform,
      name: _nameController.text.trim(),
      rtmpUrl: _rtmpController.text.trim(),
      streamKey: _keyController.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Destination added successfully!'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add destination.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rtmpController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.add_to_queue, color: Color(0xFF2563EB)),
                          SizedBox(width: 8),
                          Text('Add Broadcast Destination', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  const Text('Platform', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  AppSearchableDropdownFormField<String>.fromMenuItems(
                    initialValue: _selectedPlatform,
                    items: const [
                      DropdownMenuItem(value: 'youtube', child: Text('YouTube Live')),
                      DropdownMenuItem(value: 'facebook', child: Text('Facebook Live')),
                      DropdownMenuItem(value: 'teams', child: Text('Microsoft Teams')),
                      DropdownMenuItem(value: 'zoom', child: Text('Zoom Webinar')),
                      DropdownMenuItem(value: 'custom_rtmp', child: Text('Custom RTMP')),
                    ],
                    onChanged: _onPlatformChanged,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Destination Name *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                  ),
                  const SizedBox(height: 14),

                  const Text('RTMP / RTMPS Server URL *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _rtmpController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'RTMP URL required' : null,
                  ),
                  const SizedBox(height: 14),

                  const Text('Stream Key *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _keyController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Enter stream key provided by platform',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty ? 'Stream key required' : null,
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save Destination'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
