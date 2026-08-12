import 'package:flutter/material.dart';
import 'package:style_match/screen/home_screen.dart';
import 'package:style_match/screen/login_screen.dart';
import 'package:style_match/services/auth_service.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.isLoggedIn(),
      builder: (context, snapshot) {
        // While checking the session, show a branded splash state.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        // If logged in, go to Home. Otherwise, show Login.
        if (snapshot.data == true) {
          return const HomeScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}

/// A minimal, premium splash screen for the "Silent Login" phase.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2), // Theme background
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Branded Icon
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
              child: const Icon(Icons.checkroom, size: 64, color: Color(0xFF0F766E)),
            ),
            const SizedBox(height: 24),
            // App Name
            const Text(
              "Style Match",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF171717),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
