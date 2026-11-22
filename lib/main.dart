// main.dart
// starts the app, shows the splash while firebase loads, then picks login
// or the board from the auth state

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'auth_service.dart';
import 'board_screen.dart';
import 'firebase_options.dart';
import 'login_screen.dart';

// run with --dart-define=USE_EMULATOR=true to hit the local suite
const bool useEmulator = bool.fromEnvironment('USE_EMULATOR');

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Message Board',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// splash screen, also starts firebase
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late Future<FirebaseApp> _start;

  @override
  void initState() {
    super.initState();
    // start firebase once, keep the future out of build
    _start = _initialize();
  }

  Future<FirebaseApp> _initialize() async {
    FirebaseApp app = await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // point at the local emulators when the flag is set
    if (useEmulator) {
      await FirebaseAuth.instance.useAuthEmulator('10.0.2.2', 9099);
      FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
    }

    return app;
  }

  void _tryAgain() {
    setState(() {
      _start = _initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: _start,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 56, color: Colors.grey),
                    const SizedBox(height: 16),
                    const Text(
                      'Firebase could not start.',
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _tryAgain,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          // the splash itself
          return const Scaffold(
            backgroundColor: Color(0xFFFFF3E0),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.forum, size: 72, color: Colors.deepOrange),
                  SizedBox(height: 12),
                  Text(
                    'Message Board',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 24),
                  CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }

        return const AuthGate();
      },
    );
  }
}

// watch the auth state and pick the screen
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    AuthService auth = AuthService();

    // three states: waiting, signed out, signed in
    return StreamBuilder<User?>(
      stream: auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.data == null) {
          return const LoginScreen();
        }
        return const BoardScreen();
      },
    );
  }
}
