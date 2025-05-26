import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';

class UploadPage extends StatefulWidget {
  const UploadPage({Key? key}) : super(key: key);

  @override
  State<UploadPage> createState() => _UploadPageState();
}

class _UploadPageState extends State<UploadPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  bool isUploading = false;
  String statusMessage = '';

  Future<void> _uploadFile(String fileType) async {
    final result = await FilePicker.platform.pickFiles(
      type: fileType == 'audio' ? FileType.audio : FileType.image,
    );

    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.single.path!);
    final originalFilename = path.basename(file.path); // ex: piano.wav
    final folder = fileType == 'audio' ? 'audios' : 'images';
    final storagePath = '$folder/$originalFilename';
    final bucket = 'media';

    final mimeType = lookupMimeType(file.path);
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) {
      setState(() => statusMessage = 'Upload failed: No user session.');
      return;
    }

    try {
      await supabase.auth.refreshSession();

      setState(() {
        isUploading = true;
        statusMessage = 'Uploading $originalFilename...';
      });

      // Read bytes and upload to Supabase Storage
      try {
        final fileBytes = await file.readAsBytes();
        await supabase.storage.from(bucket).uploadBinary(
              storagePath,
              fileBytes,
              fileOptions: FileOptions(
                upsert: true,
                contentType: mimeType,
              ),
            );
      } on StorageException catch (e) {
        setState(() {
          isUploading = false;
          statusMessage = 'Storage upload failed: ${e.message}';
        });
        return;
      }

      // Generate public URL
      final publicUrl = supabase.storage.from(bucket).getPublicUrl(storagePath);

      // Insert into the appropriate table
      final tableName =
          fileType == 'audio' ? 'audio_files' : 'image_watermarks';

      try {
        await supabase.from(tableName).insert({
          'filename': originalFilename,
          'url': publicUrl,
          'uploaded_by': userId,
          'uploaded_at': DateTime.now().toIso8601String(),
        });

        setState(() {
          statusMessage = 'Upload successful!';
        });
      } on PostgrestException catch (e) {
        setState(() {
          statusMessage = 'Database insert failed: ${e.message}';
        });
      }
    } catch (e) {
      setState(() {
        statusMessage = 'Unexpected error: $e';
      });
    } finally {
      setState(() => isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload Media")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => _uploadFile('audio'),
              icon: const Icon(Icons.audiotrack),
              label: const Text("Upload Audio Host"),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _uploadFile('image'),
              icon: const Icon(Icons.image),
              label: const Text("Upload Watermark Image"),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50)),
            ),
            const SizedBox(height: 40),
            if (isUploading) const CircularProgressIndicator(),
            Text(statusMessage, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }
}
