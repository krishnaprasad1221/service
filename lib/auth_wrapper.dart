// lib/auth_wrapper.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:serviceprovider/dashboards/admin_dashboard.dart';
import 'package:serviceprovider/dashboards/serviceprovider_dashboard.dart';
import 'package:serviceprovider/edit_profile_screen.dart';
import 'package:serviceprovider/login_screen.dart';
import 'package:serviceprovider/user_dashboard.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. If connection is still loading, show a progress indicator
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. If a user is logged in
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(snapshot.data!.uid).get(),
            builder: (context, userDocSnapshot) {
              if (userDocSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }

              if (userDocSnapshot.hasData && userDocSnapshot.data!.exists) {
                final userData = userDocSnapshot.data!.data() as Map<String, dynamic>;
                final userRole = userData['role'];

                // Route based on role from Firestore
                if (userRole == 'Admin') {
                  return const AdminDashboard();
                } else if (userRole == 'User') {
                  return const UserDashboard();
                } else if (userRole == 'Service Provider') {
                    // This logic is from your login screen, ensuring consistency
                    final isProfileComplete = userData['isProfileComplete'] ?? false;
                    if (!isProfileComplete){
                      return const EditProfileScreen(isCompletingProfile: true);
                    } 
                    return const ServiceProviderDashboard();
                }
              }
              
              // If user exists in Auth but not in Firestore, send to login
              return const LoginScreen();
            },
          );
        }

        // 3. If no user is logged in, show the login screen
        return const LoginScreen();
      },
    );
  }
}