// import 'package:flutter/material.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:google_sign_in/google_sign_in.dart';

// // class LoginPage extends StatefulWidget {
// //   const LoginPage({Key? key}) : super(key: key);

// //   @override
// //   State<LoginPage> createState() => _LoginPageState();
// // }

// // class _LoginPageState extends State<LoginPage> {
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();
//   final GoogleSignIn _googleSignIn = GoogleSignIn(
//     scopes: ['email', 'openid'],
//     serverClientId:
//         '351802350238-icrdvr0li2gmc21mgeucbr1pv689t7if.apps.googleusercontent.com',
//   );
//   bool _isLoading = false;

//   Future<void> _login() async {
//     setState(() => _isLoading = true);
//     final email = _emailController.text.trim();
//     final password = _passwordController.text.trim();

//     try {
//       final response = await Supabase.instance.client.auth
//           .signInWithPassword(email: email, password: password);
//       if (response.user != null) {
//         Navigator.pushReplacementNamed(context, '/home');
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Login failed: \${e.toString()}')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   Future<void> _signInWithGoogle() async {
//     setState(() => _isLoading = true);

//     try {
//       final googleUser = await _googleSignIn.signIn();
//       if (googleUser == null) {
//         throw Exception("User canceled Google sign-in.");
//       }

//       final googleAuth = await googleUser.authentication;

//       print("ID Token: ${googleAuth.idToken}");
//       print("Access Token: ${googleAuth.accessToken}");

//       if (googleAuth.idToken == null || googleAuth.accessToken == null) {
//         throw Exception(
//             "Missing Google Auth token(s). Make sure Google sign-in is correctly configured.");
//       }

//       final response = await Supabase.instance.client.auth.signInWithIdToken(
//         provider: OAuthProvider.google,
//         idToken: googleAuth.idToken!,
//         accessToken: googleAuth.accessToken,
//       );

//       if (response.user != null) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('Google login successful!')),
//         );
//         Navigator.pushReplacementNamed(context, '/home');
//       } else {
//         throw Exception('Google login failed: user is null.');
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Google login failed: $e')),
//       );
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       resizeToAvoidBottomInset: true,
//       backgroundColor: Color.fromRGBO(255, 241, 232, 1),
//       body: SafeArea(
//         child: SingleChildScrollView(
//           padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
//           child: Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               const SizedBox(height: 24),
//               Container(
//                 height: 200,
//                 width: 200,
//                 decoration: const BoxDecoration(
//                   image: DecorationImage(
//                     image: AssetImage('assets/logo_wavemark.png'), // Sit.png
//                     fit: BoxFit.contain,
//                   ),
//                 ),
//               ),
//               const SizedBox(height: 24),
//               _buildTextField("Email"),
//               const SizedBox(height: 16),
//               _buildPasswordField("Password", _obscurePassword, () {
//                 setState(() {
//                   _obscurePassword = !_obscurePassword;
//                 });
//               }),
//               const SizedBox(height: 24),
//               ElevatedButton(
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: const Color(0xFFE4572E),
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(10),
//                   ),
//                   minimumSize: const Size(double.infinity, 48),
//                 ),
//                 onPressed: () {},
//                 child: Text(
//                   "Masuk",
//                   style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
//                 ),
//               ),
//               const SizedBox(height: 16),
//               Row(
//                 children: const [
//                   Expanded(child: Divider()),
//                   Padding(
//                     padding: EdgeInsets.symmetric(horizontal: 8.0),
//                     child: Text("Atau masuk menggunakan"),
//                   ),
//                   Expanded(child: Divider()),
//                 ],
//               ),
//               const SizedBox(height: 16),
//               _buildSocialButton(FontAwesomeIcons.google, "Google", Colors.red,
//                   _handleGoogleSignIn),
//               const SizedBox(height: 12),
//               _buildSocialButton(
//                   FontAwesomeIcons.facebook, "Facebook", Colors.blue, () {}),
//               const SizedBox(height: 24),
//               Wrap(
//                 alignment: WrapAlignment.center,
//                 children: [
//                   Text(
//                     "Belum punya akun? ",
//                     style: GoogleFonts.poppins(color: Colors.black87),
//                   ),
//                   GestureDetector(
//                     onTap: () {
//                       Navigator.pushNamed(context, '/signup');
//                     },
//                     child: Text(
//                       "daftar",
//                       style: GoogleFonts.poppins(
//                         color: Colors.blue,
//                         decoration: TextDecoration.underline,
//                       ),
//                     ),
//                   ),
//                 ],
//               )
//             ],
//           ),
//         ),
//       ),
//     );
//   }

//   Widget _buildTextField(String hint) {
//     return TextField(
//       decoration: InputDecoration(
//         hintText: hint,
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(10),
//           borderSide: const BorderSide(color: Colors.deepPurple),
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(10),
//           borderSide: const BorderSide(color: Colors.deepPurple),
//         ),
//         hintStyle: GoogleFonts.poppins(),
//         filled: true,
//         fillColor: Colors.white,
//       ),
//     );
//   }

//   Widget _buildPasswordField(String hint, bool obscure, VoidCallback toggle) {
//     return TextField(
//       obscureText: obscure,
//       decoration: InputDecoration(
//         hintText: hint,
//         suffixIcon: IconButton(
//           icon: Icon(
//             obscure ? Icons.visibility_off : Icons.visibility,
//             color: Colors.grey,
//           ),
//           onPressed: toggle,
//         ),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(10),
//           borderSide: const BorderSide(color: Colors.deepPurple),
//         ),
//         enabledBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(10),
//           borderSide: const BorderSide(color: Colors.deepPurple),
//         ),
//         hintStyle: GoogleFonts.poppins(),
//         filled: true,
//         fillColor: Colors.white,
//       ),
//     );
//   }

//   Widget _buildSocialButton(
//       IconData icon, String label, Color color, VoidCallback onPressed) {
//     return SizedBox(
//       width: double.infinity,
//       height: 48,
//       child: OutlinedButton.icon(
//         icon: FaIcon(icon, color: color),
//         label: Text(
//           label,
//           style: GoogleFonts.poppins(color: color),
//         ),
//         style: OutlinedButton.styleFrom(
//           side: BorderSide(color: color),
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//         ),
//         onPressed: onPressed,
//       ),
//     );
//   }
// }
