import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/ai_service.dart';
import '../services/api_service.dart';

class WardrobeScreen extends StatefulWidget {
  @override
  _WardrobeScreenState createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  List<Map<String, String>> clothes = [];
  final ImagePicker picker = ImagePicker();
  String? userEmail;
  bool isLoadingClothes = false;
  List<dynamic> wardrobeGaps = [];

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
    loadClothesFromBackend();
  }

  Future<void> loadClothesFromBackend() async {
    if (userEmail == null) return;
    setState(() => isLoadingClothes = true);
    try {
      final response = await http.get(
        Uri.parse("http://10.0.2.2:8000/get-clothes?email=$userEmail"),
        headers: {"Content-Type": "application/json"},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          setState(() {
            clothes = List<Map<String, String>>.from(
              data["clothes"].map((item) => {
                "id": item["id"].toString(),
                "path": item["image_path"].toString(),
                "category": item["category"].toString(),
                "subcategory": item["subcategory"]?.toString() ?? "",
                "occasion": item["occasion"].toString(),
                "season": item["season"].toString(),
                "color": item["color"]?.toString() ?? "",
              }),
            );
          });
        }
      }
    } catch (e) {
      print("Load error: $e");
    }

    final analysis = await ApiService.analyzeWardrobe(userEmail!);
    if (analysis != null && mounted) {
      setState(() {
        wardrobeGaps = analysis["gaps"] ?? [];
      });
    }

    setState(() => isLoadingClothes = false);
  }

  Future<String?> uploadToCloudinary(String imagePath) async {
    try {
      final cloudinary = CloudinaryPublic(
        dotenv.env['CLOUDINARY_CLOUD_NAME']!,
        'style_match',
        cache: false,
      );
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imagePath,
          folder: 'style_match_clothes',
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      return response.secureUrl;
    } catch (e) {
      print("Cloudinary upload error: $e");
      return null;
    }
  }

  Future<void> saveClothesToBackend(Map<String, String> item) async {
    try {
      final url = Uri.parse("http://10.0.2.2:8000/save-clothes");
      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": userEmail,
          "image_path": item["path"],
          "category": item["category"],
          "subcategory": item["subcategory"],
          "occasion": item["occasion"],
          "season": item["season"],
          "color": item["color"],
        }),
      );
    } catch (e) {
      print("Backend save error: $e");
    }
  }

  Future<void> deleteClothes(String id, int index) async {
    try {
      await http.delete(Uri.parse("http://10.0.2.2:8000/delete-clothes/$id"));
      setState(() => clothes.removeAt(index));
    } catch (e) {
      print("Delete error: $e");
    }
  }

  Future<void> pickFromSource(ImageSource source) async {
    final XFile? image = await picker.pickImage(source: source);
    if (image != null) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: Row(
            children: [
              CircularProgressIndicator(color: Color(0xFF0F766E)),
              SizedBox(width: 16),
              Text("AI detecting clothing..."),
            ],
          ),
        ),
      );

      Map<String, String> detected = await AIService.detectClothing(image.path);
      String? cloudinaryUrl = await uploadToCloudinary(image.path);

      Navigator.pop(context);

      if (cloudinaryUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to upload image. Try again.")),
        );
        return;
      }

      await showConfirmDialog(cloudinaryUrl, detected);
    }
  }

  Future<void> showConfirmDialog(String imageUrl, Map<String, String> detected) async {
    String category = detected["category"]!;
    String subcategory = detected["subcategory"]!;
    String occasion = detected["occasion"]!;
    String season = detected["season"]!;
    String color = detected["color"]!;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF0F766E), size: 20),
              SizedBox(width: 8),
              Text("AI Detected", style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFFAF7F2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _detailRow("Category", category),
                        _detailRow("Item", subcategory),
                        _detailRow("Color", color),
                        _detailRow("Occasion", occasion),
                        _detailRow("Season", season),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    "Need to change something?",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  SizedBox(height: 10),
                  _dropdownField(
                    "Category",
                    category,
                    ["Tops", "Bottoms", "Dress", "Shoes", "Outerwear", "Accessories"],
                        (val) => setDialogState(() => category = val!),
                  ),
                  SizedBox(height: 8),
                  _dropdownField(
                    "Occasion",
                    occasion,
                    ["Casual", "Work", "Formal", "Date Night", "Party", "Brunch", "Gym", "Outdoor", "Wedding", "Travel"],
                        (val) => setDialogState(() => occasion = val!),
                  ),
                  SizedBox(height: 8),
                  _dropdownField(
                    "Season",
                    season,
                    ["All Season", "Summer", "Winter"],
                        (val) => setDialogState(() => season = val!),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final newItem = {
                  "path": imageUrl,
                  "category": category,
                  "subcategory": subcategory,
                  "occasion": occasion,
                  "season": season,
                  "color": color,
                };
                await saveClothesToBackend(newItem);
                await loadClothesFromBackend();
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0F766E),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text("Looks Good ✓", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF171717))),
        ],
      ),
    );
  }

  Widget _dropdownField(String label, String value, List<String> items, Function(String?) onChanged) {
    final safeValue = items.contains(value) ? value : items.first;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Color(0xFFFAF7F2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButton<String>(
        value: safeValue,
        isExpanded: true,
        underline: SizedBox(),
        hint: Text(label),
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  void showAddOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library_outlined, color: Color(0xFF0F766E)),
                title: Text("Choose from Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  pickFromSource(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt_outlined, color: Color(0xFF0F766E)),
                title: Text("Take a Photo"),
                onTap: () {
                  Navigator.pop(context);
                  pickFromSource(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _completeOutfit(Map<String, String> selectedItem) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Row(
          children: [
            CircularProgressIndicator(color: Color(0xFF0F766E)),
            SizedBox(width: 16),
            Text("AI completing your outfit..."),
          ],
        ),
      ),
    );

    final outfit = await ApiService.completeOutfit(
      userEmail!,
      {
        "id": int.parse(selectedItem["id"]!),
        "category": selectedItem["category"]!,
        "subcategory": selectedItem["subcategory"]!,
        "color": selectedItem["color"]!,
        "image_path": selectedItem["path"]!,
      },
      "",
    );

    Navigator.pop(context);

    if (outfit == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not complete outfit. Try again.")),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Complete Outfit",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF171717),
              ),
            ),
            SizedBox(height: 4),
            Text(
              outfit["description"] ?? "",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            SizedBox(height: 16),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: (outfit["items"] as List).length,
                itemBuilder: (context, index) {
                  final item = outfit["items"][index];
                  final imagePath = item["image_path"]?.toString() ?? "";
                  final itemLabel = item["subcategory"]?.toString() ??
                      item["category"]?.toString() ?? "Item";
                  return Container(
                    width: 110,
                    margin: EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Color(0xFFF5F5F5),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(14),
                                  bottomRight: Radius.circular(14),
                                ),
                              ),
                              child: Text(
                                itemLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0F766E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  "Done",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
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
          "My Wardrobe",
          style: TextStyle(color: Color(0xFF171717), fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            onPressed: loadClothesFromBackend,
            icon: Icon(Icons.refresh, color: Color(0xFF0F766E)),
          ),
        ],
      ),
      body: isLoadingClothes
          ? Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)))
          : clothes.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 12)],
              ),
              child: Icon(Icons.checkroom, size: 50, color: Color(0xFF0F766E)),
            ),
            SizedBox(height: 20),
            Text("Your wardrobe is empty",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF171717))),
            SizedBox(height: 8),
            Text("Add your clothes to build your style 👕",
                style: TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
      )
          : Column(
        children: [
          if (wardrobeGaps.isNotEmpty)
            Container(
              margin: EdgeInsets.fromLTRB(14, 14, 14, 0),
              padding: EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Color(0xFFFFCC02)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tips_and_updates_outlined, color: Color(0xFF8B6914), size: 18),
                      SizedBox(width: 8),
                      Text(
                        "Wardrobe Suggestions",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B6914),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  ...wardrobeGaps.map((gap) => Padding(
                    padding: EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("• ", style: TextStyle(color: Color(0xFF8B6914), fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            gap["suggestion"],
                            style: TextStyle(fontSize: 12, color: Color(0xFF8B6914)),
                          ),
                        ),
                      ],
                    ),
                  )).toList(),
                ],
              ),
            ),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.fromLTRB(14, 14, 14, 120),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: clothes.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onLongPress: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text("Options"),
                        content: Text("What would you like to do?"),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text("Cancel", style: TextStyle(color: Colors.grey)),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              deleteClothes(clothes[index]["id"]!, index);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                            child: Text("Delete", style: TextStyle(color: Colors.white)),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _completeOutfit(clothes[index]);
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF0F766E)),
                            child: Text("Complete Outfit", style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: Offset(2, 4))],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            clothes[index]["path"]!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(child: CircularProgressIndicator(color: Color(0xFF0F766E), strokeWidth: 2));
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Center(child: Icon(Icons.broken_image, color: Colors.grey)),
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.55),
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(18),
                                  bottomRight: Radius.circular(18),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    clothes[index]["subcategory"]!.isEmpty
                                        ? clothes[index]["category"]!
                                        : clothes[index]["subcategory"]!,
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                  ),
                                  Text(
                                    "${clothes[index]["occasion"]} · ${clothes[index]["season"]}",
                                    style: TextStyle(color: Colors.white70, fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Color(0xFF0F766E),
        onPressed: showAddOptions,
        child: Icon(Icons.add, size: 28, color: Colors.white),
      ),
    );
  }
}