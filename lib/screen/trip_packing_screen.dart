import 'package:flutter/material.dart';
import '../services/weather_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

class TripPackingScreen extends StatefulWidget {
  const TripPackingScreen({super.key});

  @override
  State<TripPackingScreen> createState() => _TripPackingScreenState();
}

class _TripPackingScreenState extends State<TripPackingScreen> {
  final TextEditingController destinationController = TextEditingController();
  final TextEditingController daysController = TextEditingController();
  final TextEditingController activitiesController = TextEditingController();
  final TextEditingController manualWeatherController = TextEditingController();
  final FocusNode destinationFocusNode = FocusNode();

  String selectedTripType = "Vacation";
  bool isLoading = false;
  Map<String, dynamic>? result;
  String? userEmail;
  String weatherInfo = "";
  bool isFetchingWeather = false;
  bool showManualOverride = false;

  // New State variables for Travel Stylist Redesign
  DateTimeRange? _selectedDateRange;
  int _selectedTab = 0; // 0: Outfit Board, 1: Suitcase Checklist
  final Set<int> _checkedItemIds = {}; // checklist packed state
  final Map<int, bool> _regeneratingDays = {}; // tracks in-place regeneration loaders

  final List<String> tripTypes = ["Vacation", "Business", "Adventure", "Wedding"];

  @override
  void initState() {
    super.initState();
    loadEmail();
    destinationFocusNode.addListener(() {
      if (!destinationFocusNode.hasFocus) {
        final city = destinationController.text.trim();
        if (city.isNotEmpty) {
          fetchDestinationWeather(city);
        }
      }
    });
  }

  Future<void> loadEmail() async {
    final email = await AuthService.getUserEmail();
    setState(() => userEmail = email);
  }

  Future<void> fetchDestinationWeather(String city) async {
    if (city.isEmpty) return;
    setState(() {
      isFetchingWeather = true;
      showManualOverride = false;
    });
    final weather = await WeatherService.getWeatherByCity(city);
    if (!mounted) return;
    setState(() {
      isFetchingWeather = false;
      if (weather != null) {
        final temp = weather["temp"] as double;
        final description = weather["description"] as String;
        weatherInfo = "${temp.toStringAsFixed(0)}°C, $description";
        manualWeatherController.text = weatherInfo;
      } else {
        weatherInfo = "";
        manualWeatherController.text = "";
        showManualOverride = true; // Show override if fetch fails
      }
    });
  }

  String _formatDate(DateTime date) {
    final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    final weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return "${months[date.month - 1]} ${date.day} (${weekdays[date.weekday - 1]})";
  }

  String _formatDateRange(DateTimeRange range) {
    return "${_formatDate(range.start)} – ${_formatDate(range.end)}";
  }

