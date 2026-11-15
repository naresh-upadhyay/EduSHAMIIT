import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../visitors/widgets/dialogs/camera/web_qr_camera_helper.dart';
import '../../models/hostel_leave_outing_models.dart';
import '../../providers/hostel_provider.dart';
import 'hostel_gate_pass_print_dialog.dart';

/// Interactive Gate Pass Verification Terminal & Clearance Modal.
/// Provides 3 Scanning Modes:
/// 1. Upload QR Image (Computer Vision decoding via OpenCV backend)
/// 2. Live Camera Viewfinder (HTML5 Web Camera feed with scanning laser line)
/// 3. Hardware Barcode Scanner / Manual Pass ID & Token Input
class GatePassDialog extends ConsumerStatefulWidget {
  final String? initialPassNumber;
  final String? requestId;
  final String? gatePassToken;
  final GatePassData? gatePass;

  const GatePassDialog({
    super.key,
    this.initialPassNumber,
    this.requestId,
    this.gatePassToken,
    this.gatePass,
  });

  @override
  ConsumerState<GatePassDialog> createState() => _GatePassDialogState();
}

class _GatePassDialogState extends ConsumerState<GatePassDialog>
    with SingleTickerProviderStateMixin {
  // Mode: 0: Upload Image, 1: Live Camera, 2: Barcode / Pass ID
  int _activeMode = 0;

  // Barcode / Manual input
  final TextEditingController _passIdCtrl = TextEditingController();
  final FocusNode _passIdFocus = FocusNode();

  // Verification State
  bool _isProcessing = false;
  Map<String, dynamic>? _scanResult;
  String? _errorMessage;

  // Gate Security Clearance Action State
  String _selectedAction = 'EXIT'; // 'EXIT' (Departure) or 'RETURN' (Arrival)
  String _selectedGate = 'Main Gate';
  final TextEditingController _remarksCtrl = TextEditingController();
  bool _isSavingAction = false;
  bool _actionCompleted = false;

  // Live Camera State
  CameraFeedState _cameraState = CameraFeedState.uninitialized;
  String? _cameraErrorMessage;
  final String _cameraViewId = 'hostel-qr-webcam-feed-view';

  // Scanner animation
  late AnimationController _laserAnimCtrl;
  late Animation<double> _laserAnim;

  static const List<String> _gatesList = [
    'Main Gate',
    'Hostel Front Gate',
    'North Gate',
    'South Gate',
    'Back Gate',
  ];

  @override
  void initState() {
    super.initState();
    _laserAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _laserAnim = Tween<double>(begin: 0.1, end: 0.9).animate(
      CurvedAnimation(parent: _laserAnimCtrl, curve: Curves.easeInOut),
    );

    if (widget.gatePass != null) {
      final p = widget.gatePass!;
      _scanResult = {
        'success': true,
        'valid': p.status.toUpperCase() == 'ACTIVE',
        'is_valid': p.status.toUpperCase() == 'ACTIVE',
        'validity': p.status.toUpperCase(),
        'message': 'Gate pass verified',
        'suggested_action': p.status.toUpperCase() == 'EXITED' ? 'RETURN' : 'EXIT',
        'gate_pass': {
          'id': p.id,
          'pass_number': p.passNumber,
          'verification_token': p.verificationToken,
          'qr_reference': p.qrReference,
          'status': p.status,
          'valid_from_formatted': p.validFromFormatted,
          'valid_until_formatted': p.validUntilFormatted,
          'used_exit_at_formatted': p.usedExitAt?.toIso8601String(),
          'used_return_at_formatted': p.usedReturnAt?.toIso8601String(),
        },
        'student': {
          'full_name': p.studentName,
          'avatar_url': p.studentPhoto,
          'class': p.className ?? '10 A',
          'roll_number': p.rollNumber ?? '-',
          'admission_number': p.admissionNumber ?? '-',
          'hostel_name': p.hostelName ?? 'Hostel',
          'room_number': p.roomNumber ?? '-',
          'father_phone': p.emergencyContact ?? '-',
        },
        'request': {
          'request_type': p.requestType,
          'destination': p.destination,
          'reason': p.specialInstructions ?? '',
          'status': p.status,
        },
      };
      _resolveSuggestedAction(_scanResult!);
    }

    // Initial pass identifier from widget properties
    final initialId = widget.initialPassNumber ??
        widget.gatePassToken ??
        widget.gatePass?.passNumber ??
        widget.gatePass?.verificationToken;

    if (initialId != null && initialId.trim().isNotEmpty) {
      _passIdCtrl.text = initialId.trim();
      _activeMode = 2;
      if (widget.gatePass == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _verifyPassIdentifier(initialId.trim());
        });
      }
    } else if (widget.requestId != null && widget.requestId!.isNotEmpty) {
      // If only requestId is provided, lookup in currently selected request or provider
      final state = ref.read(hostelProvider);
      final req = state.selectedLeaveRequest;
      if (req != null && req.passNumber != null && req.passNumber!.isNotEmpty) {
        _passIdCtrl.text = req.passNumber!;
        _activeMode = 2;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _verifyPassIdentifier(req.passNumber!);
        });
      }
    }
  }

  @override
  void dispose() {
    WebQrCameraHelper.stopCamera();
    _laserAnimCtrl.dispose();
    _passIdCtrl.dispose();
    _passIdFocus.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  Future<void> _initLiveCamera() async {
    setState(() {
      _cameraState = CameraFeedState.initializing;
      _cameraErrorMessage = null;
    });

    final state = await WebQrCameraHelper.startCamera(
      viewTypeId: _cameraViewId,
      onQrDetected: (qrData) {
        if (_isProcessing || _scanResult != null) return;
        WebQrCameraHelper.stopCamera();
        _verifyPassIdentifier(qrData);
      },
      onFrameCaptured: (base64Frame) async {
        if (_isProcessing || _scanResult != null) return;
        _isProcessing = true;
        try {
          final notifier = ref.read(hostelProvider.notifier);
          final res = await notifier.scanGatePassImage(base64Frame);
          if (mounted && (res['success'] == true || res['valid'] == true)) {
            WebQrCameraHelper.stopCamera();
            setState(() {
              _isProcessing = false;
              _scanResult = res;
              _resolveSuggestedAction(res);
            });
          }
        } catch (_) {
        } finally {
          _isProcessing = false;
        }
      },
      onError: (err) {
        if (mounted) {
          setState(() {
            _cameraState = CameraFeedState.error;
            _cameraErrorMessage = err;
          });
        }
      },
    );

    if (mounted) {
      setState(() => _cameraState = state);
    }
  }

  Future<void> _captureNativeCameraPhoto() async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(source: ImageSource.camera, maxWidth: 1200);
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        final base64Image = base64Encode(bytes);
        setState(() {
          _isProcessing = true;
          _errorMessage = null;
        });
        final notifier = ref.read(hostelProvider.notifier);
        final res = await notifier.scanGatePassImage(base64Image);
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _scanResult = res;
            _resolveSuggestedAction(res);
            if (res['success'] != true && res['valid'] != true) {
              _errorMessage = res['message'] ?? 'Could not verify gate pass.';
            }
          });
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to capture photo: $e');
    }
  }

  Future<void> _pickAndScanImage() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final bytes = result.files.first.bytes;
        if (bytes != null) {
          final base64Image = base64Encode(bytes);
          final notifier = ref.read(hostelProvider.notifier);
          final res = await notifier.scanGatePassImage(base64Image);

          setState(() {
            _scanResult = res;
            _resolveSuggestedAction(res);
            if (res['success'] != true && res['valid'] != true) {
              _errorMessage = res['message'] ?? 'Could not verify gate pass.';
            }
          });
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to process image: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _verifyPassIdentifier(String passId) async {
    final cleanId = passId.trim();
    if (cleanId.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final notifier = ref.read(hostelProvider.notifier);
    final res = await notifier.verifyGatePass(cleanId);

    setState(() {
      _isProcessing = false;
      _scanResult = res;
      _resolveSuggestedAction(res);
      if (res['success'] != true && res['valid'] != true) {
        _errorMessage = res['message'] ?? 'Invalid pass number or QR code.';
      }
    });
  }

  void _resolveSuggestedAction(Map<String, dynamic> res) {
    final suggested = res['suggested_action'] as String?;
    if (suggested != null && suggested.isNotEmpty) {
      _selectedAction = suggested.toUpperCase() == 'RETURN' ? 'RETURN' : 'EXIT';
      return;
    }
    final req = res['request'] as Map<String, dynamic>?;
    final status = req?['status'] as String? ?? '';
    if (status.toUpperCase() == 'EXITED') {
      _selectedAction = 'RETURN';
    } else {
      _selectedAction = 'EXIT';
    }
  }

  Future<void> _handleSaveAction() async {
    if (_scanResult == null) return;
    final gp = _scanResult!['gate_pass'] as Map<String, dynamic>?;
    final passNumber = gp?['pass_number'] as String? ?? _passIdCtrl.text.trim();
    if (passNumber.isEmpty) return;

    setState(() => _isSavingAction = true);
    final notifier = ref.read(hostelProvider.notifier);
    final ok = await notifier.executeGatePassScanAction(
      passNumber,
      action: _selectedAction,
      gate: _selectedGate,
      remarks: _remarksCtrl.text.trim().isNotEmpty ? _remarksCtrl.text.trim() : null,
    );

    setState(() {
      _isSavingAction = false;
      if (ok) {
        _actionCompleted = true;
      }
    });
  }

  void _resetForNextScan() {
    setState(() {
      _scanResult = null;
      _errorMessage = null;
      _actionCompleted = false;
      _passIdCtrl.clear();
      _remarksCtrl.clear();
      _activeMode = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isNarrow = screenWidth < 680;
    final dialogWidth = isNarrow ? screenWidth * 0.95 : 640.0;

    final hasResult = _scanResult != null &&
        (_scanResult!['success'] == true || _scanResult!['valid'] == true || _scanResult!['gate_pass'] != null);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 8 : 24,
        vertical: 16,
      ),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.92),
        padding: EdgeInsets.all(isNarrow ? 16 : 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Header
              _buildHeader(isDark),
              const SizedBox(height: 16),

              // 2. Either Verified Clearance Card or Scanning Modes
              if (hasResult) ...[
                _buildVerifiedResultCard(isDark),
              ] else ...[
                // Mode Selector Tabs (Upload Image / Live Camera / Barcode Gun)
                _buildModeSelector(isDark),
                const SizedBox(height: 16),

                // Active Mode Body
                if (_activeMode == 0) _buildImageUploadMode(isDark),
                if (_activeMode == 1) _buildCameraViewfinderMode(isDark),
                if (_activeMode == 2) _buildBarcodeManualMode(isDark),

                // Error Banner
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF4444)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Color(0xFF2563EB),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hostel Gate Pass Terminal',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Scan student pass QR to clear Departure (Exit) or Arrival (Return)',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Close Terminal',
        ),
      ],
    );
  }

  Widget _buildModeSelector(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _buildModeTab(0, Icons.upload_file_rounded, 'Upload QR Image', isDark),
          _buildModeTab(1, Icons.videocam_outlined, 'Live Camera', isDark),
          _buildModeTab(2, Icons.keyboard_alt_outlined, 'Scan Gun / Pass ID', isDark),
        ],
      ),
    );
  }

  Widget _buildModeTab(int mode, IconData icon, String label, bool isDark) {
    final isSelected = _activeMode == mode;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _activeMode = mode;
            _errorMessage = null;
          });
          if (mode == 1) {
            _initLiveCamera();
          } else {
            WebQrCameraHelper.stopCamera();
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B)),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // Mode 0: Image Upload & Computer Vision Decoder
  // =========================================================================
  Widget _buildImageUploadMode(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2563EB).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(36),
            ),
            child: const Icon(
              Icons.cloud_upload_outlined,
              size: 36,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Upload Gate Pass QR Image',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Select or drag & drop a hostel gate pass QR image (PNG, JPG, WEBP).\nOur OpenCV computer vision engine will instantly extract and verify the pass.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: _isProcessing ? null : _pickAndScanImage,
                icon: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.file_open_rounded, size: 16, color: Colors.white),
                label: Text(
                  _isProcessing ? 'Analyzing QR...' : 'Browse QR File',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _isProcessing ? null : _captureNativeCameraPhoto,
                icon: const Icon(Icons.camera_alt_outlined, size: 16),
                label: const Text('Take Camera Photo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Mode 1: Live Web Camera Viewfinder
  // =========================================================================
  Widget _buildCameraViewfinderMode(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // HTML5 Camera Feed View
            if (_cameraState == CameraFeedState.streaming)
              const HtmlElementView(viewType: 'hostel-qr-webcam-feed-view')
            else if (_cameraState == CameraFeedState.initializing)
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 12),
                    Text(
                      'Requesting camera access...',
                      style: TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              )
            else if (_cameraState == CameraFeedState.permissionDenied)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.videocam_off_outlined, color: Colors.amber, size: 40),
                      const SizedBox(height: 8),
                      const Text(
                        'Camera Permission Blocked',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Please allow camera permissions in your browser address bar to use live scanning.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _initLiveCamera,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      _cameraErrorMessage ?? 'Could not start camera feed',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: _initLiveCamera,
                      child: const Text('Retry Camera'),
                    ),
                  ],
                ),
              ),

            // Animated Laser Scanning Viewfinder Box
            if (_cameraState == CameraFeedState.streaming)
              AnimatedBuilder(
                animation: _laserAnim,
                builder: (context, child) {
                  return Stack(
                    children: [
                      // Viewfinder border box
                      Center(
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF2563EB), width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      // Animated Laser Line
                      Positioned(
                        top: 40 + (_laserAnim.value * 140),
                        left: (MediaQuery.of(context).size.width - 220) / 2 > 0
                            ? (MediaQuery.of(context).size.width - 220) / 2
                            : 40,
                        right: 40,
                        child: Center(
                          child: Container(
                            width: 210,
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.8),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // Mode 2: Barcode Gun / Manual Pass ID Input
  // =========================================================================
  Widget _buildBarcodeManualMode(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.keyboard_alt_outlined, size: 18, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                'Enter Gate Pass # or Barcode Token',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Compatible with USB barcode guns, Bluetooth scanners, or manual pass numbers (e.g. GP-2026-0033).',
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: TextField(
                    controller: _passIdCtrl,
                    focusNode: _passIdFocus,
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. GP-2026-0033 or token...',
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                      prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 18, color: Color(0xFF2563EB)),
                      suffixIcon: _passIdCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _passIdCtrl.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
                      ),
                    ),
                    onSubmitted: (v) {
                      if (v.trim().isNotEmpty) _verifyPassIdentifier(v.trim());
                    },
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _isProcessing
                    ? null
                    : () {
                        if (_passIdCtrl.text.trim().isNotEmpty) {
                          _verifyPassIdentifier(_passIdCtrl.text.trim());
                        }
                      },
                icon: _isProcessing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 16, color: Colors.white),
                label: const Text('Verify Pass', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Verified Clearance Card with Resident Student 360 & Gate Security Actions
  // =========================================================================
  Widget _buildVerifiedResultCard(bool isDark) {
    final gp = _scanResult!['gate_pass'] as Map<String, dynamic>? ?? {};
    final stu = _scanResult!['student'] as Map<String, dynamic>? ?? {};
    final req = _scanResult!['request'] as Map<String, dynamic>? ?? {};

    final passNumber = gp['pass_number'] as String? ?? 'GP-2026';
    final validity = (_scanResult!['validity'] as String? ?? 'VALID').toUpperCase();
    final message = _scanResult!['message'] as String? ?? 'Verified';

    final studentName = stu['full_name'] as String? ?? 'Resident Student';
    final className = stu['class'] as String? ?? '10 A';
    final rollNumber = stu['roll_number']?.toString() ?? '-';
    final admissionNumber = stu['admission_number'] as String? ?? '-';
    final hostelName = stu['hostel_name'] as String? ?? req['hostel_name'] as String? ?? 'Hostel';
    final roomNumber = stu['room_number'] as String? ?? req['room_number'] as String? ?? '-';
    final parentPhone = stu['father_phone'] as String? ?? stu['parent_phone'] as String? ?? '-';
    final photoUrl = stu['avatar_url'] as String?;

    final requestType = (req['request_type'] as String? ?? 'OUTING').toUpperCase();
    final destination = req['destination'] as String? ?? 'City';
    final reason = req['reason'] as String? ?? '';
    final validFrom = gp['valid_from_formatted'] as String? ?? req['start_at_formatted'] as String? ?? '-';
    final validUntil = gp['valid_until_formatted'] as String? ?? req['expected_return_at_formatted'] as String? ?? '-';
    final usedExitAt = gp['used_exit_at_formatted'] as String?;
    final usedReturnAt = gp['used_return_at_formatted'] as String?;

    Color bannerColor;
    Color bannerTextColor;
    IconData bannerIcon;
    switch (validity) {
      case 'VALID':
        bannerColor = isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7);
        bannerTextColor = isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
        bannerIcon = Icons.verified_rounded;
        break;
      case 'USED':
        bannerColor = isDark ? const Color(0xFF1E3A8A) : const Color(0xFFDBEAFE);
        bannerTextColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
        bannerIcon = Icons.done_all_rounded;
        break;
      case 'EXPIRED':
        bannerColor = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
        bannerTextColor = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
        bannerIcon = Icons.timer_off_rounded;
        break;
      default:
        bannerColor = isDark ? const Color(0xFF7F1D1D) : const Color(0xFFFEE2E2);
        bannerTextColor = isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
        bannerIcon = Icons.warning_amber_rounded;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Status Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: bannerColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: bannerTextColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(bannerIcon, color: bannerTextColor, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '$passNumber • $validity',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: bannerTextColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: requestType == 'LEAVE' ? const Color(0xFF2563EB) : const Color(0xFF8B5CF6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            requestType,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: TextStyle(fontSize: 11.5, color: bannerTextColor, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. Student & Pass Details Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Student Profile Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: const Color(0xFF2563EB),
                    backgroundImage: photoUrl != null && photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null || photoUrl.isEmpty
                        ? Text(
                            studentName.isNotEmpty ? studentName[0].toUpperCase() : 'S',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Class $className • Roll $rollNumber • Adm: $admissionNumber',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.apartment_rounded, size: 14, color: Color(0xFF2563EB)),
                            const SizedBox(width: 4),
                            Text(
                              '$hostelName • Room $roomNumber',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              Divider(height: 1, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              const SizedBox(height: 10),

              // Movement Information Grid
              _buildInfoRow('Destination', destination, isDark),
              if (reason.isNotEmpty) _buildInfoRow('Reason / Purpose', reason, isDark),
              _buildInfoRow('Departure Valid', validFrom, isDark),
              _buildInfoRow('Expected Return', validUntil, isDark),
              if (usedExitAt != null) _buildInfoRow('Actual Departure', usedExitAt, isDark, highlight: true),
              if (usedReturnAt != null) _buildInfoRow('Actual Return', usedReturnAt, isDark, highlight: true),
              _buildInfoRow('Emergency Phone', parentPhone, isDark),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  final gpData = GatePassData(
                    id: gp['id']?.toString() ?? '',
                    passNumber: passNumber,
                    verificationToken: gp['verification_token']?.toString() ?? passNumber,
                    qrReference: gp['qr_reference']?.toString() ?? '',
                    qrBase64: gp['qr_base64']?.toString(),
                    status: validity,
                    studentName: studentName,
                    className: className,
                    rollNumber: rollNumber,
                    admissionNumber: admissionNumber,
                    hostelName: hostelName,
                    roomNumber: roomNumber,
                    requestType: requestType,
                    destination: destination,
                    validFromFormatted: validFrom,
                    validUntilFormatted: validUntil,
                    emergencyContact: parentPhone,
                  );
                  showDialog(
                    context: context,
                    builder: (ctx) => HostelGatePassPrintDialog(gatePass: gpData),
                  );
                },
                icon: const Icon(Icons.print_rounded, size: 15),
                label: const Text('Print Official Pass Badge', style: TextStyle(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3. Security Clearance Execution Box
        if (_actionCompleted) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF064E3B).withValues(alpha: 0.4) : const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF16A34A)),
            ),
            child: Column(
              children: [
                const Icon(Icons.check_circle_rounded, size: 40, color: Color(0xFF16A34A)),
                const SizedBox(height: 8),
                Text(
                  _selectedAction == 'EXIT' ? 'Departure Successfully Logged!' : 'Arrival Successfully Logged!',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gate clearance recorded at $_selectedGate in official movement log.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A)),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: _resetForNextScan,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: Colors.white),
                  label: const Text('Scan Another Pass', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Record Gate Clearance',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),

                // Movement Clearance Toggle: Departure (Gate Out) vs Arrival (Gate In)
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedAction = 'EXIT'),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedAction == 'EXIT'
                                ? const Color(0xFFD97706)
                                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedAction == 'EXIT' ? const Color(0xFFD97706) : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.logout_rounded,
                                size: 16,
                                color: _selectedAction == 'EXIT' ? Colors.white : const Color(0xFFD97706),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Record Departure (Exit)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedAction == 'EXIT'
                                        ? Colors.white
                                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _selectedAction = 'RETURN'),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _selectedAction == 'RETURN'
                                ? const Color(0xFF16A34A)
                                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedAction == 'RETURN' ? const Color(0xFF16A34A) : Colors.transparent,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.login_rounded,
                                size: 16,
                                color: _selectedAction == 'RETURN' ? Colors.white : const Color(0xFF16A34A),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Record Arrival (Return)',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: _selectedAction == 'RETURN'
                                        ? Colors.white
                                        : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Gate Selector & Security Remarks
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isSmall = constraints.maxWidth < 450;
                    if (isSmall) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Gate Checkpoint', style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          const SizedBox(height: 4),
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
                                value: _selectedGate,
                                isExpanded: true,
                                icon: const Icon(Icons.arrow_drop_down, size: 20),
                                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                items: _gatesList.map((g) {
                                  return DropdownMenuItem(
                                    value: g,
                                    child: Text(g, style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) setState(() => _selectedGate = v);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text('Security Remarks (Optional)', style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 38,
                            child: TextField(
                              controller: _remarksCtrl,
                              style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                              decoration: InputDecoration(
                                hintText: 'e.g. Identity verified by warden...',
                                hintStyle: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Gate Dropdown
                        Expanded(
                          flex: 4,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Gate Checkpoint', style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                              const SizedBox(height: 4),
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
                                    value: _selectedGate,
                                    isExpanded: true,
                                    icon: const Icon(Icons.arrow_drop_down, size: 20),
                                    dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                    items: _gatesList.map((g) {
                                      return DropdownMenuItem(
                                        value: g,
                                        child: Text(g, style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                                      );
                                    }).toList(),
                                    onChanged: (v) {
                                      if (v != null) setState(() => _selectedGate = v);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Remarks Input
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Security Remarks (Optional)', style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: 38,
                                child: TextField(
                                  controller: _remarksCtrl,
                                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Identity verified by warden...',
                                    hintStyle: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Action Buttons Row (Wrap to avoid overflow on any screen width)
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _resetForNextScan,
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Scan Another Pass'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isSavingAction ? null : _handleSaveAction,
                      icon: _isSavingAction
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(
                              _selectedAction == 'EXIT' ? Icons.logout_rounded : Icons.login_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                      label: Text(
                        _isSavingAction
                            ? 'Recording Clearance...'
                            : (_selectedAction == 'EXIT' ? 'Confirm Departure (Gate Out)' : 'Confirm Arrival (Gate In)'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedAction == 'EXIT' ? const Color(0xFFD97706) : const Color(0xFF16A34A),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
                color: highlight
                    ? const Color(0xFF2563EB)
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
