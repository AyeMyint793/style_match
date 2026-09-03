import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:style_match/screen/wardrobe_screen.dart';
import 'package:style_match/screen/settings_screen.dart';
import 'package:style_match/screen/ai_outfit_screen.dart';
import 'package:style_match/screen/saved_screen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String? avatarUrl;
  String? gender;
  String? email;
  bool isProfileLoading = true;

  final List<Widget> _screens = [
    const AIOutfitScreen(),
    WardrobeScreen(),
    const SavedScreen(),
  ];

  @override
  void initState() {
    super.initState();
    loadProfileData();
  }

  Future<void> loadProfileData() async {
    final userEmail = await AuthService.getUserEmail() ?? "";
    if (userEmail.isNotEmpty) {
      final profile = await ApiService.getProfile(userEmail);
      if (mounted) {
        setState(() {
          email = userEmail;
          avatarUrl = profile?["avatar_url"] ?? "";
          gender = profile?["gender"] ?? "Female";
          isProfileLoading = false;
        });
      }
    }
  }

  String _getDefaultAvatarUrl() {
    const String maleDefaultAvatar =
        "https://res.cloudinary.com/dqmtehphz/image/upload/v1787707356/xuiqtjiuicbepz52yr5d.jpg";
    const String femaleDefaultAvatar =
        "https://res.cloudinary.com/dqmtehphz/image/upload/v1787707360/bsdit0mtsqps6sby1nzv.jpg";
    return (gender?.toLowerCase() == "male") ? maleDefaultAvatar : femaleDefaultAvatar;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F2),
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Style Match",
          style: TextStyle(
            color: Color(0xFF171717),
            fontWeight: FontWeight.bold,
            fontSize: 22,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              ).then((_) => loadProfileData());
            },
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                margin: const EdgeInsets.only(right: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFF0F766E),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: isProfileLoading
                      ? const Icon(Icons.person_outline, color: Colors.white, size: 18)
                      : (avatarUrl != null && avatarUrl!.isNotEmpty)
                          ? CachedNetworkImage(
                              imageUrl: avatarUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5),
                              ),
                              errorWidget: (context, url, error) => Image.network(
                                _getDefaultAvatarUrl(),
                                fit: BoxFit.cover,
                              ),
                            )
                          : Image.network(
                              _getDefaultAvatarUrl(),
                              fit: BoxFit.cover,
                            ),
                ),
              ),
            ),
          ),
        ],
      ),

      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
            )
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          selectedItemColor: const Color(0xFF0F766E),
          unselectedItemColor: Colors.grey.shade400,
          backgroundColor: Colors.white,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.auto_awesome_outlined),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.auto_awesome),
              ),
              label: "Stylist",
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.checkroom_outlined),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.checkroom),
              ),
              label: "Wardrobe",
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.favorite_outline),
              ),
              activeIcon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.favorite),
              ),
              label: "Lookbook",
            ),
          ],
        ),
      ),
    );
  }
}
