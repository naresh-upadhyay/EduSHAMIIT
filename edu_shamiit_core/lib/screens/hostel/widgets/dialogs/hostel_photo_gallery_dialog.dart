import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/hostel_provider.dart';

class HostelPhotoGalleryDialog extends ConsumerStatefulWidget {
  final String roomId;
  final String roomNumber;
  final List<String> initialPhotos;

  const HostelPhotoGalleryDialog({
    super.key,
    required this.roomId,
    required this.roomNumber,
    required this.initialPhotos,
  });

  @override
  ConsumerState<HostelPhotoGalleryDialog> createState() => _HostelPhotoGalleryDialogState();
}

class _HostelPhotoGalleryDialogState extends ConsumerState<HostelPhotoGalleryDialog> {
  late List<String> _photos;
  int _selectedIndex = 0;
  bool _isUploading = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _photos = List<String>.from(widget.initialPhotos);
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ref.read(hostelProvider.notifier).showError('Could not read file data. Please select another image.');
        }
        return;
      }

      setState(() => _isUploading = true);
      final notifier = ref.read(hostelProvider.notifier);

      final newUrl = await notifier.service.uploadRoomPhoto(
        bytes: bytes,
        filename: file.name,
        roomId: widget.roomId,
      );

      if (mounted) {
        setState(() {
          _photos.add(newUrl);
          _selectedIndex = _photos.length - 1;
        });
        notifier.showSuccess('Photo uploaded successfully');
        notifier.fetchRoomDetail(widget.roomId);
        notifier.fetchRooms();
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll(RegExp(r'^(ApiException:|Exception:|\s*Api)+', caseSensitive: false), '').trim();
        ref.read(hostelProvider.notifier).showError(msg.isNotEmpty ? msg : 'Failed to upload photo');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _deleteCurrentPhoto() async {
    if (_photos.isEmpty || _selectedIndex >= _photos.length) return;
    final photoUrl = _photos[_selectedIndex];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this room photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    final notifier = ref.read(hostelProvider.notifier);

    try {
      final ok = await notifier.service.deleteRoomPhoto(
        roomId: widget.roomId,
        photoUrl: photoUrl,
      );

      if (mounted) {
        if (ok) {
          setState(() {
            _photos.removeAt(_selectedIndex);
            if (_selectedIndex >= _photos.length && _photos.isNotEmpty) {
              _selectedIndex = _photos.length - 1;
            } else if (_photos.isEmpty) {
              _selectedIndex = 0;
            }
          });
          notifier.showSuccess('Photo removed');
          notifier.fetchRoomDetail(widget.roomId);
          notifier.fetchRooms();
        } else {
          notifier.showError('Could not delete photo');
        }
      }
    } catch (e) {
      if (mounted) {
        notifier.showError('Error deleting photo: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.photo_library_outlined, size: 20, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Text(
                        'Room ${widget.roomNumber} Photos (${_photos.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: (_isUploading || _isDeleting) ? null : _pickAndUploadPhoto,
                        icon: _isUploading
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.add_photo_alternate_outlined, size: 16),
                        label: Text(_isUploading ? 'Uploading...' : 'Upload Photo'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Main Photo Viewer
              Expanded(
                child: _photos.isEmpty
                    ? Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 54,
                                color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No photos uploaded for Room ${widget.roomNumber}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Upload JPEG, PNG or WebP images to display room facilities and conditions.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: (_isUploading || _isDeleting) ? null : _pickAndUploadPhoto,
                                icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                                label: const Text('Upload First Photo'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              _photos[_selectedIndex],
                              fit: BoxFit.contain,
                              loadingBuilder: (ctx, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                );
                              },
                              errorBuilder: (ctx, err, stack) => const Center(
                                child: Text('Failed to load image', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                          ),
                          // Prev Button
                          if (_photos.length > 1 && _selectedIndex > 0)
                            Positioned(
                              left: 12,
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  icon: const Icon(Icons.chevron_left, color: Colors.white),
                                  onPressed: () => setState(() => _selectedIndex--),
                                ),
                              ),
                            ),
                          // Next Button
                          if (_photos.length > 1 && _selectedIndex < _photos.length - 1)
                            Positioned(
                              right: 12,
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  icon: const Icon(Icons.chevron_right, color: Colors.white),
                                  onPressed: () => setState(() => _selectedIndex++),
                                ),
                              ),
                            ),
                          // Top bar on image (counter + delete)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '${_selectedIndex + 1} / ${_photos.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: const Color(0xFFEF4444),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    icon: _isDeleting
                                        ? const SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.delete_outline, size: 16, color: Colors.white),
                                    onPressed: (_isUploading || _isDeleting) ? null : _deleteCurrentPhoto,
                                    tooltip: 'Delete Photo',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),

              // Thumbnail Strip (if multiple photos)
              if (_photos.length > 1) ...[
                const SizedBox(height: 12),
                SizedBox(
                  height: 64,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photos.length,
                    separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final isSelected = index == _selectedIndex;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedIndex = index),
                        child: Container(
                          width: 80,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.network(
                            _photos[index],
                            fit: BoxFit.cover,
                            errorBuilder: (ctx, err, stack) => Container(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              child: const Icon(Icons.broken_image, size: 16),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
