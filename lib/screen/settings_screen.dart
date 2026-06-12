import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool isLoading = true;
  bool isEditingProfile = false;
  bool isEditingPreferences = false;
  bool isSaving = false;

  String email = "";
  String name = "";
  String height = "";
  String size = "";
  String fit = "";
  String style = "";

  final TextEditingController nameController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  String editSize = "";
  String editFit = "";
  String editStyle = "";

  final List<String> sizeOptions = ['S', 'M', 'L', 'XL'];
  final List<Map<String, dynamic>> fitOptions = [
    {"label": "Loose", "icon": Icons.air},
    {"label": "Regular", "icon": Icons.straighten},
    {"label": "Fitted", "icon": Icons.accessibility_new},
  ];
  final List<Map<String, dynamic>> styleOptions = [
    {"label": "Casual", "icon": Icons.weekend_outlined},
    {"label": "Trendy", "icon": Icons.trending_up},
    {"label": "Classy", "icon": Icons.star_outline},
  ];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  @override
  void dispose() {
    nameController.dispose();
    heightController.dispose();
    super.dispose();
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    email = prefs.getString("email") ?? "";

    final profile = await ApiService.getProfile(email);
    final preferences = await ApiService.getPreferences(email);

    setState(() {
      name = profile?["name"] ?? "";
      height = profile?["height"] ?? "";
      size = profile?["size"] ?? "";
      fit = preferences?["fit"] ?? "";
      style = preferences?["style"] ?? "";
      isLoading = false;
    });
  }

  void startEditProfile() {
    nameController.text = name;
    heightController.text = height;
    editSize = size;
    setState(() => isEditingProfile = true);
  }

  void startEditPreferences() {
    editFit = fit;
    editStyle = style;
    setState(() => isEditingPreferences = true);
  }

  Future<void> saveProfile() async {
    if (nameController.text.trim().isEmpty || heightController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final response = await ApiService.saveProfile(
        email,
        nameController.text.trim(),
        heightController.text.trim(),
        editSize,
      );

      if (response) {
        setState(() {
          name = nameController.text.trim();
          height = heightController.text.trim();
          size = editSize;
          isEditingProfile = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Profile updated!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update profile")),
      );
    }

    setState(() => isSaving = false);
  }

  Future<void> savePreferences() async {
    setState(() => isSaving = true);

    try {
      final response = await ApiService.savePreferences(
        email,
        editFit,
        editStyle,
      );

      if (response) {
        setState(() {
          fit = editFit;
          style = editStyle;
          isEditingPreferences = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Preferences updated!")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update preferences")),
      );
    }

    setState(() => isSaving = false);
  }

  void logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: Color(0xFFFAF7F2),
        elevation: 0,
        centerTitle: true,
        title: Text(
          "My Profile",
          style: TextStyle(
            color: Color(0xFF0F766E),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Avatar + name + email
            Center(
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      color: Color(0xFF0F766E),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.person, size: 44, color: Colors.white),
                  ),
                  SizedBox(height: 14),
                  Text(
                    name.isEmpty ? "No name set" : name,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    email,
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),

            SizedBox(height: 32),

            // Personal Info card
            _buildCard(
              title: "Personal Info",
              isEditing: isEditingProfile,
              onEdit: startEditProfile,
              onCancel: () => setState(() => isEditingProfile = false),
              child: isEditingProfile
                  ? _editProfileContent()
                  : _viewProfileContent(),
            ),

            SizedBox(height: 16),

            // Style Preferences card
            _buildCard(
              title: "Style Preferences",
              isEditing: isEditingPreferences,
              onEdit: startEditPreferences,
              onCancel: () => setState(() => isEditingPreferences = false),
              child: isEditingPreferences
                  ? _editPreferencesContent()
                  : _viewPreferencesContent(),
            ),

            SizedBox(height: 32),

            // Logout button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                onPressed: logout,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.red.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  "Logout",
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required bool isEditing,
    required VoidCallback onEdit,
    required VoidCallback onCancel,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 10,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                isEditing
                    ? TextButton(
                  onPressed: onCancel,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size(0, 0),
                  ),
                  child: Text(
                    "Cancel",
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
                    : IconButton(
                  onPressed: onEdit,
                  icon: Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
              ],
            ),
          ),
          Divider(color: Colors.grey.shade100, height: 16),
          child,
        ],
      ),
    );
  }

  Widget _viewProfileContent() {
    return Column(
      children: [
        _infoRow(Icons.person_outline, "Name", name),
        _divider(),
        _infoRow(Icons.height, "Height", height.isEmpty ? "-" : "$height cm"),
        _divider(),
        _infoRow(Icons.straighten, "Size", size),
      ],
    );
  }

  Widget _editProfileContent() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _editLabel("Full Name"),
          SizedBox(height: 6),
          _textField(
            controller: nameController,
            hint: "Enter your name",
            icon: Icons.person_outline,
          ),
          SizedBox(height: 14),
          _editLabel("Height (cm)"),
          SizedBox(height: 6),
          _textField(
            controller: heightController,
            hint: "e.g. 170",
            icon: Icons.height,
            isNumber: true,
          ),
          SizedBox(height: 14),
          _editLabel("Clothing Size"),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: sizeOptions.map((s) {
              final isSelected = editSize == s;
              return GestureDetector(
                onTap: () => setState(() => editSize = s),
                child: Container(
                  width: 68,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected ? Color(0xFF0F766E) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      s,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 20),
          _saveButton(saveProfile),
        ],
      ),
    );
  }

  Widget _viewPreferencesContent() {
    return Column(
      children: [
        _infoRow(Icons.air, "Fit", fit),
        _divider(),
        _infoRow(Icons.style_outlined, "Style", style),
      ],
    );
  }

  Widget _editPreferencesContent() {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _editLabel("Fit Preference"),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: fitOptions.map((f) {
              final isSelected = editFit == f["label"];
              return GestureDetector(
                onTap: () => setState(() => editFit = f["label"]),
                child: Container(
                  width: 100,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Color(0xFF0F766E) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(f["icon"],
                          color: isSelected ? Colors.white : Colors.grey,
                          size: 22),
                      SizedBox(height: 6),
                      Text(
                        f["label"],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 20),
          _editLabel("Style Preference"),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: styleOptions.map((s) {
              final isSelected = editStyle == s["label"];
              return GestureDetector(
                onTap: () => setState(() => editStyle = s["label"]),
                child: Container(
                  width: 100,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Color(0xFF0F766E) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(s["icon"],
                          color: isSelected ? Colors.white : Colors.grey,
                          size: 22),
                      SizedBox(height: 6),
                      Text(
                        s["label"],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 20),
          _saveButton(savePreferences),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          Spacer(),
          Text(
            value.isEmpty ? "-" : value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _editLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Colors.grey.shade600,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isNumber = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : [],
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey, size: 20),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Color(0xFF0F766E), width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  Widget _saveButton(VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: isSaving ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF0F766E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isSaving
            ? CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            : Text(
          "Save Changes",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _divider() {
    return Divider(height: 1, color: Colors.grey.shade100, indent: 16, endIndent: 16);
  }
}