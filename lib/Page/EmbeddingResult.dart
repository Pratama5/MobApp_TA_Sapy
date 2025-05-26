import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class EmbeddingResultScreen extends StatefulWidget {
  final String audioUrl;
  final String keyUrl;
  final String method;
  final int bit;
  final int subband;
  final double alfass;
  final double? snr;

  const EmbeddingResultScreen({
    Key? key,
    required this.audioUrl,
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

  @override
  void initState() {
    super.initState();
    _loadAudio();
  }

  Future<void> _loadAudio() async {
    try {
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
    } catch (e) {
      print("Error loading audio: $e");
    } finally {
      if (!mounted) return;
      setState(() {
        isLoadingAudio = false;
      });
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
          Expanded(child: Text(value)),
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
      appBar: AppBar(title: const Text("Embedding Result")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF5E8E4),
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Watermarked Audio Preview",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              isLoadingAudio
                  ? const Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Row(
                          children: [
                            Text(_formatDuration(_position)),
                            Expanded(
                              child: Slider(
                                value: _position.inSeconds.toDouble(),
                                max: _duration.inSeconds.toDouble() > 0
                                    ? _duration.inSeconds.toDouble()
                                    : 1,
                                onChanged: (value) {
                                  _player
                                      .seek(Duration(seconds: value.toInt()));
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
                                  ? Icons.pause_circle
                                  : Icons.play_circle,
                              size: 48,
                              color: const Color(0xFFD1512D)),
                          onPressed: () async {
                            isPlaying
                                ? await _player.pause()
                                : await _player.play();
                          },
                        ),
                      ],
                    ),
              const SizedBox(height: 20),
              const Text(
                "Embedding Details",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _buildInfoRow("Method", widget.method),
              _buildInfoRow("Bit", widget.bit.toString()),
              _buildInfoRow("Subband", widget.subband.toString()),
              _buildInfoRow("Alfass", widget.alfass.toString()),
              _buildInfoRow(
                  "SNR", widget.snr != null ? "${widget.snr} dB" : "N/A"),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implement extraction navigation
                    },
                    icon: const Icon(Icons.skip_next, color: Colors.white),
                    label: const Text("To Extraction",
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD1512D),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 20),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/home', (route) => false);
                    },
                    icon: const Icon(
                      Icons.home,
                      color: Colors.white,
                    ),
                    label: const Text("Home",
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD1512D),
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 20),
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
