import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:wavemark_app_v1/Etc/app_settings.dart';
import 'package:wavemark_app_v1/Etc/bottom_nav.dart';
import 'package:wavemark_app_v1/Etc/SettingsPage.dart';
import 'package:wavemark_app_v1/Page/AttackResult.dart';
import 'package:wavemark_app_v1/Etc/QueueMonitor.dart';

// Data class to hold the structured attack information
class Attack {
  final String name; // e.g., "Low Pass Filter"
  final Map<String, List<int>> params; // e.g., {"cutoff 3 kHz": [1, 3000]}

  Attack({required this.name, required this.params});
}

class AttackPage extends StatefulWidget {
  const AttackPage({super.key});

  @override
  State<AttackPage> createState() => _AttackPageState();
}

class AudioFile {
  final String filename;
  final String url;

  AudioFile({required this.filename, required this.url});
}

class _AttackPageState extends State<AttackPage> {
  // --- State Variables ---
  bool _isApplyingAttack = false;
  bool _isAudioLoading = false;

  // Selected values from dropdowns
  Map<String, String>? selectedAudioFile;
  String? selectedAudioUrl;
  Attack? selectedAttack;
  String? selectedParamName; // The user-friendly parameter name
  AudioFile? audioToAttack;
  int? attackType;
  int? attackParam;

  // Data lists for dropdowns
  List<Map<String, String>> audioList = [];

  // Audio Player State
  late AudioPlayer _player;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isPlaying = false;

  // --- Data Structures for Attack Mapping ---
  final List<Attack> attackOptions = [
    Attack(name: 'Low Pass Filter', params: {
      'Cutoff 3 kHz': [1, 3000],
      'Cutoff 6 kHz': [1, 6000],
      'Cutoff 9 kHz': [1, 9000],
    }),
    Attack(name: 'Requantization', params: {
      '8-bit depth': [3, 8],
    }),
    Attack(name: 'Additive Noise', params: {
      'SNR 10 dB': [5, 10],
      'SNR 20 dB': [5, 20],
      'SNR 30 dB': [5, 30],
    }),
    Attack(name: 'Resampling', params: {
      '44.1 → 11.025 kHz': [6, 1],
      '44.1 → 16 kHz': [6, 2],
      '44.1 → 22.05 kHz': [6, 3],
      '44.1 → 24 kHz': [6, 4],
    }),
    Attack(name: 'MP3 Compression', params: {
      '32 kbps': [13, 32],
      '64 kbps': [13, 64],
      '96 kbps': [13, 96],
      '128 kbps': [13, 128],
      '192 kbps': [13, 192],
    }),
  ];

