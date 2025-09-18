// lib/auth_wrapper.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:serviceprovider/dashboards/admin_dashboard.dart';
import 'package:serviceprovider/dashboards/serviceprovider_dashboard.dart';
import 'package:serviceprovider/login_screen.dart';
import 'package:serviceprovider/user_dashboard.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 1. If the connection is still loading, show a progress indicator
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // 2. If the snapshot has data, it means the user is logged in
        if (snapshot.hasData && snapshot.data != null) {
          // Now, check the user's role to redirect them to the correct dashboard
          return RoleBasedRedirect(userId: snapshot.data!.uid);
        }

        // 3. If there's no data, the user is not logged in
        return const LoginScreen();
      },
    );
  }
}

class RoleBasedRedirect extends StatelessWidget {
  final String userId;

  const RoleBasedRedirect({super.key, required this.userId});

  Future<DocumentSnapshot> _getUserData() {
    return FirebaseFirestore.instance.collection('users').doc(userId).get();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: _getUserData(),
      builder: (context, userSnapshot) {
        // If we are still waiting for user data, show a loading screen
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If there's an error or the user document doesn't exist, log out and go to login
        if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
          // It's safer to sign out if the user's data is missing
          FirebaseAuth.instance.signOut();
          return const LoginScreen();
        }

        // If we have the user data, determine the role and redirect
        final userData = userSnapshot.data!.data() as Map<String, dynamic>;
        final userRole = userData['role'];

        switch (userRole) {
          case 'Admin':
            return const AdminDashboard();
          case 'User':
            return const UserDashboard();
          case 'Service Provider':
            return const ServiceProviderDashboard();
          default:
            // If the role is unknown, default to the login screen
            return const LoginScreen();
        }
      },
    );
  }
}