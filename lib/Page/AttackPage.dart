import 'package:flutter/material.dart';
import 'package:wavemark_app_v1/Etc/bottom_nav.dart';
import 'package:wavemark_app_v1/Page/AttackResult.dart'; // pastikan path ini benar

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

  void _showAttackInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFFF5E8E4),
        title: const Text('Penjelasan Attack',
            style: TextStyle(color: Color(0xFF411530))),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Attack adalah modifikasi audio seperti filter, noise, atau kompresi yang dapat merusak watermark.',
                style: TextStyle(color: Color(0xFF411530)),
              ),
              SizedBox(height: 12),
              Text('• Low Pass Filter: Menghapus frekuensi tinggi.'),
              Text('• Band Pass Filter: Menyaring frekuensi tertentu.'),
              Text('• Requantization: Menurunkan bit-depth audio.'),
              Text('• Additive Noise: Menambahkan gangguan noise.'),
              Text('• Resampling: Mengubah sampling rate audio.'),
              Text('• Time Scale Modification: Mengubah durasi audio.'),
              Text('• Linear Speed Change: Mempercepat atau memperlambat.'),
              Text('• Pitch Shifting: Mengubah nada suara.'),
              Text('• Equalizer: Mengatur kekuatan frekuensi.'),
              Text('• Echo: Menambahkan gema pada audio.'),
              Text('• MP3 Compression: Mengompres audio ke MP3.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('Tutup', style: TextStyle(color: Color(0xFF5E2A4D))),
          ),
        ],
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

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttackResult(
          originalAudio: selectedAudio!,
          attackedAudio: 'attacked_${selectedAudio!}',
          attackType: selectedAttack!,
          attackParam: selectedParam!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5E8E4),
      appBar: AppBar(
        title: const Text(
          'Apply Attack',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF411530),
          ),
        ),
        backgroundColor: const Color(0xFFF5E8E4),
        foregroundColor: const Color(0xFF411530),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showAttackInfo(context),
          )
        ],
      ),
      body: SingleChildScrollView(
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
            if (selectedAudio != null) ...[
              const Center(
                child:
                    Icon(Icons.headphones, size: 48, color: Color(0xFF411530)),
              ),
              const SizedBox(height: 8),
              Center(
                child: Column(
                  children: [
                    const Text('Selected Audio',
                        style:
                            TextStyle(fontSize: 16, color: Color(0xFF411530))),
                    const SizedBox(height: 4),
                    Text(
                      selectedAudio!,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF411530)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('00:00'),
                  Expanded(
                    child: Slider(
                      value: 0,
                      onChanged: (val) {},
                      min: 0,
                      max: 30,
                      activeColor: Colors.redAccent,
                      inactiveColor: Colors.grey.shade300,
                    ),
                  ),
                  const Text('00:30'),
                ],
              ),
              const Center(
                child: Icon(Icons.play_arrow, size: 32, color: Colors.black87),
              ),
              const SizedBox(height: 24),
            ],
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
            const SizedBox(height: 24),
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
