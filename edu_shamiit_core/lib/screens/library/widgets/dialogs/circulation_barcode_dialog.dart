import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/circulation_provider.dart';
import '../../models/circulation_models.dart';
import '../../../visitors/widgets/dialogs/camera/web_qr_camera_helper.dart';

import 'quick_issue_dialog.dart';
import 'quick_return_dialog.dart';

class CirculationBarcodeDialog extends ConsumerStatefulWidget {
  const CirculationBarcodeDialog({super.key});

  @override
  ConsumerState<CirculationBarcodeDialog> createState() =>
      _CirculationBarcodeDialogState();
}

class _CirculationBarcodeDialogState
    extends ConsumerState<CirculationBarcodeDialog>
    with SingleTickerProviderStateMixin {
  final TextEditingController _codeCtrl = TextEditingController();
  ScanResultModel? _result;
  bool _isScanning = false;
  String? _error;

  // 0: Type / USB Scanner, 1: Device Camera
  int _activeMode = 0;
  CameraFeedState _cameraState = CameraFeedState.uninitialized;
  String? _cameraErrorMessage;
  final String _cameraViewId = 'library-barcode-webcam-view';

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
  }

  @override
  void dispose() {
    WebQrCameraHelper.stopCamera();
    _laserAnimCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _initLiveCamera() async {
    setState(() {
      _cameraState = CameraFeedState.initializing;
      _cameraErrorMessage = null;
    });

    final state = await WebQrCameraHelper.startCamera(
      viewTypeId: _cameraViewId,
      onQrDetected: (code) {
        if (!mounted || _isScanning || _result != null) return;
        WebQrCameraHelper.stopCamera();
        _codeCtrl.text = code;
        setState(() {
          _activeMode = 0;
          _cameraState = CameraFeedState.uninitialized;
        });
        _handleScan(code);
      },
      onFrameCaptured: (_) {
        // Barcode detection is handled in-browser via BarcodeDetector
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

  void _switchMode(int mode) {
    if (_activeMode == mode) return;
    setState(() {
      _activeMode = mode;
      _error = null;
    });
    if (mode == 1) {
      if (WebQrCameraHelper.isSupported) {
        _initLiveCamera();
      } else {
        setState(() {
          _cameraState = CameraFeedState.error;
          _cameraErrorMessage =
              'Live camera barcode scanning is only supported in web browsers (Chrome / Edge).';
        });
      }
    } else {
      WebQrCameraHelper.stopCamera();
      setState(() => _cameraState = CameraFeedState.uninitialized);
    }
  }

  Future<void> _handleScan(String code) async {
    if (code.trim().isEmpty) return;
    setState(() {
      _isScanning = true;
      _error = null;
    });

    try {
      final res =
          await ref.read(circulationProvider.notifier).scanLookup(code.trim());
      if (!mounted) return;
      setState(() {
        _result = res;
        _isScanning = false;
        if (res == null) _error = 'No matching book, copy, or member found.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isScanning = false;
        _error = e.toString().replaceAll("Exception:", "").trim();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 540,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF6366F1), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Scan Barcode / ISBN / Card',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Mode Selector (Type / USB Scanner vs Device Camera)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  _buildModeTab(0, Icons.keyboard_rounded, 'Type / USB Scanner', isDark),
                  _buildModeTab(1, Icons.videocam_rounded, 'Device Camera', isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_activeMode == 1) ...[
              _buildCameraViewfinder(isDark),
              const SizedBox(height: 12),
            ] else ...[
              // Barcode Input
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _codeCtrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Scan or type barcode, ISBN, or Member Code...',
                        prefixIcon: const Icon(Icons.qr_code, size: 18),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onSubmitted: (val) => _handleScan(val),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    onPressed: _isScanning ? null : () => _handleScan(_codeCtrl.text),
                    child: _isScanning
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Scan'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // Result Preview
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12))),
                  ],
                ),
              )
            else if (_result != null) ...[
              _buildResultCard(_result!, isDark),
            ] else if (_activeMode == 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Point your USB/Bluetooth barcode scanner here, type the identifier, or switch to Device Camera.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 12.5),
                  ),
                ),
              ),

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_result != null || _error != null) ...[
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _result = null;
                        _error = null;
                        _codeCtrl.clear();
                      });
                      _switchMode(1);
                    },
                    icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
                    label: const Text('Scan Another with Camera'),
                  ),
                  const SizedBox(width: 8),
                ],
                OutlinedButton(
                  onPressed: () {
                    WebQrCameraHelper.stopCamera();
                    Navigator.of(context).pop();
                  },
                  child: const Text('Close'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(ScanResultModel scan, bool isDark) {
    final raw = scan.raw;
    final entityType = scan.entityType;

    if (entityType == 'BOOK_COPY') {
      final copy = raw['copy'] is Map ? raw['copy'] as Map<String, dynamic> : <String, dynamic>{};
      final book = raw['book'] is Map ? raw['book'] as Map<String, dynamic> : <String, dynamic>{};
      final activeLoan = raw['active_loan'] is Map ? raw['active_loan'] as Map<String, dynamic> : null;

      final isAvailable = copy['status'] == 'AVAILABLE';

      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Color(0xFF6366F1), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book['title']?.toString() ?? 'Book Title', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      Text('By ${book['author'] ?? 'Author'} • ISBN: ${book['isbn'] ?? 'N/A'}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                      const SizedBox(height: 4),
                      Text('Barcode: ${copy['barcode']} • Status: ${copy['status']}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (isAvailable)
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Issue This Book Copy'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                  showDialog(
                    context: context,
                    builder: (_) => QuickIssueDialog(initialBookQuery: book['title']?.toString()),
                  );
                },
              )
            else if (activeLoan != null)
              ElevatedButton.icon(
                icon: const Icon(Icons.keyboard_return_rounded, size: 16),
                label: const Text('Return This Loan Now'),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.of(context).pop();
                  showDialog(
                    context: context,
                    builder: (_) => QuickReturnDialog(initialBarcodeQuery: copy['barcode']?.toString()),
                  );
                },
              ),
          ],
        ),
      );
    } else if (entityType == 'MEMBER') {
      final member = raw['member'] is Map ? raw['member'] as Map<String, dynamic> : <String, dynamic>{};
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xFF6366F1),
                  child: Text(
                    (member['name']?.toString().isNotEmpty ?? false) ? member['name'][0] : 'M',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(member['name']?.toString() ?? 'Member Name', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      Text('${member['member_code']} • ${member['role']} • Limit: ${member['borrowing_limit']}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.menu_book_rounded, size: 16),
              label: const Text('Issue Books to this Member'),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
              onPressed: () {
                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  builder: (_) => QuickIssueDialog(initialMemberQuery: member['member_code']?.toString()),
                );
              },
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildModeTab(int mode, IconData icon, String label, bool isDark) {
    final isSelected = _activeMode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => _switchMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6366F1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? Colors.white
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraViewfinder(bool isDark) {
    if (_cameraState == CameraFeedState.initializing) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF6366F1)),
              SizedBox(height: 12),
              Text(
                'Requesting camera access...',
                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                'Please click Allow if prompted by your browser.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    if (_cameraState == CameraFeedState.permissionDenied ||
        _cameraState == CameraFeedState.error) {
      final isDenied = _cameraState == CameraFeedState.permissionDenied;
      return Container(
        height: 240,
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
                size: 40,
                color: const Color(0xFFEF4444),
              ),
              const SizedBox(height: 8),
              Text(
                isDenied ? 'Camera Access Blocked' : 'Camera Unavailable',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _cameraErrorMessage ??
                    'Please allow camera access in your browser or switch to Type / USB Scanner.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _initLiveCamera,
                    icon: const Icon(Icons.refresh_rounded, size: 15, color: Colors.white),
                    label: const Text('Retry Camera', style: TextStyle(color: Colors.white, fontSize: 12)),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1)),
                  ),
                  OutlinedButton(
                    onPressed: () => _switchMode(0),
                    child: const Text('Type Manually', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      height: 240,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: WebQrCameraHelper.buildCameraView(_cameraViewId),
          ),
          // Scanning Reticle
          Container(
            width: 240,
            height: 140,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF6366F1), width: 2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: AnimatedBuilder(
              animation: _laserAnim,
              builder: (context, _) {
                return Align(
                  alignment: Alignment(0, (_laserAnim.value * 2) - 1),
                  child: Container(
                    height: 2,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.7),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Positioned(
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Point camera at Book Barcode, ISBN, or Member Card',
                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
