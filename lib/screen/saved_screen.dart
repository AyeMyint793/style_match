import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/wardrobe_cache_service.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  List<dynamic> savedOutfits = [];
  bool isLoading = true;
  String? userEmail;

  String searchQuery = "";
  String selectedFilterTag = "All";
  final List<String> filterTags = ["All", "Casual", "Formal", "Work", "Party", "Weekend", "Sporty", "Vacation"];

  @override
  void initState() {
    super.initState();
    loadSavedOutfits();
  }

  Future<void> loadSavedOutfits() async {
    userEmail = await AuthService.getUserEmail() ?? "";
    if (userEmail!.isEmpty) {
      if (mounted) setState(() => isLoading = false);
      return;
    }

    // Load from cache first for instant UI response
    final cached = await WardrobeCacheService.getCachedSavedOutfits(userEmail!);
    if (cached != null && mounted) {
      setState(() {
        savedOutfits = cached;
        isLoading = false;
      });
    }

    final outfits = await ApiService.getSavedOutfits(userEmail!);
    if (mounted) {
      setState(() {
        savedOutfits = outfits;
        isLoading = false;
      });
      await WardrobeCacheService.saveCachedSavedOutfits(userEmail!, outfits);
    }
  }

  Future<void> deleteOutfit(int id, int index, int filteredIndex, List<dynamic> filteredList) async {
    final success = await ApiService.deleteSavedOutfit(id);
    if (success) {
      setState(() {
        final outfitToRemove = filteredList[filteredIndex];
        savedOutfits.removeWhere((element) => element["id"] == outfitToRemove["id"]);
      });
      if (userEmail != null && userEmail!.isNotEmpty) {
        await WardrobeCacheService.saveCachedSavedOutfits(userEmail!, savedOutfits);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Outfit removed")),
        );
      }
    }
  }

  void _showEditTagsSheet(Map<String, dynamic> outfit) {
    final outfitId = outfit["id"] as int;
    final List<dynamic> currentTags = outfit["tags"] as List<dynamic>? ?? [];
    List<String> selectedTags = List<String>.from(currentTags.map((t) => t.toString()));
    final List<String> availableTags = ["Casual", "Formal", "Work", "Party", "Weekend", "Sporty", "Vacation"];
    final TextEditingController customTagController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFAF7F2),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Edit Outfit Tags",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "Select style tags to categorize this outfit:",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableTags.map((tag) {
                      final isSelected = selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(tag),
                        selected: isSelected,
                        selectedColor: const Color(0xFF0F766E).withValues(alpha: 0.15),
                        checkmarkColor: const Color(0xFF0F766E),
                        labelStyle: TextStyle(
                          color: isSelected ? const Color(0xFF0F766E) : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        onSelected: (selected) {
                          setModalState(() {
                            if (selected) {
                              selectedTags.add(tag);
                            } else {
                              selectedTags.remove(tag);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    "Custom Tag:",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: customTagController,
                          decoration: InputDecoration(
                            hintText: "Add custom tag...",
                            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                            filled: true,
                            fillColor: const Color(0xFFF5F5F5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          final newTag = customTagController.text.trim();
                          if (newTag.isNotEmpty && !selectedTags.contains(newTag)) {
                            setModalState(() {
                              selectedTags.add(newTag);
                              customTagController.clear();
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                        child: const Text("Add", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                        final success = await ApiService.updateOutfitTags(outfitId, selectedTags);
                        if (success) {
                          navigator.pop();
                          loadSavedOutfits();
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text("Outfit tags successfully updated!"),
                              backgroundColor: Color(0xFF0F766E),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        "Update Tags",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredOutfits = savedOutfits.where((outfit) {
      final occasion = outfit["occasion"]?.toString().toLowerCase() ?? "";
      final season = outfit["season"]?.toString().toLowerCase() ?? "";
      final description = outfit["description"]?.toString().toLowerCase() ?? "";
      final List<dynamic> tags = outfit["tags"] as List<dynamic>? ?? [];
      final tagsLower = tags.map((t) => t.toString().toLowerCase()).toList();

      final matchesTag = selectedFilterTag == "All" ||
          tagsLower.contains(selectedFilterFilterTagLower());

      final matchesSearch = searchQuery.isEmpty ||
          occasion.contains(searchQuery.toLowerCase()) ||
          season.contains(searchQuery.toLowerCase()) ||
          description.contains(searchQuery.toLowerCase()) ||
          tagsLower.any((t) => t.contains(searchQuery.toLowerCase()));

      return matchesTag && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F766E)))
          : Column(
              children: [
                _buildSearchAndFilters(),
                Expanded(
                  child: savedOutfits.isEmpty
                      ? _buildEmptyState()
                      : filteredOutfits.isEmpty
                          ? _buildNoResultsState()
                          : RefreshIndicator(
                              color: const Color(0xFF0F766E),
                              onRefresh: loadSavedOutfits,
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                                itemCount: filteredOutfits.length,
                                itemBuilder: (context, index) {
                                  final outfit = filteredOutfits[index];
                                  final items = (outfit["items"] as List<dynamic>?) ?? [];
                                  final description = outfit["description"]?.toString() ?? "";
                                  final occasion = outfit["occasion"]?.toString() ?? "";
                                  final season = outfit["season"]?.toString() ?? "";
                                  final List<dynamic> tags = outfit["tags"] as List<dynamic>? ?? [];

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
                                              Row(
                                                children: [
                                                  GestureDetector(
                                                    onTap: () => _showEditTagsSheet(outfit),
                                                    child: Container(
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: const Icon(Icons.sell_outlined, color: Color(0xFF0F766E), size: 18),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  GestureDetector(
                                                    onTap: () => deleteOutfit(outfit["id"], index, index, filteredOutfits),
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
                                        if (tags.isNotEmpty) ...[
                                          const SizedBox(height: 10),
                                          Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            child: Wrap(
                                              spacing: 6,
                                              runSpacing: 6,
                                              children: tags.map<Widget>((tag) {
                                                return Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFE8F6F4),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    tag.toString(),
                                                    style: const TextStyle(
                                                      color: Color(0xFF0F766E),
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          ),
                                        ],
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
                                                            color: Colors.black.withValues(alpha: 0.55),
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
                ),
              ],
            ),
    );
  }

  String selectedFilterFilterTagLower() {
    return selectedFilterTag.toLowerCase();
  }

  Widget _buildSearchAndFilters() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              onChanged: (val) {
                setState(() {
                  searchQuery = val;
                });
              },
              decoration: InputDecoration(
                hintText: "Search outfits by style, tag, or season...",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF0F766E), size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 36,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: filterTags.length,
              itemBuilder: (context, index) {
                final tag = filterTags[index];
                final isSelected = selectedFilterTag == tag;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(tag),
                    selected: isSelected,
                    selectedColor: const Color(0xFF0F766E),
                    backgroundColor: const Color(0xFFF5F5F5),
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                    checkmarkColor: Colors.white,
                    showCheckmark: false,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF0F766E) : Colors.transparent,
                      ),
                    ),
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          selectedFilterTag = tag;
                        });
                      }
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
    );
  }

  Widget _buildNoResultsState() {
    return Center(
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
            child: const Icon(Icons.search_off_rounded, size: 50, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          const Text(
            "No matching outfits",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF171717),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Try adjusting your filters or search terms",
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}