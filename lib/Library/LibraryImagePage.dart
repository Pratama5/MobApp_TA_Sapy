import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:wavemark_app_v1/Etc/bottom_nav.dart';
import 'package:wavemark_app_v1/Library/image_gallery_preview.dart';

class LibraryImagePage extends StatefulWidget {
  const LibraryImagePage({super.key});

  @override
  State<LibraryImagePage> createState() => _LibraryImagePageState();
}

class _LibraryImagePageState extends State<LibraryImagePage> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> imageFiles = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchImageFiles();
  }

  Future<void> fetchImageFiles() async {
    try {
      final data = await supabase
          .from('image_watermarks')
          .select('filename, url,uploaded_at, is_public')
          .order('uploaded_at', ascending: false);

      setState(() {
        imageFiles = List<Map<String, dynamic>>.from(data);
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading images: $e')));
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
    // Check if the audio is public
    if (image['is_public'] == true) {
      // If public, show a message and do nothing else
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("This is a Public audio and can't be deleted.")),
      );
      return; // Stop the function here
    }
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
      await supabase.storage.from('media').remove(['images/$filename']);
      await supabase.from('image_watermarks').delete().eq('filename', filename);

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
          "Image Library",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF411530),
          ),
        ),
        backgroundColor: const Color(0xFFF5E8E4),
        elevation: 0,
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
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ImageGalleryPreview(
                                imageDataList:
                                    List<Map<String, dynamic>>.from(imageFiles),
                                initialIndex: index,
                              ),
                            ),
                          );
                          // If the result is true, it means a deletion happened.
                          if (result == true && mounted) {
                            setState(() {
                              isLoading =
                                  true; // Show loading indicator while refetching
                            });
                            fetchImageFiles(); // Refresh the list!
                          }
                        },
                        onLongPress: () =>
                            showImageOptions(context, url, filename, image),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.broken_image, size: 40),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFD1512D),
        tooltip: 'Upload Image',
        child: const Icon(Icons.file_upload, color: Colors.white),
        onPressed: () async {
          final result = await Navigator.pushNamed(context, '/uploadImage');
          if (result == true) {
            fetchImageFiles(); // refresh after upload
          }
        },
      ),
      bottomNavigationBar: const BottomNavBar(currentRoute: '/library_images'),
    );
  }
}
