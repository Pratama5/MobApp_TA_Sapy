import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:wavemark_app_v1/Etc/bottom_nav.dart';

class AudioScreen extends StatefulWidget {
  final bool isPicker;

  const AudioScreen({super.key, this.isPicker = false});

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isAscending = true;
  final AudioPlayer _player = AudioPlayer();
  String? _currentTitle;
  bool _isPlaying = false;

  final List<Map<String, String>> audioList = [
    {
      'title': 'Beautiful Life',
      'artist': 'Ace of Base',
      'file': 'assets/audio/beautiful_life-ace_of_base.wav',
    },
    {
      'title': 'Evangeline',
      'artist': 'Matthew Sweet',
      'file': 'assets/audio/evangeline-matthew_sweet.wav',
    },
    {
      'title': 'Don\'t Speak',
      'artist': 'No Doubt',
      'file': 'assets/audio/dont_speak-no_doubt.wav',
    },
    {
      'title': 'I Ran So Far Away',
      'artist': 'Flock of Seagulls',
      'file': 'assets/audio/i_ran_so_far_away-flock_of_seagulls.wav',
    },
    {'title': 'Host', 'artist': 'Unknown', 'file': 'assets/audio/host.wav'},
  ];

  void _toggleSort() {
    setState(() => _isAscending = !_isAscending);
  }

  void _playAudio(String path, String title) async {
    try {
      await _player.setAsset(path);
      _player.play();
      setState(() {
        _currentTitle = title;
        _isPlaying = true;
      });
    } catch (e) {
      print('Failed to play audio: $e');
    }
  }

  void _togglePlayPause() {
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
    setState(() => _isPlaying = _player.playing);
  }

  void _confirmDelete(String title) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Hapus Audio"),
        content: Text("Yakin ingin menghapus '$title'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Batal",
              style: TextStyle(color: Color(0xFFD1512D)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: handle hapus dari list jika pakai storage
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text(
              "Hapus",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, String>> filteredList = audioList
        .where(
          (audio) => audio['title']!.toLowerCase().contains(
                _searchQuery.toLowerCase(),
              ),
        )
        .toList();

    filteredList.sort(
      (a, b) => _isAscending
          ? a['title']!.compareTo(b['title']!)
          : b['title']!.compareTo(a['title']!),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5E8E4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: true,
        iconTheme: const IconThemeData(color: Color(0xFF411530)),
        title: const Text(
          'Audio',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF411530),
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${filteredList.length} audio library',
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: 'Search',
                          prefixIcon: const Icon(Icons.search),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: _toggleSort,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Color(0xFFD1512D),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _isAscending
                              ? Icons.sort_by_alpha
                              : Icons.sort_by_alpha_outlined,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: filteredList.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final audio = filteredList[index];
                final path = audio['file']!;
                final title = audio['title']!;
                return ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: const Icon(
                    Icons.music_note,
                    color: Color(0xFFD1512D),
                  ),
                  title: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF411530),
                    ),
                  ),
                  subtitle: Text(audio['artist'] ?? ''),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'download') {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Fitur download belum diimplementasi.",
                            ),
                          ),
                        );
                      } else if (value == 'delete') {
                        _confirmDelete(title);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'download',
                        child: Text('Download'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Hapus')),
                    ],
                  ),
                  onTap: () {
                    if (widget.isPicker) {
                      Navigator.pop(
                        context,
                        path,
                      ); // ✔️ Return ke EmbeddingScreen
                    } else {
                      _playAudio(path, title); // 🎧 Fungsi play
                    }
                  },
                );
              },
            ),
          ),
          if (_currentTitle != null && !widget.isPicker)
            Container(
              color: const Color(0xFF5E2A4D),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.music_note, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _currentTitle!,
                      style: const TextStyle(color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      _player.stop();
                      setState(() {
                        _currentTitle = null;
                        _isPlaying = false;
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                    onPressed: _togglePlayPause,
                  ),
                ],
              ),
            ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(currentRoute: '/library'),
    );
  }
}
