// lib/main.dart

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:serviceprovider/auth_wrapper.dart'; // <-- IMPORT THE NEW WRAPPER
import 'package:serviceprovider/welcome_screen.dart';

import 'firebase_options.dart'; // From FlutterFire CLI

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🔗 Keeping your helpful Firebase Console link printout
  const String firebaseProjectId = "YOUR_PROJECT_ID"; // Replace with your Firebase Project ID
  print(
    "🚀 Open Firebase Console: https://console.firebase.google.com/project/$firebaseProjectId/overview",
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'On Demand Service App', // Changed title to reflect the whole app
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity, // Good for modern UI
      ),
      // Start at a polished WelcomeScreen, then it navigates to AuthWrapper.
      home: const WelcomeScreen(),
    );
  }
}