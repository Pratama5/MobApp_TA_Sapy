import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:wavemark_app_v1/Auth/LoginPage.dart';
import 'package:wavemark_app_v1/Auth/SignUpPage.dart';
import 'package:wavemark_app_v1/Page/Home.dart';

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
      initialRoute: '/',
      routes: {
        '/': (context) => AuthGate(),
        '/login': (context) => const LoginPage(),
        '/signup': (context) => const SignUpPage(),
        '/home': (context) => HomeScreen(),
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