  @override
  void initState() {
    super.initState();
    _loadAudioFiles();
    _player = AudioPlayer();

    _player.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });
    _player.durationStream.listen((dur) {
      if (mounted && dur != null) setState(() => _duration = dur);
    });
    _player.playerStateStream.listen((state) {
      if (mounted) setState(() => _isPlaying = state.playing);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  // --- Data Fetching ---
  Future<void> _loadAudioFiles() async {
    final response = await Supabase.instance.client
        .from('audio_watermarked')
        .select('filename, url')
        .filter('source', 'is', null) // CORRECT way to check for NULL
        .order('uploaded_at', ascending: false);

    if (mounted) {
      setState(() {
        audioList = (response as List)
            .map((item) => {
                  'filename': item['filename']?.toString() ?? '',
                  'url': item['url']?.toString() ?? '',
                })
            .toList();
      });
    }
  }

// In AttackPage.dart

  Future<void> _applyAttack() async {
    if (selectedAudioFile == null ||
        selectedAttack == null ||
        selectedParamName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select all options.")),
      );
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not authenticated.")),
      );
      return;
    }

    setState(() => _isApplyingAttack = true);

    final List<int>? attackValues = selectedAttack!.params[selectedParamName];
    if (attackValues == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid attack parameter selected.")),
      );
      setState(() => _isApplyingAttack = false);
      return;
    }

    final String serverIp = await AppSettings.getServerIp();
    final uri = Uri.parse("http://$serverIp:8000/attack");

    final payload = {
      "audio_url": selectedAudioFile!['url'],
      "original_filename": selectedAudioFile!['filename'],
      "attack_type": attackValues[0],
      "attack_param": attackValues[1],
      "uploaded_by": userId,
    };

    try {
      final response = await http
          .post(
            uri,
            headers: {
              "Content-Type": "application/json",
              "Authorization":
                  "Bearer ${Supabase.instance.client.auth.currentSession?.accessToken}",
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 300));

      final result = jsonDecode(response.body);

      if (response.statusCode == 200 && result["status"] == "queued") {
        final taskId = result['task_id'];
        final finalResult = await showQueueDialog(
            context: context,
            taskId: taskId,
            serverIp: serverIp,
            taskTitle: 'Applying Attack');

        if (finalResult == null || finalResult['status'] != 'success') {
          _showConnectionErrorDialog(
              "Attack task finished, but result could not be found.", serverIp);
          return;
        }

        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AttackResult(
                originalAudioName: selectedAudioFile!['filename']!,
                originalAudioUrl: selectedAudioFile!['url']!,
                attackedAudioName: finalResult["attacked_filename"],
                attackedAudioUrl: finalResult["attacked_audio_url"],
                attackType: selectedAttack!.name,
                attackParam: selectedParamName!,
              ),
            ),
          );
          _resetSelections();
        }
      } else if (response.statusCode == 200 && result["status"] == "success") {
        if (mounted) {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AttackResult(
                originalAudioName: selectedAudioFile!['filename']!,
                originalAudioUrl: selectedAudioFile!['url']!,
                attackedAudioName: result["attacked_filename"],
                attackedAudioUrl: result["attacked_audio_url"],
                attackType: selectedAttack!.name,
                attackParam: selectedParamName!,
              ),
            ),
          );
          _resetSelections();
        }
      } else {
        _showConnectionErrorDialog(
            result["message"] ?? "An unknown server error occurred.", serverIp);
      }
    } on TimeoutException {
      _showConnectionErrorDialog(
          "The connection to the server timed out.", serverIp);
    } on SocketException catch (e) {
      _showConnectionErrorDialog(
          "Could not reach the server. (Details: ${e.message})", serverIp);
    } catch (e) {
      _showConnectionErrorDialog(
          "An unexpected error occurred: ${e.toString()}", serverIp);
    } finally {
      if (mounted) {
        setState(() => _isApplyingAttack = false);
      }
    }
  }

  void _resetSelections() {
    setState(() {
      selectedAudioFile = null;
      selectedAudioUrl = null;
      selectedAttack = null;
      selectedParamName = null;
      _position = Duration.zero;
      _duration = Duration.zero;
      _player.stop();
    });
  }

  void _showAttackInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFF5E8E4),
        title: const Text('Attack Explanation',
            style: TextStyle(color: Color(0xFF411530))),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Attacks are audio modifications such as filters, noise, or compression that can damage the watermark.',
                style: TextStyle(color: Color(0xFF411530)),
              ),
              SizedBox(height: 12),
              Text('• Low Pass Filter: Removes high frequencies.'),
              // Text('• Band Pass Filter: Menyaring frekuensi tertentu.'),
              Text('• Requantization: Reduces the bit-depth of the audio.'),
              Text('• Additive Noise: Adds noise interference.'),
              Text('• Resampling: Change the audio sampling rate.'),
              // Text('• Time Scale Modification: Mengubah durasi audio.'),
              // Text('• Linear Speed Change: Mempercepat atau memperlambat.'),
              // Text('• Pitch Shifting: Mengubah nada suara.'),
              // Text('• Equalizer: Mengatur kekuatan frekuensi.'),
              // Text('• Echo: Menambahkan gema pada audio.'),
              Text('•MP3 Compression: Compress audio to MP3.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Close', style: TextStyle(color: Color(0xFF5E2A4D))),
          ),
        ],
      ),
    );
  }

  // --- UI and Widgets ---
  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFF411530), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _showConnectionErrorDialog(
      String specificMessage, String serverIpUsed) async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Failed'),
        content: Text(
            "$specificMessage\n\nPlease check your network and ensure the server IP ($serverIpUsed) is correct."),
        actions: [
          TextButton(
            child: const Text('Go to Settings'),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SettingsPage()));
            },
          ),
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5E8E4),
      appBar: AppBar(
        title: const Text('Apply Attack',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF411530))),
        backgroundColor: const Color(0xFFF5E8E4),
        foregroundColor: const Color(0xFF411530),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showAttackInfo(context),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Audio Selection ---
            const Text('Select Watermarked Audio',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF411530))),
            const SizedBox(height: 6),
            DropdownButtonFormField<Map<String, String>>(
              value: selectedAudioFile,
              isExpanded: true,
              decoration: _inputDecoration("Select an original audio file"),
              items: audioList
                  .map((audio) => DropdownMenuItem(
                      value: audio, child: Text(audio['filename']!)))
                  .toList(),
              onChanged: (val) async {
                if (val == null) return;
                setState(() {
                  selectedAudioFile = val;
                  selectedAudioUrl = val['url'];
                  audioToAttack = AudioFile(
                    filename: val['filename']!,
                    url: val['url']!,
                  );
                  _isAudioLoading = true;
                  _position = Duration.zero;
                  _duration = Duration.zero;
                });
                try {
                  await _player.setUrl(selectedAudioUrl!);
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Failed to load audio: $e")));
                }
                if (mounted) setState(() => _isAudioLoading = false);
              },
            ),
            const SizedBox(height: 20),

            // --- Audio Player UI ---
            if (selectedAudioFile != null) ...[
              const Center(
                  child: Icon(Icons.headphones,
                      size: 48, color: Color(0xFF411530))),
              const SizedBox(height: 8),
              Center(
                  child: Text(selectedAudioFile!['filename']!,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF411530)))),
              const SizedBox(height: 16),
              Slider(
                value: _position.inMilliseconds.toDouble(),
                max: _duration.inMilliseconds > 0
                    ? _duration.inMilliseconds.toDouble()
                    : 1,
                onChanged: (value) =>
                    _player.seek(Duration(milliseconds: value.toInt())),
                activeColor: Colors.redAccent,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatDuration(_position)),
                    IconButton(
                        icon: _isAudioLoading
                            ? const CircularProgressIndicator()
                            : Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
                                size: 32),
                        onPressed: _isAudioLoading
                            ? null
                            : () =>
                                _isPlaying ? _player.pause() : _player.play()),
                    Text(_formatDuration(_duration)),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // --- Attack Type Selection ---
            const Text('Select Attack Type',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF411530))),
            const SizedBox(height: 6),
            DropdownButtonFormField<Attack>(
              value: selectedAttack,
              isExpanded: true,
              decoration: _inputDecoration("Select an attack type"),
              items: attackOptions
                  .map((attack) =>
                      DropdownMenuItem(value: attack, child: Text(attack.name)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  selectedAttack = val;
                  selectedParamName = null;
                });
              },
            ),
            const SizedBox(height: 20),

            // --- Attack Parameter Selection ---
            if (selectedAttack != null) ...[
              const Text('Select Attack Parameter',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF411530))),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: selectedParamName,
                isExpanded: true,
                decoration: _inputDecoration("Select a parameter"),
                items: selectedAttack!.params.keys
                    .map((paramName) => DropdownMenuItem(
                        value: paramName, child: Text(paramName)))
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    selectedParamName = val;

                    final pair = selectedAttack?.params[val];
                    if (pair != null && pair.length == 2) {
                      attackType = pair[0];
                      attackParam = pair[1];
                    }
                  });
                },
              ),
            ],
            const SizedBox(height: 32),

            // --- Apply Attack Button ---
            ElevatedButton.icon(
              onPressed: _isApplyingAttack ? null : _applyAttack,
              icon: _isApplyingAttack
                  ? Container(
                      width: 24,
                      height: 24,
                      padding: const EdgeInsets.all(2.0),
                      child: const CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 3),
                    )
                  : const Icon(Icons.whatshot),
              label: Text(_isApplyingAttack ? "Applying..." : "Apply Attack"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E2A4D),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentRoute: '/attack'),
    );
  }
}
