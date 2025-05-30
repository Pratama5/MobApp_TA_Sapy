// import 'dart:io';
// import 'dart:typed_data';
// import 'package:dio/dio.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:just_audio/just_audio.dart';
// import 'package:path_provider/path_provider.dart'; // For default/fallback if user preference is not set
// import 'package:shared_preferences/shared_preferences.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:wavemark_app_v1/Etc/bottom_nav.dart';

// // Import new packages

// import 'package:permission_handler/permission_handler.dart';

// class LibraryAudioPage extends StatefulWidget {
//   const LibraryAudioPage({Key? key}) : super(key: key); //

//   @override
//   State<LibraryAudioPage> createState() => _LibraryAudioPageState();
// }

// class _LibraryAudioPageState extends State<LibraryAudioPage> {
//   final SupabaseClient supabase = Supabase.instance.client; //
//   final AudioPlayer _player = AudioPlayer(); //
//   final TextEditingController _searchController = TextEditingController(); //
//   String _searchQuery = ''; //
//   bool _isAscending = true; //
//   String? _currentTitle; //
//   bool _isPlaying = false; //
//   List<Map<String, dynamic>> audioFiles = []; //
//   Map<String, int> fileSizes = {}; //
//   bool isLoading = true; //

//   @override
//   void initState() {
//     super.initState(); //
//     fetchAudioFiles().then((_) => fetchAudioSizes()); //
//   }

//   Future<void> fetchAudioFiles() async {
//     //
//     // ... existing fetchAudioFiles code ...
//     try {
//       final response = await supabase
//           .from('audio_files')
//           .select('filename, url, uploaded_at, is_public')
//           .order('uploaded_at', ascending: false);

//       setState(() {
//         audioFiles = List<Map<String, dynamic>>.from(response);
//         isLoading = false;
//       });
//     } catch (e) {
//       setState(() => isLoading = false);
//       if (mounted) {
//         // Check if widget is still in the tree
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error fetching audio files: $e')),
//         );
//       }
//     }
//   }

//   Future<void> fetchAudioSizes() async {
//     //
//     // ... existing fetchAudioSizes code ...
//     try {
//       final files = await supabase.storage.from('media').list(path: 'audios');
//       if (mounted) {
//         // Check if widget is still in the tree
//         setState(() {
//           fileSizes = {
//             for (final file in files) file.name: file.metadata?['size'] ?? 0,
//           };
//         });
//       }
//     } catch (e) {
//       print("Failed to fetch sizes: $e");
//     }
//   }

//   Future<bool> _requestStoragePermission() async {
//     PermissionStatus status = await Permission.storage.request();
//     if (status.isGranted) {
//       return true;
//     } else if (status.isPermanentlyDenied) {
//       // Guide user to app settings if permission is permanently denied
//       await openAppSettings();
//       return false;
//     } else {
//       return false;
//     }
//   }

//   Future<void> downloadAudio(String url, String filenameWithExtension) async {
//     //
//     // Capture ScaffoldMessenger before async operations
//     final scaffoldMessenger = ScaffoldMessenger.of(context);

//     bool hasPermission = await _requestStoragePermission();
//     if (!hasPermission) {
//       scaffoldMessenger.showSnackBar(
//         const SnackBar(
//             content: Text("Storage permission is required to download files.")),
//       );
//       return;
//     }

//     // Show a "downloading" indicator
//     scaffoldMessenger.showSnackBar(
//       SnackBar(content: Text("Downloading $filenameWithExtension...")),
//     );

//     try {
//       final response = await Dio().get<List<int>>(
//         //
//         url,
//         options: Options(responseType: ResponseType.bytes), //
//       );
//       final Uint8List bytes = Uint8List.fromList(response.data!); //

//       String nameWithoutExtension = filenameWithExtension.contains('.')
//           ? filenameWithExtension.substring(
//               0, filenameWithExtension.lastIndexOf('.'))
//           : filenameWithExtension;
//       String extension = filenameWithExtension.contains('.')
//           ? filenameWithExtension
//               .substring(filenameWithExtension.lastIndexOf('.') + 1)
//           : "mp3"; // Default to mp3 if no extension, or determine more accurately if possible

//       // Using file_saver to save to a public location (typically "Downloads" folder)
//       // MimeType can be inferred by the system or explicitly set if known.
//       // For audio, common mime types are "audio/mpeg", "audio/wav", "audio/aac", etc.
//       // If you know the specific mime type, it's good to provide it.
//       // Otherwise, file_saver will use a generic one or the system will infer from extension.
//       // String? savedPath = await FileSaver.instance.saveFile(
//       //     name: nameWithoutExtension,
//       //     bytes: bytes,
//       //     ext: extension,
//       //     // Example: mimeType: MimeType.audio (generic audio)
//       //     // or more specific: mimeType: extension == "mp3" ? MimeType.mpeg : MimeType.audio
//       //     // For simplicity, letting the system infer or using a common one:
//       //     mimeType: MimeType
//       //         .audio // This sets "audio/*", specific type often inferred from extension by OS.
//       //     );

