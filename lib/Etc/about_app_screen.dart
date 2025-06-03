import 'package:flutter/material.dart';
import 'bottom_nav.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(255, 241, 232, 1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFD1512D)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Tentang Aplikasi',
          style: TextStyle(
            color: Color(0xFF411530),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Image.asset('assets/logo_wavemark.png', height: 100)),
            const SizedBox(height: 25),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Color(0xFF411530), width: 1.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'WaveMark',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text('Versi 1.0.1'),
                  Divider(height: 24, thickness: 1),
                  Text(
                    'Aplikasi ini dikembangkan untuk menanamkan watermark pada file audio secara aman dan tak terdengar.'
                    'Menggunakan metode kombinasi multi-domain yang tahan terhadap berbagai serangan sinyal.',
                  ),
                  Divider(height: 24, thickness: 1),
                  Text(
                    'Pengembang:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text('• Andika Rizki Pratama'),
                  Text('• Putra Pratama Sijabat'),
                  Text('• Nur Said'),
                  Text('• Yesaya Pasaribu'),
                  SizedBox(height: 16),
                  Text(
                    'Dosen Pembimbing:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Text('• Dr. Gelar Budiman, S.T., M.T.'),
                  Text('• Sofia Sa’Idah S.T., M.T.'),
                  Divider(height: 24, thickness: 1),
                  Text(
                    'Proyek Tugas Akhir - Universitas Telkom',
                    style: TextStyle(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentRoute: '/profile'),
    );
  }
}
