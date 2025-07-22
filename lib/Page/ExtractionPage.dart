import 'dart:convert';
import 'dart:io'; // For SocketException, TimeoutException (if adding timeout)
import 'dart:async'; // For TimeoutException

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:wavemark_app_v1/Page/ExtractionResult.dart';
import 'package:wavemark_app_v1/Page/ExtractionDLResult.dart';
import 'package:wavemark_app_v1/Etc/app_settings.dart';
import 'package:wavemark_app_v1/Etc/SettingsPage.dart';
import 'package:wavemark_app_v1/Etc/QueueMonitor.dart';

class ExtractionPage extends StatefulWidget {
  const ExtractionPage({super.key});

  @override
  State<ExtractionPage> createState() => _ExtractionPageState();
}

class _ExtractionPageState extends State<ExtractionPage> {
  String _status = '';
  Map<String, String>? selectedAudio;
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

  // --- MODIFICATION: Separate loading states for each button ---
  bool _isExtracting = false;
  bool _isExtractingDL = false; // New state for the DL button

  List<Map<String, String>> audioList = [];

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

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> loadDropdownData() async {
    final response = await Supabase.instance.client
        .from('audio_watermarked')
        .select('filename, url')
        .order('uploaded_at', ascending: false);

    if (mounted) {
      setState(() {
        audioList = (response)
            .map((item) => {
                  'filename': item['filename']?.toString() ?? '',
                  'url': item['url']?.toString() ?? '',
                })
            .toList();
      });
    }
  }

  String getPublicAudioUrl(String fileName) {
    return Supabase.instance.client.storage
        .from('watermarked')
        .getPublicUrl('audios/$fileName');
  }

