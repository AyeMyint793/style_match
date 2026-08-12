import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:style_match/app_theme.dart';
import 'package:style_match/widgets/auth_wrapper.dart';

void main() async {
  // Ensure Flutter is initialized before any async setup
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables (API keys, etc.)
  await dotenv.load(fileName: ".env");
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Style Match',
      
      // Centralized premium theme
      theme: AppTheme.theme,
      
      // AuthWrapper handles the silent login / session check
      home: const AuthWrapper(),
    );
  }
}
