import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:wavemark_app_v1/Etc/edit_profile_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'openid'],
    serverClientId:
        '351802350238-icrdvr0li2gmc21mgeucbr1pv689t7if.apps.googleusercontent.com',
  );
  bool _isLoading = false;

  Future<void> _login() async {
    setState(() => _isLoading = true);
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final response = await Supabase.instance.client.auth
          .signInWithPassword(email: email, password: password);
      if (response.user != null) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${e.toString()}')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw Exception("User canceled Google sign-in.");
      }

      final googleAuth = await googleUser.authentication;

      print("ID Token: ${googleAuth.idToken}");
      print("Access Token: ${googleAuth.accessToken}");

      if (googleAuth.idToken == null || googleAuth.accessToken == null) {
        throw Exception(
            "Missing Google Auth token(s). Make sure Google sign-in is correctly configured.");
      }

      final response = await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      if (response.user != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google login successful!')),
        );
        // Navigator.pushReplacementNamed(
        //     context, '/home'); // Navigate to home screen
        await _handleUserProfile(response.user!);
      } else {
        throw Exception('Google login failed: user is null.');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Google login failed: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleUserProfile(User user) async {
    if (!mounted) return;

    final profileResponse = await Supabase.instance.client
        .from('profiles')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();

    if (profileResponse == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const EditProfileScreen()),
      );
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color.fromRGBO(255, 241, 232, 1),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Container(
                height: 200,
                width: 200,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/logo_wavemark.png'),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  hintText: 'Email',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  hintText: 'Password',
                  suffixIcon: const Icon(Icons.visibility_off),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Lupa password?',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE0592A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Masuk'),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '—Atau masuk menggunakan—',
                style: GoogleFonts.montserrat(color: Colors.grey[600]),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(FontAwesomeIcons.google,
                          color: Colors.red),
                      label: const Text('Google'),
                      onPressed: _isLoading ? null : _signInWithGoogle,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(FontAwesomeIcons.facebookF,
                          color: Colors.blue),
                      label: const Text('Facebook'),
                      onPressed:
                          _isLoading // Also disable this button if _isLoading is true
                              ? null
                              : () {
                                  // Show a SnackBar when the Facebook button is pressed
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          "Facebook login is currently under development."),
                                      duration:
                                          Duration(seconds: 2), // Optional
                                    ),
                                  );
                                },
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        side: const BorderSide(color: Colors.blue),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Belum punya akun?'),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/signup'),
                    child: const Text(
                      'Mendaftar sekarang',
                      style: TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
