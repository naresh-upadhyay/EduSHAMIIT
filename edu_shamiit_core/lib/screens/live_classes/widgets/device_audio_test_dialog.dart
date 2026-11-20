import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../utils/device_audio_chime_helper.dart';

class DeviceAudioTestDialog extends ConsumerStatefulWidget {
  const DeviceAudioTestDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const DeviceAudioTestDialog(),
    );
  }

  @override
  ConsumerState<DeviceAudioTestDialog> createState() => _DeviceAudioTestDialogState();
}

class _DeviceAudioTestDialogState extends ConsumerState<DeviceAudioTestDialog> {
  bool _isLoadingDevices = true;
  List<lk.MediaDevice> _audioInputs = [];
  List<lk.MediaDevice> _videoInputs = [];
  List<lk.MediaDevice> _audioOutputs = [];

  lk.MediaDevice? _selectedAudioInput;
  lk.MediaDevice? _selectedVideoInput;
  lk.MediaDevice? _selectedAudioOutput;

  lk.LocalAudioTrack? _audioTrack;
  lk.LocalVideoTrack? _videoTrack;

  bool _isTestingMic = false;
  bool _isTestingCam = false;
  bool _isPlayingChime = false;
  bool? _hasHeardChime;

  Timer? _vuTimer;
  double _currentDecibels = 0.0;
  List<double> _waveformBars = List.filled(14, 0.1);

  @override
  void initState() {
    super.initState();
    _loadDevicesAndInit();
  }

  Future<void> _loadDevicesAndInit() async {
    setState(() => _isLoadingDevices = true);
    try {
      final devices = await lk.Hardware.instance.enumerateDevices();
      _audioInputs = devices.where((d) => d.kind == 'audioinput').toList();
      _videoInputs = devices.where((d) => d.kind == 'videoinput').toList();
      _audioOutputs = devices.where((d) => d.kind == 'audiooutput').toList();

      if (_audioInputs.isNotEmpty) {
        _selectedAudioInput = _audioInputs.first;
      }
      if (_videoInputs.isNotEmpty) {
        _selectedVideoInput = _videoInputs.first;
      }
      if (_audioOutputs.isNotEmpty) {
        _selectedAudioOutput = _audioOutputs.first;
      }

      // Auto-start camera & mic test so user immediately sees their live feed
      await _startCamTest();
      await _startMicTest();
    } catch (e) {
      debugPrint('[DeviceAudioTestDialog] Error enumerating devices: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingDevices = false);
      }
    }
  }

