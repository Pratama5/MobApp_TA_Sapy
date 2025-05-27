import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dio/dio.dart';
import 'package:wavemark_app_v1/Etc/bottom_nav.dart'; // For fetching image size

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

// Helper class to hold all details for the info dialog
class FullImageInfo {
  String filename;
  String uploadedAt;
  String size;
  String sourceAudio;
  String ber;
  String? method;
  int? subband;
  int? bit;
  double? alfass;
  bool isLoadingDetails; // For the second stage of loading (embedding params)

  FullImageInfo({
    required this.filename,
    required this.uploadedAt,
    required this.size,
    required this.sourceAudio,
    required this.ber,
    this.method,
    this.subband,
    this.bit,
    this.alfass,
    this.isLoadingDetails = false,
  });

  // Method to update and return a new instance, useful for ValueNotifier
  FullImageInfo copyWith({
    String? filename,
    String? uploadedAt,
    String? size,
    String? sourceAudio,
    String? ber,
    String? method,
    int? subband,
    int? bit,
    double? alfass,
    bool? isLoadingDetails,
  }) {
    return FullImageInfo(
      filename: filename ?? this.filename,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      size: size ?? this.size,
      sourceAudio: sourceAudio ?? this.sourceAudio,
      ber: ber ?? this.ber,
      method: method ?? this.method,
      subband: subband ?? this.subband,
      bit: bit ?? this.bit,
      alfass: alfass ?? this.alfass,
      isLoadingDetails: isLoadingDetails ?? this.isLoadingDetails,
    );
  }
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

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<int> fetchImageSizeFromUrl(String url) async {
    try {
      final response = await Dio().head(url);
      final contentLength = response.headers.value('content-length');
      return int.tryParse(contentLength ?? '') ?? 0;
    } catch (e) {
      print("Error fetching size for $url: $e");
      return 0;
    }
  }

  String readableSize(int bytes) {
    if (bytes <= 0) return "0 B";
    if (bytes >= 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
    } else if (bytes >= 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    }
    return "$bytes B";
  }

