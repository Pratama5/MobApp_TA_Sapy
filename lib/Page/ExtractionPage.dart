import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;

class ExtractionPage extends StatefulWidget {
  const ExtractionPage({super.key});

  @override
  State<ExtractionPage> createState() => _ExtractionPageState();
}

class _ExtractionPageState extends State<ExtractionPage> {
  String _status = '';
  String? selectedAudio;
  String? selectedAudioUrl;

  late AudioPlayer _player;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isAudioLoading = false;
  bool _isExtracting = false;

  List<String> audioList = [];
  List<String> watermarkList = [];

  @override
  void initState() {
    super.initState();
    loadDropdownData();
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

  Future<void> loadDropdownData() async {
    final audios = await fetchFileNamesFromSupabase('audios');

    setState(() {
      audioList = audios;
    });
  }

  String getPublicAudioUrl(String fileName) {
    return Supabase.instance.client.storage
        .from('media')
        .getPublicUrl('audios/$fileName');
  }

  Future<List<String>> fetchFileNamesFromSupabase(String path) async {
    final response = await Supabase.instance.client.storage
        .from('watermarked')
        .list(path: path);

    if (response.isEmpty) return [];

    final filenames = response
        .where((item) =>
            item.name.endsWith('.wav') ||
            item.name.endsWith('.mp3') ||
            item.name.endsWith('.png') ||
            item.name.endsWith('.jpg'))
        .map((item) => item.name)
        .toList();

    return filenames;
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF411530), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Future<void> _startExtraction() async {
    setState(() => _isExtracting = true);

    final uri = Uri.parse(
        "http://192.168.18:8000/extract"); // Always change this when  change connection

    final payload = {
      "audio_url": selectedAudioUrl,
      "filename": selectedAudio,
    };

    try {
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      final result = jsonDecode(response.body);
      if (result["status"] == "success") {
        final watermarkUrl = result["watermark_url"];
        final ber = result["ber"];

        print("Watermark URL: $watermarkUrl");
        print("BER: $ber");

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Extraction successful! BER: $ber")),
        );
      } else {
        print("Server error: ${result["message"]}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${result["message"]}")),
        );
      }
    } catch (e) {
      print("Extraction error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Extraction failed.")),
      );
    }

    setState(() => _isExtracting = false);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioName = selectedAudio != null
        ? path.basename(selectedAudio!)
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
            const SizedBox(height: 10),
            const Text(
              "Select Audio",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF411530),
              ),
            ),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              hint: const Text("Audio"),
              value: selectedAudio,
              isExpanded: true,
              items: audioList
                  .map((audio) =>
                      DropdownMenuItem(value: audio, child: Text(audio)))
                  .toList(),
              onChanged: (value) async {
                setState(() {
                  selectedAudio = value;
                  selectedAudioUrl =
                      getPublicAudioUrl(value!); // Supabase public URL
                  _isAudioLoading = true; // start loading
                });
                // Load audio into the player
                try {
                  await _player.setUrl(selectedAudioUrl!);
                  // ✅ Reset player UI after loading new audio
                  setState(() {
                    _position = Duration.zero;
                    _duration = _player.duration ?? Duration.zero;
                  });
                } catch (e) {
                  print("Failed to load audio: $e");
                }
                setState(() {
                  _isAudioLoading = false; // done loading
                });
              },
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 30),
            Column(
              children: [
                const Icon(Icons.headphones,
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
                        icon: _isAudioLoading
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFFD1512D)),
                                ),
                              )
                            : Icon(
                                _isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 40,
                              ),
                        onPressed: _isAudioLoading
                            ? null
                            : () {
                                if (selectedAudioUrl != null) {
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
              onPressed: _isExtracting ||
                      selectedAudio == null ||
                      selectedAudioUrl == null
                  ? null
                  : _startExtraction,
              icon: const Icon(Icons.find_in_page),
              label:
                  Text(_isExtracting ? 'Extracting...' : 'Extract Watermark'),
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
