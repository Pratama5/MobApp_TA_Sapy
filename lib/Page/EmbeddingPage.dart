import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:wavemark_app_v1/Page/EmbeddingResult.dart';

class EmbeddingPage extends StatefulWidget {
  const EmbeddingPage({super.key});

  @override
  State<EmbeddingPage> createState() => _EmbeddingPageState();
}

class _EmbeddingPageState extends State<EmbeddingPage> {
  String? selectedMethod;
  int? selectedSubband;
  int? selectedBit;
  String? selectedAudio;
  String? selectedWatermark;
  double selectedAlfass = 0.05;

  final TextEditingController alfassController = TextEditingController();

  List<String> methodList = [
    'DWT-DST-SVD-SS',
    'DWT-DCT-SVD-SS',
    'SWT-DST-QR-SS',
    'SWT-DCT-QR-SS',
  ];
  List<String> audioList = [];
  List<String> watermarkList = [];
  List<int> subbandoptions = [1, 2, 3, 4];
  List<int> bitOptions = [16, 32];

  @override
  void initState() {
    super.initState();
    loadDropdownData();
  }

  String _getMethodIdentifier(String? fullMethodName) {
    if (fullMethodName == null) {
      print(
          "Warning: fullMethodName is null in _getMethodIdentifier. Defaulting to 'A'.");
      return "A"; // Default or handle error appropriately
    }

    switch (fullMethodName) {
      case 'DWT-DST-SVD-SS':
        return "A";
      case 'DWT-DCT-SVD-SS':
        return "B";
      case 'SWT-DST-QR-SS':
        return "C";
      case 'SWT-DCT-QR-SS':
        return "D";
      default:
        print(
            "Warning: Unknown method '$fullMethodName' selected in _getMethodIdentifier. Defaulting to identifier 'A'.");
        return "A"; // Fallback identifier, or you could throw an error
    }
  }

  Future<void> loadDropdownData() async {
    final audios = await fetchFileNamesFromSupabase('audios');
    final images = await fetchFileNamesFromSupabase('images');

    setState(() {
      audioList = audios;
      watermarkList = images;
    });
  }

  Future<List<String>> fetchFileNamesFromSupabase(String path) async {
    final response =
        await Supabase.instance.client.storage.from('media').list(path: path);

    if (response.isEmpty) return [];

    final filenames = response
        .where((item) =>
            item.name.endsWith('.wav') ||
            item.name.endsWith('.mp3') ||
            item.name.endsWith('.png') ||
            item.name.endsWith('.jpg'))
        .map((item) => item.name)
        .toList();

    return filenames;
  }

  String getPublicImageUrl(String fileName) {
    final url = Supabase.instance.client.storage
        .from('media')
        .getPublicUrl('images/$fileName');
    return url;
  }

  String getPublicAudioUrl(String fileName) {
    final url = Supabase.instance.client.storage
        .from('media')
        .getPublicUrl('audios/$fileName');
    return url;
  }

  Future<Map<String, dynamic>> sendToLocalServer({
    required String audioUrl,
    required String imageUrl,
    required String methodIdentifier,
    required int subband,
    required int bit,
    required double alfass,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      // Handle case where user is not logged in, perhaps return an error or throw
      return {
        "status": "error",
        "message": "User not authenticated.",
      };
    }

    final String serverIp =
        "192.168.18.10"; // Consider making this configurable
    try {
      print(
          "Sending to server: audio_url=$audioUrl, img_url=$imageUrl, method_identifier=$methodIdentifier, subband=$subband, bit=$bit, alfass=$alfass, uploaded_by=$userId");
      final response = await http.post(
        Uri.parse(
            "http://$serverIp:8000/embed"), // Always change the IP wheb change connection
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "audio_url": audioUrl,
          "img_url": imageUrl,
          "method_identifier": methodIdentifier,
          "subband": subband,
          "bit": bit,
          "alfass": alfass,
          "uploaded_by": userId,
        }),
      );