  Future<void> _selectDateRange() async {
    final initialDateRange = _selectedDateRange ?? DateTimeRange(
      start: DateTime.now(),
      end: DateTime.now().add(const Duration(days: 4)),
    );
    
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initialDateRange,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F766E),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF171717),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0F766E),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
        daysController.text = (picked.duration.inDays + 1).toString();
      });
    }
  }

  Future<void> generatePackingList() async {
    if (destinationController.text.isEmpty || daysController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter destination and trip dates")),
      );
      return;
    }

    setState(() {
      isLoading = true;
      result = null;
      _checkedItemIds.clear();
      _regeneratingDays.clear();
    });

    if (weatherInfo.isEmpty && !showManualOverride) {
      await fetchDestinationWeather(destinationController.text.trim());
    }

    final finalWeather = showManualOverride
        ? manualWeatherController.text.trim()
        : weatherInfo;

    try {
      final data = await ApiService.tripPacking(
        userEmail!,
        destinationController.text.trim(),
        int.parse(daysController.text.trim()),
        selectedTripType,
        activitiesController.text.trim(),
        finalWeather,
        startDate: _selectedDateRange != null ? _selectedDateRange!.start.toIso8601String().substring(0, 10) : null,
        endDate: _selectedDateRange != null ? _selectedDateRange!.end.toIso8601String().substring(0, 10) : null,
      );

      if (!mounted) return;

      if (data != null && data["success"] == true) {
        setState(() {
          result = data;
          _selectedTab = 0; // Default to Daily Outfit Board
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(data?["message"] ?? "Failed to generate packing list")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Connection error. Is backend running?")),
        );
      }
    }

    if (mounted) setState(() => isLoading = false);
  }

  List<List<int>> getOtherDaysOutfits(int currentDayNumber) {
    List<List<int>> otherOutfits = [];
    final itinerary = result?["itinerary"] as List<dynamic>? ?? [];
    for (var day in itinerary) {
      if (day["day_number"] != currentDayNumber) {
        final List<int> itemIds = [];
        final outfit = day["outfit"];
        if (outfit != null && outfit["items"] != null) {
          for (var item in outfit["items"]) {
            final int id = int.tryParse(item["id"].toString()) ?? 0;
            if (id != 0) {
              itemIds.add(id);
            }
          }
        }
        if (itemIds.isNotEmpty) {
          otherOutfits.add(itemIds);
        }
      }
    }
    return otherOutfits;
  }

  Future<void> regenerateDayOutfit(int dayNumber, String date, String activity, String weather, List<int> previousItemIds) async {
    if (userEmail == null) return;
    
    setState(() {
      _regeneratingDays[dayNumber] = true;
    });

    try {
      final otherOutfits = getOtherDaysOutfits(dayNumber);
      final response = await ApiService.regenerateDayOutfit(
        email: userEmail!,
        destination: destinationController.text.trim(),
        dayNumber: dayNumber,
        date: date,
        activity: activity,
        weather: weather,
        tripType: selectedTripType,
        previousOutfitItemIds: previousItemIds,
        otherDaysOutfits: otherOutfits,
      );

      if (response != null && response["success"] == true && mounted) {
        setState(() {
          final itinerary = result?["itinerary"] as List<dynamic>? ?? [];
          for (int i = 0; i < itinerary.length; i++) {
            if (itinerary[i]["day_number"] == dayNumber) {
              itinerary[i]["style_concept"] = response["style_concept"];
              itinerary[i]["styling_tip"] = response["styling_tip"];
              itinerary[i]["outfit"] = {
                "description": response["description"],
                "items": response["outfit"]["items"]
              };
              break;
            }
          }
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Day $dayNumber outfit refreshed successfully!"),
            backgroundColor: const Color(0xFF0F766E),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to regenerate outfit for this day.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error regenerating outfit.")),
        );
      }
    }

    if (mounted) {
      setState(() {
        _regeneratingDays[dayNumber] = false;
      });
    }
  }

  Future<void> saveOutfitToLookbook(String concept, String description, List<int> itemIds) async {
    if (userEmail == null) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Saving to Lookbook..."),
        duration: Duration(seconds: 1),
      ),
    );

    final success = await ApiService.saveOutfit(
      userEmail!,
      concept,
      "All Season",
      itemIds,
      description,
      tags: ["Trip", selectedTripType],
    );

    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Saved to Lookbook! ❤️"),
          backgroundColor: Color(0xFF0F766E),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to save outfit.")),
      );
    }
  }

  List<dynamic> getDynamicPackingList() {
    final Map<int, dynamic> uniqueItems = {};
    final itinerary = result?["itinerary"] as List<dynamic>? ?? [];
    for (var day in itinerary) {
      final outfit = day["outfit"];
      if (outfit != null && outfit["items"] != null) {
        for (var item in outfit["items"]) {
          final int id = int.tryParse(item["id"].toString()) ?? 0;
          if (id != 0) {
            uniqueItems[id] = item;
          }
        }
      }
    }
    return uniqueItems.values.toList();
  }

  @override
  void dispose() {
    destinationController.dispose();
    daysController.dispose();
    activitiesController.dispose();
    manualWeatherController.dispose();
    destinationFocusNode.dispose();
    super.dispose();
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
          "AI Travel Stylist",
          style: TextStyle(
            color: Color(0xFF171717),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF171717)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result == null) _buildPlannerForm() else _buildTripSummaryBanner(),
            const SizedBox(height: 24),
            if (result != null) ...[
              _buildTabSelector(),
              const SizedBox(height: 20),
              _selectedTab == 0 ? _buildDailyOutfitBoard() : _buildSuitcaseChecklist(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlannerForm() {
    return Container(
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
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFF0F766E), size: 20),
              SizedBox(width: 8),
              Text(
                "Create Travel Lookbook",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF171717),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            "Specify your trip details and let AI design a customized day-by-day capsule lookbook from your closet.",
            style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
          ),

          const SizedBox(height: 20),

          // Destination Box
          const Text(
            "DESTINATION",
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF888888)),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: TextField(
              controller: destinationController,
              focusNode: destinationFocusNode,
              decoration: InputDecoration(
                hintText: "e.g. Paris, Tokyo, Bali",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                prefixIcon: const Icon(Icons.flight_takeoff, color: Color(0xFF0F766E), size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),

          _buildWeatherSection(),

          const SizedBox(height: 16),

          // Dates Card Row
          _buildDatesCardRow(),

          const SizedBox(height: 16),

          // Vibe Selector
          const Text(
            "TRIP VIBE / STYLE",
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF888888)),
          ),
          const SizedBox(height: 6),
          _buildVibeSelectorGrid(),

          const SizedBox(height: 16),

          // Activities
          const Text(
            "PLANNED ACTIVITIES (OPTIONAL)",
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF888888)),
          ),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFAF7F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: TextField(
              controller: activitiesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: "e.g. Day 1 travel + dinner, Day 2 sightseeing, Day 3 upscale dinner party...",
                hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(12),
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),

          const SizedBox(height: 24),

          // Primary CTA Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: isLoading ? null : generatePackingList,
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
                          "Designing Your Lookbook...",
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
                          "Generate My Trip Looks",
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatesCardRow() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _selectDateRange,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "DEPARTURE",
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month, size: 16, color: Color(0xFF0F766E)),
                      const SizedBox(width: 6),
                      Text(
                        _selectedDateRange == null ? "Select Date" : _formatDate(_selectedDateRange!.start),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: _selectDateRange,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFAF7F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "RETURN",
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month, size: 16, color: Color(0xFF0F766E)),
                      const SizedBox(width: 6),
                      Text(
                        _selectedDateRange == null ? "Select Date" : _formatDate(_selectedDateRange!.end),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVibeSelectorGrid() {
    final vibeOptions = [
      {"type": "Vacation", "icon": Icons.beach_access, "desc": "Relax, sun & beaches"},
      {"type": "Business", "icon": Icons.business_center, "desc": "Smart & professional"},
      {"type": "Adventure", "icon": Icons.explore, "desc": "Outdoors & active"},
      {"type": "Wedding", "icon": Icons.celebration, "desc": "Festive & formal"},
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: vibeOptions.map((opt) {
        final type = opt["type"] as String;
        final icon = opt["icon"] as IconData;
        final desc = opt["desc"] as String;
        final isSelected = selectedTripType == type;
        return GestureDetector(
          onTap: () => setState(() => selectedTripType = type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0F766E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFE5E7EB),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected ? const Color(0xFF0F766E).withOpacity(0.2) : Colors.black.withOpacity(0.01),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected ? Colors.white : const Color(0xFF0F766E),
                  size: 22,
                ),
                const SizedBox(height: 8),
                Text(
                  type,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFF171717),
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white70 : Colors.grey.shade500,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTripSummaryBanner() {
    final rangeText = _selectedDateRange != null ? _formatDateRange(_selectedDateRange!) : "${daysController.text} Days";
    final days = daysController.text;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F766E),
            Color(0xFF115E59),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 6),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.04),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          selectedTripType.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 20),
                        onPressed: () {
                          setState(() {
                            result = null; // resets and shows form
                          });
                        },
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "BOARDING FOR",
                            style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            destinationController.text.trim(),
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Divider(color: Colors.white30, thickness: 1, height: 1),
                              Icon(Icons.flight_takeoff, color: Colors.white.withOpacity(0.7), size: 18),
                            ],
                          ),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            "DURATION",
                            style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9735B),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              "$days DAYS",
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_month, color: Colors.white70, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            rangeText,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      if (weatherInfo.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.wb_sunny_outlined, color: Colors.white, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                weatherInfo,
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSingleTab(0, "Outfit Board", Icons.auto_awesome),
          ),
          Expanded(
            child: _buildSingleTab(1, "Suitcase Checklist", Icons.luggage),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleTab(int index, String label, IconData icon) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F766E) : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.white : Colors.grey.shade600, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyOutfitBoard() {
    final itinerary = result?["itinerary"] as List<dynamic>? ?? [];

    if (itinerary.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text("No daily recommendations available."),
        ),
      );
    }

    return Column(
      children: itinerary.map((day) => _buildDayCard(day)).toList(),
    );
  }

  Widget _buildOutfitCollage(List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    
    final double collageHeight = 220;

    Widget buildImageCard(dynamic item, {required double height, required double width}) {
      final imagePath = item["image_path"]?.toString() ?? "";
      final color = item["color"]?.toString() ?? "";
      final subcat = item["subcategory"]?.toString() ?? "";

      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEEEEEE)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFFF3F4F6),
                  child: const Icon(Icons.broken_image, color: Colors.grey),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Text(
                    "$color $subcat",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (items.length == 1) {
      return buildImageCard(items[0], height: collageHeight, width: double.infinity);
    } else if (items.length == 2) {
      return SizedBox(
        height: collageHeight,
        child: Row(
          children: [
            Expanded(child: buildImageCard(items[0], height: collageHeight, width: double.infinity)),
            const SizedBox(width: 10),
            Expanded(child: buildImageCard(items[1], height: collageHeight, width: double.infinity)),
          ],
        ),
      );
    } else if (items.length == 3) {
      return SizedBox(
        height: collageHeight,
        child: Row(
          children: [
            Expanded(
              flex: 12,
              child: buildImageCard(items[0], height: collageHeight, width: double.infinity),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 10,
              child: Column(
                children: [
                  Expanded(child: buildImageCard(items[1], height: collageHeight / 2 - 5, width: double.infinity)),
                  const SizedBox(height: 10),
                  Expanded(child: buildImageCard(items[2], height: collageHeight / 2 - 5, width: double.infinity)),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      return SizedBox(
        height: collageHeight,
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(child: buildImageCard(items[0], height: collageHeight / 2 - 5, width: double.infinity)),
                  const SizedBox(width: 10),
                  Expanded(child: buildImageCard(items[1], height: collageHeight / 2 - 5, width: double.infinity)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                children: [
                  Expanded(child: buildImageCard(items[2], height: collageHeight / 2 - 5, width: double.infinity)),
                  const SizedBox(width: 10),
                  Expanded(child: buildImageCard(items[3], height: collageHeight / 2 - 5, width: double.infinity)),
                ],
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDayCard(dynamic day) {
    final int dayNumber = day["day_number"] ?? 0;
    final String date = day["date"] ?? "Day $dayNumber";
    final String activity = day["activity"] ?? "Sightseeing";
    final String weather = day["weather"] ?? "";
    final String styleConcept = day["style_concept"] ?? "Casual Look";
    final String stylingTip = day["styling_tip"] ?? "";
    final outfit = day["outfit"];
    final description = outfit?["description"] ?? "";
    final List<dynamic> items = outfit?["items"] as List<dynamic>? ?? [];

    final isRegenerating = _regeneratingDays[dayNumber] == true;
    final List<int> itemIds = items.map((i) => int.tryParse(i["id"].toString()) ?? 0).where((id) => id != 0).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                // Day Card Header
                Container(
                  color: const Color(0xFFF0FAF9),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              date,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              activity,
                              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      if (weather.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFD2EBE7)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.wb_cloudy_outlined, color: Color(0xFF0F766E), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                weather,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF0F766E), fontWeight: FontWeight.w600),
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
                          Text(
                            styleConcept,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
                          ),
                          IconButton(
                            icon: const Icon(Icons.favorite_border, color: Color(0xFFF9735B)),
                            onPressed: () => saveOutfitToLookbook(styleConcept, description, itemIds),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Quote-style Stylist Rationale
                      Container(
                        padding: const EdgeInsets.only(left: 12),
                        decoration: const BoxDecoration(
                          border: Border(
                            left: BorderSide(
                              color: Color(0xFFF9735B),
                              width: 3.5,
                            ),
                          ),
                        ),
                        child: Text(
                          description,
                          style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.45),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Pinterest Layout Collage
                      const Text(
                        "LOOKBOOK COMBINATION",
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey),
                      ),
                      const SizedBox(height: 10),
                      _buildOutfitCollage(items),

                      // Styling Tip Box
                      if (stylingTip.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFAF7F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF1ECE4)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.lightbulb_outline, color: Color(0xFFF9735B), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Styling Tip",
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF9735B)),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      stylingTip,
                                      style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), height: 1.3),
                                    ),
                                  ],
                                ),
                              )
                            ],
                          ),
                        ),
                      ],

                      const Divider(height: 24),

                      // Change look button
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: isRegenerating
                              ? null
                              : () => regenerateDayOutfit(dayNumber, date, activity, weather, itemIds),
                          icon: const Icon(Icons.auto_awesome_outlined, size: 16),
                          label: const Text(
                            "Change This Look",
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F766E),
                            side: const BorderSide(color: Color(0xFF0F766E), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            backgroundColor: const Color(0xFF0F766E).withOpacity(0.04),
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

  Widget _buildSuitcaseChecklist() {
    final items = getDynamicPackingList();

    if (items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text("Pack checklist is empty. Daily outfits use zero items."),
        ),
      );
    }

    final Map<String, List<dynamic>> groupedItems = {};
    for (var item in items) {
      final category = item["category"]?.toString() ?? "Others";
      groupedItems.putIfAbsent(category, () => []).add(item);
    }

    final totalCount = items.length;
    final packedCount = items.where((i) => _checkedItemIds.contains(int.tryParse(i["id"].toString()) ?? 0)).length;
    final progress = totalCount > 0 ? packedCount / totalCount : 0.0;

    final missingItems = result?["missing_items"] as List<dynamic>? ?? [];
    final packingTip = result?["packing_tip"]?.toString() ?? "";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Suitcase Circular Meter Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 12,
                offset: const Offset(0, 4),
              )
            ],
            border: Border.all(color: const Color(0xFFEEEEEE)),
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 65,
                    height: 65,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 6,
                      backgroundColor: const Color(0xFFE5E7EB),
                      color: const Color(0xFF0F766E),
                    ),
                  ),
                  Text(
                    "${(progress * 100).toStringAsFixed(0)}%",
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Suitcase Progress",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "$packedCount of $totalCount items packed",
                      style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      progress == 1.0 ? "🎉 Fully Packed & Ready to Go!" : "Keep packing to complete your lookbook!",
                      style: TextStyle(
                        fontSize: 11, 
                        fontWeight: FontWeight.w600,
                        color: progress == 1.0 ? const Color(0xFF2E7D32) : const Color(0xFFF9735B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        const Text(
          "Items to Pack",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
        ),
        const SizedBox(height: 12),

        ...groupedItems.entries.map((group) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  group.key.toUpperCase(),
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 0.5),
                ),
              ),
              ...group.value.map((item) {
                final int id = int.tryParse(item["id"].toString()) ?? 0;
                final imagePath = item["image_path"]?.toString() ?? "";
                final color = item["color"]?.toString() ?? "";
                final subcat = item["subcategory"]?.toString() ?? "";
                final isChecked = _checkedItemIds.contains(id);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isChecked ? const Color(0xFFD2EBE7) : const Color(0xFFEEEEEE)),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: isChecked,
                        activeColor: const Color(0xFF0F766E),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _checkedItemIds.add(id);
                            } else {
                              _checkedItemIds.remove(id);
                            }
                          });
                        },
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          imagePath,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            width: 50,
                            height: 50,
                            color: const Color(0xFFF3F4F6),
                            child: const Icon(Icons.broken_image, color: Colors.grey, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "$color $subcat",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF171717),
                            decoration: isChecked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 12),
            ],
          );
        }).toList(),

        // Missing Items Section
        if (missingItems.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            "What's Missing / Suggestions to Pack",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
          ),
          const SizedBox(height: 4),
          const Text(
            "These are recommended items not found in your wardrobe:",
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFCC02).withOpacity(0.3)),
            ),
            child: Column(
              children: missingItems.map((item) {
                final itemText = item.toString();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("• ", style: TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          itemText,
                          style: const TextStyle(fontSize: 13, color: Color(0xFFB7791F), height: 1.4),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        // Stylist Packing Tip
        if (packingTip.isNotEmpty) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE0F2F1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFB2DFDB)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, color: Color(0xFF0F766E), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Stylist Packing Tip",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        packingTip,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF0F766E), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWeatherSection() {
    final city = destinationController.text.trim();
    if (city.isEmpty) return const SizedBox.shrink();

    if (isFetchingWeather) {
      return Padding(
        padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
        child: Row(
          children: [
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E)),
            ),
            const SizedBox(width: 10),
            Text(
              "Fetching weather for $city...",
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    if (showManualOverride) {
      return Container(
        margin: const EdgeInsets.only(top: 6, bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFFE0B2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wb_cloudy_outlined, color: Color(0xFFE65100), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    weatherInfo.isEmpty
                        ? "Weather unavailable. Specify manual override:"
                        : "Customize weather context below:",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFE65100),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (weatherInfo.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        showManualOverride = false;
                        manualWeatherController.text = weatherInfo;
                      });
                    },
                    child: const Icon(Icons.close, color: Color(0xFFE65100), size: 16),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: TextField(
                controller: manualWeatherController,
                decoration: const InputDecoration(
                  hintText: "e.g. Warm and sunny, 25°C",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
      );
    }

    if (weatherInfo.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.only(top: 6, bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFC8E6C9)),
        ),
        child: Row(
          children: [
            const Icon(Icons.wb_sunny_outlined, color: Color(0xFF2E7D32), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Weather report: $weatherInfo",
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF2E7D32),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  showManualOverride = true;
                });
              },
              child: const Icon(Icons.edit, color: Color(0xFF2E7D32), size: 16),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}