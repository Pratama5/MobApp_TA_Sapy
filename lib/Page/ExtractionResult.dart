import 'package:flutter/material.dart';
import 'package:wavemark_app_v1/Etc/bottom_nav.dart'; // Ensure this path is correct

class ExtractionResultScreen extends StatelessWidget {
  final String imageUrl;
  final String watermark;
  final int subband;
  final int bit;
  final String alfass;
  final String actualBer;
  final String status;

  const ExtractionResultScreen({
    super.key,
    required this.imageUrl,
    required this.watermark,
    required this.subband,
    required this.bit,
    required this.alfass,
    required this.actualBer,
    required this.status,
  });

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

  @override
  Widget build(BuildContext context) {
    final bool isDL = alfass == "DL-Auto";
    print("Displaying ExtractionResultScreen with imageUrl: $imageUrl");

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Color(0xFFD1512D)),
        title: const Text(
          'Extraction Result',
          style: TextStyle(
            color: Color(0xFF411530),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.file_download_outlined,
              color: Color(0xFF411530),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:
                      Text("Download image functionality not yet implemented."),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: Color(0xFF411530)),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Explanation BER & Payload"),
                  content: const Text(
                    "🔸 BER (Bit Error Rate): The ratio of bit errors to the total number of transferred bits. Lower is better.\n\n"
                    "🔸 Payload: Information or data embedded within the host audio signal.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close"),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(
                0xFFF5E8E4), // Matches EmbeddingResult.dart container color
            borderRadius: BorderRadius.circular(15),
            boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Extracted Watermark Image",
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF411530)),
              ),
              const SizedBox(height: 15),
              Center(
                child: Container(
                  // You can adjust this width and height to your preferred fixed size
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    // Debugging background color removed
                    // color: Colors.blue.withOpacity(0.3),
                    // Keeping the border as requested. You can change its color and width.
                    border: Border.all(
                        color: Color(0xFF411530),
                        width:
                            1), // Change Colors.red to your desired border color
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(
                        11), // Adjust if border width changes
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality
                          .none, // Keeping this for clear, pixelated scaling
                      loadingBuilder: (BuildContext context, Widget child,
                          ImageChunkEvent? loadingProgress) {
                        if (loadingProgress == null) {
                          print("✅ Image loaded successfully: $imageUrl");
                          return child;
                        }
                        final double progressPercentage =
                            loadingProgress.expectedTotalBytes != null
                                ? (loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!) *
                                    100
                                : -1;
                        print(
                            "⏳ Image loading progress: ${progressPercentage.toStringAsFixed(0)}% for $imageUrl");
                        return Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            color: const Color(0xFFD1512D),
                          ),
                        );
                      },
                      errorBuilder: (BuildContext context, Object error,
                          StackTrace? stackTrace) {
                        print("❌ Image load error for $imageUrl: $error");
                        if (stackTrace != null) {
                          print("📄 StackTrace: $stackTrace");
                        }
                        return Container(
                          padding: const EdgeInsets.all(10),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.broken_image,
                                  color: Colors.red, size: 40),
                              const SizedBox(height: 4),
                              Text(
                                "Error loading image. Check logs.",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.redAccent, fontSize: 12),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                "Extraction Details",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF411530)),
              ),
              const SizedBox(height: 15),
              _buildInfoRow("Method", watermark),
              _buildInfoRow("Subband", isDL ? '-' : subband.toString()),
              _buildInfoRow("Bit", isDL ? '-' : bit.toString()),
              _buildInfoRow("Alpha", alfass),
              _buildInfoRow("BER", actualBer),
              _buildInfoRow("Payload", "172.266"), // This is still hardcoded
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentRoute: '/extract'),
    );
  }
}