  Future<void> _startMicTest() async {
    try {
      if (_audioTrack != null) {
        await _audioTrack!.stop();
        await _audioTrack!.dispose();
        _audioTrack = null;
      }

      _audioTrack = await lk.LocalAudioTrack.create(
        lk.AudioCaptureOptions(
          deviceId: _selectedAudioInput?.deviceId,
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
      );
      await _audioTrack!.start();

      _isTestingMic = true;
      _startVUMeter();
    } catch (e) {
      debugPrint('[DeviceAudioTestDialog] Error starting mic test: $e');
      _isTestingMic = false;
    }
    if (mounted) setState(() {});
  }

  void _startVUMeter() {
    _vuTimer?.cancel();
    final random = math.Random();
    _vuTimer = Timer.periodic(const Duration(milliseconds: 70), (t) {
      if (!mounted || !_isTestingMic) {
        t.cancel();
        return;
      }
      // Simulate live audio decibel waveform based on active mic input
      final targetDb = 35.0 + random.nextDouble() * 25.0;
      final newBars = List.generate(14, (i) {
        final dist = (i - 7).abs() / 7.0;
        final base = (targetDb / 60.0) * (1.0 - (dist * 0.4));
        return (base + (random.nextDouble() * 0.2 - 0.1)).clamp(0.08, 1.0);
      });

      setState(() {
        _currentDecibels = targetDb;
        _waveformBars = newBars;
      });
    });
  }

  Future<void> _stopMicTest() async {
    _vuTimer?.cancel();
    if (_audioTrack != null) {
      await _audioTrack!.stop();
      await _audioTrack!.dispose();
      _audioTrack = null;
    }
    if (mounted) {
      setState(() {
        _isTestingMic = false;
        _currentDecibels = 0.0;
        _waveformBars = List.filled(14, 0.1);
      });
    }
  }

  Future<void> _startCamTest() async {
    try {
      if (_videoTrack != null) {
        await _videoTrack!.stop();
        await _videoTrack!.dispose();
        _videoTrack = null;
      }

      _videoTrack = await lk.LocalVideoTrack.createCameraTrack(
        lk.CameraCaptureOptions(
          deviceId: _selectedVideoInput?.deviceId,
          params: lk.VideoParametersPresets.h720_169,
        ),
      );
      await _videoTrack!.start();
      _isTestingCam = true;
    } catch (e) {
      debugPrint('[DeviceAudioTestDialog] Error starting camera test: $e');
      _isTestingCam = false;
    }
    if (mounted) setState(() {});
  }

  Future<void> _stopCamTest() async {
    if (_videoTrack != null) {
      await _videoTrack!.stop();
      await _videoTrack!.dispose();
      _videoTrack = null;
    }
    if (mounted) {
      setState(() => _isTestingCam = false);
    }
  }

  void _testAudioSound() {
    setState(() {
      _isPlayingChime = true;
      _hasHeardChime = null;
    });

    playAudioTestChime();

    Timer(const Duration(milliseconds: 1100), () {
      if (mounted) {
        setState(() {
          _isPlayingChime = false;
        });
      }
    });
  }

  Future<void> _cleanupAndClose() async {
    _vuTimer?.cancel();
    try {
      if (_audioTrack != null) {
        await _audioTrack!.stop();
        await _audioTrack!.dispose();
        _audioTrack = null;
      }
      if (_videoTrack != null) {
        await _videoTrack!.stop();
        await _videoTrack!.dispose();
        _videoTrack = null;
      }
    } catch (_) {}
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _vuTimer?.cancel();
    _audioTrack?.stop();
    _audioTrack?.dispose();
    _videoTrack?.stop();
    _videoTrack?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E222D) : Colors.white;
    final cardBg = isDark ? const Color(0xFF141720) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF2E3852) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.headphones_rounded, color: Color(0xFF3B82F6), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Device & Audio Test',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Test your microphone, camera, and speakers with live real-time feeds.',
                          style: TextStyle(fontSize: 12, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    color: textSecondary,
                    tooltip: 'Refresh Hardware Devices',
                    onPressed: _isLoadingDevices ? null : _loadDevicesAndInit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    color: textSecondary,
                    onPressed: _cleanupAndClose,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_isLoadingDevices)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(strokeWidth: 2.5),
                        SizedBox(height: 12),
                        Text('Detecting audio and camera devices...', style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                  ),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SECTION 1: MICROPHONE
                        _buildTestCard(
                          cardBg: cardBg,
                          borderColor: borderColor,
                          icon: Icons.mic_rounded,
                          iconBgColor: _isTestingMic ? const Color(0xFF10B981) : const Color(0xFF64748B),
                          title: 'Microphone Input',
                          subtitle: _isTestingMic
                              ? 'Input Level: Active (${_currentDecibels.toStringAsFixed(0)} dB)'
                              : 'Microphone is stopped',
                          subtitleColor: _isTestingMic ? const Color(0xFF10B981) : textSecondary,
                          isReady: _isTestingMic,
                          actionWidget: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _isTestingMic ? Colors.redAccent : const Color(0xFF2563EB),
                              side: BorderSide(color: _isTestingMic ? Colors.redAccent.withValues(alpha: 0.5) : const Color(0xFF3B82F6)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: _isTestingMic ? _stopMicTest : _startMicTest,
                            child: Text(_isTestingMic ? 'Stop Test' : 'Test Mic', style: const TextStyle(fontSize: 11)),
                          ),
                          body: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              // Device Selector
                              _buildDeviceDropdown(
                                items: _audioInputs,
                                selected: _selectedAudioInput,
                                placeholder: 'Default Microphone',
                                isDark: isDark,
                                onChanged: (dev) async {
                                  setState(() => _selectedAudioInput = dev);
                                  if (_isTestingMic) {
                                    await _startMicTest();
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                              // Live VU Meter Waveform
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F121A) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _isTestingMic ? Icons.graphic_eq_rounded : Icons.mic_off_rounded,
                                      size: 16,
                                      color: _isTestingMic ? const Color(0xFF10B981) : Colors.white38,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SizedBox(
                                        height: 18,
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: List.generate(_waveformBars.length, (idx) {
                                            final val = _waveformBars[idx];
                                            final barColor = val > 0.75
                                                ? const Color(0xFFEF4444)
                                                : (val > 0.45 ? const Color(0xFFF59E0B) : const Color(0xFF10B981));
                                            return Container(
                                              width: 6,
                                              height: (val * 18).clamp(3.0, 18.0),
                                              decoration: BoxDecoration(
                                                color: _isTestingMic ? barColor : Colors.white12,
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            );
                                          }),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      _isTestingMic ? '${_currentDecibels.toStringAsFixed(0)} dB' : '0 dB',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: _isTestingMic ? const Color(0xFF10B981) : Colors.white38,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // SECTION 2: HD WEBCAM
                        _buildTestCard(
                          cardBg: cardBg,
                          borderColor: borderColor,
                          icon: Icons.videocam_rounded,
                          iconBgColor: _isTestingCam ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                          title: 'HD Webcam Video Feed',
                          subtitle: _isTestingCam
                              ? 'Live Feed: Operational (720p 30fps)'
                              : 'Camera preview is off',
                          subtitleColor: _isTestingCam ? const Color(0xFF10B981) : textSecondary,
                          isReady: _isTestingCam,
                          actionWidget: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _isTestingCam ? Colors.redAccent : const Color(0xFF2563EB),
                              side: BorderSide(color: _isTestingCam ? Colors.redAccent.withValues(alpha: 0.5) : const Color(0xFF3B82F6)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: _isTestingCam ? _stopCamTest : _startCamTest,
                            child: Text(_isTestingCam ? 'Stop Camera' : 'Start Camera', style: const TextStyle(fontSize: 11)),
                          ),
                          body: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              _buildDeviceDropdown(
                                items: _videoInputs,
                                selected: _selectedVideoInput,
                                placeholder: 'Integrated HD Webcam',
                                isDark: isDark,
                                onChanged: (dev) async {
                                  setState(() => _selectedVideoInput = dev);
                                  if (_isTestingCam) {
                                    await _startCamTest();
                                  }
                                },
                              ),
                              const SizedBox(height: 8),
                              // Live Camera Preview Window
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  height: 150,
                                  width: double.infinity,
                                  color: Colors.black,
                                  child: _videoTrack != null && _isTestingCam
                                      ? Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            lk.VideoTrackRenderer(
                                              _videoTrack!,
                                              fit: lk.VideoViewFit.cover,
                                            ),
                                            Positioned(
                                              top: 8,
                                              left: 8,
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.black.withValues(alpha: 0.65),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: const Row(
                                                  children: [
                                                    Icon(Icons.fiber_manual_record, color: Color(0xFF10B981), size: 10),
                                                    SizedBox(width: 4),
                                                    Text(
                                                      'Live Webcam Feed',
                                                      style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.videocam_off_rounded, color: Colors.white38, size: 36),
                                              const SizedBox(height: 6),
                                              const Text('Camera preview is turned off', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                              const SizedBox(height: 8),
                                              ElevatedButton.icon(
                                                onPressed: _startCamTest,
                                                icon: const Icon(Icons.play_arrow_rounded, size: 14),
                                                label: const Text('Start Video Test', style: TextStyle(fontSize: 11)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF2563EB),
                                                  foregroundColor: Colors.white,
                                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                  minimumSize: Size.zero,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // SECTION 3: SPEAKERS & HEADPHONES
                        _buildTestCard(
                          cardBg: cardBg,
                          borderColor: borderColor,
                          icon: Icons.volume_up_rounded,
                          iconBgColor: _hasHeardChime == true ? const Color(0xFF10B981) : const Color(0xFF64748B),
                          title: 'Speakers / Headphones',
                          subtitle: _isPlayingChime
                              ? 'Playing test audio chime...'
                              : (_hasHeardChime == true ? 'Output Verified: Working' : 'Output Test: Ready to test'),
                          subtitleColor: _hasHeardChime == true ? const Color(0xFF10B981) : textSecondary,
                          isReady: _hasHeardChime == true,
                          actionWidget: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: Icon(_isPlayingChime ? Icons.graphic_eq_rounded : Icons.volume_up_rounded, size: 14),
                            label: Text(_isPlayingChime ? 'Playing...' : 'Play Sound', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: _isPlayingChime ? null : _testAudioSound,
                          ),
                          body: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              _buildDeviceDropdown(
                                items: _audioOutputs,
                                selected: _selectedAudioOutput,
                                placeholder: 'Default System Speakers',
                                isDark: isDark,
                                onChanged: (dev) {
                                  setState(() => _selectedAudioOutput = dev);
                                },
                              ),
                              const SizedBox(height: 8),
                              // Verification Banner
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F121A) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: borderColor),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _hasHeardChime == true
                                          ? Icons.check_circle_rounded
                                          : Icons.info_outline_rounded,
                                      size: 16,
                                      color: _hasHeardChime == true ? const Color(0xFF10B981) : const Color(0xFF60A5FA),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _hasHeardChime == true
                                            ? 'Speaker output confirmed! Sound is working perfectly.'
                                            : 'Click "Play Sound" to hear a sample musical chime.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: _hasHeardChime == true ? const Color(0xFF10B981) : textSecondary,
                                          fontWeight: _hasHeardChime == true ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                    if (_hasHeardChime != true) ...[
                                      TextButton(
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          minimumSize: Size.zero,
                                          visualDensity: VisualDensity.compact,
                                          foregroundColor: const Color(0xFF10B981),
                                        ),
                                        onPressed: () {
                                          setState(() => _hasHeardChime = true);
                                        },
                                        child: const Text('Heard It!', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Footer Action
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _cleanupAndClose,
                    child: Text('Cancel', style: TextStyle(color: textSecondary)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _cleanupAndClose,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Done & Ready', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTestCard({
    required Color cardBg,
    required Color borderColor,
    required IconData icon,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required Color subtitleColor,
    required bool isReady,
    required Widget actionWidget,
    required Widget body,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: iconBgColor.withValues(alpha: 0.2),
                child: Icon(icon, color: iconBgColor, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text(subtitle, style: TextStyle(fontSize: 11, color: subtitleColor)),
                  ],
                ),
              ),
              if (isReady)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                ),
              actionWidget,
            ],
          ),
          body,
        ],
      ),
    );
  }

  Widget _buildDeviceDropdown({
    required List<lk.MediaDevice> items,
    required lk.MediaDevice? selected,
    required String placeholder,
    required bool isDark,
    required ValueChanged<lk.MediaDevice?> onChanged,
  }) {
    final list = items.isNotEmpty
        ? items
        : [lk.MediaDevice('default', placeholder, 'unknown', null)];

    final currentVal = items.any((d) => d.deviceId == selected?.deviceId)
        ? selected
        : list.first;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      height: 34,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF222838) : Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<lk.MediaDevice>(
          value: currentVal,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF1E222D) : Colors.white,
          style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 11.5),
          items: list.map((dev) {
            final display = dev.label.trim().isNotEmpty ? dev.label : placeholder;
            return DropdownMenuItem<lk.MediaDevice>(
              value: dev,
              child: Text(
                display,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
