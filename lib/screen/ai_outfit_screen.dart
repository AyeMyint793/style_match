import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:style_match/services/weather_service.dart';
import '../services/auth_service.dart';
import '../services/wardrobe_cache_service.dart';
import '../widgets/outfit_avatar.dart';


class _Item {
  final String label;
  final IconData icon;
  const _Item(this.label, this.icon);
}

class AIOutfitScreen extends StatefulWidget {
  final List<int>? preselectedItemIds;
  const AIOutfitScreen({super.key, this.preselectedItemIds});

  @override
  State<AIOutfitScreen> createState() => _AIOutfitScreenState();
}

class _AIOutfitScreenState extends State<AIOutfitScreen> {
  String selectedOccasion = "Casual";
  String selectedSeason = "All Season";
  bool isLoading = false;
  List<dynamic> outfits = [];
  List<List<int>> previousOutfits = [];
  String? userEmail;
  Map<String, dynamic>? weatherData;
  String weatherText = "";
  List<dynamic> wardrobeItems = [];
  List<int> selectedItemIds = [];

  // Tracks indices of outfits currently undergoing in-place regeneration
  final Set<int> _regeneratingOutfitIndices = {};
  String userGender = "Female";

  final List<_Item> occasions = const [
    _Item("Casual", Icons.local_cafe_outlined),
    _Item("Work", Icons.work_outline),
    _Item("Date Night", Icons.favorite_border),
    _Item("Party", Icons.celebration_outlined),
    _Item("Wedding", Icons.diamond_outlined),
    _Item("Travel", Icons.flight_outlined),
  ];

  final List<_Item> seasons = const [
    _Item("All Season", Icons.auto_awesome),
    _Item("Summer", Icons.beach_access_outlined),
    _Item("Winter", Icons.ac_unit),
  ];

  @override
  void initState() {
    super.initState();
    loadEmail();
    if (widget.preselectedItemIds != null) {
      selectedItemIds = List<int>.from(widget.preselectedItemIds!);
    }
  }

  Future<void> loadEmail() async {
    final email = await AuthService.getUserEmail();
    if (!mounted) return;
    setState(() => userEmail = email);

    // Try to get current position/weather via GPS
    Map<String, dynamic>? weather = await WeatherService.getCurrentWeather();

    // Fall back to last saved city if GPS fails/times out
    if (weather == null) {
      final lastCity = await WeatherService.getLastCity();
      if (lastCity != null && lastCity.isNotEmpty) {
        weather = await WeatherService.getWeatherByCity(lastCity);
      }
    }

    if (weather != null && mounted) {
      setState(() {
        weatherData = weather;
        weatherText = WeatherService.getWeatherContext(weather!);
      });
    }

    if (userEmail != null) {
      _fetchUserGender(userEmail!);
      final items = await ApiService.getClothes(userEmail!);
      if (items != null) {
        if (mounted) {
          setState(() => wardrobeItems = items);
        }
      } else {
        final cached = await WardrobeCacheService.getCachedClothes(userEmail!);
        if (cached != null && mounted) {
          setState(() => wardrobeItems = cached);
        }
      }
    }
  }

  Future<void> _fetchUserGender(String email) async {
    try {
      final profile = await ApiService.getProfile(email);
      if (profile != null && profile["success"] == true) {
        if (mounted) {
          setState(() {
            userGender = profile["gender"]?.toString() ?? "Female";
          });
        }
      }
    } catch (e) {
      print("Error fetching user gender: $e");
    }
  }


