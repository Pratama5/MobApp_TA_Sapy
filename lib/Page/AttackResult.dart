import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class AttackResult extends StatefulWidget {
  final String originalAudio;
  final String attackedAudio;
  final String attackType;
  final String attackParam;

  const AttackResult({
    super.key,
    required this.originalAudio,
    required this.attackedAudio,
    required this.attackType,
    required this.attackParam,
  });

  @override
  State<AttackResult> createState() => _AttackResultState();
}

class _AttackResultState extends State<AttackResult> {
  late AudioPlayer _originalPlayer;
  late AudioPlayer _attackedPlayer;

  Duration _originalDuration = Duration.zero;
  Duration _attackedDuration = Duration.zero;
  Duration _originalPosition = Duration.zero;
  Duration _attackedPosition = Duration.zero;

  @override
  void initState() {
    super.initState();
    _originalPlayer = AudioPlayer();
    _attackedPlayer = AudioPlayer();
    _loadPlayers();
  }

  Future<void> _loadPlayers() async {
    await _originalPlayer.setAsset('assets/audio/${widget.originalAudio}');
    await _attackedPlayer.setAsset('assets/audio/${widget.attackedAudio}');

    _originalPlayer.durationStream.listen((d) {
      if (d != null) setState(() => _originalDuration = d);
    });
    _attackedPlayer.durationStream.listen((d) {
      if (d != null) setState(() => _attackedDuration = d);
    });

    _originalPlayer.positionStream.listen((p) {
      setState(() => _originalPosition = p);
    });
    _attackedPlayer.positionStream.listen((p) {
      setState(() => _attackedPosition = p);
    });
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
    required Duration duration,
    required Duration position,
    required void Function(double) onChanged,
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
        const Center(
          child: Icon(Icons.headphones, size: 40, color: Color(0xFF411530)),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            filename,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF411530),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFFEEECEC),
            inactiveTrackColor: const Color(0xFFEEECEC),
            thumbColor: Colors.deepOrange,
            overlayColor: Colors.deepOrange.withOpacity(0.3),
          ),
          child: Slider(
            min: 0,
            max: duration.inSeconds.toDouble(),
            value: position.inSeconds
                .toDouble()
                .clamp(0.0, duration.inSeconds.toDouble()),
            onChanged: onChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(position)),
            Text(_formatDuration(duration)),
          ],
        ),
        Center(
          child: IconButton(
            icon: Icon(player.playing ? Icons.pause : Icons.play_arrow),
            iconSize: 32,
            onPressed: () {
              player.playing ? player.pause() : player.play();
            },
          ),
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
        title: const Text(
          'Attack Result',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: const Color(0xFFF5E8E4),
        foregroundColor: const Color(0xFF411530),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildPlayer(
              player: _originalPlayer,
              filename: widget.originalAudio,
              titleLabel: 'Watermarked Audio',
              duration: _originalDuration,
              position: _originalPosition,
              onChanged: (val) {
                _originalPlayer.seek(Duration(seconds: val.toInt()));
              },
            ),
            const Divider(height: 40, color: Colors.grey),
            _buildPlayer(
              player: _attackedPlayer,
              filename: widget.attackedAudio,
              titleLabel: 'Attacked Audio',
              duration: _attackedDuration,
              position: _attackedPosition,
              onChanged: (val) {
                _attackedPlayer.seek(Duration(seconds: val.toInt()));
              },
            ),
            const SizedBox(height: 24),
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
              onPressed: () => Navigator.pushNamed(context, '/extract'),
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
