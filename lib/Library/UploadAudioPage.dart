import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:just_audio/just_audio.dart';

class UploadAudioPage extends StatefulWidget {
  const UploadAudioPage({super.key});

  @override
  State<UploadAudioPage> createState() => _UploadAudioPageState();
}

class _UploadAudioPageState extends State<UploadAudioPage> {
  File? _selectedFile;
  String _status = '';
  bool _isUploading = false;

  late AudioPlayer _player;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _player.positionStream.listen((pos) {
      if (!mounted) return;
      setState(() => _position = pos);
    });

    _player.durationStream.listen((dur) {
      if (!mounted || dur == null) return;
      setState(() => _duration = dur);
    });

    _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() => _isPlaying = state.playing);
    });
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _status = '';
      });

      await _player.setFilePath(_selectedFile!.path);
    }
  }

  Future<void> _uploadAudioFile() async {
    if (_selectedFile == null) {
      setState(() => _status = 'Please select a file first.');
      return;
    }

    setState(() {
      _isUploading = true;
      _status = 'Uploading...';
    });

    try {
      final fileName = path.basename(_selectedFile!.path);
      final bytes = await _selectedFile!.readAsBytes();

      await Supabase.instance.client.storage.from('media').uploadBinary(
          'audios/$fileName', bytes,
          fileOptions: const FileOptions(upsert: true));

      final publicUrl = Supabase.instance.client.storage
          .from('media')
          .getPublicUrl('audios/$fileName');

      final user = Supabase.instance.client.auth.currentUser;
      await Supabase.instance.client.from('audio_files').insert({
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

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioName = _selectedFile != null
        ? path.basename(_selectedFile!.path)
        : 'No file selected';

    return Scaffold(
      backgroundColor: const Color(0xFFF5E8E4),
      appBar: AppBar(
        title: const Text(
          'Upload Audio',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF411530),
          ),
        ),
        backgroundColor: const Color(0xFFF5E8E4),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: _pickAudioFile,
              icon: const Icon(Icons.folder_open),
              label: const Text("Select Audio File"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD1512D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 30),
            Column(
              children: [
                const Icon(Icons.music_note,
                    size: 50, color: Color(0xFF411530)),
                const SizedBox(height: 30),
                const Text(
                  'Selected',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                Text(
                  audioName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            /// Audio Player Centered
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Slider(
                    value: _position.inMilliseconds.toDouble(),
                    max: _duration.inMilliseconds > 0
                        ? _duration.inMilliseconds.toDouble()
                        : 1,
                    onChanged: (value) {
                      _player.seek(Duration(milliseconds: value.toInt()));
                    },
                    activeColor: const Color(0xFFD1512D),
                    inactiveColor: Colors.grey[300],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_formatDuration(_position)),
                      IconButton(
                        icon: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          size: 40,
                        ),
                        onPressed: () {
                          if (_selectedFile != null) {
                            _isPlaying ? _player.pause() : _player.play();
                          }
                        },
                      ),
                      Text(_formatDuration(_duration)),
                    ],
                  ),
                ],
              ),
            ),

            ElevatedButton.icon(
              onPressed: _isUploading ? null : _uploadAudioFile,
              icon: const Icon(Icons.cloud_upload),
              label: Text(_isUploading ? 'Uploading...' : 'Upload Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E2A4D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 20),
            if (_status.isNotEmpty)
              Text(
                _status,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _status.contains('failed') ? Colors.red : Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
