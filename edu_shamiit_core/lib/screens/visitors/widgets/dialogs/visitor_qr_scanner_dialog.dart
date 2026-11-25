import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/visitor_models.dart';
import '../../providers/visitors_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'camera/web_qr_camera_helper.dart';

class VisitorQrScannerDialog extends ConsumerStatefulWidget {
  final String? initialPassNumber;

  const VisitorQrScannerDialog({super.key, this.initialPassNumber});

  @override
  ConsumerState<VisitorQrScannerDialog> createState() =>
      _VisitorQrScannerDialogState();
}

class _VisitorQrScannerDialogState extends ConsumerState<VisitorQrScannerDialog>
    with SingleTickerProviderStateMixin {
  int _activeMode = 0; // 0: Upload Image, 1: Live Camera Viewfinder, 2: Barcode / ID Input

  // Manual / Barcode input
  final TextEditingController _passIdCtrl = TextEditingController();
  final FocusNode _passIdFocus = FocusNode();

  // Verification State
  bool _isProcessing = false;
  GatePassScanResult? _scanResult;
  String? _errorMessage;

  // Selected Action for Gate Security
  String _selectedAction = 'CHECK_IN'; // 'CHECK_IN' or 'CHECK_OUT'
  String _checkpointLocation = 'Main Gate';
  final TextEditingController _remarksCtrl = TextEditingController();
  bool _isSavingAction = false;
  bool _actionCompleted = false;

  // Camera Feed State
  CameraFeedState _cameraState = CameraFeedState.uninitialized;
  String? _cameraErrorMessage;
  final String _cameraViewId = 'qr-webcam-feed-view';

  // Scanner animation
  late AnimationController _laserAnimCtrl;
  late Animation<double> _laserAnim;

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

    if (widget.initialPassNumber != null &&
        widget.initialPassNumber!.isNotEmpty) {
      _passIdCtrl.text = widget.initialPassNumber!;
      _activeMode = 2;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _verifyPassId(widget.initialPassNumber!);
      });
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
        _verifyPassId(qrData);
      },
      onFrameCaptured: (base64Frame) async {
        if (_isProcessing || _scanResult != null) return;
        _isProcessing = true;
        try {
          final notifier = ref.read(visitorsProvider.notifier);
          final scanRes = await notifier.scanGatePassImage(base64Frame);
          if (mounted && scanRes.isValid) {
            WebQrCameraHelper.stopCamera();
            setState(() {
              _isProcessing = false;
              _scanResult = scanRes;
              if (scanRes.suggestedAction != null) {
                _selectedAction = scanRes.suggestedAction!;
              }
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
        final notifier = ref.read(visitorsProvider.notifier);
        final scanRes = await notifier.scanGatePassImage(base64Image);
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _scanResult = scanRes;
            if (scanRes.suggestedAction != null) {
              _selectedAction = scanRes.suggestedAction!;
            }
            if (!scanRes.isValid) {
              _errorMessage = scanRes.message;
            }
          });
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'Failed to take camera photo: $e');
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
          final notifier = ref.read(visitorsProvider.notifier);
          final scanRes = await notifier.scanGatePassImage(base64Image);

          setState(() {
            _scanResult = scanRes;
            if (scanRes.isValid && scanRes.suggestedAction != null) {
              _selectedAction = scanRes.suggestedAction!;
            }
            if (!scanRes.isValid) {
              _errorMessage = scanRes.message;
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

  Future<void> _verifyPassId(String passId) async {
    final cleanId = passId.trim();
    if (cleanId.isEmpty) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    final notifier = ref.read(visitorsProvider.notifier);
    final res = await notifier.verifyGatePass(cleanId);

    setState(() {
      _isProcessing = false;
      _scanResult = res;
      if (res.isValid && res.suggestedAction != null) {
        _selectedAction = res.suggestedAction!;
      }
      if (!res.isValid) {
        _errorMessage = res.message;
      }
    });
  }

  Future<void> _handleSaveAction() async {
    if (_scanResult == null || !_scanResult!.isValid) return;
    final passNumber = _scanResult!.data?['pass_number'] ?? _passIdCtrl.text.trim();
    if (passNumber.isEmpty) return;

    setState(() => _isSavingAction = true);
    final notifier = ref.read(visitorsProvider.notifier);
    final success = await notifier.executeScanAction(
      passNumber,
      action: _selectedAction,
      location: _checkpointLocation,
      remarks: _remarksCtrl.text.trim().isNotEmpty
          ? _remarksCtrl.text.trim()
          : null,
    );

    setState(() {
      _isSavingAction = false;
      if (success) {
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isNarrow = screenWidth < 680;
    final dialogWidth = isNarrow ? screenWidth * 0.95 : 620.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 8 : 24,
        vertical: 16,
      ),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.90),
        padding: EdgeInsets.all(isNarrow ? 16 : 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(isDark),
              const SizedBox(height: 16),

              // If scan result verified, show the Security Action Card
              if (_scanResult != null && _scanResult!.isValid) ...[
                _buildVerifiedResultCard(isDark),
              ] else ...[
                // Mode Selector Tabs (Image Upload / Camera / Barcode Gun)
                _buildModeSelector(isDark),
                const SizedBox(height: 16),

                // Active Mode View
                if (_activeMode == 0) _buildImageUploadMode(isDark),
                if (_activeMode == 1) _buildCameraViewfinderMode(isDark),
                if (_activeMode == 2) _buildBarcodeManualMode(isDark),

                // Error message banner
                if (_errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF4444)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded,
                            color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFFDC2626)),
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
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: Color(0xFF059669),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gate Security QR Scanner',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Scan QR code to authorize visitor Check-In or Check-Out',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
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
          icon: const Icon(Icons.close_rounded,
              size: 20, color: Color(0xFF64748B)),
          onPressed: () => Navigator.of(context).pop(),
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
          style: BorderStyle.solid,
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
            'Select or drag & drop a gate pass QR image (PNG, JPG, WEBP).\nOur computer vision engine will instantly extract and decode the pass.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isProcessing ? null : _pickAndScanImage,
            icon: _isProcessing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.photo_library_outlined,
                    size: 18, color: Colors.white),
            label: Text(
              _isProcessing ? 'Analyzing QR with OpenCV...' : 'Choose Pass Image File',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Mode 1: Live Camera Viewfinder Simulation
  // =========================================================================
  Widget _buildCameraViewfinderMode(bool isDark) {
    if (_cameraState == CameraFeedState.initializing) {
      return Container(
        height: 250,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF38BDF8)),
              SizedBox(height: 14),
              Text(
                'Requesting camera access...',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text(
                'Please click \'Allow\' if prompted by your browser.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    if (_cameraState == CameraFeedState.permissionDenied || _cameraState == CameraFeedState.error) {
      final isDenied = _cameraState == CameraFeedState.permissionDenied;
      return Container(
        height: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDenied ? Icons.videocam_off_rounded : Icons.error_outline_rounded,
                size: 44,
                color: const Color(0xFFEF4444),
              ),
              const SizedBox(height: 10),
              Text(
                isDenied ? 'Camera Access Blocked' : 'Camera Error',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _cameraErrorMessage ??
                    'Please enable camera permissions in your browser or switch to \'Upload QR Image\'.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _initLiveCamera,
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                    label: const Text('Try Camera Again', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _activeMode = 0),
                    icon: const Icon(Icons.upload_file_rounded, size: 16),
                    label: const Text('Upload QR Image'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Live Video Feed from Camera
          Positioned.fill(
            child: WebQrCameraHelper.isSupported
                ? WebQrCameraHelper.buildCameraView(_cameraViewId)
                : Center(
                    child: ElevatedButton.icon(
                      onPressed: _captureNativeCameraPhoto,
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Capture with Device Camera'),
                    ),
                  ),
          ),

          // Viewfinder reticle frame
          Container(
            width: 170,
            height: 170,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF38BDF8), width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),

          // Animated Scanning Laser
          AnimatedBuilder(
            animation: _laserAnim,
            builder: (context, child) {
              return Positioned(
                top: 40 + (_laserAnim.value * 170),
                child: Container(
                  width: 170,
                  height: 3,
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
              );
            },
          ),

          // Live Camera Status Banner
          Positioned(
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.75),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'Live Camera Active • Point at Gate Pass QR Code',
                    style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Mode 2: Hardware Barcode Scanner / Manual Pass ID
  // =========================================================================
  Widget _buildBarcodeManualMode(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.barcode_reader,
                  size: 20, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                'Hardware Barcode Scanner / Manual ID',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Scan using USB/Bluetooth barcode gun or enter the Pass ID (e.g. GP-2026-0298):',
            style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _passIdCtrl,
                  focusNode: _passIdFocus,
                  onSubmitted: _verifyPassId,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5),
                  decoration: InputDecoration(
                    hintText: 'Enter or scan Pass ID (e.g. GP-2026-0298)',
                    prefixIcon:
                        const Icon(Icons.tag_rounded, size: 18, color: Color(0xFF64748B)),
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: _isProcessing
                    ? null
                    : () => _verifyPassId(_passIdCtrl.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Verify Pass',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // Verified Gate Pass Result & Action Execution Card
  // =========================================================================
  Widget _buildVerifiedResultCard(bool isDark) {
    final data = _scanResult!.data ?? {};
    final passNumber = data['pass_number']?.toString() ?? 'GP-2026';
    final visitorName = data['visitor_name']?.toString() ?? 'Visitor';
    final visitorType = data['visitor_type']?.toString() ?? 'Guest';
    final phone = data['phone']?.toString() ?? '';
    final destination = data['destination']?.toString() ?? 'Main Gate';
    final hostName = data['host_name']?.toString() ?? 'Administration';
    final visitStatus = data['visit_status']?.toString() ?? 'Pending';
    final photoUrl = data['photo_url']?.toString();
    final isBlocked = _scanResult!.isBlacklisted;

    if (_actionCompleted) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF10B981)),
        ),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: Color(0xFF10B981),
              child: Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 12),
            const Text(
              'Gate Entry Successfully Recorded!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF065F46),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Visitor $visitorName marked ${_selectedAction == 'CHECK_IN' ? 'Checked In' : 'Checked Out'} at $_checkpointLocation.\nEntry is now live on the All Visitors Grid.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF047857)),
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _resetForNextScan,
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                  label: const Text('Scan Another Pass'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981)),
                  child: const Text('Done & View Grid',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isBlocked ? const Color(0xFFEF4444) : const Color(0xFF10B981),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Verification Badge Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isBlocked
                  ? const Color(0xFFFEE2E2)
                  : const Color(0xFFDCFCE7),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  isBlocked
                      ? Icons.warning_amber_rounded
                      : Icons.verified_user_rounded,
                  color: isBlocked
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF15803D),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isBlocked
                        ? 'SECURITY ALERT: RESTRICTED VISITOR'
                        : 'GATE PASS VERIFIED • AUTHORIZED ACCESS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isBlocked
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF15803D),
                    ),
                  ),
                ),
                Text(
                  passNumber,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isBlocked
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF15803D),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Visitor Summary Row
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    const Color(0xFF2563EB).withValues(alpha: 0.15),
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: photoUrl == null || photoUrl.isEmpty
                    ? Text(
                        visitorName.isNotEmpty ? visitorName[0] : 'V',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2563EB)),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visitorName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Type: $visitorType • Phone: $phone',
                      style: const TextStyle(
                          fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                    Text(
                      'Destination: $destination • Host: $hostName',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: visitStatus == 'Inside'
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  visitStatus == 'Inside' ? 'Inside Campus' : 'Scheduled',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: visitStatus == 'Inside'
                        ? const Color(0xFF15803D)
                        : const Color(0xFF2563EB),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          // Security Action Selector (Check In vs Check Out)
          Text(
            'Security Gate Action *',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildActionOption(
                  action: 'CHECK_IN',
                  title: 'Mark Check-In (Entry)',
                  subtitle: 'Record campus entrance',
                  icon: Icons.login_rounded,
                  color: const Color(0xFF16A34A),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionOption(
                  action: 'CHECK_OUT',
                  title: 'Mark Check-Out (Exit)',
                  subtitle: 'Close pass & record exit',
                  icon: Icons.logout_rounded,
                  color: const Color(0xFFDC2626),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Location and Security Remarks
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gate / Checkpoint *',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF475569))),
                    const SizedBox(height: 4),
                    AppSearchableDropdownFormField<String>.fromMenuItems(
                      initialValue: _checkpointLocation,
                      isDense: true,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                      items: [
                        'Main Gate',
                        'Library Gate',
                        'Hostel Gate',
                        'Reception Desk',
                        'Admin Office Gate'
                      ]
                          .map((loc) => DropdownMenuItem(
                              value: loc, child: Text(loc)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _checkpointLocation = val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Security Remarks (Optional)',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF475569))),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _remarksCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Identity verified, badge issued',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Save & Confirm Button
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              TextButton(
                onPressed: _resetForNextScan,
                child: const Text('Cancel & Scan Another'),
              ),
              ElevatedButton.icon(
                onPressed: _isSavingAction ? null : _handleSaveAction,
                icon: _isSavingAction
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Icon(
                        _selectedAction == 'CHECK_IN'
                            ? Icons.check_circle_outline
                            : Icons.exit_to_app_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                label: Text(
                  _isSavingAction
                    ? 'Saving Gate Entry...'
                    : 'Confirm & Save ${_selectedAction == 'CHECK_IN' ? 'Check-In' : 'Check-Out'}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedAction == 'CHECK_IN'
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionOption({
    required String action,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    final isSelected = _selectedAction == action;
    return InkWell(
      onTap: () => setState(() => _selectedAction = action),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.2 : 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFCBD5E1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? color : const Color(0xFF94A3B8),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      color: isSelected
                          ? color
                          : (isDark ? Colors.white : const Color(0xFF0F172A)),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
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
