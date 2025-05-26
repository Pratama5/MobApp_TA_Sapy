import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? downloadPath;

  @override
  void initState() {
    super.initState();
    loadSavedPath();
  }

  Future<void> loadSavedPath() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      downloadPath = prefs.getString('download_folder');
    });
  }

  Future<void> pickDownloadFolder() async {
    final path = await getDirectoryPath();
    if (path != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('download_folder', path);
      setState(() => downloadPath = path);
    }
  }

  Future<String> getEffectivePath() async {
    if (downloadPath != null) return downloadPath!;
    final defaultDir = await getApplicationDocumentsDirectory();
    return defaultDir.path;
  }

  Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('download_folder');
    setState(() => downloadPath = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Download folder reset to default")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Download Folder:",
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            FutureBuilder<String>(
              future: getEffectivePath(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                return Text(snapshot.data!,
                    style: const TextStyle(color: Colors.black87));
              },
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⚠️ To make downloaded files visible in your File Manager, select the folder: /storage/emulated/0/Download',
                style: TextStyle(color: Colors.black87),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: resetToDefault,
              icon: const Icon(Icons.restart_alt),
              label: const Text("Reset to Default"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey.shade400,
                foregroundColor: Colors.black,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: pickDownloadFolder,
              icon: const Icon(Icons.folder),
              label: const Text("Select Download Folder"),
            ),
          ],
        ),
      ),
    );
  }
}
