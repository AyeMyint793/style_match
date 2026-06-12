import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class TripPackingScreen extends StatefulWidget {
  const TripPackingScreen({super.key});

  @override
  State<TripPackingScreen> createState() => _TripPackingScreenState();
}

class _TripPackingScreenState extends State<TripPackingScreen> {
  final TextEditingController destinationController = TextEditingController();
  final TextEditingController daysController = TextEditingController();
  final TextEditingController activitiesController = TextEditingController();

  String selectedTripType = "Vacation";
  bool isLoading = false;
  Map<String, dynamic>? result;
  String? userEmail;
  String weatherInfo = "";

  final List<String> tripTypes = ["Vacation", "Business", "Adventure", "Wedding"];

  @override
  void initState() {
    super.initState();
    loadEmail();
  }

  Future<void> loadEmail() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => userEmail = prefs.getString("email"));
  }

  Future<void> fetchDestinationWeather(String city) async {
    try {
      final apiKey = dotenv.env['OPENWEATHER_API_KEY']!;
      final url = "https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric";
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final temp = data["main"]["temp"].toDouble();
        final description = data["weather"][0]["description"];
        setState(() {
          weatherInfo = "${temp.toStringAsFixed(0)}°C, $description";
        });
      }
    } catch (e) {
      print("Weather fetch error: $e");
    }
  }

  Future<void> generatePackingList() async {
    if (destinationController.text.isEmpty || daysController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter destination and number of days")),
      );
      return;
    }

    setState(() {
      isLoading = true;
      result = null;
    });

    // Fetch weather for destination
    await fetchDestinationWeather(destinationController.text.trim());

    try {
      final response = await http.post(
        Uri.parse("http://10.0.2.2:8000/trip-packing"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": userEmail,
          "destination": destinationController.text.trim(),
          "days": int.parse(daysController.text.trim()),
          "trip_type": selectedTripType,
          "activities": activitiesController.text.trim(),
          "weather": weatherInfo,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data["success"] == true) {
          setState(() => result = data);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data["message"] ?? "Failed to generate packing list")),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Connection error. Is backend running?")),
      );
    }

    setState(() => isLoading = false);
  }

  @override
  void dispose() {
    destinationController.dispose();
    daysController.dispose();
    activitiesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F766E),
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Trip Packing",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Header
            const Text(
              "Plan your trip outfits",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF171717),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "AI will pack smart using your wardrobe",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),

            const SizedBox(height: 24),

            // Destination
            const Text(
              "Destination",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: destinationController,
              decoration: InputDecoration(
                hintText: "e.g. Paris, Bali, New York",
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.flight_takeoff, color: Color(0xFF0F766E)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Number of days
            const Text(
              "Number of Days",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: daysController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: "e.g. 5",
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF0F766E)),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Trip type
            const Text(
              "Trip Type",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: tripTypes.map((type) {
                final isSelected = selectedTripType == type;
                return GestureDetector(
                  onTap: () => setState(() => selectedTripType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0F766E) : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFE8E8E8),
                      ),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 16),

            // Planned activities
            const Text(
              "Planned Activities (optional)",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 4),
            const Text(
              "Tell AI what you'll be doing",
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: activitiesController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "e.g. beach during day, rooftop party one night, casual sightseeing...",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),

            const SizedBox(height: 28),

            // Generate button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: isLoading ? null : generatePackingList,
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
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                    SizedBox(width: 12),
                    Text(
                      "Planning your trip...",
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                )
                    : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.luggage, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      "Generate Packing List",
                      style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Results
            if (result != null) ...[

              // Weather info
              if (weatherInfo.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F5E9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF81C784)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.wb_sunny_outlined, color: Color(0xFF388E3C), size: 20),
                      const SizedBox(width: 10),
                      Text(
                        "${result!["destination"]} — $weatherInfo",
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF388E3C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              // Packing list
              const Text(
                "Pack These Items",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
              ),
              const SizedBox(height: 4),
              const Text(
                "From your wardrobe",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),

              ...(result!["packing_list"] as List<dynamic>).map((item) {
                final cloth = item["item"];
                final reason = item["reason"]?.toString() ?? "";
                final imagePath = cloth["image_path"]?.toString() ?? "";
                final itemLabel = cloth["subcategory"]?.toString() ?? cloth["category"]?.toString() ?? "Item";
                final color = cloth["color"]?.toString() ?? "";

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          imagePath,
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                width: 70,
                                height: 70,
                                color: const Color(0xFFF5F5F5),
                                child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                              ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "$color $itemLabel",
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF171717),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              reason,
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),

              const SizedBox(height: 20),

              // Combinations
              if ((result!["combinations"] as List).isNotEmpty) ...[
                const Text(
                  "Outfit Combinations",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Mix and match these looks",
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ...(result!["combinations"] as List<dynamic>).asMap().entries.map((entry) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          decoration: const BoxDecoration(
                            color: Color(0xFF0F766E),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              "${entry.key + 1}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.value.toString(),
                            style: const TextStyle(fontSize: 13, color: Color(0xFF171717)),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ],

              const SizedBox(height: 20),

              // Missing items
              if ((result!["missing_items"] as List).isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFCC02)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.shopping_bag_outlined, color: Color(0xFF8B6914), size: 18),
                          SizedBox(width: 8),
                          Text(
                            "What's Missing",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF8B6914),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...(result!["missing_items"] as List<dynamic>).map((item) =>
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text("• ", style: TextStyle(color: Color(0xFF8B6914), fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Text(
                                    item.toString(),
                                    style: const TextStyle(fontSize: 13, color: Color(0xFF8B6914)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ).toList(),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Packing tip
              if (result!["packing_tip"] != null && result!["packing_tip"].toString().isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF90CAF9)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.lightbulb_outline, color: Color(0xFF1565C0), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          result!["packing_tip"].toString(),
                          style: const TextStyle(fontSize: 13, color: Color(0xFF1565C0)),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 30),
            ],
          ],
        ),
      ),
    );
  }
}