//       // if (savedPath != null && savedPath.isNotEmpty) {
//       //   scaffoldMessenger.showSnackBar(
//       //     SnackBar(content: Text("Downloaded to: $savedPath")), //
//       //   );
//       // } else {
//       //   // Check if downloadPath preference is set
//       //   final prefs = await SharedPreferences.getInstance(); //
//       //   String? userPreferredPath = prefs.getString('download_folder'); //
//       //   String fallbackPath =
//       //       (await getApplicationDocumentsDirectory()).path; //
//       //   String actualBasePath = userPreferredPath ?? fallbackPath; //

//         // Attempt to save to app-specific directory as a final fallback if file_saver failed
//         // This part is if file_saver returns null/empty which implies it couldn't handle it.
//         // However, file_saver is designed to throw an error on failure typically.
//         // This fallback might be more for if `file_saver` itself isn't used.
//         // Given file_saver, this else block might signify a different issue or plugin failure.

//         // Let's refine: if file_saver fails, it usually throws. If it returns empty, it's also a failure.
//         // The original code's fallback to app documents directory is if userSelectedPath is null.
//         // With file_saver, it aims for public downloads. If that fails, we report file_saver's error.
//         scaffoldMessenger.showSnackBar(
//           const SnackBar(
//               content: Text(
//                   "Download failed using file_saver. File may not have been saved.")),
//         );
//       }
//     } catch (e) {
//       print("Download failed: $e"); //
//       String errorMessage = "Download failed: ${e.toString()}"; //
//       // More specific error check
//       if (e is DioException && e.type == DioExceptionType.connectionError ||
//           e is DioException && e.type == DioExceptionType.connectionTimeout) {
//         errorMessage =
//             "Download failed: Network error. Please check your connection.";
//       } else if (e.toString().toLowerCase().contains("permission denied") ||
//           (e is FileSystemException && e.osError?.errorCode == 13)) {
//         errorMessage = "Download failed: Storage permission denied.";
//       }
//       scaffoldMessenger.showSnackBar(
//         SnackBar(content: Text(errorMessage)),
//       );
//     }
//   }

//   void _playAudio(String url, String title) async {
//     //
//     // ... existing _playAudio code ...
//     try {
//       await _player.setUrl(url);
//       _player.play();
//       if (mounted) {
//         setState(() {
//           _currentTitle = title;
//           _isPlaying = true;
//         });
//       }
//     } catch (e) {
//       print("Playback failed: $e");
//     }
//   }

//   void _toggleSort() => setState(() => _isAscending = !_isAscending); //

//   void _togglePlayPause() {
//     //
//     // ... existing _togglePlayPause code ...
//     if (_player.playing) {
//       _player.pause();
//     } else {
//       _player.play();
//     }
//     if (mounted) setState(() => _isPlaying = _player.playing);
//   }

//   void _confirmDelete(String filename, Map<String, dynamic> audio) async {
//     //
//     // ... existing _confirmDelete code ...
//     if (audio['is_public'] == true) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//               content: Text("This is a Public audio and can't be deleted.")),
//         );
//       }
//       return;
//     }

//     final confirm = await showDialog<bool>(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text("Confirm Deletion"),
//         content: Text("Are you sure you want to delete $filename?"),
//         actions: [
//           TextButton(
//               onPressed: () => Navigator.pop(context, false),
//               child: const Text("Cancel")),
//           TextButton(
//               onPressed: () => Navigator.pop(context, true),
//               child: const Text("Delete", style: TextStyle(color: Colors.red)))
//         ],
//       ),
//     );

//     if (confirm != true) return;

//     try {
//       await supabase.storage.from('media').remove(['audios/$filename']);
//       await supabase.from('audio_files').delete().eq('filename', filename);
//       if (mounted) {
//         setState(() => audioFiles.remove(audio));
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text("$filename deleted successfully.")),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context)
//             .showSnackBar(SnackBar(content: Text("Delete failed: $e")));
//       }
//     }
//   }

//   String readableSize(int bytes) {
//     //
//     // ... existing readableSize code ...
//     if (bytes <= 0) return "0 B";
//     if (bytes >= 1024 * 1024) {
//       return "${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB";
//     } else if (bytes >= 1024) {
//       return "${(bytes / 1024).toStringAsFixed(1)} KB";
//     }
//     return "$bytes B";
//   }

