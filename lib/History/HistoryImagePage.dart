import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wavemark_app_v1/Etc/bottom_nav.dart';
import 'package:wavemark_app_v1/History/HistoryGalleryPreview.dart';

class HistoryImagePage extends StatefulWidget {
  const HistoryImagePage({super.key});

  @override
  State<HistoryImagePage> createState() => _HistoryImagePageState();
}

class _HistoryImagePageState extends State<HistoryImagePage> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> imageFiles = [];
  bool isLoading = true;
  int _pressCount = 0;

  @override
  void initState() {
    super.initState();
    fetchImageFiles();
  }

  Future<void> fetchImageFiles() async {
    setState(() {
      // Set loading true at the beginning
      isLoading = true;
    });
    try {
      final data = await supabase
          .from('image_extracted')
          .select(
              'filename, url, uploaded_at, source_audio, ber') // <<< MAKE SURE THIS LINE IS UPDATED
          .order('uploaded_at', ascending: false);

      // It's good to log what you actually receive from Supabase for debugging
      print("Fetched data in HistoryImagePage: $data");

      if (mounted) {
        setState(() {
          imageFiles = List<Map<String, dynamic>>.from(data);
          isLoading = false;
        });
      }
    } catch (e) {
      print("Error in fetchImageFiles (HistoryImagePage): $e");
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading images: $e')));
      }
    }
  }

  Future<void> downloadImage(String url) async {
    try {
      if (!await launchUrlString(url)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Download failed: $e')));
    }
  }

  Future<void> deleteImage(String filename, Map<String, dynamic> image) async {
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
      await supabase.storage.from('watermarked').remove(['images/$filename']);
      await supabase.from('image_extracted').delete().eq('filename', filename);

      setState(() => imageFiles.remove(image));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image deleted successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  void showImageOptions(BuildContext context, String url, String filename,
      Map<String, dynamic> image) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF5E8E4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Info'),
              subtitle: Text(filename),
            ),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Download'),
              onTap: () {
                Navigator.pop(context);
                downloadImage(url);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete),
              title: const Text('Delete'),
              onTap: () {
                Navigator.pop(context);
                deleteImage(filename, image);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5E8E4),
      appBar: AppBar(
        title: const Text(
          "Extraction Results",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF411530),
          ),
        ),
        backgroundColor: const Color(0xFFF5E8E4),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.hide_source, color: Color(0xFFF5E8E4)),
            onPressed: () {
              setState(() {
                _pressCount++;
                if (_pressCount >= 5) {
                  _pressCount = 0; // Reset counter after success
                  Navigator.pushNamed(context, '/hidden');
                }
              });
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : imageFiles.isEmpty
              ? const Center(child: Text("No images found."))
              : Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: GridView.builder(
                    itemCount: imageFiles.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 20,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.0,
                    ),
                    itemBuilder: (context, index) {
                      final image = imageFiles[index];
                      final url = image['url'];
                      final filename = image['filename'];

                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HistoryGalleryPreview(
                                imageDataList: imageFiles,
                                initialIndex: index,
                              ),
                            ),
                          );
                        },
                        onLongPress: () =>
                            showImageOptions(context, url, filename, image),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality
                                .none, // Added for sharp pixelated scaling
                            loadingBuilder: (BuildContext context, Widget child,
                                ImageChunkEvent? loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth:
                                      2, // Make it a bit thinner for grid view
                                  color: const Color(
                                      0xFFD1512D), // Optional: Consistent color
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              // Corrected signature
                              print(
                                  "Error loading grid image $url: $error"); // Optional: log error
                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  // borderRadius is handled by ClipRRect if this container doesn't fill it
                                ),
                                child: const Icon(Icons.broken_image,
                                    size: 40, color: Colors.grey),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
      bottomNavigationBar: const BottomNavBar(currentRoute: '/history'),
    );
  }
}