  Future<void> _fetchAudioWatermarkDetails(String audioFileName) async {
    try {
      final response = await Supabase.instance.client
          .from('audio_watermarked')
          .select('method, subband, bit, alfass')
          .eq('filename', audioFileName)
          .limit(1)
          .maybeSingle();

      if (response != null && response.isNotEmpty) {
        if (mounted) {
          setState(() {
            _fetchedMethod = response['method'] as String?;
            _fetchedSubband = response['subband'] as int?;
            _fetchedBit = response['bit'] as int?;
            var alfassValue = response['alfass'];
            if (alfassValue is num) {
              _fetchedAlfass = alfassValue.toDouble();
            } else if (alfassValue is String) {
              _fetchedAlfass = double.tryParse(alfassValue);
            } else {
              _fetchedAlfass = null;
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _fetchedMethod = "N/A";
            _fetchedSubband = null;
            _fetchedBit = null;
            _fetchedAlfass = null;
          });
        }
      }
    } catch (e) {
      print("Error fetching watermark details: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching details for $audioFileName.")),
        );
        setState(() {
          _fetchedMethod = "Error";
          _fetchedSubband = null;
          _fetchedBit = null;
          _fetchedAlfass = null;
        });
      }
    }
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

  Future<void> _showConnectionErrorDialog(
      String specificMessage, String serverIpUsed) async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Connection Failed'),
        content: SingleChildScrollView(
          child: Text(
              "$specificMessage\n\nPlease check your network connection and ensure the Server IP address ($serverIpUsed) in settings is correct and the server is running."),
        ),
        actions: [
          TextButton(
            child: const Text('Go to Settings'),
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(dialogContext),
          ),
        ],
      ),
    );
  }

  // In ExtractionPage.dart

  Future<void> _performExtraction({required bool isDLExtraction}) async {
    if (selectedAudio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an audio file.")),
      );
      return;
    }

    // START: Activate the correct loading spinner in the UI
    if (!mounted) return;
    setState(() {
      if (isDLExtraction) {
        _isExtractingDL = true;
      } else {
        _isExtracting = true;
      }
    });
    // END: Activate spinner

    final serverIp = await AppSettings.getServerIp();

    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  "Authentication Error: Not logged in. Please log in again."),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      final userId = session.user.id;

      final endpoint = isDLExtraction ? "extract-dl" : "extract";
      final audioFilename = selectedAudio!['filename'] ?? '';
      final audioUrl = selectedAudio!['url'] ?? '';

      final response = await http
          .post(
            Uri.parse("http://$serverIp:8000/$endpoint"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "filename": audioFilename,
              "audio_url": audioUrl,
              "uploaded_by": userId,
            }),
          )
          .timeout(const Duration(seconds: 10)); // Add a timeout for robustness

      if (!mounted) return; // Check if widget is still active after the request

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result['status'] == 'queued') {
        final taskId = result['task_id'];
        final finalResult = await showQueueDialog(
            context: context,
            taskId: taskId,
            serverIp: serverIp,
            taskTitle: 'Extracting Watermark');

        if (!mounted) return;

        if (finalResult == null || finalResult['status'] != 'success') {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Extraction Failed'),
              content: Text(finalResult?['message'] ??
                  'Task finished but the result could not be found.'),
              actions: [
                TextButton(
                  child: const Text('Close'),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          );
          return;
        }

        final String imageUrl = finalResult['watermark_url'] ?? '';
        final String actualBer =
            (finalResult['ber'] as num?)?.toString() ?? "N/A";

        if (isDLExtraction) {
          final String predictedAttack =
              finalResult['predicted_attack'] ?? 'Not available';
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ExtractionDLResultScreen(
                imageUrl: imageUrl,
                actualBer: actualBer,
                watermark: _fetchedMethod ?? "N/A",
                subband: _fetchedSubband ?? 0,
                bit: _fetchedBit ?? 0,
                alfass: _fetchedAlfass?.toString() ?? "N/A",
                status: 'success',
                predictedAttack: predictedAttack,
              ),
            ),
          );
        } else {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ExtractionResultScreen(
                imageUrl: imageUrl,
                actualBer: actualBer,
                watermark: _fetchedMethod ?? "N/A",
                subband: _fetchedSubband ?? 0,
                bit: _fetchedBit ?? 0,
                alfass: _fetchedAlfass?.toString() ?? "N/A",
                status: 'success',
              ),
            ),
          );
        }
      } else {
        _showConnectionErrorDialog(
            result['message'] ?? "An unknown server error occurred.", serverIp);
      }
    } on TimeoutException {
      _showConnectionErrorDialog(
          "The connection to the server timed out.", serverIp);
    } on SocketException {
      _showConnectionErrorDialog(
          "Could not reach the server. It might be offline or the IP is incorrect.",
          serverIp);
    } catch (e) {
      // Catch any other unexpected errors
      _showConnectionErrorDialog(
          "An unexpected error occurred: ${e.toString()}", serverIp);
    } finally {
      // FINALLY: This block ALWAYS runs, ensuring the UI is never left frozen
      if (mounted) {
        setState(() {
          _isExtracting = false;
          _isExtractingDL = false;
        });
      }
      // END: Deactivate spinners
    }
  }

  @override
  Widget build(BuildContext context) {
    final audioName = selectedAudio != null
        ? path.basename(selectedAudio!['filename'] ?? '')
        : 'No file selected';

    // A flag to disable buttons if any extraction is happening
    final bool isAnyExtractionRunning = _isExtracting || _isExtractingDL;

    return Scaffold(
      backgroundColor: const Color(0xFFF5E8E4),
      appBar: AppBar(
        title: const Text(
          'Extract Watermark',
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
              "Select Watermarked Audio",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF411530),
              ),
            ),
            const SizedBox(height: 5),
            DropdownButtonFormField<Map<String, String>>(
              hint: const Text("Select Audio"),
              value: selectedAudio,
              isExpanded: true,
              items: audioList
                  .map((item) => DropdownMenuItem(
                      value: item, child: Text(item['filename']!)))
                  .toList(),
              onChanged: (value) async {
                if (value == null) return;
                if (!mounted) return;
                setState(() {
                  selectedAudio = value;
                  selectedAudioUrl = getPublicAudioUrl(value['filename']!);
                  _isAudioLoading = true;
                  _position = Duration.zero;
                  _duration = Duration.zero;
                  _fetchedMethod = null;
                  _fetchedSubband = null;
                  _fetchedBit = null;
                  _fetchedAlfass = null;
                });

                await _fetchAudioWatermarkDetails(value['filename']!);

                try {
                  if (selectedAudioUrl != null) {
                    await _player.setUrl(selectedAudioUrl!);
                  }
                } catch (e) {
                  print("Failed to load audio: $e");
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Failed to load audio: $value")),
                    );
                  }
                }
                if (mounted) {
                  setState(() {
                    _isAudioLoading = false;
                  });
                }
              },
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 30),
            if (selectedAudio != null) ...[
              // This is the audio player UI
              Column(
                children: [
                  const Icon(Icons.headphones,
                      size: 50, color: Color(0xFF411530)),
                  const SizedBox(height: 10),
                  const Text(
                    'Selected Audio',
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  Text(
                    audioName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                        ? const SizedBox(
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
                    onPressed: _isAudioLoading || selectedAudioUrl == null
                        ? null
                        : () {
                            if (_isPlaying) {
                              _player.pause();
                            } else {
                              _player.play();
                            }
                          },
                  ),
                  Text(_formatDuration(_duration)),
                ],
              ),
              const Spacer(),
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
            // --- MODIFICATION: Original Extraction Button ---
            ElevatedButton.icon(
              onPressed: isAnyExtractionRunning || selectedAudioUrl == null
                  ? null
                  : () => _performExtraction(isDLExtraction: false),
              icon: _isExtracting // Use the original loading state
                  ? Container(
                      width: 24,
                      height: 24,
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  : const Icon(Icons.find_in_page),
              label:
                  Text(_isExtracting ? 'Extracting...' : 'Extract Watermark'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E2A4D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12), // Spacing between buttons

            // --- NEW: Deep Learning Extraction Button ---
            ElevatedButton.icon(
              onPressed: isAnyExtractionRunning || selectedAudioUrl == null
                  ? null
                  // Call the generic function with the DL flag
                  : () => _performExtraction(isDLExtraction: true),
              icon: _isExtractingDL // Use the new loading state
                  ? Container(
                      width: 24,
                      height: 24,
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    )
                  // A new icon for the DL button
                  : const Icon(Icons.psychology_alt_outlined),
              label: Text(_isExtractingDL
                  ? 'Extracting...'
                  : 'Extract with Deep Learning'),
              style: ElevatedButton.styleFrom(
                // A slightly different color to distinguish the button
                backgroundColor: const Color(0xFFD1512D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            // --- END NEW BUTTON ---
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
