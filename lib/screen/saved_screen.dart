import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<dynamic> savedOutfits = [];
  bool isLoading = true;
  String? userEmail;

  @override
  void initState() {
    super.initState();
    loadSavedOutfits();
  }

  Future<void> loadSavedOutfits() async {
    final prefs = await SharedPreferences.getInstance();
    userEmail = prefs.getString("email") ?? "";

    final outfits = await ApiService.getSavedOutfits(userEmail!);

    setState(() {
      savedOutfits = outfits;
      isLoading = false;
    });
  }

  Future<void> deleteOutfit(int id, int index) async {
    final success = await ApiService.deleteSavedOutfit(id);
    if (success) {
      setState(() => savedOutfits.removeAt(index));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Outfit removed")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)))
          : savedOutfits.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 12)],
              ),
              child: const Icon(Icons.favorite_border, size: 50, color: Color(0xFF0F766E)),
            ),
            const SizedBox(height: 20),
            const Text(
              "No saved outfits yet",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF171717),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Tap ❤️ on any outfit to save it here",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
      )
          : RefreshIndicator(
        color: const Color(0xFF0F766E),
        onRefresh: loadSavedOutfits,
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: savedOutfits.length,
          itemBuilder: (context, index) {
            final outfit = savedOutfits[index];
            final items = (outfit["items"] as List<dynamic>?) ?? [];
            final description = outfit["description"]?.toString() ?? "";
            final occasion = outfit["occasion"]?.toString() ?? "";
            final season = outfit["season"]?.toString() ?? "";

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEEEEEE)),
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
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "$occasion Look",
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF171717),
                                ),
                              ),
                              Text(
                                "$occasion · $season",
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => deleteOutfit(outfit["id"], index),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFF0F0),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      description,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 120,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      itemCount: items.length,
                      itemBuilder: (context, i) {
                        final item = items[i];
                        final imagePath = item["image_path"]?.toString() ?? "";
                        final itemLabel = item["subcategory"]?.toString() ??
                            item["category"]?.toString() ?? "Item";
                        return Container(
                          width: 100,
                          margin: const EdgeInsets.only(right: 10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: const Color(0xFFF5F5F5),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  imagePath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                  const Center(child: Icon(Icons.broken_image_outlined, color: Colors.grey)),
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.55),
                                      borderRadius: const BorderRadius.only(
                                        bottomLeft: Radius.circular(12),
                                        bottomRight: Radius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      itemLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
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
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}