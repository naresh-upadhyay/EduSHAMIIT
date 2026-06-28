import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/download_helper_stub.dart'
    if (dart.library.js) '../utils/download_helper_web.dart'
    if (dart.library.io) '../utils/download_helper_mobile.dart';

class ImagePreviewDialog extends StatelessWidget {
  final String imageUrl;
  final String? title;

  const ImagePreviewDialog({
    super.key,
    required this.imageUrl,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    // Dynamically replace kong:8000 with 127.0.0.1:8000 for local development resolution
    final String resolvedUrl = imageUrl.replaceAll('http://kong:8000', 'http://127.0.0.1:8000');

    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: resolvedUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(Icons.error, color: Colors.white, size: 50),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(context),
                ),
                if (title != null)
                  Expanded(
                    child: Text(
                      title!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.white, size: 30),
                  onPressed: () async {
                    try {
                      final filename = resolvedUrl.split('/').last.split('?').first;
                      await getDownloadHelper().downloadFile(resolvedUrl, filename);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Download started...')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Download failed: $e')),
                        );
                      }
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void show(BuildContext context, String imageUrl, {String? title}) {
    showDialog(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.black,
      builder: (context) => ImagePreviewDialog(imageUrl: imageUrl, title: title),
    );
  }
}
