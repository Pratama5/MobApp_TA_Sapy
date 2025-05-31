// lib/screens/upload_profile_picture_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as p; // Using 'p' as prefix to avoid conflict

class UploadProfilePictureScreen extends StatefulWidget {
  const UploadProfilePictureScreen({super.key});

  @override
  State<UploadProfilePictureScreen> createState() =>
      _UploadProfilePictureScreenState();
}

class _UploadProfilePictureScreenState
    extends State<UploadProfilePictureScreen> {
  File? _selectedImage;
  bool _isUploading = false;
  String _status = '';

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      // Optional: Add compression or size limits if needed for profile pictures
      // withData: true, // if you need bytes directly for some reason
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedImage = File(result.files.single.path!);
        _status = ''; // Clear previous status
      });
    }
  }

  Future<void> _uploadAndUseImage() async {
    if (_selectedImage == null) {
      setState(() => _status = 'Please select an image first.');
      return;
    }

    setState(() {
      _isUploading = true;
      _status = 'Uploading...';
    });

    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated.');
      }

      final fileExtension = p.extension(_selectedImage!.path);
      // Use user ID for filename to ensure uniqueness and easy replacement
      final fileName = '${currentUser.id}${fileExtension}';
      final String storagePath = 'media/profile_picture/$fileName';

      final bytes = await _selectedImage!.readAsBytes();

      // Upload to Supabase Storage, using upsert to overwrite if it exists for this user
      await Supabase.instance.client.storage.from('media').uploadBinary(
            storagePath,
            bytes,
            fileOptions:
                const FileOptions(upsert: true), // Upsert allows overwriting
          );

      // Get the public URL
      final String publicUrl = Supabase.instance.client.storage
          .from('media')
          .getPublicUrl(storagePath);

      // Add timestamp to URL to help bust cache if image is updated with same name
      final String urlWithTimestamp =
          '$publicUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      if (mounted) {
        setState(() {
          _isUploading = false;
          _status = 'Upload successful!';
        });
        // Pop and return the new URL
        Navigator.pop(context, urlWithTimestamp);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _status = 'Upload failed: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF8EDEB), // Consistent with EditProfileScreen
      appBar: AppBar(
        title: const Text('Upload Profile Picture',
            style: TextStyle(color: Color(0xFF411530))),
        backgroundColor: Colors.transparent, // Consistent
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFD1512D)),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: _pickImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Select Image from Gallery'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD1512D), // Theme accent
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Center(
                child: _selectedImage != null
                    ? Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.file(_selectedImage!, fit: BoxFit.cover),
                        ),
                      )
                    : Container(
                        width: 250,
                        height: 250,
                        decoration: BoxDecoration(
                          border: Border.all(
                              color: Colors.grey.shade400,
                              style: BorderStyle.solid),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.grey[100],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo_outlined,
                                size: 60, color: Colors.grey),
                            SizedBox(height: 16),
                            Text('Image Preview',
                                style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            if (_status.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _status.contains('failed')
                        ? Colors.red
                        : Colors.green.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ElevatedButton.icon(
              onPressed: (_selectedImage == null || _isUploading)
                  ? null
                  : _uploadAndUseImage,
              icon: _isUploading
                  ? Container(
                      width: 20,
                      height: 20,
                      child: const CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.cloud_upload_outlined),
              label: Text(_isUploading ? 'Uploading...' : 'Use This Picture'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF5E2A4D), // Theme secondary accent
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
