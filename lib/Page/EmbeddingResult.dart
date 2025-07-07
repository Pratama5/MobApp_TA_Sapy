import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher_string.dart';

class EmbeddingResultScreen extends StatefulWidget {
  final String audioUrl;
  final String audioFilename; // <-- ADDED: To store and display the filename
  final String keyUrl;
  final String method;
  final int bit;
  final int subband;
  final double alfass;
  final double? snr;

  const EmbeddingResultScreen({
    Key? key,
    required this.audioUrl,
    required this.audioFilename, // <-- ADDED: Make it required
    required this.keyUrl,
    required this.method,
    required this.bit,
    required this.subband,
    required this.alfass,
    this.snr,
  }) : super(key: key);

  @override
  State<EmbeddingResultScreen> createState() => _EmbeddingResultScreenState();
}

class _EmbeddingResultScreenState extends State<EmbeddingResultScreen> {
  final AudioPlayer _player = AudioPlayer();
  bool isLoadingAudio = true;
  bool isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  static const String _downloadKeyOption = 'download_key';
  static const String _downloadAudioOption = 'download_audio';

  @override
  void initState() {
    super.initState();
    _loadAudio();
  }

  Future<void> _loadAudio() async {
    setState(() {
      // Ensure loading starts true
      isLoadingAudio = true;
    });
    try {
      if (widget.audioUrl.isEmpty) {
        print("Error: Audio URL is empty.");
        if (mounted) setState(() => isLoadingAudio = false);
        return;
      }
      await _player.setUrl(widget.audioUrl);

      _player.durationStream.listen((d) {
        if (!mounted || d == null) return;
        setState(() => _duration = d);
      });

      _player.positionStream.listen((p) {
        if (!mounted) return;
        setState(() => _position = p);
      });

      _player.playerStateStream.listen((state) {
        if (!mounted) return;
        setState(() => isPlaying = state.playing);
      });

      await _player.load();
    } catch (e) {
      print("Error loading audio in EmbeddingResultScreen: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoadingAudio = false;
        });
      }
    }
  }

  Future<void> _launchSingleUrl(String? url, String fileTypeDescription) async {
    final scaffoldMessenger =
        ScaffoldMessenger.of(context); // Use the State's context
    if (!mounted) return;

    if (url != null && url.isNotEmpty) {
      try {
        if (await launchUrlString(url)) {
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                  content: Text(
                      "Opening $fileTypeDescription... Please check your browser or downloads.")),
            );
          }
        } else {
          if (mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                  content:
                      Text('Could not launch $fileTypeDescription URL: $url')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
                content: Text('Failed to launch $fileTypeDescription URL: $e')),
          );
        }
      }
    } else {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
              content: Text('$fileTypeDescription URL is missing or invalid.')),
        );
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Widget _buildInfoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(Icons.label, size: 20, color: Colors.grey[700]),
          const SizedBox(width: 8),
          Text(
            "$title:",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Using transparent AppBar with custom back button to match other screens
      backgroundColor:
          const Color(0xFFF5E8E4), // Assuming this is your desired background
      appBar: AppBar(
        title: const Text(
          "Embedding Result",
          style: TextStyle(
            color: Color(0xFF411530), // Matching title color from other pages
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.transparent, // Make AppBar transparent
        elevation: 0, // No shadow
        leading: const BackButton(
            color: Color(0xFFD1512D)), // Custom back button color
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.file_download_outlined, // You can keep this icon
              color: Color(0xFF411530),
            ),
            tooltip: "Download Options",
            onSelected: (String value) async {
              // Make this async
              switch (value) {
                case _downloadKeyOption:
                  await _launchSingleUrl(widget.keyUrl, "key file");
                  break;
                case _downloadAudioOption:
                  // Using widget.audioFilename for a more descriptive message
                  await _launchSingleUrl(
                      widget.audioUrl, "audio file (${widget.audioFilename})");
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: _downloadKeyOption,
                child: Row(
                  children: <Widget>[
                    Icon(Icons.vpn_key_outlined, color: Colors.orange.shade800),
                    const SizedBox(width: 10),
                    const Text('Download Key File'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: _downloadAudioOption,
                child: Row(
                  children: <Widget>[
                    Icon(Icons.audiotrack_outlined,
                        color: Colors.blue.shade700),
                    const SizedBox(width: 10),
                    const Text('Download Audio File'),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFF411530)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Penjelasan SNR "),
                  content: const Text(
                      "🔸 SNR (Signal-to-Noise Ratio): mengukur rasio kualitas sinyal terhadap noise. "
                      "Semakin tinggi nilainya, semakin baik kualitas audio.\n\n"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Tutup"),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors
                .white, // Changed to white for better contrast with F5E8E4 background
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [
              BoxShadow(
                  blurRadius: 6, color: Colors.black26, offset: Offset(0, 2))
            ], // Slightly adjusted shadow
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Watermarked Audio Preview",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF411530)),
              ),
              const SizedBox(height: 4), // Reduced space
              // --- ADDED: Displaying the audio filename ---
              Text(
                widget.audioFilename,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic),
                overflow: TextOverflow.ellipsis,
              ),
              // --- End of added filename ---
              const SizedBox(height: 10),
              isLoadingAudio
                  ? const Center(
                      child: Padding(
                      padding: EdgeInsets.symmetric(
                          vertical: 30.0), // Add some padding
                      child:
                          CircularProgressIndicator(color: Color(0xFFD1512D)),
                    ))
                  : Column(
                      children: [
                        if (_player.duration != null) ...[
                          // Only show player if duration is available
                          Row(
                            children: [
                              Text(_formatDuration(_position)),
                              Expanded(
                                child: Slider(
                                  value: _position.inMilliseconds
                                      .toDouble()
                                      .clamp(0.0,
                                          _duration.inMilliseconds.toDouble()),
                                  max: _duration.inMilliseconds.toDouble() > 0
                                      ? _duration.inMilliseconds.toDouble()
                                      : 1.0, // Ensure max is not 0
                                  onChanged: (value) {
                                    _player.seek(
                                        Duration(milliseconds: value.toInt()));
                                  },
                                  activeColor: const Color(0xFFD1512D),
                                  inactiveColor: Colors.grey[300],
                                ),
                              ),
                              Text(_formatDuration(_duration)),
                            ],
                          ),
                          IconButton(
                            icon: Icon(
                                isPlaying
                                    ? Icons.pause_circle_filled // Changed icon
                                    : Icons.play_circle_filled, // Changed icon
                                size: 52, // Slightly larger
                                color: const Color(0xFFD1512D)),
                            onPressed: () async {
                              if (_player.processingState ==
                                  ProcessingState.completed) {
                                await _player.seek(Duration.zero);
                                await _player.play();
                              } else if (isPlaying) {
                                await _player.pause();
                              } else {
                                await _player.play();
                              }
                            },
                          ),
                        ] else
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 30.0),
                            child: Text(
                                "Audio preview not available or failed to load.",
                                textAlign: TextAlign.center),
                          )
                      ],
                    ),
              const SizedBox(height: 20),
              const Text(
                "Embedding Details",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF411530)),
              ),
              const SizedBox(height: 10),
              _buildInfoRow("Method", widget.method),
              _buildInfoRow("Bit", widget.bit.toString()),
              _buildInfoRow("Subband", widget.subband.toString()),
              _buildInfoRow(
                  "Alfass", widget.alfass.toStringAsFixed(3)), // Format alfass
              _buildInfoRow(
                  "SNR",
                  widget.snr != null
                      ? "${widget.snr?.toStringAsFixed(2)} dB"
                      : "N/A"), // Format SNR
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    // Make button take more width if needed, or use MainAxisAlignment.center for single button
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamed(
                          context,
                          '/extraction', // Assuming this is a defined route
                        );
                      },
                      icon: const Icon(Icons.find_in_page_outlined,
                          color: Colors.white), // Changed icon
                      label: const Text("To Extraction",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD1512D),
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 20), // Adjusted padding
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10)) // Added shape
                          ),
                    ),
                  ),
                  // The "Home" button was in one version you provided, I'll keep it for now.
                  // If you only want one button, remove the SizedBox and the second ElevatedButton.
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(context, '/',
                            (route) => false); // Navigate to Home ('/')
                      },
                      icon: const Icon(
                        Icons.home_outlined, // Changed icon
                        color: Colors.white,
                      ),
                      label: const Text("Home",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Color(
                              0xFF5E2A4D), // Different color for distinction
                          padding: const EdgeInsets.symmetric(
                              vertical: 14, horizontal: 20), // Adjusted padding
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(10)) // Added shape
                          ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
