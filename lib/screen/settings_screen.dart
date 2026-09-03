import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
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
  bool isUploadingAvatar = false;

  String email = "";
  String name = "";
  String height = "";
  String size = "";
  String fit = "";
  String style = "";
  String gender = "Female";
  String avatarUrl = "";

  final TextEditingController nameController = TextEditingController();
  final TextEditingController heightController = TextEditingController();
  String editSize = "";
  String editFit = "";
  String editStyle = "";
  String editGender = "Female";

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

  static const String maleDefaultAvatar =
      "https://res.cloudinary.com/dqmtehphz/image/upload/v1787707356/xuiqtjiuicbepz52yr5d.jpg";
  static const String femaleDefaultAvatar =
      "https://res.cloudinary.com/dqmtehphz/image/upload/v1787707360/bsdit0mtsqps6sby1nzv.jpg";

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
    email = await AuthService.getUserEmail() ?? "";

    final profile = await ApiService.getProfile(email);
    final preferences = await ApiService.getPreferences(email);

    setState(() {
      name = profile?["name"] ?? "";
      height = profile?["height"] ?? "";
      size = profile?["size"] ?? "";
      gender = profile?["gender"] ?? "Female";
      avatarUrl = profile?["avatar_url"] ?? "";
      fit = preferences?["fit"] ?? "";
      style = preferences?["style"] ?? "";
      isLoading = false;
    });
  }

  void startEditProfile() {
    nameController.text = name;
    heightController.text = height;
    editSize = size;
    editGender = gender;
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
        const SnackBar(content: Text("Please fill all fields")),
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
        gender: editGender,
        avatarUrl: avatarUrl,
      );

      if (response) {
        setState(() {
          name = nameController.text.trim();
          height = heightController.text.trim();
          size = editSize;
          gender = editGender;
          isEditingProfile = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile updated!")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update profile")),
        );
      }
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
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Preferences updated!")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to update preferences")),
        );
      }
    }

    setState(() => isSaving = false);
  }

  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    final picker = ImagePicker();
    try {
      final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
      if (pickedFile == null) return;

      setState(() => isUploadingAvatar = true);

      final uploadedUrl = await ApiService.uploadAvatar(pickedFile.path);
      if (uploadedUrl == null) {
        throw Exception("Server failed to process and store avatar");
      }

      final success = await ApiService.saveProfile(
        email,
        name,
        height,
        size,
        gender: gender,
        avatarUrl: uploadedUrl,
      );

      if (success) {
        setState(() {
          avatarUrl = uploadedUrl;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile picture updated!")),
          );
        }
      } else {
        throw Exception("Failed to save avatar URL to profile");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to upload image: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isUploadingAvatar = false);
      }
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => isUploadingAvatar = true);
    try {
      final success = await ApiService.saveProfile(
        email,
        name,
        height,
        size,
        gender: gender,
        avatarUrl: "",
      );
      if (success) {
        setState(() {
          avatarUrl = "";
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Profile picture removed")),
          );
        }
      } else {
        throw Exception("Failed to remove avatar from profile");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to remove image: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isUploadingAvatar = false);
      }
    }
  }

  void _showAvatarPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFAF7F2),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Profile Photo",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined, color: Color(0xFF0F766E)),
                title: const Text("Take Photo", style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadAvatar(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF0F766E)),
                title: const Text("Upload from Gallery", style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
              if (avatarUrl.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text("Remove Photo", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                  onTap: () {
                    Navigator.pop(context);
                    _removeAvatar();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  String _getDefaultAvatarUrl() {
    return gender.toLowerCase() == "male" ? maleDefaultAvatar : femaleDefaultAvatar;
  }

  void logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F2),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "My Profile",
          style: TextStyle(
            color: Color(0xFF171717),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF171717)),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Clickable Avatar
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: isUploadingAvatar ? null : _showAvatarPickerSheet,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 100,
                                height: 100,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0F766E),
                                  shape: BoxShape.circle,
                                ),
                                child: ClipOval(
                                  child: avatarUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: avatarUrl,
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => const Center(
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
                                            ),
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
                              if (isUploadingAvatar)
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 3,
                                    ),
                                  ),
                                ),
                              if (!isUploadingAvatar)
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF0F766E),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          name.isEmpty ? "No name set" : name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          email,
                          style: const TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Personal Info card
                  _buildCard(
                    title: "Personal Info",
                    isEditing: isEditingProfile,
                    onEdit: startEditProfile,
                    onCancel: () => setState(() => isEditingProfile = false),
                    child: isEditingProfile ? _editProfileContent() : _viewProfileContent(),
                  ),

                  const SizedBox(height: 16),

                  // Style Preferences card
                  _buildCard(
                    title: "Style Preferences",
                    isEditing: isEditingPreferences,
                    onEdit: startEditPreferences,
                    onCancel: () => setState(() => isEditingPreferences = false),
                    child: isEditingPreferences ? _editPreferencesContent() : _viewPreferencesContent(),
                  ),

                  const SizedBox(height: 32),

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
                      child: const Text(
                        "Logout",
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
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
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                isEditing
                    ? TextButton(
                        onPressed: onCancel,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 0),
                        ),
                        child: const Text(
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
                        icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
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
        _infoRow(Icons.male_outlined, "Gender", gender),
        _divider(),
        _infoRow(Icons.height, "Height", height.isEmpty ? "-" : "$height cm"),
        _divider(),
        _infoRow(Icons.straighten, "Size", size),
      ],
    );
  }

  Widget _editProfileContent() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _editLabel("Full Name"),
          const SizedBox(height: 6),
          _textField(
            controller: nameController,
            hint: "Enter your name",
            icon: Icons.person_outline,
          ),
          const SizedBox(height: 14),
          _editLabel("Height (cm)"),
          const SizedBox(height: 6),
          _textField(
            controller: heightController,
            hint: "e.g. 170",
            icon: Icons.height,
            isNumber: true,
          ),
          const SizedBox(height: 14),
          _editLabel("Gender"),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: ['Male', 'Female'].map((g) {
              final isSelected = editGender == g;
              return GestureDetector(
                onTap: () => setState(() => editGender = g),
                child: Container(
                  width: 145,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0F766E) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      g,
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
          const SizedBox(height: 14),
          _editLabel("Clothing Size"),
          const SizedBox(height: 10),
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
                    color: isSelected ? const Color(0xFF0F766E) : Colors.grey.shade100,
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
          const SizedBox(height: 20),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _editLabel("Fit Preference"),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: fitOptions.map((f) {
              final isSelected = editFit == f["label"];
              return GestureDetector(
                onTap: () => setState(() => editFit = f["label"]),
                child: Container(
                  width: 100,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF0F766E) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(f["icon"], color: isSelected ? Colors.white : Colors.grey, size: 22),
                      const SizedBox(height: 6),
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
          const SizedBox(height: 20),
          _editLabel("Style Preference"),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: styleOptions.map((s) {
              final isSelected = editStyle == s["label"];
              return GestureDetector(
                onTap: () => setState(() => editStyle = s["label"]),
                child: Container(
                  width: 100,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.black : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Icon(s["icon"], color: isSelected ? Colors.white : Colors.grey, size: 22),
                      const SizedBox(height: 6),
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
          const SizedBox(height: 20),
          _saveButton(savePreferences),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const Spacer(),
          Text(
            value.isEmpty ? "-" : value,
            style: const TextStyle(
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 6,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber ? [FilteringTextInputFormatter.digitsOnly] : [],
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.grey, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
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
          elevation: 0,
        ),
        child: isSaving
            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            : const Text(
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