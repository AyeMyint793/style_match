import 'package:flutter/material.dart';
import 'package:style_match/screen/wardrobe_screen.dart';
import 'login_screen.dart';
import 'package:style_match/screen/settings_screen.dart';
import 'package:style_match/screen/ai_outfit_screen.dart';
import 'package:style_match/screen/saved_screen.dart';
import 'package:style_match/screen/trip_packing_screen.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    AIOutfitScreen(),
    WardrobeScreen(),
    const SavedScreen(),
  ];

  void logout(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      ),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0F766E),
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Style Match",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
            },
            icon: Icon(Icons.person_outline, color: Colors.white),
          ),
        ],
      ),

      body: _screens[_currentIndex],

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: Color(0xFF0F766E),
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.auto_awesome),
            label: "AI Outfit",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.checkroom),
            label: "Wardrobe",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            label: "Saved",
          ),
        ],
      ),
    );
  }
}

//  Placeholder screens (we will build these properly later)
class AIScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "AI Outfit Suggestion",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "Coming soon 🔥",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class OutfitScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 60, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            "Saved Outfits",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8),
          Text(
            "No saved outfits yet",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}