//   void showAudioInfoDialog(Map<String, dynamic> audio) {
//     //
//     // ... existing showAudioInfoDialog code ...
//     final filename = audio['filename'] ?? 'Unknown';
//     final rawDate = audio['uploaded_at'];
//     final uploadedAt = rawDate != null
//         ? DateFormat("MMM dd, yyyy – HH:mm") // Corrected yyyy format
//             .format(DateTime.parse(rawDate).toLocal())
//         : 'Unknown';

//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text("Audio Info"),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text("📛 Filename: $filename"),
//             const SizedBox(height: 4),
//             Text("🗓 Uploaded At: $uploadedAt"),
//             const SizedBox(height: 4),
//             Text("📦 Size: ${readableSize(fileSizes[filename] ?? 0)}")
//           ],
//         ),
//         actions: [
//           TextButton(
//               onPressed: () => Navigator.pop(context),
//               child: const Text("Close")),
//         ],
//       ),
//     );
//   }

//   String _formatDuration(Duration d) {
//     //
//     // ... existing _formatDuration code ...
//     final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
//     final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
//     return '$m:$s';
//   }

//   @override
//   void dispose() {
//     _player.dispose(); //
//     _searchController.dispose(); // Dispose search controller
//     super.dispose(); //
//   }

//   @override
//   Widget build(BuildContext context) {
//     //
//     // ... existing build method, ensure to use mounted checks for setState if necessary ...
//     final filteredList = audioFiles //
//         .where((audio) => audio['filename'] //
//             .toLowerCase() //
//             .contains(_searchQuery.toLowerCase())) //
//         .toList() //
//       ..sort((a, b) => _isAscending //
//           ? a['filename'].compareTo(b['filename']) //
//           : b['filename'].compareTo(a['filename'])); //

//     return Scaffold(
//       //
//       appBar: AppBar(
//         //
//         title: const Text(
//           //
//           "Audio Library", //
//           style: TextStyle(
//             //
//             fontSize: 20, //
//             fontWeight: FontWeight.bold, //
//             color: Color(0xFF411530), //
//           ),
//         ),
//         backgroundColor: const Color(0xFFF5E8E4), //
//       ),
//       backgroundColor: const Color(0xFFF5E8E4), //
//       body: isLoading // Added isLoading check for the body
//           ? const Center(child: CircularProgressIndicator())
//           : Column(
//               //
//               children: [
//                 //
//                 Padding(
//                   //
//                   padding: const EdgeInsets.all(16), //
//                   child: Row(
//                     //
//                     children: [
//                       //
//                       Expanded(
//                         //
//                         child: TextField(
//                           //
//                           controller: _searchController, //
//                           onChanged: (v) => setState(() => _searchQuery = v), //
//                           decoration: InputDecoration(
//                             //
//                             hintText: 'Search audio...', //
//                             prefixIcon: const Icon(Icons.search), //
//                             border: OutlineInputBorder(
//                               //
//                               borderRadius: BorderRadius.circular(12), //
//                               borderSide: BorderSide.none, //
//                             ),
//                             filled: true, //
//                             fillColor: Colors.white, //
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 10), //
//                       GestureDetector(
//                         //
//                         onTap: _toggleSort, //
//                         child: Container(
//                           //
//                           padding: const EdgeInsets.all(10), //
//                           decoration: BoxDecoration(
//                             //
//                             color: const Color(0xFFD1512D), //
//                             borderRadius: BorderRadius.circular(10), //
//                           ),
//                           child: Icon(
//                             //
//                             _isAscending //
//                                 ? Icons.sort_by_alpha //
//                                 : Icons.sort_by_alpha_outlined, //
//                             color: Colors.white, //
//                           ),
//                         ),
//                       )
//                     ],
//                   ),
//                 ),
//                 Expanded(
//                   //
//                   child: filteredList.isEmpty && !_searchQuery.isEmpty
//                       ? Center(
//                           child: Text("No audio found for '$_searchQuery'"))
//                       : filteredList.isEmpty &&
//                               _searchQuery.isEmpty &&
//                               !isLoading
//                           ? Center(
//                               child: Text("No audio files in library yet."))
//                           : ListView.separated(
//                               //
//                               padding: const EdgeInsets.fromLTRB(
//                                   16, 0, 16, 16), // Adjusted padding
//                               itemCount: filteredList.length, //
//                               separatorBuilder: (_, __) =>
//                                   const SizedBox(height: 10), //
//                               itemBuilder: (context, index) {
//                                 //
//                                 final audio = filteredList[index]; //
//                                 final filename = audio['filename']; //
//                                 final url = audio['url']; //

