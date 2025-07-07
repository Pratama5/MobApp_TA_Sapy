import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:wavemark_app_v1/Auth/LoginPage.dart';
import 'package:wavemark_app_v1/Auth/SignUpPage.dart';
import 'package:wavemark_app_v1/History/HiddenUpload.dart';
import 'package:wavemark_app_v1/History/HistoryAudioPage.dart';
import 'package:wavemark_app_v1/History/HistoryImagePage.dart';
import 'package:wavemark_app_v1/History/history_screen.dart';
import 'package:wavemark_app_v1/Library/LibraryAudioPage.dart';
import 'package:wavemark_app_v1/Library/LibraryImagePage.dart';
import 'package:wavemark_app_v1/Library/UploadAudioPage.dart';
import 'package:wavemark_app_v1/Library/UploadImagePage.dart';
import 'package:wavemark_app_v1/Page/EmbeddingPage.dart';
import 'package:wavemark_app_v1/Page/ExtractionPage.dart';
import 'package:wavemark_app_v1/Page/Home.dart';
import 'package:wavemark_app_v1/Page/Attackpage.dart';
import 'package:wavemark_app_v1/Etc/ProfilePage.dart';
import 'package:wavemark_app_v1/Etc/SettingsPage.dart';
import 'package:wavemark_app_v1/Library/library_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://amteejgqwgugfvgnoagb.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFtdGVlamdxd2d1Z2Z2Z25vYWdiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDY2ODc3MzUsImV4cCI6MjA2MjI2MzczNX0.WF-MzVig7lj-g21gMDcQHVZL-whmeJTSaOYH9bn3Um0',
  );
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final SupabaseClient supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wavemark App',
      theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false,

      initialRoute:
          '/', //  FOR TESTING: Open HomeScreen directly. Leave as '/' for production.
      routes: {
        '/': (context) => AuthGate(), // keep this for future use
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => const HomeScreen(),
        '/profile': (context) => const ProfilePage(),
        '/library': (context) => const LibraryScreen(),
        '/library_audio': (context) => const LibraryAudioPage(),
        '/library_images': (context) => const LibraryImagePage(),
        '/history': (context) => const HistoryScreen(),
        '/history_audio': (context) => const HistoryAudioPage(),
        '/history_images': (context) => const HistoryImagePage(),
        '/embedding': (context) => const EmbeddingPage(),
        '/extraction': (context) => const ExtractionPage(),
        '/settings': (context) => const SettingsPage(),
        '/uploadAudio': (context) => const UploadAudioPage(),
        '/uploadImage': (context) => const UploadImagePage(),
        '/hidden': (context) => const HiddenUpload(),
        '/attack': (context) => const AttackPage(),
      },
    );
  }
}

class AuthGate extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      return HomeScreen();
    } else {
      return LoginPage();
    }
  }
}