      // It's good to check the status code before decoding
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Server response: $data");
        return data;
      } else {
        print("Server error: ${response.statusCode} - ${response.body}");
        return {
          "status": "error",
          "message": "Server error: ${response.statusCode} - ${response.body}",
        };
      }
    } catch (e) {
      print("Error connecting to server: $e");
      return {
        "status": "error",
        "message": "Failed to connect to server: $e",
      };
    }
  }

  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void onProceed() async {
    if (selectedAudio == null ||
        selectedWatermark == null ||
        selectedMethod == null ||
        selectedBit == null ||
        selectedSubband == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please complete all selections")),
      );
      return;
    }

    selectedAlfass = double.tryParse(alfassController.text.trim()) ?? 0.05;
    if (alfassController.text.trim().isEmpty) {
      // Explicitly set if empty
      alfassController.text = selectedAlfass.toString();
    }
    // Show confirmation dialog
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFFF5E8E4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        title: const Text('Confirmation'),
        content: const Text('Please make sure your selected data is correct.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );

    if (proceed != true) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // Get the method identifier ("A", "B", "C", or "D")
    final String methodIdentifierToSend = _getMethodIdentifier(selectedMethod);

    // Send request to server
    final result = await sendToLocalServer(
      audioUrl: getPublicAudioUrl(selectedAudio!),
      imageUrl: getPublicImageUrl(selectedWatermark!),
      methodIdentifier: methodIdentifierToSend, // PASS THE IDENTIFIER HERE
      subband: selectedSubband!,
      bit: selectedBit!,
      alfass: selectedAlfass,
    );

    // Close loading
    if (mounted) Navigator.of(context).pop(); // Close loading dialog

    // Show result dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(result['status'] == 'success' ? 'Success' : 'Error'),
        content: Text(
          result['status'] == 'success'
              ? 'Watermark successfully embedded.\nSNR: ${result['snr'] ?? "N/A"}'
              : result['message'] ?? 'Unknown error',
        ),
        actions: [
          if (result['status'] == 'success')
            TextButton(
              child: const Text('Next'),
              onPressed: () {
                if (!mounted) return;
                Navigator.pop(context); // Close current dialog

                String watermarkedAudioUrl = result['audio_url'] ?? '';
                String keyUrlFromServer = result['key_url'] ?? '';
                double? snrFromServer = (result['snr'] as num?)?.toDouble();

                // --- USE THE FILENAME DIRECTLY FROM SERVER RESPONSE ---
                String actualWatermarkedFilename =
                    result['watermarked_filename'] ?? "Unknown Audio File";
                print(
                    "✅ Server returned watermarked_filename: $actualWatermarkedFilename");
                // --- END ---

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EmbeddingResultScreen(
                      audioUrl: watermarkedAudioUrl,
                      audioFilename:
                          actualWatermarkedFilename, // <-- PASS THE DIRECT FILENAME HERE
                      keyUrl: keyUrlFromServer,
                      snr: snrFromServer,
                      method: selectedMethod!,
                      bit: selectedBit!,
                      subband: selectedSubband!,
                      alfass: selectedAlfass,
                    ),
                  ),
                );
              },
            ),
          TextButton(
            child: const Text('Close'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration() {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5E8E4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Color(0xFFD1512D)),
        title: const Text(
          'Embedding',
          style: TextStyle(
            color: Color(0xFF411530),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFF411530)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Penjelasan Parameter"),
                  content: const Text(
                    "🔸 Subband: bagian frekuensi tempat watermark disisipkan.\n"
                    "🔸 Bit: panjang bit watermark (misal 16-bit atau 32-bit).\n"
                    "🔸 Alfass: kekuatan penyisipan watermark (semakin besar, semakin kuat namun bisa mempengaruhi kualitas audio).",
                  ),
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Select Method",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF411530),
              ),
            ),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              hint: const Text("Method"),
              value: selectedMethod,
              isExpanded: true,
              items: methodList
                  .map((method) =>
                      DropdownMenuItem(value: method, child: Text(method)))
                  .toList(),
              onChanged: (value) => setState(() => selectedMethod = value),
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 10),
            const Text(
              "Select Audio",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF411530),
              ),
            ),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              hint: const Text("Audio"),
              value: selectedAudio,
              isExpanded: true,
              items: audioList
                  .map((audio) =>
                      DropdownMenuItem(value: audio, child: Text(audio)))
                  .toList(),
              onChanged: (value) => setState(() => selectedAudio = value),
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 10),
            const Text(
              "Select Watermark",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF411530),
              ),
            ),
            const SizedBox(height: 5),
            DropdownButtonFormField<String>(
              hint: const Text("Watermark"),
              value: selectedWatermark,
              isExpanded: true,
              items: watermarkList
                  .map((wm) => DropdownMenuItem(
                        value: wm,
                        child: Row(
                          children: [
                            Image.network(
                              getPublicImageUrl(wm),
                              width: 40,
                              height: 40,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                                child:
                                    Text(wm, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => selectedWatermark = value),
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 10),
            const Text(
              "Select Subband",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF411530),
              ),
            ),
            const SizedBox(height: 5),
            DropdownButtonFormField<int>(
              hint: const Text("Subband"),
              value: selectedSubband,
              isExpanded: true,
              items: subbandoptions
                  .map((method) => DropdownMenuItem(
                      value: method, child: Text(method.toString())))
                  .toList(),
              onChanged: (value) => setState(() => selectedSubband = value),
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 10),
            const Text(
              "Select Bit",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF411530),
              ),
            ),
            const SizedBox(height: 5),
            DropdownButtonFormField<int>(
              hint: const Text("Bit"),
              value: selectedBit,
              isExpanded: true,
              items: bitOptions
                  .map((method) => DropdownMenuItem(
                      value: method, child: Text(method.toString())))
                  .toList(),
              onChanged: (value) => setState(() => selectedBit = value),
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 10),
            const Text(
              "Enter Alfass",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Color(0xFF411530),
              ),
            ),
            const SizedBox(height: 5),
            TextFormField(
              controller: alfassController,
              decoration: _inputDecoration().copyWith(labelText: 'Alfass'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            Center(
              child: ElevatedButton(
                onPressed: onProceed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD1512D),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  'Start Embedding',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
