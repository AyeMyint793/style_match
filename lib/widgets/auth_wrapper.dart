import 'package:flutter/material.dart';
import 'package:style_match/screen/home_screen.dart';
import 'package:style_match/screen/login_screen.dart';
import 'package:style_match/services/auth_service.dart';

/// The Root entry-point of the application.
/// It determines whether to show the [LoginScreen] or the [HomeScreen]
/// based on the existence of a valid user session.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: AuthService.isLoggedIn(),
      builder: (context, snapshot) {
        // While checking the session, show a clean, branded loading state.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF0F766E),
              ),
            ),
          );
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
