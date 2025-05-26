import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class LibraryAudioPage extends StatefulWidget {
  const LibraryAudioPage({Key? key}) : super(key: key);

  @override
  State<LibraryAudioPage> createState() => _LibraryAudioPageState();
}

class _LibraryAudioPageState extends State<LibraryAudioPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Map<String, dynamic>> audioFiles = [];
  Map<String, int> fileSizes = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchAudioFiles().then((_) => fetchAudioSizes());
  }

  Future<void> fetchAudioFiles() async {
    try {
      final response = await supabase
          .from('audio_files')
          .select('filename, url, uploaded_at')
          .order('uploaded_at', ascending: false);

      print('Supabase audio_files response: $response');

      setState(() {
        audioFiles = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });

      print('Fetched audio count: ${audioFiles.length}');
    } catch (e) {
      setState(() => isLoading = false);
      print('Fetch error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching audio files: $e')),
      );
    }
  }

  Future<void> fetchAudioSizes() async {
    try {
      final files = await supabase.storage.from('media').list(path: 'audios');
      setState(() {
        fileSizes = {
          for (final file in files) file.name: file.metadata?['size'] ?? 0,
        };
      });
    } catch (e) {
      print("Failed to fetch audio file sizes: $e");
    }
  }

  Future<void> downloadAudio(
      String url, String filename, BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? basePath = prefs.getString('download_folder');

      if (basePath == null) {
        final dir = await getApplicationDocumentsDirectory();
        basePath = dir.path;
      }

      final path = '$basePath/$filename';

      final dio = Dio();
      final response = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      final file = File(path);
      await file.writeAsBytes(Uint8List.fromList(response.data!));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Downloaded to: $path")),
      );
    } catch (e) {
      print("Download error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Download failed: $e")),
      );
    }
  }

  void showAudioPlayerModal(BuildContext context, String title, String url) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final player = AudioPlayer();

        return FutureBuilder<void>(
          future: player.setUrl(url),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }

            player.play(); // now inside the visible tree

            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 20),
                  StreamBuilder<Duration>(
                    stream: player.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final total = player.duration ?? Duration.zero;
                      return Column(
                        children: [
                          Slider(
                            min: 0,
                            max: total.inMilliseconds.toDouble(),
                            value: position.inMilliseconds
                                .clamp(0, total.inMilliseconds)
                                .toDouble(),
                            onChanged: (value) {
                              player
                                  .seek(Duration(milliseconds: value.toInt()));
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(_formatDuration(position)),
                              Text(_formatDuration(total)),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  StreamBuilder<PlayerState>(
                    stream: player.playerStateStream,
                    builder: (context, snapshot) {
                      final state = snapshot.data;
                      final isPlaying = state?.playing ?? false;
                      final isCompleted =
                          state?.processingState == ProcessingState.completed;

                      return IconButton(
                        iconSize: 48,
                        icon: Icon(
                          isCompleted
                              ? Icons.replay
                              : isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                        ),
                        onPressed: () {
                          if (isCompleted) {
                            player.seek(Duration.zero);
                            player.play();
                          } else if (isPlaying) {
                            player.pause();
                          } else {
                            player.play();
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      // Safely dispose after the modal closes
      AudioPlayer().dispose();
    });
  }

  void showAudioInfoDialog(Map<String, dynamic> audio) {
    final filename = audio['filename'] ?? 'Unknown';
    final rawDate = audio['uploaded_at'];
    final uploadedAt = rawDate != null
        ? DateFormat("MMM dd, yyyy – HH:mm").format(DateTime.parse(rawDate))
        : 'Unknown';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Audio Info"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("📛 Filename: $filename"),
            const SizedBox(height: 4),
            Text("🗓 Uploaded At: $uploadedAt"),
            const SizedBox(height: 4),
            Text("📦 Size: ${readableSize(fileSizes[filename] ?? 0)}")
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close")),
        ],
      ),
    );
  }

  Future<void> deleteAudio(String filename, Map<String, dynamic> audio) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Deletion"),
        content: Text("Are you sure you want to delete $filename?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Step 1: Delete from storage
      await supabase.storage.from('media').remove(['audios/$filename']);

      // Step 2: Delete from table
      await supabase.from('audio_files').delete().eq('filename', filename);

      setState(() => audioFiles.remove(audio));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Deleted $filename")),
      );
    } catch (e) {
      print("Delete error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete failed: $e")),
      );
    }
  }

  String _formatDuration(Duration duration) {
    return duration.toString().split('.').first.padLeft(8, "0");
  }

  String readableSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
    } else if (bytes >= 1024) {
      return "${(bytes / 1024).toStringAsFixed(1)} KB";
    }
    return "$bytes B";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Audio Library")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : audioFiles.isEmpty
              ? const Center(child: Text("No audio files found."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: audioFiles.length,
                  itemBuilder: (context, index) {
                    final audio = audioFiles[index];
                    final filename = audio['filename'] ?? 'Unknown';
                    final url = audio['url'] ?? '';

                    return ListTile(
                      leading: const Icon(Icons.music_note,
                          color: Colors.deepOrange),
                      title: Text(filename,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.play_arrow,
                                color: Colors.green),
                            onPressed: () =>
                                showAudioPlayerModal(context, filename, url),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'download') {
                                downloadAudio(url, filename, context);
                              } else if (value == 'info') {
                                showAudioInfoDialog(audio);
                              } else if (value == 'delete') {
                                deleteAudio(filename, audio);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'info',
                                child: ListTile(
                                    leading: Icon(Icons.info_outline),
                                    title: Text("Info")),
                              ),
                              const PopupMenuItem(
                                value: 'download',
                                child: ListTile(
                                    leading: Icon(Icons.download),
                                    title: Text("Download")),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: ListTile(
                                    leading:
                                        Icon(Icons.delete, color: Colors.red),
                                    title: Text("Delete")),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
