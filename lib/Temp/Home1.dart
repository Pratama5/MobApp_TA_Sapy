import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _showSearch = false;

  void onNavTap(String label) {
    if (label == 'Profile') {
      Navigator.pushNamed(context, '/profile');
    } else if (label == 'library') {
      Navigator.pushNamed(
          context, '/library'); // this is the route for LibraryPage
    } else {
      debugPrint('Navigasi ke $label');
    }
  }

  void onCardTap(String label) {
    if (label == 'Watermark' || label == 'Upload') {
      Navigator.pushNamed(context, '/upload');
    } else if (label == 'Embed') {
      Navigator.pushNamed(context, '/embedding');
    } else if (label == 'Extract') {
      Navigator.pushNamed(context, '/extraction');
    } else {
      debugPrint('Klik pada: $label');
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final metadata = user?.userMetadata ?? {};
    final userName = metadata['username'] ??
        metadata['full_name'] ??
        metadata['name'] ??
        'User';

    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF5E8E4),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Icon(Icons.menu, color: Color(0xFF411530)),
                        const Text(
                          'WaveMark',
                          style: TextStyle(
                            fontFamily: 'Archivo Black',
                            fontSize: 24,
                            color: Color(0xFF411530),
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _showSearch = !_showSearch;
                            });
                          },
                          child: const Icon(Icons.search,
                              color: Color(0xFFD1512D)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Search Field
                    _showSearch
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search media...',
                                prefixIcon: const Icon(Icons.search,
                                    color: Color(0xFF411530)),
                                filled: true,
                                fillColor: const Color(0xFFFFF6F3),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),

                    // Welcome Text
                    Text(
                      "Welcome,",
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFFD1512D),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 24,
                        color: Color(0xFF411530),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Watermark Banner
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: GestureDetector(
                        onTap: () => onCardTap('Watermark'),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset(
                            "assets/banner.png",
                            height: screenWidth * 0.55,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                height: screenWidth * 0.55,
                                color: Colors.red.withOpacity(0.2),
                                alignment: Alignment.center,
                                child: const Text('Gagal memuat banner.png'),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 50),

                    // Cards
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => onCardTap('Embed'),
                          child: buildMediaCard(
                              "Audio", "assets/audio_cover.png", context),
                        ),
                        GestureDetector(
                          onTap: () => onCardTap('Extract'),
                          child: buildMediaCard(
                              "Image", "assets/image_cover.png", context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Navigation
            SizedBox(
              height: 88,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset("assets/nav_bg.png",
                      fit: BoxFit.cover, width: double.infinity),
                  Positioned(
                    bottom: 10,
                    child: GestureDetector(
                      onTap: () => onCardTap('Upload'),
                      child: Image.asset("assets/home_button.png",
                          width: 72, height: 72),
                    ),
                  ),
                  Positioned(
                    left: 32,
                    bottom: 20,
                    child: GestureDetector(
                      onTap: () => onCardTap('Upload'),
                      child: Image.asset("assets/upload.png", width: 24),
                    ),
                  ),
                  Positioned(
                    left: 90,
                    bottom: 20,
                    child: GestureDetector(
                      onTap: () => onNavTap('library'),
                      child: Image.asset("assets/book.png", width: 28),
                    ),
                  ),
                  Positioned(
                    right: 90,
                    bottom: 20,
                    child: GestureDetector(
                      onTap: () => onNavTap('Music'),
                      child: Image.asset("assets/headphones.png", width: 28),
                    ),
                  ),
                  Positioned(
                    right: 32,
                    bottom: 20,
                    child: GestureDetector(
                      onTap: () => onNavTap('Profile'),
                      child: const Icon(Icons.person,
                          size: 28, color: Colors.white70),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildMediaCard(String label, String imagePath, BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Image.asset(
            imagePath,
            width: screenWidth * 0.42,
            height: screenWidth * 0.39,
            fit: BoxFit.cover,
          ),
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
