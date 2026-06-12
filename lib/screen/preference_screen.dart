import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'home_screen.dart';

class PreferenceScreen extends StatefulWidget {
  const PreferenceScreen({Key? key}) : super(key: key);

  @override
  State<PreferenceScreen> createState() => _PreferenceScreenState();
}

class _PreferenceScreenState extends State<PreferenceScreen> {

  String? selectedFit;
  final List<Map<String, dynamic>> fitOptions = [
    {"label": "Loose", "icon": Icons.air},
    {"label": "Regular", "icon": Icons.straighten},
    {"label": "Fitted", "icon": Icons.accessibility_new},
  ];

  String? selectedStyle;
  final List<Map<String, dynamic>> styleOptions = [
    {"label": "Casual", "icon": Icons.weekend_outlined},
    {"label": "Trendy", "icon": Icons.trending_up},
    {"label": "Classy", "icon": Icons.star_outline},
  ];

  bool isLoading = false;
  String? userEmail;

  @override
  void initState() {
    super.initState();
    loadEmail();
  }

  void loadEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userEmail = prefs.getString("email");
    });
  }

  Future<void> savePreferences() async {
    setState(() => isLoading = true);

    try {
      // Save to database
      final url = Uri.parse("http://10.0.2.2:8000/save-preferences");
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": userEmail,
          "fit": selectedFit ?? "Regular",
          "style": selectedStyle ?? "Casual",
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["success"] == true) {
        //  Also save locally
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("fit_preference", selectedFit ?? "Regular");
        await prefs.setString("style_preference", selectedStyle ?? "Casual");
        await prefs.setBool("preferences_done", true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Preferences saved! ")),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save preferences")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection error. Is backend running?")),
      );
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAF7F2),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              SizedBox(height: 20),

              Center(
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 15,
                      )
                    ],
                  ),
                  child: Icon(Icons.style_outlined,
                      size: 50, color: Colors.black),
                ),
              ),

              SizedBox(height: 24),

              Center(
                child: Text(
                  "Your Style Preferences",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),

              SizedBox(height: 8),

              Center(
                child: Text(
                  "This helps us suggest better outfits for you",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),

              SizedBox(height: 36),

              //  Fit Preference
              Text(
                "Fit Preference",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 6),
              Text(
                "How do you like your clothes to fit?",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: fitOptions.map((fit) {
                  final isSelected = selectedFit == fit["label"];
                  return GestureDetector(
                    onTap: () => setState(() => selectedFit = fit["label"]),
                    child: Container(
                      width: 100,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? Color(0xFF0F766E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 8,
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            fit["icon"],
                            color: isSelected ? Colors.white : Colors.grey,
                            size: 28,
                          ),
                          SizedBox(height: 8),
                          Text(
                            fit["label"],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              SizedBox(height: 32),

              //  Style Preference
              Text(
                "Style Preference",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 6),
              Text(
                "What's your personal style?",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: styleOptions.map((style) {
                  final isSelected = selectedStyle == style["label"];
                  return GestureDetector(
                    onTap: () =>
                        setState(() => selectedStyle = style["label"]),
                    child: Container(
                      width: 100,
                      padding: EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.black : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.shade200,
                            blurRadius: 8,
                          )
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            style["icon"],
                            color: isSelected ? Colors.white : Colors.grey,
                            size: 28,
                          ),
                          SizedBox(height: 8),
                          Text(
                            style["label"],
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.black87,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              SizedBox(height: 48),

              //  Save button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isLoading ? null : savePreferences,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0F766E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                    "Save & Continue",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}