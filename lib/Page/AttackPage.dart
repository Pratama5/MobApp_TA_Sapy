import 'package:flutter/material.dart';
import 'package:wavemark_app_v1/Etc/bottom_nav.dart';

class AttackPage extends StatefulWidget {
  const AttackPage({super.key});

  @override
  State<AttackPage> createState() => _AttackPageState();
}

class _AttackPageState extends State<AttackPage> {
  String? selectedAudio;
  String? selectedAttack;
  String? selectedParam;

  final List<String> audioOptions = [
    'host1_watermarked.wav',
    'host2_watermarked.wav',
    'host3_watermarked.wav',
  ];

  final Map<String, List<String>> attackParams = {
    'Low Pass Filter': ['cutoff 3 kHz', 'cutoff 6 kHz', 'cutoff 9 kHz'],
    'Band Pass Filter': [
      '100–3 kHz',
      '100–6 kHz',
      '100–9 kHz',
      '50–6 kHz',
      '25–6 kHz'
    ],
    'Requantization': ['8-bit depth'],
    'Additive Noise': ['SNR 10 dB', 'SNR 20 dB', 'SNR 30 dB'],
    'Resampling': [
      '44.1 → 11.025 kHz',
      '44.1 → 16 kHz',
      '44.1 → 22.05 kHz',
      '44.1 → 24 kHz'
    ],
    'Time Scale Modification': [
      'scale factor 0.99',
      'scale factor 0.98',
      'scale factor 0.97',
      'scale factor 0.96'
    ],
    'Linear Speed Change': [
      'speed factor 0.99',
      'speed factor 0.95',
      'speed factor 0.90'
    ],
    'Pitch Shifting': [
      'pitch factor 0.99',
      'pitch factor 0.98',
      'pitch factor 0.97',
      'pitch factor 0.96'
    ],
    'Equalizer': ['default preset'],
    'Echo': ['delay 0.3s, decay 100%'],
    'MP3 Compression': [
      '32 kbps',
      '64 kbps',
      '96 kbps',
      '128 kbps',
      '192 kbps'
    ],
  };

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

  void _applyAttack() {
    if (selectedAudio == null ||
        selectedAttack == null ||
        selectedParam == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select all options.")),
      );
      return;
    }

    // TODO: Ganti dengan pemanggilan backend/API untuk menerapkan serangan
    debugPrint("Applying $selectedAttack ($selectedParam) to $selectedAudio");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Applied $selectedAttack to $selectedAudio")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5E8E4),
      appBar: AppBar(
        title: const Text('Apply Attack'),
        backgroundColor: const Color(0xFFF5E8E4),
        foregroundColor: Color(0xFF411530),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Watermarked Audio',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF411530)),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              hint: const Text("Select Audio"),
              value: selectedAudio,
              isExpanded: true,
              items: audioOptions
                  .map((audio) =>
                      DropdownMenuItem(value: audio, child: Text(audio)))
                  .toList(),
              onChanged: (val) => setState(() => selectedAudio = val),
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 20),
            const Text(
              'Select Attack Type',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF411530)),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              hint: const Text("Select Attack"),
              value: selectedAttack,
              isExpanded: true,
              items: attackParams.keys
                  .map((type) =>
                      DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  selectedAttack = val;
                  selectedParam = null;
                });
              },
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 20),
            if (selectedAttack != null &&
                attackParams[selectedAttack!] != null) ...[
              const Text(
                'Select Attack Parameter',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF411530)),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                hint: const Text("Select Parameter"),
                value: selectedParam,
                isExpanded: true,
                items: attackParams[selectedAttack!]!
                    .map((param) =>
                        DropdownMenuItem(value: param, child: Text(param)))
                    .toList(),
                onChanged: (val) => setState(() => selectedParam = val),
                decoration: _inputDecoration(),
              ),
            ],
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _applyAttack,
              icon: const Icon(Icons.shield),
              label: const Text("Apply Attack"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5E2A4D),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const BottomNavBar(currentRoute: '/attack'),
    );
  }
}
