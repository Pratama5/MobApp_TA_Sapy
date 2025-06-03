// Home.dart

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart'; // For _logout
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wavemark_app_v1/Etc/about_app_screen.dart';
import 'package:wavemark_app_v1/Etc/bottom_nav.dart';
import 'package:url_launcher/url_launcher_string.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- State variables for profile data ---
  String _userName = 'User'; // Default value
  String _email = ''; // Default value
  String? _bio;
  String? _avatarUrl;
  bool _isLoadingProfile = true; // To manage loading state

  // ... (your existing onCardTap, _googleSignIn, _logout, _showLogoutSheet methods remain the same)
  void onCardTap(String label) {
    if (label == 'Embedding') {
      Navigator.pushNamed(context, '/embedding');
    } else if (label == 'Extraction') {
      Navigator.pushNamed(context, '/extraction');
    } else if (label == 'Profile') {
      // When navigating to profile, and then back, we might want to refresh data
      // This can be handled by awaiting the push or using a state management solution
      Navigator.pushNamed(context, '/profile')
          .then((_) => _loadProfileData()); // Refresh on return
    }
  }

  final GoogleSignIn _googleSignIn = GoogleSignIn();
  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    try {
      await _googleSignIn.disconnect();
    } catch (e) {
      debugPrint("Google disconnect failed: $e");
    }
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  void _showLogoutSheet() {
    // ... (this method is fine as is) ...
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFFF5E8E4),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Log out',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 10),
              const Text(
                'Are you sure you want to Log out?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFD1512D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Close sheet first
                        _logout(this.context); // Then logout
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD1512D),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Log out'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  // --- New method to load profile data ---
  Future<void> _loadProfileData() async {
    if (!mounted) return;
    // Don't set isLoading to true if it's a background refresh,
    // unless it's the initial load.
    if (_userName == 'User' && _email == '') {
      // Simple check for initial load
      setState(() => _isLoadingProfile = true);
    }

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _userName = 'Guest';
          _email = '';
          _avatarUrl = null;
          _bio = null;
          _isLoadingProfile = false;
        });
        // It's unusual for HomeScreen to have a null user, usually protected by auth guard.
        // If this happens, consider redirecting.
        // Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    final String authEmail = user.email ?? 'No email';
    // Initialize with fallbacks from auth metadata first
    String profileDisplayName =
        user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? 'User';
    String? profileAvatarUrl = user.userMetadata?['avatar_url'];
    String? profileBio;

    try {
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('display_name, avatar_url, bio')
          .eq('id', user.id)
          .maybeSingle();

      if (profileResponse != null) {
        profileDisplayName =
            profileResponse['display_name'] ?? profileDisplayName;
        profileAvatarUrl = profileResponse['avatar_url'] ?? profileAvatarUrl;
        profileBio = profileResponse['bio'];
      } else {
        print(
            "HomeScreen: No profile found in 'profiles' table for user ${user.id}. Using auth metadata.");
      }
    } catch (e) {
      print("HomeScreen: Error fetching profile from 'profiles' table: $e");
      // Data will remain as initialized from auth metadata in case of error
    }

    if (mounted) {
      setState(() {
        _userName = profileDisplayName;
        _email = authEmail;
        _avatarUrl = profileAvatarUrl;
        _bio = profileBio;
        _isLoadingProfile = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // final user = Supabase.instance.client.auth.currentUser; // Now fetched in _loadProfileData
    // final metadata = user?.userMetadata ?? {}; // Now fetched in _loadProfileData
    // final userName = ... // Now use _userName state variable
    // final email = ...    // Now use _email state variable
    // final bio = ...      // Now use _bio state variable
    // final avatarUrl = ... // Now use _avatarUrl state variable
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFF5E8E4),
      drawer: Drawer(
        backgroundColor: const Color(0xFFF5E8E4),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFF393646)),
              child:
                  _isLoadingProfile // Show loader or placeholder in DrawerHeader
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.white))
                      : Row(
                          children: [
                            CircleAvatar(
                              radius: 32,
                              backgroundColor:
                                  Colors.grey.shade400, // Fallback bg
                              backgroundImage: (_avatarUrl != null &&
                                      _avatarUrl!.isNotEmpty)
                                  ? NetworkImage(_avatarUrl!)
                                  : const AssetImage('assets/profile_pic.png')
                                      as ImageProvider,
                              child: (_avatarUrl == null ||
                                          _avatarUrl!.isEmpty) &&
                                      !(_avatarUrl?.startsWith('http') ?? false)
                                  ? const Icon(Icons.person,
                                      size: 32, color: Colors.white70)
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _userName, // Use state variable
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _email, // Use state variable
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (_bio != null &&
                                      _bio!.isNotEmpty) // Use state variable
                                    Text(
                                      _bio!,
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
            ),
            ListTile(
                leading: const Icon(Icons.person_outline), // Updated icon
                title: const Text('Profile'),
                onTap: () {
                  Navigator.pop(context); // Close drawer first
                  onCardTap('Profile');
                }),
            ListTile(
                leading: const Icon(Icons.settings_outlined), // Updated icon
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context); // Close drawer first
                  Navigator.pushNamed(context, '/settings');
                }),
            ListTile(
                leading: const Icon(Icons.info_outline), // Updated icon
                title: const Text('About App'),
                onTap: () {
                  Navigator.pop(context); // Close drawer first
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AboutAppScreen(),
                    ),
                  );
                }),
            ListTile(
              leading: const Icon(
                  Icons.feedback_outlined), // Or Icons.rate_review_outlined
              title: const Text('Survey & Feedback'),
              onTap: () {
                Navigator.pop(context); // Close the drawer
                // TODO: Implement navigation to your Survey/Feedback page or launch URL
                // Example: Navigator.pushNamed(context, '/feedback');
                launchUrlString('https://forms.gle/9wyTSGQKomd2nVVQ8');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Redirecting!")),
                );
              },
            ),
            ListTile(
                leading: const Icon(Icons.logout_rounded), // Updated icon
                title: const Text('Log Out'),
                onTap: () {
                  Navigator.pop(context); // Close drawer first
                  _showLogoutSheet();
                }),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                // ... (AppBar section is fine as is) ...
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Builder(
                        builder: (context) => IconButton(
                          icon: const Icon(
                            Icons.menu,
                            color: Color(0xFF411530),
                          ),
                          onPressed: () => Scaffold.of(context).openDrawer(),
                        ),
                      ),
                    ),
                    const Center(
                      child: Text(
                        'WaveMark',
                        style: TextStyle(
                          fontFamily: 'Archivo Black',
                          fontSize: 24,
                          color: Color(0xFF411530),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Image.asset(
                'assets/turntable.png',
                width: screenWidth,
                height: 430,
                fit: BoxFit.cover,
              ),
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    // ... (Feature card container is fine as is) ...
                    width: double.infinity,
                    padding: const EdgeInsets.only(
                      top: 60, // Space for the welcome card
                      left: 20,
                      right: 20,
                      bottom: 20,
                    ),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF6F3),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(
                            height: 30), // Adjust if needed after welcome card
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _featureCard('Embedding', 'assets/embed_icon.png'),
                            const SizedBox(width: 70),
                            _featureCard(
                                'Extraction', 'assets/extract_icon.png'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: -40, // Adjust this to position the card correctly
                    left: 20, // Added padding from edge
                    right: 20, // Added padding from edge
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(
                            0xFFFFF6F3), // Or Colors.white for more contrast
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child:
                          _isLoadingProfile // Show loader or placeholder in Welcome card
                              ? const SizedBox(
                                  height: 50, // Give some height for the loader
                                  child: Center(
                                      child: CircularProgressIndicator(
                                          color: Color(0xFFD1512D))))
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Welcome,",
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFFD1512D),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Text(
                                      _userName, // Use state variable
                                      style: const TextStyle(
                                        fontSize: 24,
                                        color: Color(0xFF411530),
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomNavBar(
          currentRoute: '/'), // Ensure currentRoute is correct
    );
  }

  Widget _featureCard(String label, String imagePath) {
    // ... (this widget method is fine as is) ...
    final screenWidth = MediaQuery.of(context).size.width;
    return GestureDetector(
      onTap: () => onCardTap(label),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.asset(
              imagePath,
              width: screenWidth * 0.28,
              height: screenWidth * 0.28,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Color(0xFF411530),
            ),
          ),
        ],
      ),
    );
  }
}
