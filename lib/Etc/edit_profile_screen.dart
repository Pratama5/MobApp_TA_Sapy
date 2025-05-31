import 'package:flutter/material.dart';
import 'package:wavemark_app_v1/Etc/uploadProfilePicPage.dart'; // Your import for the upload page
import 'bottom_nav.dart'; // Assuming this is your custom bottom navigation
import 'package:supabase_flutter/supabase_flutter.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();
  bool isLoading = true;
  String? _networkAvatarUrl; // For URLs from Supabase/Google or newly uploaded

  // Theme Colors (copied from your previous version for consistency)
  static const Color _scaffoldBgColor = Color(0xFFF8EDEB);
  static const Color _appBarLeadingColor = Color(0xFFD1512D);
  static const Color _appBarTitleColor = Color(0xFF411530);
  static const Color _buttonPrimaryBgColor = Color(0xFFD1512D);
  static const Color _buttonPrimaryFgColor = Colors.white;

  @override
  void initState() {
    super.initState();
    _loadProfileDataFromSupabase();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _changeProfilePicture() async {
    final String? newAvatarUrl = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (context) => const UploadProfilePictureScreen()),
    );

    if (newAvatarUrl != null && newAvatarUrl.isNotEmpty) {
      if (mounted) {
        setState(() {
          _networkAvatarUrl = newAvatarUrl; // Update the URL to display
        });
      }
    }
  }

  Future<void> _loadProfileDataFromSupabase() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    final supabase = Supabase.instance.client;
    final currentUser = supabase.auth.currentUser;

    if (currentUser == null) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
      return;
    }

    _emailController.text = currentUser.email ?? '';
    _networkAvatarUrl = null; // Initialize

    try {
      final profileResponse = await supabase
          .from('profiles')
          .select(
              'display_name, bio, phone, avatar_url') // Select specific columns
          .eq('id', currentUser.id)
          .maybeSingle();

      if (profileResponse != null) {
        _nameController.text = profileResponse['display_name'] ?? '';
        _bioController.text = profileResponse['bio'] ?? '';
        _phoneController.text = profileResponse['phone'] ?? '';
        // Directly use avatar_url from DB as it should be a network URL or null
        _networkAvatarUrl = profileResponse['avatar_url'];
      } else {
        // Profile doesn't exist yet, pre-fill with Google data if available
        _nameController.text = currentUser.userMetadata?['full_name'] ??
            currentUser.userMetadata?['name'] ??
            '';
        _networkAvatarUrl =
            currentUser.userMetadata?['avatar_url']; // This is a network URL
        _bioController.text = '';
        _phoneController.text = '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final bio = _bioController.text.trim();
    final phone = _phoneController.text.trim();
    final currentUser = Supabase.instance.client.auth.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Not authenticated!')));
      return;
    }

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama Lengkap (Name) cannot be empty')));
      return;
    }

    if (!mounted) return;
    setState(() => isLoading = true);

    // _networkAvatarUrl now holds the URL from Google, loaded from DB, or newly uploaded
    final String? finalAvatarUrlToSave = _networkAvatarUrl;

    final profileData = {
      'id': currentUser.id,
      'display_name': name,
      'bio': bio,
      'phone': phone.isNotEmpty ? phone : null,
      'avatar_url': finalAvatarUrlToSave, // This will be null if no avatar
      'created_at': DateTime.now().toIso8601String(),
    };

    try {
      await Supabase.instance.client.from('profiles').upsert(
            profileData,
            onConflict: 'id',
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!')),
        );
        Navigator.pop(context, true); // Indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent, // Or your themed background color
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _appBarLeadingColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: _appBarTitleColor,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
      ),
      backgroundColor: _scaffoldBgColor,
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(
                  color: _buttonPrimaryBgColor)) // Use themed color
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _changeProfilePicture,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor:
                          Colors.grey.shade300, // Fallback background
                      backgroundImage: _networkAvatarUrl != null &&
                              _networkAvatarUrl!.isNotEmpty
                          ? NetworkImage(_networkAvatarUrl!)
                          : const AssetImage(
                                  'assets/profile_pic.png') // Default placeholder
                              as ImageProvider,
                      child: (_networkAvatarUrl == null ||
                                  _networkAvatarUrl!.isEmpty) &&
                              !(_networkAvatarUrl?.startsWith('http') ??
                                  false) // Also check if it's a valid network URL to avoid showing icon over asset
                          ? const Icon(Icons.person,
                              size: 50,
                              color: Colors.white70) // Icon if no image
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _changeProfilePicture,
                    child: const Text(
                      'Change Profile Picture',
                      style: TextStyle(color: _buttonPrimaryBgColor),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nama Lengkap',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[200],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _phoneController,
                    decoration: InputDecoration(
                      labelText: 'Nomor HP (Phone)',
                      prefixIcon: const Icon(Icons.phone_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _bioController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Bio',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _buttonPrimaryBgColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: _buttonPrimaryFgColor, strokeWidth: 2))
                          : const Text(
                              'Simpan',
                              style: TextStyle(
                                  fontSize: 16, color: _buttonPrimaryFgColor),
                            ),
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: const BottomNavBar(
          currentRoute: '/profile'), // Make sure this route is correct
    );
  }
}
