import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:wavemark_app_v1/Etc/SettingsPage.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';

// Import your AppSettings class
import '../etc/app_settings.dart'; // Adjust the path if needed

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
  double selectedAlfass = 0.015; // Default value

  // Initialize with the default value or an empty string if you prefer
  final TextEditingController alfassController =
      TextEditingController(text: "0.015");

  List<String> methodList = [
    'DWT-DST-SVD-SS',
    'DWT-DCT-SVD-SS',
    'SWT-DST-QR-SS',
    'SWT-DCT-QR-SS',
  ];
  List<Map<String, String>> audioList = [];
  List<Map<String, String>> watermarkList = [];
  List<int> subbandoptions = [1, 2, 3, 4];
  List<int> bitOptions = [16, 32];

  @override
  void initState() {
    super.initState();
    loadDropdownData();
    // alfassController.text = selectedAlfass.toString(); // Set initial text for alfass
  }

  String _getMethodIdentifier(String? fullMethodName) {
    if (fullMethodName == null) {
      print(
          "Warning: fullMethodName is null in _getMethodIdentifier. Defaulting to 'A'.");
      return "A";
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
        return "A";
    }
  }

  Future<void> loadDropdownData() async {
    final audioResponse = await Supabase.instance.client
        .from('audio_files')
        .select('filename, url')
        .order('uploaded_at', ascending: false);

    final imageResponse = await Supabase.instance.client
        .from('image_watermarks')
        .select('filename, url')
        .order('uploaded_at', ascending: false);

    if (mounted) {
      setState(() {
        audioList = (audioResponse as List<dynamic>)
            .map((item) => {
                  'filename': item['filename'] as String,
                  'url': item['url'] as String,
                })
            .toList();

        watermarkList = (imageResponse as List<dynamic>)
            .map((item) => {
                  'filename': item['filename'] as String,
                  'url': item['url'] as String,
                })
            .toList();
      });
    }
  }

  String getPublicImageUrl(String fileName) {
    // ... (your existing getPublicImageUrl method is fine)
    final url = Supabase.instance.client.storage
        .from('media')
        .getPublicUrl('images/$fileName');
    return url;
  }

  String getPublicAudioUrl(String fileName) {
    // ... (your existing getPublicAudioUrl method is fine)
    final url = Supabase.instance.client.storage
        .from('media')
        .getPublicUrl('audios/$fileName');
    return url;
  }

  // Updated sendToLocalServer function
  Future<Map<String, dynamic>> sendToLocalServer({
    required String audioUrl,
    required String imageUrl,
    required String methodIdentifier,
    required int subband,
    required int bit,
    required double alfass,
  }) async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      return {
        "status": "error",
        "message": "User not authenticated.",
      };
    }
    final accessToken = session.accessToken;
    final userId = session.user.id;

    // --- FETCH SERVER IP FROM SETTINGS ---
    final String serverIp = await AppSettings.getServerIp();
    // --- END FETCH SERVER IP ---

    try {
      print(
          "Sending to server (http://$serverIp:8000): audio_url=$audioUrl, img_url=$imageUrl, method_identifier=$methodIdentifier, subband=$subband, bit=$bit, alfass=$alfass, uploaded_by=$userId");
      final response = await http.post(
        Uri.parse("http://$serverIp:8000/embed"), // IP is now dynamic
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
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
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("Server response: $data");
        return data; // Success case should ideally also have a "status": "success" from server
      } else {
        String errorType =
            "server_error"; // Default for server-side HTTP errors
        String detailedMessage =
            "Server responded with error ${response.statusCode}.";
        if (response.body.isNotEmpty) {
          detailedMessage += " Details: ${response.body}";
        }

        // Specific HTTP errors that might relate to wrong IP/server config
        if (response.statusCode == 404) {
          // Not Found
          errorType = "connection_error";
          detailedMessage =
              "Endpoint not found on server at $serverIp (Error 404). This might be a configuration issue or wrong Server IP.";
        } else if (response.statusCode == 503) {
          // Service Unavailable
          errorType = "connection_error";
          detailedMessage =
              "Server at $serverIp is temporarily unavailable (Error 503). Please try again later or check server status.";
        }
        // You can add more specific status code checks here (e.g., 401 for auth issues from server)

        print("Server error: ${response.statusCode} - ${response.body}");
        return {
          "status": "error",
          "message": detailedMessage,
          "error_type": errorType,
        };
      }
    } on TimeoutException catch (e) {
      print("Connection to server ($serverIp) timed out: $e");
      return {
        "status": "error",
        "message":
            "Connection timed out when trying to reach the server at $serverIp. Please check the Server IP and your network.",
        "error_type": "connection_error",
      };
    } on SocketException catch (e) {
      // Typically for host not found / connection refused
      print(
          "SocketException / Network error connecting to server ($serverIp): $e");
      return {
        "status": "error",
        "message":
            "Could not reach the server at $serverIp. It might be offline or the IP is incorrect. Please check the Server IP in settings and your network. (Details: ${e.message})",
        "error_type": "connection_error",
      };
    } on http.ClientException catch (e) {
      // Other HTTP client-side errors
      print("ClientException connecting to server ($serverIp): $e");
      return {
        "status": "error",
        "message":
            "A network or client error occurred when trying to reach $serverIp. (Details: ${e.message})",
        "error_type": "connection_error", // Often connection related
      };
    } catch (e) {
      // Catch-all for other unexpected errors
      print("Unexpected error connecting to server ($serverIp): $e");
      return {
        "status": "error",
        "message":
            "An unexpected error occurred while trying to connect to the server at $serverIp. (Details: $e)",
        "error_type": "generic_error",
      };
    }
  }

  void showErrorDialog(String message) {
    // ... (your existing showErrorDialog method is fine)
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void onProceed() async {
    // ... (your existing onProceed method, but ensure alfassController handling is robust)
    if (selectedAudio == null ||
        selectedWatermark == null ||
        selectedMethod == null ||
        selectedBit == null ||
        selectedSubband == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please complete all selections")),
      );
      return;
    }
    selectedAlfass = double.tryParse(alfassController.text.trim()) ?? 0.015;

    if (alfassController.text.trim().isEmpty) {
      alfassController.text = selectedAlfass.toString();
    }

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

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final String methodIdentifierToSend = _getMethodIdentifier(selectedMethod);

    final result = await sendToLocalServer(
      audioUrl: getPublicAudioUrl(selectedAudio!),
      imageUrl: getPublicImageUrl(selectedWatermark!),
      methodIdentifier: methodIdentifierToSend,
      subband: selectedSubband!,
      bit: selectedBit!,
      alfass: selectedAlfass,
    );

    if (mounted) Navigator.of(context).pop(); // Close loading dialog

    // --- MODIFIED DIALOG LOGIC for result ---
    if (result['status'] == 'success') {
      // Your existing success dialog logic
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Success'),
          content: Text(
              'Watermark successfully embedded.\nSNR: ${result['snr'] ?? "N/A"}'),
          actions: [
            TextButton(
              child: const Text('Next'),
              onPressed: () {
                if (!mounted) return;
                Navigator.pop(dialogContext); // Close current dialog

                String watermarkedAudioUrl = result['audio_url'] ?? '';
                String keyUrlFromServer = result['key_url'] ?? '';
                double? snrFromServer = (result['snr'] as num?)?.toDouble();
                String actualWatermarkedFilename =
                    result['watermarked_filename'] ?? "Unknown Audio File";

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => EmbeddingResultScreen(
                      audioUrl: watermarkedAudioUrl,
                      audioFilename: actualWatermarkedFilename,
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
              onPressed: () => Navigator.pop(dialogContext),
            ),
          ],
        ),
      );
    } else {
      // status == 'error'
      String errorMessage = result['message'] ?? 'An unknown error occurred.';
      String errorType = result['error_type'] ?? 'generic_error';
      // final String serverIpUsed = await AppSettings.getServerIp(); // No need to fetch again, message has it

      if (errorType == 'connection_error') {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Connection Failed'),
            content: SingleChildScrollView(
              // In case error message is long
              child: Text(
                  // The message from sendToLocalServer already contains IP and error details
                  errorMessage +
                      "\n\nPlease check your network and ensure the Server IP in settings is correct."),
            ),
            actions: [
              TextButton(
                child: const Text('Go to Settings'),
                onPressed: () {
                  Navigator.pop(dialogContext); // Close this error dialog
                  // Navigate to SettingsPage
                  Navigator.push(
                    context, // Use the original page's context for navigation
                    MaterialPageRoute(
                        builder: (context) => const SettingsPage()),
                  );
                },
              ),
              TextButton(
                child: const Text('Close'),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
        );
      } else {
        // Show a more generic error dialog for other types of errors
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Error Occurred'),
            content: SingleChildScrollView(child: Text(errorMessage)),
            actions: [
              TextButton(
                child: const Text('Close'),
                onPressed: () => Navigator.pop(dialogContext),
              ),
            ],
          ),
        );
      }
    }
    // --- END OF MODIFIED DIALOG LOGIC ---
  }

  InputDecoration _inputDecoration() {
    // ... (your existing _inputDecoration method is fine)
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
  void dispose() {
    alfassController.dispose(); // Dispose the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ... (your existing build method is fine)
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
                  .map((audio) => DropdownMenuItem(
                        value: audio['filename'],
                        child: Text(audio['filename'] ?? ''),
                      ))
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
                  .map((image) => DropdownMenuItem(
                        value: image['filename'],
                        child: Row(
                          children: [
                            Image.network(
                              getPublicImageUrl(image['filename']!),
                              width: 40,
                              height: 40,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                                child: Text(image['filename'] ?? '',
                                    overflow: TextOverflow.ellipsis)),
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
              decoration: _inputDecoration()
                  .copyWith(labelText: 'Alfass (e.g., 0.015)'), // Added example
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true), // Allow decimal
            ),
            const SizedBox(height: 20), // Increased spacing
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
            const SizedBox(height: 20), // Added spacing at the bottom
          ],
        ),
      ),
    );
  }
}
