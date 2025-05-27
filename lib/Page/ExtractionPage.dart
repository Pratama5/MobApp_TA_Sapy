import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path; // Keep this import
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:wavemark_app_v1/Page/ExtractionResult.dart';
// Add this import for ExtractionResultScreen
// Ensure the path is correct based on your project structure

class ExtractionPage extends StatefulWidget {
  const ExtractionPage({super.key});

  @override
  State<ExtractionPage> createState() => _ExtractionPageState();
}

class _ExtractionPageState extends State<ExtractionPage> {
  String _status = '';
  String? selectedAudio;
  String? selectedAudioUrl;
  String? _fetchedMethod;
  int? _fetchedSubband;
  int? _fetchedBit;
  double? _fetchedAlfass;

  late AudioPlayer _player;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  bool _isAudioLoading = false;
  bool _isExtracting = false;

  List<String> audioList = [];
  // watermarkList is declared but not used in the provided code.
  // List<String> watermarkList = [];

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
    // Assuming you want to load audios from the 'audios' path within the 'watermarked' bucket
    final audios = await fetchFileNamesFromSupabase('audios'); //

    setState(() {
      audioList = audios; //
    });
  }

  String getPublicAudioUrl(String fileName) {
    return Supabase.instance.client.storage
        .from(
            'media') // Assuming this is the correct bucket for public audio URLs
        .getPublicUrl('audios/$fileName'); //
  }

  Future<void> _fetchAudioWatermarkDetails(String audioFileName) async {
    try {
      final response = await Supabase.instance.client
          .from('audio_watermarked')
          .select('method, subband, bit, alfass')
          .eq('filename', audioFileName)
          .limit(1)
          .maybeSingle(); // Use maybeSingle() to gracefully handle 0 or 1 row

      if (response != null && response.isNotEmpty) {
        if (mounted) {
          setState(() {
            _fetchedMethod = response['method'] as String?;
            _fetchedSubband = response['subband'] as int?;
            _fetchedBit = response['bit'] as int?;
            _fetchedAlfass = response['alfass'] as double?;
          });
        }
      } else {
        print('No details found for $audioFileName in audio_watermarked');
        if (mounted) {
          // Reset if not found, or handle as an error
          setState(() {
            _fetchedMethod = "N/A"; // Or some default/error indicator
            // ... reset other fields similarly or show a message
          });
        }
      }
    } catch (e) {
      print("Error fetching watermark details: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching details for $audioFileName.")),
        );
        // Optionally set placeholder/error values for the fetched details
        setState(() {
          _fetchedMethod = "Error";
        });
      }
    }
  }

  Future<List<String>> fetchFileNamesFromSupabase(String folderPath) async {
    //
    final response = await Supabase.instance.client.storage
        .from('watermarked') // This bucket is used to list files
        .list(path: folderPath); // path parameter used here

    if (response.isEmpty) return []; //

    final filenames = response
        .where((item) =>
            item.name.endsWith('.wav') || //
            item.name.endsWith(
                '.mp3')) // // Removed .png and .jpg as this is for audioList
        .map((item) => item.name) //
        .toList(); //

    return filenames; //
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0'); //
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0'); //
    return '$m:$s'; //
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true, //
      fillColor: Colors.white, //
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), //
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF411530), width: 1.5), //
        borderRadius: BorderRadius.circular(12), //
      ),
    );
  }

  Future<void> _startExtraction() async {
    if (selectedAudioUrl == null || selectedAudio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an audio file first.")),
      );
      return;
    }

    setState(() => _isExtracting = true); //

    final uri = Uri.parse(
        "http://192.168.18.10:8000/extract"); // Always change this when connection changes //

    final payload = {
      "audio_url": selectedAudioUrl, //
      "filename": selectedAudio, //
    };

    try {
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"}, //
        body: jsonEncode(payload), //
      );

      final result = jsonDecode(response.body); //
      if (result["status"] == "success") {
        //
        final String watermarkUrl = result["watermark_url"]; //
        final dynamic ber = result["ber"]; //

        // Navigate to ExtractionResultScreen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ExtractionResultScreen(
              imageUrl: watermarkUrl,
              watermark: _fetchedMethod ?? "N/A", // Use fetched value
              subband: _fetchedSubband ?? 0, // Use fetched value
              bit: _fetchedBit ?? 0, // Use fetched value
              alfass: _fetchedAlfass?.toString() ?? "N/A", // Use fetched value
              actualBer: ber.toString(),
              status: "success",
            ),
          ),
        );
        // You can choose to remove or keep this SnackBar
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text("Extraction successful! BER: $ber")),
        // );
      } else {
        print("Server error: ${result["message"]}"); //
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${result["message"]}")), //
        );
      }
    } catch (e) {
      print("Extraction error: $e"); //
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Extraction failed.")), //
      );
    }

    setState(() => _isExtracting = false); //
  }

  @override
  void dispose() {
    _player.dispose(); //
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioName = selectedAudio != null
        ? path.basename(selectedAudio!) //
        : 'No file selected'; //

    return Scaffold(
      backgroundColor: const Color(0xFFF5E8E4), //
      appBar: AppBar(
        title: const Text(
          'Extract Watermark', // Changed title to be more descriptive
          style: TextStyle(
            fontSize: 20, //
            fontWeight: FontWeight.bold, //
            color: Color(0xFF411530), //
          ),
        ),
        backgroundColor: const Color(0xFFF5E8E4), //
      ),
      body: Padding(
        padding: const EdgeInsets.all(24), //
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, //
          children: [
            const SizedBox(height: 10), //
            const Text(
              "Select Watermarked Audio", // Changed text
              style: TextStyle(
                fontWeight: FontWeight.bold, //
                fontSize: 18, //
                color: Color(0xFF411530), //
              ),
            ),
            const SizedBox(height: 5), //
            DropdownButtonFormField<String>(
              hint: const Text("Select Audio"), // Changed hint
              value: selectedAudio, //
              isExpanded: true, //
              items: audioList
                  .map((audio) =>
                      DropdownMenuItem(value: audio, child: Text(audio))) //
                  .toList(), //
              onChanged: (value) async {
                if (value == null) return;
                setState(() {
                  selectedAudio = value; //
                  // Ensure 'media' bucket and 'audios/' path are correct for your Supabase setup
                  selectedAudioUrl = getPublicAudioUrl(value); //
                  _isAudioLoading = true; //
                  _position = Duration.zero; // Reset position for new audio
                  _duration = Duration.zero; // Reset duration for new audio

                  // Reset previously fetched details
                  _fetchedMethod = null;
                  _fetchedSubband = null;
                  _fetchedBit = null;
                  _fetchedAlfass = null;
                });

                // Fetch new details
                await _fetchAudioWatermarkDetails(value); // New function call

                try {
                  if (selectedAudioUrl != null) {
                    // Check if URL is not null before setting
                    await _player.setUrl(selectedAudioUrl!);
                  }
                } catch (e) {
                  print("Failed to load audio: $e"); //
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Failed to load audio: $value")),
                  );
                }
                setState(() {
                  _isAudioLoading = false; //
                });
              },
              decoration: _inputDecoration(), //
            ),
            const SizedBox(height: 30), //
            if (selectedAudio != null) ...[
              Column(
                children: [
                  const Icon(Icons.headphones,
                      size: 50, color: Color(0xFF411530)), //
                  const SizedBox(height: 10), // Adjusted spacing
                  const Text(
                    'Selected Audio', // Changed text
                    style: TextStyle(fontSize: 14, color: Colors.black54), //
                  ),
                  Text(
                    audioName,
                    style: const TextStyle(
                      fontSize: 16, //
                      fontWeight: FontWeight.bold, //
                      color: Colors.black87, //
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16), //
              Slider(
                value: _position.inMilliseconds.toDouble(), //
                max: _duration.inMilliseconds > 0
                    ? _duration.inMilliseconds.toDouble() //
                    : 1, //
                onChanged: (value) {
                  _player.seek(Duration(milliseconds: value.toInt())); //
                },
                activeColor: const Color(0xFFD1512D), //
                inactiveColor: Colors.grey[300], //
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, //
                children: [
                  Text(_formatDuration(_position)), //
                  IconButton(
                    icon: _isAudioLoading
                        ? SizedBox(
                            width: 24, //
                            height: 24, //
                            child: CircularProgressIndicator(
                              strokeWidth: 3, //
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFD1512D)), //
                            ),
                          )
                        : Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow, //
                            size: 40, //
                          ),
                    onPressed: _isAudioLoading || selectedAudioUrl == null //
                        ? null //
                        : () {
                            if (_isPlaying) {
                              //
                              _player.pause(); //
                            } else {
                              _player.play(); //
                            }
                          },
                  ),
                  Text(_formatDuration(_duration)), //
                ],
              ),
              const Spacer(), // Use Spacer to push the button to the bottom
            ] else ...[
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.audio_file_outlined,
                          size: 60, color: Colors.grey),
                      SizedBox(height: 16),
                      Text("No audio selected",
                          style:
                              TextStyle(fontSize: 16, color: Colors.black54)),
                      Text("Select an audio file to see player controls.",
                          style: TextStyle(fontSize: 14, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ],
            ElevatedButton.icon(
              onPressed: _isExtracting ||
                      selectedAudio == null ||
                      selectedAudioUrl == null //
                  ? null //
                  : _startExtraction, //
              icon: _isExtracting
                  ? Container(
                      width: 24,
                      height: 24,
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : const Icon(Icons.find_in_page), //
              label: Text(
                  _isExtracting ? 'Extracting...' : 'Extract Watermark'), //
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E2A4D), //
                foregroundColor: Colors.white, //
                padding: const EdgeInsets.symmetric(vertical: 14), //
                textStyle:
                    const TextStyle(fontSize: 16), // Added for better text size
              ),
            ),
            const SizedBox(height: 20), //
            // _status is not visibly updated in a way that would show here, consider removing or using it
            if (_status.isNotEmpty) //
              Text(
                _status, //
                textAlign: TextAlign.center, //
                style: TextStyle(
                  color:
                      _status.contains('failed') ? Colors.red : Colors.green, //
                  fontWeight: FontWeight.bold, //
                ),
              ),
          ],
        ),
      ),
    );
  }
}
