import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart'; // For _logout
import 'package:supabase_flutter/supabase_flutter.dart';
import 'about_app_screen.dart'; // Your import
import 'edit_profile_screen.dart'; // Your import
import 'bottom_nav.dart'; // Your import

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String name = 'User'; // Default value
  String email = ''; // Default value
  String? bio;
  String? avatarUrl;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileFromSupabase();
  }

  // Logout logic remains the same
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  Future<void> _logout(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    try {
      await _googleSignIn.disconnect();
    } catch (e) {
      debugPrint("Google disconnect failed: $e");
    }
    if (mounted) {
      // Check if mounted before navigating
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _loadProfileFromSupabase() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          isLoading = false;
          name = 'Guest';
          email = 'Not logged in';
          avatarUrl = null;
          bio = null;
        });
        // Optionally navigate to login or handle appropriately
        // Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    // Always get email from the auth user
    final String authEmail = user.email ?? 'No email provided';

    // Initialize with fallbacks from auth metadata first
    String profileDisplayName = user.userMetadata?['full_name'] ??
        user.userMetadata?['name'] ??
        'User'; // Fallback to 'User' if names are null
    String? profileAvatarUrl = user.userMetadata?['avatar_url'];
    String? profileBio; // Bio is less likely to be in auth metadata

    try {
      // Fetch the profile from your 'profiles' table
      final profileResponse = await Supabase.instance.client
          .from('profiles')
          .select('display_name, avatar_url, bio') // Select only needed fields
          .eq('id', user.id)
          .maybeSingle();

      if (profileResponse != null) {
        // Profile exists in 'profiles' table, prioritize its data
        profileDisplayName =
            profileResponse['display_name'] ?? profileDisplayName;
        profileAvatarUrl = profileResponse['avatar_url'] ??
            profileAvatarUrl; // Prioritize profile's avatar_url
        profileBio = profileResponse['bio'];
      } else {
        // Profile doesn't exist in 'profiles' table.
        // We've already set initial values from user.user_metadata.
        // This might be a good place to log or consider if user should be forced to EditProfileScreen
        print(
            "ProfilePage: No profile found in 'profiles' table for user ${user.id}. Using auth metadata as fallback.");
      }
    } catch (e) {
      print("ProfilePage: Error fetching profile from 'profiles' table: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('Could not load all profile details: ${e.toString()}')));
      }
      // In case of error, we're already using fallbacks from user.user_metadata initialized above.
    }

    if (mounted) {
      setState(() {
        name = profileDisplayName;
        email = authEmail;
        avatarUrl =
            profileAvatarUrl; // This will now prioritize the URL from your 'profiles' table
        bio = profileBio;
        isLoading = false;
      });
    }
  }

  void _editProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    // If EditProfileScreen indicates data was saved (e.g., returns true), refresh profile
    if (result == true && mounted) {
      _loadProfileFromSupabase();
    }
  }

  void _showLogoutDialog() {
    // ... (your existing _showLogoutDialog method is fine) ...
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
                        side: const BorderSide(color: Color(0xFFD1512D)),
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
                      // Pass the correct BuildContext to _logout
                      onPressed: () => _logout(this
                          .context), // Use this.context or ensure context is from builder
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD1512D),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Log Out'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ImageProvider<Object> avatarImage = (avatarUrl != null &&
            avatarUrl!.isNotEmpty)
        ? NetworkImage(
            avatarUrl!) // This will be from 'profiles' table if available
        : const AssetImage('assets/profile_pic.png') as ImageProvider<Object>;

    return Scaffold(
      backgroundColor: const Color(0xFFF5E8E4),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFFD1512D)),
            // Ensure pop can happen, or remove if this is a root page in this tab
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                // Handle case where it can't pop, e.g., navigate to home or do nothing
                Navigator.pushReplacementNamed(context, '/home');
              }
            }),
        title: const Text(
          'Profile',
          style: TextStyle(
            color: Color(0xFF411530),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFFD1512D))) // Themed loader
            : RefreshIndicator(
                // Added RefreshIndicator for pull-to-refresh
                onRefresh: _loadProfileFromSupabase,
                color: const Color(0xFFD1512D), // Theme color for indicator
                child: ListView(
                  // Changed to ListView to support RefreshIndicator easily
                  children: [
                    Center(
                      // Center the avatar and user info
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor:
                                Colors.grey.shade300, // Fallback background
                            backgroundImage: avatarImage,
                            child: (avatarUrl == null || avatarUrl!.isEmpty) &&
                                    !(avatarUrl?.startsWith('http') ?? false)
                                ? const Icon(Icons.person,
                                    size: 50, color: Colors.white70)
                                : null,
                          ),
                          const SizedBox(height: 20),
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF411530),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(email,
                              style: const TextStyle(color: Colors.black54)),
                          if (bio != null && bio!.isNotEmpty) ...[
                            const SizedBox(height: 12), // Increased spacing
                            Container(
                              // Added a container for better bio presentation
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0, vertical: 8.0),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                bio!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.black87,
                                    fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),

                    /// Menu Cards
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: ListTile(
                        leading: const Icon(
                          Icons.edit_outlined, // Changed icon
                          color: Color(0xFFD1512D),
                        ),
                        title: const Text('Edit Profile'),
                        onTap: _editProfile,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: ListTile(
                        leading: const Icon(
                          Icons.settings_outlined, // Changed icon
                          color: Color(0xFFD1512D),
                        ),
                        title: const Text('Settings'),
                        onTap: () => Navigator.pushNamed(context, '/settings'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: ListTile(
                        leading: const Icon(
                          Icons.info_outline_rounded, // Changed icon
                          color: Color(0xFFD1512D),
                        ),
                        title: const Text('About App'),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AboutAppScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      child: ListTile(
                        leading: const Icon(Icons.logout_rounded,
                            color: Colors.red), // Changed icon
                        title: const Text('Log Out'),
                        onTap: _showLogoutDialog,
                      ),
                    ),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: const BottomNavBar(currentRoute: '/profile'),
    );
  }
}