  Future<void> generateOutfit() async {
    if (userEmail == null) return;
    setState(() {
      isLoading = true;
      outfits = [];
    });
    try {
      final data = await ApiService.generateOutfit(
        userEmail!,
        selectedOccasion,
        selectedSeason,
        weatherText,
        previousOutfits,
        selectedItemIds,
      );
      if (!mounted) return;
      if (data != null && data["success"] == true) {
        setState(() => outfits = data["outfits"]);
        for (var outfit in outfits) {
          final items = outfit["items"] as List<dynamic>? ?? [];
          final itemIds = items.map((i) => int.tryParse(i["id"]?.toString() ?? "") ?? 0).where((id) => id != 0).toList();
          if (itemIds.isNotEmpty) {
            previousOutfits.add(itemIds);
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data?["message"] ?? "Could not generate outfit")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection error. Is backend running?")),
      );
    }
    if (!mounted) return;
    setState(() => isLoading = false);
  }

  Future<void> regenerateOutfitOption(int index, List<int> currentOutfitItemIds) async {
    if (userEmail == null) return;
    
    if (currentOutfitItemIds.isNotEmpty) {
      previousOutfits.add(currentOutfitItemIds);
    }
    
    setState(() {
      _regeneratingOutfitIndices.add(index);
    });

    try {
      final data = await ApiService.generateOutfit(
        userEmail!,
        selectedOccasion,
        selectedSeason,
        weatherText,
        previousOutfits,
        selectedItemIds,
      );

      if (data != null && data["success"] == true && mounted) {
        final List<dynamic> newOutfits = data["outfits"];
        if (newOutfits.isNotEmpty) {
          setState(() {
            outfits[index] = newOutfits[0];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Outfit option refreshed!"),
              backgroundColor: Color(0xFF0F766E),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No alternate combinations found in closet.")),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to refresh outfit combination.")),
      );
    }

    if (mounted) {
      setState(() {
        _regeneratingOutfitIndices.remove(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: canPop
          ? AppBar(
              backgroundColor: const Color(0xFFFAF7F2),
              elevation: 0,
              centerTitle: true,
              title: const Text(
                "Daily Stylist",
                style: TextStyle(color: Color(0xFF171717), fontWeight: FontWeight.bold, fontSize: 18),
              ),
              iconTheme: const IconThemeData(color: Color(0xFF171717)),
            )
          : null,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!canPop) ...[
              const Text(
                "Daily Stylist",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF171717),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "AI-curated looks from your wardrobe.",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
            ],
            
            // Setup card container (like Trip Planner)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWeatherBar(),
                  const SizedBox(height: 20),
                  
                  _sectionHeader("Occasion"),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: occasions.map((occ) => _chip(occ.label, occ.icon, isOccasion: true)).toList(),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  _sectionHeader("Season"),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: seasons.map((sea) => _chip(sea.label, sea.icon, isOccasion: false)).toList(),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _sectionHeader("Style Specific Items (Optional)"),
                      if (selectedItemIds.isNotEmpty)
                        GestureDetector(
                          onTap: () => setState(() => selectedItemIds.clear()),
                          child: const Text(
                            "Clear",
                            style: TextStyle(fontSize: 12, color: Color(0xFFE11D48), fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStylingItemSelector(),
                  
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : generateOutfit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: isLoading
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  "Styling Your Looks...",
                                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                ),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  "Style My Look",
                                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            if (outfits.isEmpty && !isLoading) _emptyState(),
            if (outfits.isNotEmpty) ...[
              Row(
                children: [
                  _sectionHeader("Your Recommendations"),
                  const Spacer(),
                  Text(
                    "${outfits.length} Looks",
                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              for (int i = 0; i < outfits.length; i++)
                _outfitCard(outfits[i], i),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.bold,
        color: Color(0xFF171717),
      ),
    );
  }

  Widget _chip(String label, IconData icon, {required bool isOccasion}) {
    final bool isSelected = isOccasion ? selectedOccasion == label : selectedSeason == label;
    return GestureDetector(
      onTap: () => setState(() {
        if (isOccasion) {
          selectedOccasion = label;
        } else {
          selectedSeason = label;
        }
        previousOutfits.clear();
        outfits.clear();
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F766E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: const Color(0xFF0F766E).withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 3),
              )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF0F766E),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF171717),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 40,
                color: Color(0xFF0F766E),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "Start Curation",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF171717),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Select an occasion and style choice, then hit Style My Look to trigger AI outfit ideas.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _outfitCard(dynamic outfit, int index) {
    final items = (outfit["items"] as List<dynamic>?) ?? [];
    final description = outfit["description"]?.toString() ?? "A curated look for you.";
    final isFallback = outfit["is_fallback"] == true;
    final fallbackExplanation = outfit["missing_pieces_explanation"]?.toString();
    final styleConcept = outfit["style_concept"]?.toString() ?? "Stylist Concept";
    final stylingTip = outfit["styling_tip"]?.toString() ?? "";

    final List<int> itemIds = items.map((i) => int.tryParse(i["id"]?.toString() ?? "") ?? 0).where((id) => id != 0).toList();
    final isRegenerating = _regeneratingOutfitIndices.contains(index);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isFallback && fallbackExplanation != null && fallbackExplanation.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF3E0),
                      border: Border(bottom: BorderSide(color: Color(0xFFFFCC02), width: 0.5)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Color(0xFFE65100), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Capsule Suggestion",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE65100),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                fallbackExplanation,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFE65100),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  styleConcept,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF171717),
                                  ),
                                ),
                                if (items.any((it) => (it["color"]?.toString() ?? "").isNotEmpty)) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    items
                                        .map((it) => it["color"]?.toString() ?? "")
                                        .where((c) => c.isNotEmpty)
                                        .toSet()
                                        .take(3)
                                        .join(" · "),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF737373),
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          _saveButton(items, description),
                        ],
                      ),
                      const SizedBox(height: 14),
                      OutfitAvatar(items: items),
                      if (stylingTip.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF9F6),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFEBEAE5)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Stylist Tip",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F766E),
                                  letterSpacing: 0.2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                stylingTip,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF4B5563),
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton(
                          onPressed: isRegenerating
                              ? null
                              : () => regenerateOutfitOption(index, itemIds),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F766E),
                            side: const BorderSide(color: Color(0xFF0F766E), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: const Color(0xFF0F766E).withOpacity(0.04),
                          ),
                          child: const Text(
                            "Change This Look",
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                      ),

                    ],
                  ),
                ),
              ],
            ),
            if (isRegenerating)
              Positioned(
                top: 0,
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  color: Colors.white.withOpacity(0.85),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Color(0xFF0F766E)),
                        SizedBox(height: 12),
                        Text(
                          "Styling a new look...",
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }



  Widget _saveButton(List<dynamic> items, String desc) {
    return GestureDetector(
      onTap: () => _showSaveOutfitSheet(items, desc),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(color: Color(0xFFFDE8E8), shape: BoxShape.circle),
        child: const Icon(Icons.favorite, color: Color(0xFFE11D48), size: 18),
      ),
    );
  }

  void _showSaveOutfitSheet(List<dynamic> items, String desc) {
    final ids = items.map((i) => int.tryParse(i["id"]?.toString() ?? "") ?? 0).where((id) => id != 0).toList();
    List<String> selectedTags = [];
    final List<String> availableTags = ["Casual", "Formal", "Work", "Party", "Weekend", "Sporty", "Vacation"];

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
                    "Save Outfit",
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
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        final success = await ApiService.saveOutfit(
                          userEmail!,
                          selectedOccasion,
                          selectedSeason,
                          ids,
                          desc,
                          tags: selectedTags,
                        );
                        if (success && mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Outfit successfully saved to Lookbook!"),
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
                        "Save to Lookbook",
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

  Widget _buildWeatherBar() {
    final hasWeather = weatherData != null;
    final city = hasWeather ? (weatherData!["city"] ?? "Unknown") : "";
    final temp = hasWeather ? (weatherData!["temp"]?.toStringAsFixed(0) ?? "0") : "";
    final desc = hasWeather ? (weatherData!["description"] ?? "") : "";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: hasWeather ? const Color(0xFFF0FAF9) : const Color(0xFFFFF9F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasWeather ? const Color(0xFFD2EBE7) : const Color(0xFFFFE9D2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "TODAY'S WEATHER & LOCATION",
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: hasWeather ? const Color(0xFF0F766E) : const Color(0xFFF9735B),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                hasWeather ? Icons.wb_sunny_outlined : Icons.location_off_outlined,
                color: hasWeather ? const Color(0xFF0F766E) : const Color(0xFFF9735B),
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasWeather ? "$city, $temp°C" : "Location Unavailable",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: hasWeather ? const Color(0xFF171717) : const Color(0xFFF9735B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hasWeather ? desc : "Search city for weather styling context",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: _showCityInputDialog,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: hasWeather ? const Color(0xFF0F766E).withOpacity(0.08) : const Color(0xFFF9735B).withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasWeather ? Icons.edit_location_alt_outlined : Icons.search_outlined,
                    color: hasWeather ? const Color(0xFF0F766E) : const Color(0xFFF9735B),
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCityInputDialog() {
    final controller = TextEditingController(text: weatherData?["city"] ?? "");
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter City Name"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "e.g. New York, London"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final city = controller.text.trim();
              if (city.isNotEmpty) {
                Navigator.pop(context);
                setState(() => isLoading = true);
                final weather = await WeatherService.getWeatherByCity(city);
                if (weather != null) {
                  await WeatherService.saveLastCity(city);
                  if (mounted) {
                    setState(() {
                      weatherData = weather;
                      weatherText = WeatherService.getWeatherContext(weather);
                    });
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("City not found")),
                    );
                  }
                }
                if (mounted) setState(() => isLoading = false);
              }
            },
            child: const Text("Search"),
          ),
        ],
      ),
    );
  }

  Widget _buildStylingItemSelector() {
    if (wardrobeItems.isEmpty) {
      return const Text(
        "No items in wardrobe to select.",
        style: TextStyle(fontSize: 13, color: Colors.grey),
      );
    }

    if (selectedItemIds.isEmpty) {
      return GestureDetector(
        onTap: _openWardrobePicker,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE8E8E8)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: const Column(
            children: [
              Icon(Icons.checkroom, color: Color(0xFF0F766E), size: 28),
              SizedBox(height: 8),
              Text(
                "Choose from Wardrobe",
                style: TextStyle(
                  color: Color(0xFF0F766E),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 2),
              Text(
                "AI will complete the outfit around selected pieces",
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    final selectedItems = selectedItemIds.map((id) {
      return wardrobeItems.firstWhere((item) => (int.tryParse(item["id"]?.toString() ?? "") ?? 0) == id, orElse: () => null);
    }).where((item) => item != null).toList();

    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: selectedItems.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return GestureDetector(
              onTap: _openWardrobePicker,
              child: Container(
                width: 80,
                margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF0F766E)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Color(0xFF0F766E), size: 20),
                    SizedBox(height: 4),
                    Text(
                      "Add More",
                      style: TextStyle(color: Color(0xFF0F766E), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );
          }

          final item = selectedItems[index - 1]!;
          final imagePath = item["image_path"]?.toString() ?? "";

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 80,
                margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  image: DecorationImage(
                    image: NetworkImage(imagePath),
                    fit: BoxFit.cover,
                  ),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
              ),
              Positioned(
                top: 0,
                right: 8,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedItemIds.remove(int.tryParse(item["id"]?.toString() ?? "") ?? 0);
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 10),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openWardrobePicker() async {
    final List<int>? result = await showDialog<List<int>>(
      context: context,
      builder: (context) {
        List<int> tempSelected = List<int>.from(selectedItemIds);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFAF7F2),
              title: const Text("Select Styling Items", style: TextStyle(fontWeight: FontWeight.bold)),
              content: wardrobeItems.isEmpty
                  ? const SizedBox(
                      height: 100,
                      child: Center(child: Text("No wardrobe items found.")),
                    )
                  : SizedBox(
                      width: double.maxFinite,
                      height: 350,
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: wardrobeItems.length,
                        itemBuilder: (context, idx) {
                          final item = wardrobeItems[idx];
                          final id = int.tryParse(item["id"]?.toString() ?? "") ?? 0;
                          final imagePath = item["image_path"]?.toString() ?? "";
                          final subcat = item["subcategory"]?.toString() ?? item["category"]?.toString() ?? "";
                          final isSel = tempSelected.contains(id);

                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                if (isSel) {
                                  tempSelected.remove(id);
                                } else {
                                  tempSelected.add(id);
                                }
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSel ? const Color(0xFF0F766E) : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(imagePath, fit: BoxFit.cover),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        color: Colors.black.withOpacity(0.6),
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Text(
                                          subcat,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white, fontSize: 9),
                                        ),
                                      ),
                                    ),
                                    if (isSel)
                                      const Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Icon(Icons.check_circle, color: Color(0xFF0F766E), size: 18),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, tempSelected),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
                  child: const Text("Confirm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        selectedItemIds = result;
      });
    }
  }
}
