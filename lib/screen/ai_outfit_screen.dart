import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:style_match/services/weather_service.dart';
import 'package:style_match/screen/trip_packing_screen.dart';
class _Item {
  final String label;
  final IconData icon;
  const _Item(this.label, this.icon);
}

class AIOutfitScreen extends StatefulWidget {
  const AIOutfitScreen({super.key});

  @override
  State<AIOutfitScreen> createState() => _AIOutfitScreenState();
}

class _AIOutfitScreenState extends State<AIOutfitScreen> {
  String selectedOccasion = "Casual";
  String selectedSeason = "All Season";
  bool isLoading = false;
  List<dynamic> outfits = [];
  List<int> shownItemIds = [];
  String? userEmail;
  Map<String, dynamic>? weatherData;
  String weatherText = "";

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
  }

  Future<void> loadEmail() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => userEmail = prefs.getString("email"));

    // Load weather
    final weather = await WeatherService.getCurrentWeather();
    if (weather != null && mounted) {
      setState(() {
        weatherData = weather;
        weatherText = WeatherService.getWeatherContext(weather);
      });
    }
  }

  Future<void> generateOutfit() async {
    if (userEmail == null) return;
    setState(() {
      isLoading = true;
      outfits = [];
    });
    try {
      final response = await http.post(
        Uri.parse("http://10.0.2.2:8000/generate-outfit"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": userEmail,
          "occasion": selectedOccasion,
          "season": selectedSeason,
          "weather": weatherText,
          "shown_item_ids": shownItemIds,
        }),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          setState(() => outfits = data["outfits"]);
          // Track shown items
          for (var outfit in outfits) {
            for (var item in outfit["items"]) {
              final id = item["id"] as int;
              if (!shownItemIds.contains(id)) {
                shownItemIds.add(id);
              }
            }
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data["message"] ?? "Could not generate outfit")),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Title
              const Text(
                "Your Outfit",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TripPackingScreen(),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F766E),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.luggage, color: Colors.white, size: 22),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Plan a Trip",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            "AI packs your wardrobe for any destination",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                      Spacer(),
                      Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                "Pick an occasion and season — AI does the rest.",
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),

              const SizedBox(height: 28),

              // Occasion
              const Text(
                "Occasion",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF888888),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: occasions.map((occasion) {
                  final isSelected = selectedOccasion == occasion.label;
                  return GestureDetector(
                    onTap: () => setState(() => selectedOccasion = occasion.label),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0F766E) : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFE8E8E8),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            occasion.icon,
                            size: 15,
                            color: isSelected ? Colors.white : const Color(0xFF888888),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            occasion.label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Season
              const Text(
                "Season",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF888888),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: seasons.map((season) {
                  final isSelected = selectedSeason == season.label;
                  return GestureDetector(
                    onTap: () => setState(() => selectedSeason = season.label),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0F766E) : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFE8E8E8),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            season.icon,
                            size: 15,
                            color: isSelected ? Colors.white : const Color(0xFF888888),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            season.label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 28),

              // Generate button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isLoading ? null : generateOutfit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: isLoading
                      ? const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Styling your look...",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                      : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        "Create My Outfit",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // Empty state
              if (!isLoading && outfits.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.checkroom_outlined, size: 40, color: Color(0xFFCCCCCC)),
                      SizedBox(height: 12),
                      Text(
                        "Your looks will appear here",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF888888),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Tap Create My Outfit to get started",
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFAAAAAA),
                        ),
                      ),
                    ],
                  ),
                ),

              // Outfits
              if (outfits.isNotEmpty) ...[
                const Text(
                  "Your Looks",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "$selectedOccasion · $selectedSeason",
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ...outfits.map((outfit) => _outfitCard(outfit)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _outfitCard(dynamic outfit) {
    final items = (outfit["items"] as List<dynamic>?) ?? [];
    final description = outfit["description"]?.toString() ?? "A polished look selected for you.";
    final outfitNumber = int.tryParse(outfit["outfit_number"]?.toString() ?? "1") ?? 1;
    final labels = ["Effortless Look", "Polished Vibe", "Confident Style"];
    final label = outfitNumber <= 3 ? labels[outfitNumber - 1] : "Look $outfitNumber";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
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
                        label,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        "Look $outfitNumber",
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () async {
                    final itemIds = items.map((item) => item["id"] as int).toList();
                    final success = await ApiService.saveOutfit(
                      userEmail!,
                      selectedOccasion,
                      selectedSeason,
                      itemIds,
                      description,
                    );
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Outfit saved ❤️")),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Failed to save outfit")),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF0F0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite_border, color: Colors.red, size: 18),
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
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
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
                          const Center(
                            child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                          ),
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
  }
}