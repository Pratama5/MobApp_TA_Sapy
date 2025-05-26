import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;

class UploadImagePage extends StatefulWidget {
  const UploadImagePage({super.key});

  @override
  State<UploadImagePage> createState() => _UploadImagePageState();
}

class _UploadImagePageState extends State<UploadImagePage> {
  File? _selectedImage;
  String _status = '';
  bool _isUploading = false;

  Future<void> _pickImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedImage = File(result.files.single.path!);
        _status = '';
      });
    }
  }

  Future<void> _uploadImage() async {
    if (_selectedImage == null) {
      setState(() => _status = 'Please select an image first.');
      return;
    }

    setState(() {
      _isUploading = true;
      _status = 'Uploading...';
    });

    try {
      final fileName = path.basename(_selectedImage!.path);
      final bytes = await _selectedImage!.readAsBytes();

      await Supabase.instance.client.storage.from('media').uploadBinary(
          'images/$fileName', bytes,
          fileOptions: const FileOptions(upsert: true));

      final publicUrl = Supabase.instance.client.storage
          .from('media')
          .getPublicUrl('images/$fileName');

      final user = Supabase.instance.client.auth.currentUser;

      await Supabase.instance.client.from('image_watermarks').insert({
        'filename': fileName,
        'url': publicUrl,
        'uploaded_at': DateTime.now().toIso8601String(),
        'uploaded_by': user?.id,
      });

      setState(() {
        _isUploading = false;
        _status = 'Upload successful!';
      });

      await Future.delayed(const Duration(seconds: 1));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _isUploading = false;
        _status = 'Upload failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageName = _selectedImage != null
        ? path.basename(_selectedImage!.path)
        : 'No file selected';

    return Scaffold(
      backgroundColor: const Color(0xFFF5E8E4),
      appBar: AppBar(
        title: const Text('Upload Image'),
        backgroundColor: const Color(0xFF411530),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.folder_open),
                label: const Text("Select Image"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD1512D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Selected',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              Text(
                imageName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 20),

              /// Placeholder box
              Center(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey,
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[100],
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(
                            _selectedImage!,
                            fit: BoxFit.cover,
                            width: 220,
                            height: 220,
                          ),
                        )
                      // ignore: prefer_const_constructors
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.image_outlined,
                                size: 40, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'No image selected',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 30),

              ElevatedButton.icon(
                onPressed: _isUploading ? null : _uploadImage,
                icon: const Icon(Icons.cloud_upload),
                label: Text(_isUploading ? 'Uploading...' : 'Upload Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF5E2A4D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (_status.isNotEmpty)
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        _status.contains('failed') ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
