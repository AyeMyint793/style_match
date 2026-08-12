import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'package:style_match/services/weather_service.dart';

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
      // FIX: 5 Positional arguments: email, occasion, season, weather, shownItemIds
      final data = await ApiService.generateOutfit(
        userEmail!,
        selectedOccasion,
        selectedSeason,
        weatherText,
        shownItemIds,
      );
      if (!mounted) return;
      if (data != null && data["success"] == true) {
        setState(() => outfits = data["outfits"]);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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

              const SizedBox(height: 32),

              _sectionHeader("Occasion"),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: occasions.map((occ) => _chip(occ.label, occ.icon, isOccasion: true)).toList(),
              ),

              const SizedBox(height: 28),

              _sectionHeader("Season"),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: seasons.map((sea) => _chip(sea.label, sea.icon, isOccasion: false)).toList(),
              ),

              const SizedBox(height: 36),

              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isLoading ? null : generateOutfit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.auto_awesome, size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              "Style My Look",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 40),

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
                ...outfits.map((outfit) => _outfitCard(outfit)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Color(0xFF888888),
        letterSpacing: 0.5,
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
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F766E) : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFE8E8E8),
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: const Color(0xFF0F766E).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
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
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        children: [
          Icon(Icons.wb_sunny_outlined, size: 48, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            "Select an occasion and season to begin",
            style: TextStyle(color: Colors.grey, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _outfitCard(dynamic outfit) {
    final items = (outfit["items"] as List<dynamic>?) ?? [];
    final description = outfit["description"]?.toString() ?? "A curated look for you.";

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    description,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF444444), height: 1.5),
                  ),
                ),
                const SizedBox(width: 12),
                _saveButton(items, description),
              ],
            ),
          ),
          SizedBox(
            height: 160,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12, bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    image: DecorationImage(
                      image: NetworkImage(item["image_path"]),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _saveButton(List<dynamic> items, String desc) {
    return GestureDetector(
      onTap: () async {
        final ids = items.map((i) => i["id"] as int).toList();
        final success = await ApiService.saveOutfit(userEmail!, selectedOccasion, selectedSeason, ids, desc);
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Outfit saved to Lookbook!")));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: const Color(0xFFFDE8E8), shape: BoxShape.circle),
        child: const Icon(Icons.favorite, color: Color(0xFFE11D48), size: 18),
      ),
    );
  }
}
