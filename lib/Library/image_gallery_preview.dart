import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';

class ImageGalleryPreview extends StatefulWidget {
  final List<Map<String, dynamic>> imageDataList;
  final int initialIndex;

  const ImageGalleryPreview({
    super.key,
    required this.imageDataList,
    required this.initialIndex,
  });

  @override
  State<ImageGalleryPreview> createState() => _ImageGalleryPreviewState();
}

class _ImageGalleryPreviewState extends State<ImageGalleryPreview> {
  final SupabaseClient supabase = Supabase.instance.client;
  late PageController _pageController;
  late int currentIndex;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: currentIndex);
  }

  Future<int> fetchImageSizeFromUrl(String url) async {
    try {
      final response = await Dio().head(url);
      final contentLength = response.headers.value('content-length');
      return int.tryParse(contentLength ?? '') ?? 0;
    } catch (e) {
      print("Error fetching size: $e");
      return 0;
    }
  }

  String readableSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
    } else if (bytes >= 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    }
    return "$bytes B";
  }

  void _showImageInfoDialog(Map<String, dynamic> image) async {
    final filename = image['filename'] ?? 'Unknown';
    final uploadedAtRaw = image['uploaded_at'];
    final uploadedAt = uploadedAtRaw != null
        ? DateFormat("MMM dd, yyyy – HH:mm")
            .format(DateTime.parse(uploadedAtRaw))
        : 'Unknown';
    final sizeBytes = await fetchImageSizeFromUrl(image['url']);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Image Info"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📛 Filename: $filename"),
            const SizedBox(height: 4),
            Text("🗓 Uploaded At: $uploadedAt"),
            const SizedBox(height: 4),
            Text("📦 Size: ${readableSize(sizeBytes)}"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadImage(String url) async {
    try {
      if (!await launchUrlString(url)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Download failed: $e')),
      );
    }
  }

  Future<void> _deleteImage(Map<String, dynamic> image) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Image"),
        content: const Text("Are you sure you want to delete this image?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red)))
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final filename = image['filename'];
      await supabase.storage.from('media').remove(['images/$filename']);
      await supabase.from('image_files').delete().eq('filename', filename);

      setState(() {
        widget.imageDataList.removeAt(currentIndex);
        if (widget.imageDataList.isEmpty) {
          Navigator.pop(context);
        } else {
          currentIndex = currentIndex.clamp(0, widget.imageDataList.length - 1);
          _pageController.jumpToPage(currentIndex);
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Image deleted successfully.")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete failed: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageDataList.isEmpty) {
      return const Scaffold(
        backgroundColor: const Color(0xFFF5E8E4),
        body: Center(
          child: Text("No images", style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final currentImage = widget.imageDataList[currentIndex];
    final imageUrl = currentImage['url'];

    return Scaffold(
      backgroundColor: const Color(0xFFF5E8E4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const CloseButton(color: const Color(0xFF411530)),
        actions: [
          IconButton(
            onPressed: () => _showImageInfoDialog(currentImage),
            icon:
                const Icon(Icons.info_outline, color: const Color(0xFF411530)),
            tooltip: "Info",
          ),
          IconButton(
            onPressed: () => _downloadImage(imageUrl),
            icon: const Icon(Icons.download, color: const Color(0xFF411530)),
            tooltip: "Download",
          ),
          IconButton(
            onPressed: () => _deleteImage(currentImage),
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: "Delete",
          ),
        ],
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageDataList.length,
        onPageChanged: (index) => setState(() => currentIndex = index),
        itemBuilder: (context, index) {
          final imageUrl = widget.imageDataList[index]['url'];
          return InteractiveViewer(
            child: Center(
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}
