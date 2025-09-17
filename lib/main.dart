import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:serviceprovider/login_screen.dart';

import 'firebase_options.dart'; // From FlutterFire CLI

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🔗 Print Firebase Console link in the Run console
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
      title: 'Registration App',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginScreen(),
    );
  }
}
