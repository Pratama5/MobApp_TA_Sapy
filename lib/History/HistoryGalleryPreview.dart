import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';

class HistoryGalleryPreview extends StatefulWidget {
  final List<Map<String, dynamic>> imageDataList;
  final int initialIndex;

  const HistoryGalleryPreview({
    super.key,
    required this.imageDataList,
    required this.initialIndex,
  });

  @override
  State<HistoryGalleryPreview> createState() => _HistoryGalleryPreviewState();
}

class _HistoryGalleryPreviewState extends State<HistoryGalleryPreview> {
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
      final response = await Dio().head(url); // Using Dio for HEAD request
      final contentLength = response.headers.value('content-length');
      return int.tryParse(contentLength ?? '') ?? 0;
    } catch (e) {
      print("Error fetching size for $url: $e");
      return 0;
    }
  }

  String readableSize(int bytes) {
    if (bytes <= 0) return "0 B"; // Handle zero or negative bytes
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
    final uploadedAt =
        uploadedAtRaw != null && uploadedAtRaw.toString().isNotEmpty
            ? DateFormat("MMM dd, yyyy – HH:mm") // Corrected DateFormat pattern
                .format(DateTime.parse(uploadedAtRaw.toString()))
            : 'Unknown';
    // Show a loading indicator for size initially
    String sizeString = "Loading...";
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false, // Prevent closing while loading size
        builder: (context) => AlertDialog(
          title: const Text("Image Info"),
          content: StatefulBuilder(
            // Use StatefulBuilder to update size later
            builder: (BuildContext context, StateSetter setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("📛 Filename: $filename"),
                  const SizedBox(height: 4),
                  Text("🗓 Uploaded At: $uploadedAt"),
                  const SizedBox(height: 4),
                  Text("📦 Size: $sizeString"),
                ],
              );
            },
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

    final sizeBytes = await fetchImageSizeFromUrl(image['url']);
    sizeString = readableSize(sizeBytes);

    // If dialog is still open (mounted is a bit broad here, ideally check dialog state)
    // For simplicity, we're re-opening dialog if it was closed or updating if we could track its state.
    // A more robust way would involve passing a StateSetter to update the dialog content.
    // For this example, we pop if it might be open, and then show updated.
    if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog
    }
    if (mounted) {
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
              Text("📦 Size: $sizeString"), // Show fetched size
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
  }

  Future<void> _downloadImage(String url) async {
    try {
      if (!await launchUrlString(url, mode: LaunchMode.externalApplication)) {
        // Suggest external app for download
        throw 'Could not launch $url';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  Future<void> _deleteImage(Map<String, dynamic> image) async {
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Image"),
        content: const Text(
            "Are you sure you want to delete this image? This action cannot be undone."),
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
      // Assuming images are in 'watermarked/images/' path as per previous server.py context for extracted images
      await supabase.storage.from('watermarked').remove(['images/$filename']);
      // Assuming the table is 'image_extracted' as per your previous problem description
      await supabase.from('image_extracted').delete().eq('filename', filename);

      if (mounted) {
        setState(() {
          widget.imageDataList.removeAt(currentIndex);
          if (widget.imageDataList.isEmpty) {
            Navigator.pop(context); // Pop if no images left
          } else {
            // Adjust currentIndex if it's now out of bounds
            if (currentIndex >= widget.imageDataList.length) {
              currentIndex = widget.imageDataList.length - 1;
            }
            // No need to jump if PageView handles current item update correctly,
            // but explicitly setting might be needed if issues arise.
            // _pageController.jumpToPage(currentIndex); // Might not be needed if PageView rebuilds correctly
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Image deleted successfully.")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Delete failed: $e")),
        );
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageDataList.isEmpty) {
      return Scaffold(
        // Added Scaffold for consistency
        backgroundColor: const Color(0xFFF5E8E4),
        appBar: AppBar(
          // Added AppBar for back navigation
          title: const Text("No Images"),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: const CloseButton(color: Color(0xFF411530)),
        ),
        body: const Center(
          child: Text("No images available.",
              style: TextStyle(color: Color(0xFF411530), fontSize: 16)),
        ),
      );
    }

    // Ensure currentIndex is valid before accessing imageDataList
    // This can happen if an image is deleted and the list becomes shorter.
    final safeCurrentIndex =
        currentIndex.clamp(0, widget.imageDataList.length - 1);
    if (widget.imageDataList.isEmpty || safeCurrentIndex < 0) {
      // Double check after clamp if list became empty
      return build(context); // Recurse to show "No images" screen
    }
    final currentImage = widget.imageDataList[safeCurrentIndex];
    final currentImageUrl = currentImage['url'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF5E8E4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const CloseButton(color: Color(0xFF411530)),
        actions: [
          IconButton(
            onPressed: () => _showImageInfoDialog(currentImage),
            icon: const Icon(Icons.info_outline, color: Color(0xFF411530)),
            tooltip: "Info",
          ),
          IconButton(
            onPressed: () {
              if (currentImageUrl != null) {
                _downloadImage(currentImageUrl);
              }
            },
            icon: const Icon(Icons.download, color: Color(0xFF411530)),
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
        onPageChanged: (index) {
          if (mounted) {
            // Ensure widget is still mounted before calling setState
            setState(() => currentIndex = index);
          }
        },
        itemBuilder: (context, index) {
          final imageUrl = widget.imageDataList[index]['url'] as String?;
          if (imageUrl == null) {
            // Handle case where URL might be null for an item
            return Container(
              width: 300,
              height: 300,
              color: Colors.grey[200],
              child: const Center(
                child: Icon(
                  Icons.error_outline,
                  color: Colors.grey,
                  size: 50,
                ),
              ),
            );
          }
          return InteractiveViewer(
            minScale: 0.5, // Optional: Set min scale
            maxScale: 4.0, // Optional: Set max scale
            child: Center(
              child: Image.network(
                imageUrl,
                fit: BoxFit.contain,
                // --- Applied changes for better display of small images ---
                width: 300, // Fixed width for initial display
                height: 300, // Fixed height for initial display
                filterQuality:
                    FilterQuality.none, // For clear pixelated scaling
                loadingBuilder: (BuildContext context, Widget child,
                    ImageChunkEvent? loadingProgress) {
                  if (loadingProgress == null) return child; // Image is loaded
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      color: const Color(0xFFD1512D),
                    ),
                  );
                },
                errorBuilder: (BuildContext context, Object error,
                    StackTrace? stackTrace) {
                  print(
                      "❌ Error loading image in HistoryGalleryPreview: $imageUrl, Error: $error");
                  return Container(
                    width: 250, // Consistent size for error placeholder
                    height: 250,
                    color: Colors.grey[200],
                    child: const Center(
                      child: Icon(
                        Icons.broken_image,
                        color: Colors.grey,
                        size: 50,
                      ),
                    ),
                  );
                },
                // --- End of applied changes ---
              ),
            ),
          );
        },
      ),
    );
  }
}
