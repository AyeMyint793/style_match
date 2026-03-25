import 'package:flutter/material.dart';
import 'profile_setup_screen.dart';
import 'register_screen.dart';
import '../services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> loginUser() async {

    bool success = await ApiService.login(
      emailController.text.trim(),
      passwordController.text.trim(),
    );

    if (success) {

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString("email", emailController.text); // ✅ save email

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const ProfileSetupScreen(),
        ),
      );

    }  else {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login failed")),
      );

    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFE5E5E5),

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),

          child: Container(
            padding: const EdgeInsets.all(25),

            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 20,
                  offset:  Offset(0, 8),
                ),
              ],
            ),

            child: Form(
              key: _formKey,

              child: Column(
                mainAxisSize: MainAxisSize.min,

                children: [

                  const Icon(Icons.style, size: 60, color: Colors.black87),

                  const SizedBox(height: 10),

                  const Text(
                    "Style Match",
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  const Text(
                    "Login to continue",
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 25),

                  // EMAIL FIELD

                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,

                    validator: (value) {

                      if (value == null || value.isEmpty) {
                        return "Enter your email";
                      }

                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$')
                          .hasMatch(value)) {
                        return "Enter a valid email";
                      }

                      return null;
                    },

                    decoration: InputDecoration(
                      hintText: "Email",
                      prefixIcon: const Icon(Icons.email_outlined),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F2),

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // PASSWORD FIELD

                  TextFormField(
                    controller: passwordController,
                    obscureText: true,

                    validator: (value) {

                      if (value == null || value.isEmpty) {
                        return "Enter your password";
                      }

                      if (value.length < 6) {
                        return "Password must be at least 6 characters";
                      }

                      return null;
                    },

                    decoration: InputDecoration(
                      hintText: "Password",
                      prefixIcon: const Icon(Icons.lock_outline),
                      filled: true,
                      fillColor: const Color(0xFFF2F2F2),

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  // LOGIN BUTTON

                  SizedBox(
                    width: double.infinity,
                    height: 50,

                    child: ElevatedButton(

                      onPressed: () {

                        if (_formKey.currentState!.validate()) {
                          loginUser();
                        }

                      },

                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black87,

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),

                      child: const Text(
                        "Login",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // REGISTER OPTION

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,

                    children: [

                      const Text("Don't have an account? "),

                      GestureDetector(

                        onTap: () {

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>  RegisterScreen(),
                            ),
                          );

                        },

                        child: const Text(
                          "Register",
                          style: TextStyle(
                            color: Colors.pink,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}