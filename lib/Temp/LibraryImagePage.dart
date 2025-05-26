import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class LibraryImagePage extends StatefulWidget {
  const LibraryImagePage({Key? key}) : super(key: key);

  @override
  State<LibraryImagePage> createState() => _LibraryImagePageState();
}

class _LibraryImagePageState extends State<LibraryImagePage> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> imageFiles = [];
  Map<String, int> fileSizes = {};
  bool isLoading = true;
  String readableSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
    } else if (bytes >= 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    }
    return "$bytes B";
  }

  @override
  void initState() {
    super.initState();
    fetchImageFiles().then((_) => fetchImageSizes());
  }

  Future<void> fetchImageFiles() async {
    try {
      final response = await supabase
          .from('image_watermarks')
          .select('filename, url,uploaded_at')
          .order('uploaded_at', ascending: false);

      setState(() {
        imageFiles = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching image files: $e')),
      );
    }
  }

  Future<void> fetchImageSizes() async {
    try {
      final files = await supabase.storage.from('media').list(path: 'images');
      setState(() {
        fileSizes = {
          for (final file in files) file.name: file.metadata?['size'] ?? 0,
        };
      });
    } catch (e) {
      print("Failed to fetch file sizes: $e");
    }
  }

  void showImageInfoDialog(Map<String, dynamic> image) {
    final filename = image['filename'] ?? 'Unknown';
    final uploadedAtRaw = image['uploaded_at'];
    final uploadedAt = uploadedAtRaw != null
        ? DateFormat("MMM dd, yyyy – HH:mm")
            .format(DateTime.parse(uploadedAtRaw))
        : 'Unknown';
    final sizeBytes = fileSizes[filename] ?? 0;

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

  Future<void> downloadImage(String url, String filename) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? basePath = prefs.getString('download_folder');
      if (basePath == null) {
        final dir = await getApplicationDocumentsDirectory();
        basePath = dir.path;
      }

      final filePath = '$basePath/$filename';
      final dio = Dio();
      final response = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      final file = File(filePath);
      await file.writeAsBytes(Uint8List.fromList(response.data!));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Downloaded to: $filePath")),
      );
    } catch (e) {
      print("Download error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Download failed: $e")),
      );
    }
  }

  Future<void> deleteImage(
      BuildContext context, Map<String, dynamic> image) async {
    final filename = image['filename'];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: Text("Are you sure you want to delete $filename?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Step 1: Delete from Storage (no .error — exceptions are caught)
      await supabase.storage.from('media').remove(['images/$filename']);

      // Step 2: Delete metadata from DB
      await supabase.from('image_watermarks').delete().eq('filename', filename);

      setState(() {
        imageFiles.remove(image);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Deleted $filename")),
      );
    } catch (e) {
      print("Delete error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete failed: $e")),
      );
    }
  }

  void showFullScreenImage(String url, String filename) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Image.network(url, fit: BoxFit.contain),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void showImageOptions(BuildContext context, Map<String, dynamic> image) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text("Info"),
              onTap: () {
                Navigator.pop(context);
                showImageInfoDialog(image);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text("Download"),
              onTap: () {
                Navigator.pop(context);
                downloadImage(image['url'], image['filename']);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text("Delete"),
              onTap: () {
                Navigator.pop(context);
                deleteImage(context, image);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Image Gallery")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : imageFiles.isEmpty
              ? const Center(child: Text("No images found."))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: imageFiles.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    final image = imageFiles[index];
                    final url = image['url'];
                    final filename = image['filename'];

                    return Stack(
                      children: [
                        GestureDetector(
                          onTap: () => showFullScreenImage(url, filename),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade200,
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                url,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    const Icon(Icons.broken_image),
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            width: 28, // ✅ Scale down circle size
                            height: 28,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.more_vert,
                                  color: Colors.white),
                              iconSize: 18, //  Smaller icon
                              padding:
                                  const EdgeInsets.all(6), //  Slight padding
                              constraints:
                                  const BoxConstraints(), //  Remove default constraints
                              onPressed: () => showImageOptions(context, image),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }
}