//                                 return ListTile(
//                                   //
//                                   tileColor: Colors.white, //
//                                   shape: RoundedRectangleBorder(
//                                       //
//                                       borderRadius:
//                                           BorderRadius.circular(12)), //
//                                   leading: //
//                                       const Icon(Icons.music_note,
//                                           color: Color(0xFFD1512D)), //
//                                   title: Text(filename, //
//                                       style: const TextStyle(
//                                           fontWeight: FontWeight.w600)), //
//                                   trailing: PopupMenuButton<String>(
//                                     //
//                                     onSelected: (value) {
//                                       //
//                                       if (value == 'download') {
//                                         //
//                                         downloadAudio(url, filename); //
//                                       } else if (value == 'delete') {
//                                         //
//                                         _confirmDelete(filename, audio); //
//                                       } else if (value == 'info') {
//                                         //
//                                         showAudioInfoDialog(audio); //
//                                       }
//                                     },
//                                     itemBuilder: (context) => [
//                                       //
//                                       const PopupMenuItem(
//                                           //
//                                           value: 'download',
//                                           child: Text("Download")), //
//                                       const PopupMenuItem(
//                                           //
//                                           value: 'delete',
//                                           child: Text("Delete")), //
//                                       const PopupMenuItem(
//                                           value: 'info',
//                                           child: Text("Info")), //
//                                     ],
//                                   ),
//                                   onTap: () => _playAudio(url, filename), //
//                                 );
//                               },
//                             ),
//                 ),
//                 if (_currentTitle != null) //
//                   Container(
//                     //
//                     color: const Color(0xFF5E2A4D), //
//                     padding: const EdgeInsets.symmetric(
//                         horizontal: 20, vertical: 12), //
//                     child: Column(
//                       //
//                       mainAxisSize: MainAxisSize.min, //
//                       children: [
//                         //
//                         Row(
//                           //
//                           children: [
//                             //
//                             const Icon(Icons.music_note,
//                                 color: Colors.white), //
//                             const SizedBox(width: 12), //
//                             Expanded(
//                               //
//                               child: Text(
//                                 //
//                                 _currentTitle!, //
//                                 style: const TextStyle(color: Colors.white), //
//                                 overflow: TextOverflow.ellipsis, //
//                               ),
//                             ),
//                             IconButton(
//                               //
//                               icon: Icon(
//                                 //
//                                 _isPlaying ? Icons.pause : Icons.play_arrow, //
//                                 color: Colors.white, //
//                               ),
//                               onPressed: _togglePlayPause, //
//                             ),
//                           ],
//                         ),
//                         StreamBuilder<Duration>(
//                           //
//                           stream: _player.positionStream, //
//                           builder: (context, snapshot) {
//                             //
//                             final position = snapshot.data ?? Duration.zero; //
//                             final duration =
//                                 _player.duration ?? Duration.zero; //

//                             return Column(
//                               //
//                               children: [
//                                 //
//                                 Slider(
//                                   //
//                                   min: 0.0, //
//                                   max: duration.inMilliseconds.toDouble(), //
//                                   value: position.inMilliseconds //
//                                       .clamp(0, duration.inMilliseconds) //
//                                       .toDouble(), //
//                                   onChanged: (value) {
//                                     //
//                                     _player //
//                                         .seek(Duration(
//                                             milliseconds: value.toInt())); //
//                                   },
//                                   activeColor: Colors.white, //
//                                   inactiveColor: Colors.white24, //
//                                 ),
//                                 Row(
//                                   //
//                                   mainAxisAlignment:
//                                       MainAxisAlignment.spaceBetween, //
//                                   children: [
//                                     //
//                                     Text(_formatDuration(position), //
//                                         style: const TextStyle(
//                                             //
//                                             color: Colors.white70,
//                                             fontSize: 12)), //
//                                     Text(_formatDuration(duration), //
//                                         style: const TextStyle(
//                                             //
//                                             color: Colors.white70,
//                                             fontSize: 12)), //
//                                   ],
//                                 )
//                               ],
//                             );
//                           },
//                         )
//                       ],
//                     ),
//                   )
//               ],
//             ),
//       floatingActionButton: FloatingActionButton(
//           //
//           backgroundColor: const Color(0xFFD1512D), //
//           child: const Icon(Icons.file_upload, color: Colors.white), //
//           onPressed: () async {
//             //
//             final result =
//                 await Navigator.pushNamed(context, '/uploadAudio'); //
//             if (result == true) {
//               //
//               // Re-fetch the audio list
//               fetchAudioFiles(); //
//             }
//           }),
//       bottomNavigationBar: const BottomNavBar(currentRoute: '/library'), //
//     );
//   }
// }