  void _showImageInfoDialog(Map<String, dynamic> currentImageFromList) async {
    // Initial data from the list (image_extracted table)
    final initialInfo = FullImageInfo(
      filename: currentImageFromList['filename'] ?? 'Unknown',
      uploadedAt: (currentImageFromList['uploaded_at'] != null &&
              currentImageFromList['uploaded_at'].toString().isNotEmpty)
          ? DateFormat("MMM dd, yyyy – HH:mm") // Standardized date format
              .format(DateTime.parse(
                  currentImageFromList['uploaded_at'].toString()))
          : 'Unknown',
      size: "Calculating...", // Will be fetched
      sourceAudio: currentImageFromList['source_audio'] as String? ?? 'N/A',
      ber: currentImageFromList['ber']?.toString() ?? 'N/A',
      isLoadingDetails: true, // Start by loading everything
    );

    final ValueNotifier<FullImageInfo> infoNotifier =
        ValueNotifier(initialInfo);

    // Show dialog immediately with initial info & loading states
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => ValueListenableBuilder<FullImageInfo>(
          valueListenable: infoNotifier,
          builder: (context, info, child) {
            return AlertDialog(
              title: const Text("Image Details"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("📛 Filename: ${info.filename}"),
                    const SizedBox(height: 4),
                    Text("🗓 Uploaded At: ${info.uploadedAt}"),
                    const SizedBox(height: 4),
                    Text(
                        "📦 Size: ${info.size}"), // Shows "Calculating..." or fetched size
                    const SizedBox(height: 8),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text("🔊 Source Audio: ${info.sourceAudio}"),
                    const SizedBox(height: 4),
                    Text("📉 BER: ${info.ber}"),
                    const SizedBox(height: 8),
                    if (info.isLoadingDetails &&
                        info.size ==
                            "Calculating...") // Show general loading if size is still calculating
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(child: Text("Loading image info...")),
                      )
                    else if (info
                        .isLoadingDetails) // Show loading for embedding params if size is done
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Column(
                          children: [
                            Text("Embedding Parameters:",
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          ],
                        ),
                      )
                    else ...[
                      // Display embedding parameters if not loading
                      const Text("Embedding Parameters:",
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text("  Metode: ${info.method ?? 'N/A'}"),
                      Text(
                          "  🔸 Sub-band: ${info.subband?.toString() ?? 'N/A'}"),
                      Text("  🔸 Bit: ${info.bit?.toString() ?? 'N/A'}"),
                      Text("  🔸 Alpha: ${info.alfass?.toString() ?? 'N/A'}"),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close"),
                ),
              ],
            );
          },
        ),
      );
    }

    // Asynchronously fetch size
    final sizeBytes = await fetchImageSizeFromUrl(currentImageFromList['url']);
    if (mounted) {
      infoNotifier.value = infoNotifier.value.copyWith(
        size: readableSize(sizeBytes),
        // isLoadingDetails remains true until embedding params are also fetched or fail
      );
    }

    // Asynchronously fetch embedding details if sourceAudio is available
    if (initialInfo.sourceAudio != 'N/A') {
      try {
        final audioWatermarkedData = await supabase
            .from('audio_watermarked') // Make sure this table name is correct
            .select('method, subband, bit, alfass')
            .eq('filename', initialInfo.sourceAudio)
            .maybeSingle();

        if (mounted) {
          if (audioWatermarkedData != null) {
            infoNotifier.value = infoNotifier.value.copyWith(
              method: audioWatermarkedData['method'] as String?,
              subband: audioWatermarkedData['subband'] as int?,
              bit: audioWatermarkedData['bit'] as int?,
              alfass: (audioWatermarkedData['alfass'] as num?)
                  ?.toDouble(), // Handle num from DB
              isLoadingDetails: false,
            );
          } else {
            // Embedding details not found for the source audio
            infoNotifier.value = infoNotifier.value
                .copyWith(isLoadingDetails: false, method: "N/A (not found)");
          }
        }
      } catch (e) {
        print("Error fetching embedding details: $e");
        if (mounted) {
          infoNotifier.value = infoNotifier.value
              .copyWith(isLoadingDetails: false, method: "N/A (error)");
        }
      }
    } else {
      // No source audio to fetch embedding details from
      if (mounted) {
        infoNotifier.value =
            infoNotifier.value.copyWith(isLoadingDetails: false);
      }
    }
  }

  Future<void> _downloadImage(String url) async {
    try {
      if (!await launchUrlString(url, mode: LaunchMode.externalApplication)) {
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
      final filename = image['filename'] as String?;
      if (filename == null) {
        throw "Filename is null, cannot delete.";
      }
      // Corrected storage path and table name based on prior discussions
      await supabase.storage.from('watermarked').remove(['images/$filename']);
      await supabase.from('image_extracted').delete().eq('filename', filename);

      if (mounted) {
        final originalIndex = widget.imageDataList.indexOf(image);
        setState(() {
          widget.imageDataList.removeAt(originalIndex);
          // If the current page was the one deleted, and it was the last one,
          // we need to adjust currentIndex carefully.
          if (widget.imageDataList.isEmpty) {
            // No items left, pop the gallery view
            Navigator.pop(context);
          } else if (currentIndex >= widget.imageDataList.length) {
            // If current index is now out of bounds (was last item)
            currentIndex = widget.imageDataList.length - 1;
            _pageController.jumpToPage(currentIndex);
          } else if (currentIndex == originalIndex &&
              originalIndex < widget.imageDataList.length) {
            // If we deleted the current page and it wasn't the last one,
            // PageView might handle it, or we might need to nudge it.
            // For simplicity, we're relying on PageView to show the new item at 'currentIndex'
            // or the next item if current was deleted. A specific jump might be needed if PageView
            // doesn't update smoothly. The onPageChanged will update currentIndex.
          }
          // No explicit jump here, relying on PageView's itemCound change and
          // onPageChanged to keep currentIndex in sync.
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
  Widget build(BuildContext context) {
    if (widget.imageDataList.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5E8E4),
        appBar: AppBar(
          title: const Text("Gallery"), // More generic title
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
    final safeCurrentIndex =
        currentIndex.clamp(0, widget.imageDataList.length - 1);
    final currentImageForAppBar =
        widget.imageDataList[safeCurrentIndex]; // Used for AppBar actions
    final currentImageUrlForAppBar = currentImageForAppBar['url'] as String?;

    return Scaffold(
      backgroundColor: const Color(0xFFF5E8E4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const CloseButton(color: Color(0xFF411530)),
        actions: [
          IconButton(
            onPressed: () => _showImageInfoDialog(currentImageForAppBar),
            icon: const Icon(Icons.info_outline, color: Color(0xFF411530)),
            tooltip: "Info",
          ),
          IconButton(
            onPressed: () {
              if (currentImageUrlForAppBar != null) {
                _downloadImage(currentImageUrlForAppBar);
              }
            },
            icon: const Icon(Icons.download, color: Color(0xFF411530)),
            tooltip: "Download",
          ),
          IconButton(
            onPressed: () => _deleteImage(currentImageForAppBar),
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
            setState(() => currentIndex = index);
          }
        },
        itemBuilder: (context, index) {
          final imageItem = widget.imageDataList[index];
          final imageUrl = imageItem['url'] as String?;
          final sourceAudio = imageItem['source_audio'] as String? ?? 'N/A';
          final ber = imageItem['ber']?.toString() ?? 'N/A';

          if (imageUrl == null) {
            return Container(
              // Fallback for null URL
              width: 350, height: 350, color: Colors.grey[200],
              child: const Center(
                  child:
                      Icon(Icons.error_outline, color: Colors.grey, size: 50)),
            );
          }

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      width: 350, // Fixed width for initial display
                      height: 350, // Fixed height for initial display
                      filterQuality:
                          FilterQuality.none, // For clear pixelated scaling
                      loadingBuilder: (BuildContext context, Widget child,
                          ImageChunkEvent? loadingProgress) {
                        if (loadingProgress == null) return child;
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
                            "❌ Error loading image in PageView: $imageUrl, Error: $error");
                        return Container(
                          width: 350,
                          height: 350,
                          color: Colors.grey[200],
                          child: const Center(
                              child: Icon(Icons.broken_image,
                                  color: Colors.grey, size: 50)),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize
                      .min, // Important for Column inside Expanded parent
                  children: [
                    Text(
                      "Audio File: $sourceAudio",
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800]), // Adjusted style
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "BER: $ber",
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800]), // Adjusted style
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
