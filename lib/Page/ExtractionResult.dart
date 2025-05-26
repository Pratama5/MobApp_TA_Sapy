import 'package:flutter/material.dart';
import 'package:wavemark_app_v1/Etc/bottom_nav.dart';

class ExtractionResultScreen extends StatelessWidget {
  final String imagePath;
  final String watermark;
  final int subband;
  final int bit;
  final String alfass;

  const ExtractionResultScreen({
    super.key,
    required this.imagePath,
    required this.watermark,
    required this.subband,
    required this.bit,
    required this.alfass,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDL = alfass == "DL-Auto";

    return Scaffold(
      backgroundColor: const Color(0xFFF5E8E4),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: const BackButton(color: Color(0xFFD1512D)),
        title: const Text(
          'Hasil Extraction',
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
                  content: Text("Download image belum diimplementasi."),
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
                  title: const Text("Penjelasan BER & Payload"),
                  content: const Text(
                    "🔸 BER (Bit Error Rate): Rasio jumlah bit error terhadap total bit. Semakin rendah, semakin baik.\n\n"
                    "🔸 Payload adalah istilah yang merujuk pada informasi atau data yang disisipkan ke dalam sinyal audio host.",
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
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            Flexible(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain, // ✅ konsisten, tidak terpotong
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Text("Gagal memuat gambar hasil ekstraksi."),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Color(0xFF411530), width: 1.5),
              ),
              child: Text(
                "Metode: $watermark\n"
                "Subband: ${isDL ? '-' : subband} | Bit: ${isDL ? '-' : bit} | Alpha: $alfass\n"
                "BER (pre-attack): 0.0000\n"
                "BER (post-attack): 0.0000\n"
                "Payload: 172.266",
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Color(0xFF411530),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentRoute: '/extract'),
    );
  }
}
