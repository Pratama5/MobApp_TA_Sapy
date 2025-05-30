import 'dart:convert';
import 'dart:io'; // For SocketException, TimeoutException (if adding timeout)
import 'dart:async'; // For TimeoutException

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:wavemark_app_v1/Page/ExtractionResult.dart';
import 'package:wavemark_app_v1/etc/app_settings.dart';
import 'package:wavemark_app_v1/Etc/SettingsPage.dart';

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
    if (mounted) {
      // Check if mounted
      setState(() {
        audioList = audios;
      });
    }
  }

  String getPublicAudioUrl(String fileName) {
    return Supabase.instance.client.storage
        .from('watermarked')
        .getPublicUrl('audios/$fileName');
  }

  Future<void> _fetchAudioWatermarkDetails(String audioFileName) async {
    // ... (your existing _fetchAudioWatermarkDetails method is fine) ...
    try {
      final response = await Supabase.instance.client
          .from('audio_watermarked')
          .select('method, subband, bit, alfass')
          .eq('filename', audioFileName)
          .limit(1)
          .maybeSingle();

      if (response != null && response.isNotEmpty) {
        // Check if response is not null and not empty
        if (mounted) {
          setState(() {
            _fetchedMethod = response['method'] as String?;
            _fetchedSubband = response['subband'] as int?;
            _fetchedBit = response['bit'] as int?;
            // Ensure alfass is correctly parsed as double
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
        print('No details found for $audioFileName in audio_watermarked');
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

  Future<List<String>> fetchFileNamesFromSupabase(String folderPath) async {
    // ... (your existing fetchFileNamesFromSupabase method is fine) ...
    final response = await Supabase.instance.client.storage
        .from('watermarked')
        .list(path: folderPath);

    if (response.isEmpty) return [];

    final filenames = response
        .where(
            (item) => item.name.endsWith('.wav') || item.name.endsWith('.mp3'))
        .map((item) => item.name)
        .toList();

    return filenames;
  }

  String _formatDuration(Duration d) {
    // ... (your existing _formatDuration method is fine) ...
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  InputDecoration _inputDecoration() {
    // ... (your existing _inputDecoration method is fine) ...
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
  // ... inside _ExtractionPageState class ...

  Future<void> _showConnectionErrorDialog(
      String specificMessage, String serverIpUsed) async {
    if (!mounted) return; // Check if the widget is still in the tree

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
              Navigator.pop(dialogContext); // Close this dialog first
              Navigator.push(
                context, // Use the original page's context for navigation
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

  Future<void> _startExtraction() async {
    if (selectedAudioUrl == null || selectedAudio == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select an audio file first.")),
      );
      return;
    }

    setState(() => _isExtracting = true);

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("User not authenticated. Cannot perform extraction.")),
      );
      if (mounted) setState(() => _isExtracting = false); // Check mounted
      return;
    }

    // --- FETCH SERVER IP FROM AppSettings ---
    final String serverIp = await AppSettings.getServerIp();
    // --- END FETCH SERVER IP ---

    final uri = Uri.parse("http://$serverIp:8000/extract"); // Use dynamic IP

    final payload = {
      "audio_url": selectedAudioUrl,
      "filename": selectedAudio,
      "uploaded_by": userId,
    };

    // Capture ScaffoldMessenger before async calls if context might change
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      print("Sending extraction request to $uri with payload: $payload");
      final response = await http
          .post(
            uri,
            headers: {"Content-Type": "application/json"},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30)); // Keep or adjust timeout

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result["status"] == "success") {
          final String watermarkUrl = result["watermark_url"];
          final dynamic ber = result["ber"];
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ExtractionResultScreen(
                  imageUrl: watermarkUrl,
                  watermark: _fetchedMethod ?? "N/A",
                  subband: _fetchedSubband ?? 0,
                  bit: _fetchedBit ?? 0,
                  alfass: _fetchedAlfass?.toString() ?? "N/A",
                  actualBer: ber?.toString() ?? "N/A",
                  status: "success",
                ),
              ),
            );
          }
        } else {
          // Server responded with 200 OK, but a logical error in the payload
          String serverErrorMessage =
              result["message"] ?? 'Unknown server error';
          print("Server logic error during extraction: $serverErrorMessage");
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text("Extraction Error: $serverErrorMessage")),
          );
        }
      } else {
        // HTTP status code is not 200
        String httpErrorMessage = "Server error: ${response.statusCode}.";
        if (response.body.isNotEmpty) {
          try {
            final errorResult = jsonDecode(response.body);
            httpErrorMessage +=
                " Details: ${errorResult['message'] ?? response.body}";
          } catch (_) {
            httpErrorMessage += " Details: ${response.body}";
          }
        }
        print(httpErrorMessage);

        if (response.statusCode == 404 || response.statusCode == 503) {
          // These often indicate server/IP issues
          _showConnectionErrorDialog(
              "Server at $serverIp returned ${response.statusCode}. It might be an incorrect endpoint or the server is temporarily down.",
              serverIp);
        } else {
          // Other HTTP errors (e.g., 400, 401, 500 from server processing)
          _showConnectionErrorDialog(
              // Or a more generic error dialog
              "An error occurred (HTTP ${response.statusCode}). Details: ${response.body.isNotEmpty ? response.body : 'No additional details.'}",
              serverIp);
        }
      }
    } on TimeoutException catch (e) {
      print("Extraction timed out connecting to $serverIp: $e");
      _showConnectionErrorDialog(
          "The connection to the server at $serverIp timed out.", serverIp);
    } on SocketException catch (e) {
      print("Extraction SocketException for $serverIp: $e");
      _showConnectionErrorDialog(
          "Could not reach the server at $serverIp. It might be offline or the IP is incorrect. (Details: ${e.message})",
          serverIp);
    } on http.ClientException catch (e) {
      print("Extraction ClientException for $serverIp: $e");
      _showConnectionErrorDialog(
          "A network client error occurred when trying to reach $serverIp. (Details: ${e.message})",
          serverIp);
    } catch (e) {
      // Generic catch-all
      print("Generic extraction error for $serverIp: $e");
      _showConnectionErrorDialog(
          "An unexpected error occurred while trying to connect to $serverIp.",
          serverIp);
    }

    if (mounted) setState(() => _isExtracting = false);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ... (your existing build method is fine, ensure selectedAudio handling is robust) ...
    final audioName = selectedAudio != null
        ? path.basename(selectedAudio!)
        : 'No file selected';

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
            DropdownButtonFormField<String>(
              hint: const Text("Select Audio"),
              value: selectedAudio,
              isExpanded: true,
              items: audioList
                  .map((audio) =>
                      DropdownMenuItem(value: audio, child: Text(audio)))
                  .toList(),
              onChanged: (value) async {
                if (value == null) return;
                // Use mounted check before async gap for setState
                if (!mounted) return;
                setState(() {
                  selectedAudio = value;
                  selectedAudioUrl = getPublicAudioUrl(value);
                  _isAudioLoading = true;
                  _position = Duration.zero;
                  _duration = Duration.zero;

                  _fetchedMethod = null;
                  _fetchedSubband = null;
                  _fetchedBit = null;
                  _fetchedAlfass = null;
                });

                await _fetchAudioWatermarkDetails(value);

                try {
                  if (selectedAudioUrl != null) {
                    await _player.setUrl(selectedAudioUrl!);
                  }
                } catch (e) {
                  print("Failed to load audio: $e");
                  if (mounted) {
                    // Check mounted
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Failed to load audio: $value")),
                    );
                  }
                }
                if (mounted) {
                  // Check mounted
                  setState(() {
                    _isAudioLoading = false;
                  });
                }
              },
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 30),
            if (selectedAudio != null) ...[
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
            ElevatedButton.icon(
              onPressed: _isExtracting ||
                      selectedAudio == null ||
                      selectedAudioUrl == null
                  ? null
                  : _startExtraction,
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
                  : const Icon(Icons.find_in_page),
              label:
                  Text(_isExtracting ? 'Extracting...' : 'Extract Watermark'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E2A4D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold), // Ensure consistent style
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
