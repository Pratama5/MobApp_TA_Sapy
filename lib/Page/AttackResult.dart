import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AttackResult extends StatefulWidget {
  final String originalAudioName;
  final String originalAudioUrl;
  final String attackedAudioName;
  final String attackedAudioUrl;
  final String attackType;
  final String attackParam;

  const AttackResult({
    super.key,
    required this.originalAudioName,
    required this.originalAudioUrl,
    required this.attackedAudioName,
    required this.attackedAudioUrl,
    required this.attackType,
    required this.attackParam,
  });

  @override
  State<AttackResult> createState() => _AttackResultState();
}

class _AttackResultState extends State<AttackResult> {
  late AudioPlayer _originalPlayer;
  late AudioPlayer _attackedPlayer;

  // Loading states for each player
  bool _isOriginalLoading = true;
  bool _isAttackedLoading = true;

  @override
  void initState() {
    super.initState();
    _originalPlayer = AudioPlayer();
    _attackedPlayer = AudioPlayer();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    try {
      // Load original audio from URL
      await _originalPlayer.setUrl(widget.originalAudioUrl);
      if (mounted) setState(() => _isOriginalLoading = false);
    } catch (e) {
      print("Error loading original audio: $e");
      if (mounted) {
        setState(() => _isOriginalLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to load original audio.")));
      }
    }

    try {
      // Load attacked audio from URL
      await _attackedPlayer.setUrl(widget.attackedAudioUrl);
      if (mounted) setState(() => _isAttackedLoading = false);
    } catch (e) {
      print("Error loading attacked audio: $e");
      if (mounted) {
        setState(() => _isAttackedLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to load attacked audio.")));
      }
    }
  }

  @override
  void dispose() {
    _originalPlayer.dispose();
    _attackedPlayer.dispose();
    super.dispose();
  }

  Widget _buildPlayer({
    required AudioPlayer player,
    required String filename,
    required String titleLabel,
    required bool isLoading,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titleLabel,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: Color(0xFF411530),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Icon(Icons.headphones, size: 40, color: Color(0xFF411530)),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            filename,
            style: const TextStyle(fontSize: 14, color: Color(0xFF411530)),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        // StreamBuilder to reactively build the player UI
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (context, snapshot) {
            final playerState = snapshot.data;
            final processingState = playerState?.processingState;
            final playing = playerState?.playing ?? false;

            if (isLoading ||
                processingState == ProcessingState.loading ||
                processingState == ProcessingState.buffering) {
              return const Center(child: CircularProgressIndicator());
            }

            return Column(
              children: [
                StreamBuilder<Duration>(
                  stream: player.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final duration = player.duration ?? Duration.zero;
                    return Slider(
                      min: 0,
                      max: duration.inSeconds.toDouble(),
                      value: position.inSeconds
                          .toDouble()
                          .clamp(0.0, duration.inSeconds.toDouble()),
                      onChanged: (val) {
                        player.seek(Duration(seconds: val.toInt()));
                      },
                      activeColor: Colors.redAccent,
                    );
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    StreamBuilder<Duration>(
                        stream: player.positionStream,
                        builder: (context, snapshot) => Text(
                            _formatDuration(snapshot.data ?? Duration.zero))),
                    Text(_formatDuration(player.duration ?? Duration.zero)),
                  ],
                ),
                Center(
                  child: IconButton(
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                    iconSize: 32,
                    onPressed: () => playing ? player.pause() : player.play(),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5E8E4),
      appBar: AppBar(
        title: const Text('Attack Result',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        backgroundColor: const Color(0xFFF5E8E4),
        foregroundColor: const Color(0xFF411530),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildPlayer(
              player: _originalPlayer,
              filename: widget.originalAudioName,
              titleLabel: 'Original Watermarked Audio',
              isLoading: _isOriginalLoading,
            ),
            const Divider(height: 40, color: Colors.grey),
            _buildPlayer(
              player: _attackedPlayer,
              filename: widget.attackedAudioName,
              titleLabel: 'Attacked Audio',
              isLoading: _isAttackedLoading,
            ),
            const SizedBox(height: 24),
            // Card(
            //   color: Colors.white,
            //   elevation: 2,
            //   shape: RoundedRectangleBorder(
            //       borderRadius: BorderRadius.circular(12)),
            //   child: Padding(
            //     padding: const EdgeInsets.all(16.0),
            //     child: Column(
            //       children: [
            //         Text(
            //           "Attack Applied: ${widget.attackType}",
            //           style: const TextStyle(
            //               fontWeight: FontWeight.bold,
            //               color: Color(0xFF411530),
            //               fontSize: 16),
            //         ),
            //         const SizedBox(height: 4),
            //         Text(
            //           "Parameter: ${widget.attackParam}",
            //           style: const TextStyle(color: Color(0xFF411530)),
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
            Text(
              "Attack: ${widget.attackType}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF411530),
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "Parameter: ${widget.attackParam}",
              style: const TextStyle(
                color: Color(0xFF411530),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamed(context, '/extraction'),
              icon: const Icon(Icons.search),
              label: const Text("Go to Extract Watermark"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E2A4D),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
