import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

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
    'SWT-DST-QR-SS',
    'SWT-DCT-QR-SS',
    'DWT-DST-SVD-SS',
    'DWT-DCT-SVD-SS',
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

  Future<void> sendToLocalServer({
    required String audioUrl,
    required String imageUrl,
    required String method,
    required int subband,
    required int bit,
    required double alfass,
  }) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User not authenticated")),
      );
      return;
    }

    final uri = Uri.parse("http://192.168.18.10:8000/embed"); // Use your IP

    final payload = {
      "audio_url": audioUrl,
      "img_url": imageUrl,
      "method": method,
      "subband": subband,
      "bit": bit,
      "alfass": alfass,
      "uploaded_by": userId,
    };

    try {
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['status'] == 'success') {
        // Success
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Embedding Successful'),
            content: Text(
              'Watermarked audio was created.\nSNR: ${responseData['snr'] ?? "N/A"}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('OK'),
              ),
            ],
          ),
        );
        // You can also navigate to result screen here
      } else {
        // Server error response
        showErrorDialog(
            responseData['message'] ?? 'An unknown error occurred.');
      }
    } catch (e) {
      // Network or JSON error
      showErrorDialog('Failed to connect to server: $e');
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

    selectedAlfass = double.tryParse(alfassController.text) ?? 0.05;

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

    // Send request to server
    final result = await sendToLocalServer(
      audioUrl: getPublicAudioUrl(selectedAudio!),
      imageUrl: getPublicImageUrl(selectedWatermark!),
      method: selectedMethod!,
      subband: selectedSubband!,
      bit: selectedBit!,
      alfass: selectedAlfass,
    );

    // Close loading
    Navigator.of(context).pop();

    // Show result dialog
    // showDialog(
    //   context: context,
    //   builder: (context) => AlertDialog(
    //     title: Text(result['status'] == 'success' ? 'Success' : 'Error'),
    //     content: Text(result['message'] ?? 'Unknown error'),
    //     actions: [
    //       TextButton(
    //         onPressed: () => Navigator.pop(context),
    //         child: const Text('OK'),
    //       )
    //     ],
    //   ),
    // );
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
              hint: const Text("Audio"),
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
