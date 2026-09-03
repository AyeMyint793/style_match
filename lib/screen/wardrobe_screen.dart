import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/wardrobe_cache_service.dart';
import '../widgets/multi_item_review_sheet.dart';
import 'trip_packing_screen.dart';
import 'ai_outfit_screen.dart';


class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  List<Map<String, String>> clothes = [];
  String selectedCategory = "All";
  final ImagePicker picker = ImagePicker();
  String? userEmail;
  bool isLoadingClothes = false;
  List<dynamic> wardrobeGaps = [];
  Map<String, dynamic>? wardrobeStats;
  bool isAnalyzing = false;
  String? insightsError;
  bool showInsights = true;

  bool isOffline = false;
  bool isSyncing = false;
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    _initUser();
    _setupConnectivity();
    WardrobeUploadManager().addListener(_onUploadQueueChanged);
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    WardrobeUploadManager().removeListener(_onUploadQueueChanged);
    super.dispose();
  }

  void _setupConnectivity() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final List<ConnectivityResult> list = results;
      final hasConnection = list.any((result) => result != ConnectivityResult.none);
      if (hasConnection) {
        if (_wasOffline) {
          // Connection restored! Auto refresh and retry failed uploads
          loadClothes(forceRefresh: true);
          WardrobeUploadManager().retryFailedItems();
          _wasOffline = false;
        }
      } else {
        _wasOffline = true;
        if (mounted) {
          setState(() {
            isOffline = true;
          });
        }
      }
    });
  }

  void _onUploadQueueChanged() {
    if (mounted) {
      loadClothes(forceRefresh: true);
    }
  }

  Future<void> _initUser() async {
    userEmail = await AuthService.getUserEmail();
    if (userEmail != null) {
      WardrobeUploadManager().initialize(userEmail!);
    }
    if (mounted) setState(() {});
    loadClothes();
  }

  Future<void> loadClothes({bool forceRefresh = false}) async {
    if (userEmail == null) return;

    // Load from cache first if currently empty or not forced
    if (clothes.isEmpty || !forceRefresh) {
      final cachedClothes = await WardrobeCacheService.getCachedClothes(userEmail!);
      final cachedStats = await WardrobeCacheService.getCachedStats(userEmail!);
      final cachedGaps = await WardrobeCacheService.getCachedGaps(userEmail!);
      if (cachedClothes != null && mounted) {
        setState(() {
          clothes = cachedClothes;
          wardrobeStats = cachedStats;
          wardrobeGaps = cachedGaps ?? [];
          isLoadingClothes = false;
        });
      } else {
        if (mounted) {
          setState(() => isLoadingClothes = true);
        }
      }
    }

    if (mounted) setState(() => isSyncing = true);

    try {
      final clothesData = await ApiService.getClothes(userEmail!);
      if (clothesData != null) {
        final List<Map<String, String>> freshClothes = List<Map<String, String>>.from(
          clothesData.map((item) => {
            "id": item["id"].toString(),
            "path": item["image_path"].toString(),
            "category": item["category"].toString(),
            "subcategory": item["subcategory"]?.toString() ?? "",
            "occasion": item["occasion"].toString(),
            "season": item["season"].toString(),
            "color": item["color"]?.toString() ?? "",
          }),
        );

        if (mounted) {
          setState(() {
            clothes = freshClothes;
            isOffline = false;
          });
        }
        await WardrobeCacheService.saveCachedClothes(userEmail!, freshClothes);
      } else {
        if (mounted) {
          setState(() {
            isOffline = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Load clothes error: $e");
      if (mounted) {
        setState(() {
          isOffline = true;
        });
      }
    }

    if (!isOffline) {
      setState(() => isAnalyzing = true);
      try {
        final analysis = await ApiService.analyzeWardrobe(userEmail!);
        if (analysis != null && mounted) {
          setState(() {
            wardrobeStats = analysis["stats"];
            wardrobeGaps = analysis["gaps"] ?? analysis["insights"] ?? [];
          });
          await WardrobeCacheService.saveCachedStats(userEmail!, wardrobeStats);
          await WardrobeCacheService.saveCachedGaps(userEmail!, wardrobeGaps);
        }
      } catch (e) {
        debugPrint("Analyze wardrobe error: $e");
      }
      if (mounted) setState(() => isAnalyzing = false);
    }

    if (mounted) {
      setState(() {
        isLoadingClothes = false;
        isSyncing = false;
      });
    }
  }

  void showBatchUploadSheet(List<XFile> selectedFiles) {
    if (userEmail == null) return;

    final manager = WardrobeUploadManager();
    if (selectedFiles.isNotEmpty) {
      manager.addItems(selectedFiles);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (context) {
        return _BatchUploadTray(
          userEmail: userEmail!,
          onComplete: () {
            loadClothes(forceRefresh: true);
          },
        );
      },
    );
  }

  void showAddOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Add to Wardrobe",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF0F766E).withOpacity(0.08),
                      const Color(0xFFF9735B).withOpacity(0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF0F766E).withOpacity(0.3)),
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF0F766E),
                    child: Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  ),
                  title: const Text(
                    "✨ Magic Flat-Lay (Multi-Item)",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    "Lay out 2–5 pieces on bed/floor & snap 1 photo",
                    style: TextStyle(fontSize: 12),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF0F766E)),
                  onTap: () {
                    Navigator.pop(context);
                    _handleMagicFlatLay();
                  },
                ),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF0F766E)),
                title: const Text("Single Garment Camera"),
                subtitle: const Text("Quick capture of an individual item"),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 1280,
                    maxHeight: 1280,
                    imageQuality: 82,
                  );
                  if (image != null) {
                    _processPhotoForReview(image);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF0F766E)),
                title: const Text("Photo Gallery"),
                subtitle: const Text("Select existing clothing pictures"),
                onTap: () async {
                  Navigator.pop(context);
                  final List<XFile> images = await picker.pickMultiImage(
                    maxWidth: 1280,
                    maxHeight: 1280,
                    imageQuality: 82,
                  );
                  if (images.length == 1) {
                    _processPhotoForReview(images.first);
                  } else if (images.length > 1) {
                    showBatchUploadSheet(images);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleMagicFlatLay() async {
    if (userEmail == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Magic Flat-Lay Photo",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                "Lay out 2-5 items on a bed or flat surface and capture",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: Color(0xFF0F766E)),
                title: const Text("Take Flat-Lay Photo"),
                subtitle: const Text("Snap directly with your camera"),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? photo = await picker.pickImage(
                    source: ImageSource.camera,
                    maxWidth: 1280,
                    maxHeight: 1280,
                    imageQuality: 82,
                  );
                  if (photo != null) {
                    _processPhotoForReview(photo);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: Color(0xFF0F766E)),
                title: const Text("Choose from Gallery"),
                subtitle: const Text("Select existing flat-lay picture"),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? photo = await picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 1280,
                    maxHeight: 1280,
                    imageQuality: 82,
                  );
                  if (photo != null) {
                    _processPhotoForReview(photo);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _processPhotoForReview(XFile photo) async {
    if (!mounted || userEmail == null) return;

    // Show progressive loading feedback
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 38,
                height: 38,
                child: CircularProgressIndicator(
                  color: Color(0xFF0F766E),
                  strokeWidth: 3,
                ),
              ),
              SizedBox(height: 20),
              Text(
                "Detecting Garments...",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF171717),
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Scanning photo, isolating authentic clothing & ignoring backgrounds...",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );

    final result = await ApiService.processMultiWardrobeImage(photo.path);

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

    if (result != null && result["success"] == true && (result["items"] as List).isNotEmpty) {
      final items = List<Map<String, dynamic>>.from(result["items"]);
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => MultiItemReviewSheet(
          userEmail: userEmail!,
          detectedItems: items,
          onCompleted: () => loadClothes(forceRefresh: true),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result?["message"]?.toString() ?? "Could not detect clothing items. Please take a clear photo of apparel, shoes, or accessories."),
          backgroundColor: Colors.orange.shade800,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildCategoryEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.checkroom, color: Colors.grey, size: 60),
            const SizedBox(height: 16),
            Text(
              "No items in $selectedCategory",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
            ),
            const SizedBox(height: 6),
            const Text(
              "Start uploading clothes in this category to complete your digitised closet.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredClothes = selectedCategory == "All"
        ? clothes
        : clothes.where((item) => item["category"]?.toString().toLowerCase() == selectedCategory.toLowerCase()).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: isLoadingClothes
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F766E)))
          : RefreshIndicator(
              onRefresh: () => loadClothes(forceRefresh: true),
              color: const Color(0xFF0F766E),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (isOffline)
                    SliverToBoxAdapter(child: _buildOfflineBanner()),
                  if (isSyncing)
                    const SliverToBoxAdapter(
                      child: LinearProgressIndicator(
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
                      ),
                    ),
                  SliverToBoxAdapter(child: _buildTripPlannerBanner()),
                  SliverToBoxAdapter(child: _buildUploadProgressBanner()),
                  if (wardrobeGaps.isNotEmpty)
                    SliverToBoxAdapter(child: _buildSuggestions()),
                  SliverToBoxAdapter(child: _buildCategoryFilters()),
                  if (clothes.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildEmptyState(),
                    )
                  else if (filteredClothes.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _buildCategoryEmptyState(),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.85,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => _buildClothesCard(filteredClothes, index),
                          childCount: filteredClothes.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0F766E),
        onPressed: showAddOptions,
        icon: const Icon(Icons.add_a_photo_outlined, color: Colors.white),
        label: const Text("Add Clothes",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7), // Amber 50
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)), // Amber 200
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Color(0xFFD97706), size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "Offline mode. Showing cached wardrobe.",
              style: TextStyle(
                color: Color(0xFF92400E), // Amber 800
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () => loadClothes(forceRefresh: true),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              "Retry",
              style: TextStyle(
                color: Color(0xFFB45309), // Amber 700
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadProgressBanner() {
    return AnimatedBuilder(
      animation: WardrobeUploadManager(),
      builder: (context, child) {
        final manager = WardrobeUploadManager();
        if (manager.queue.isEmpty) return const SizedBox.shrink();

        final activeItems = manager.queue.where((item) => item.status != "Done" && item.status != "Invalid").toList();
        if (activeItems.isEmpty) return const SizedBox.shrink();

        final total = manager.totalCount;
        final completed = manager.processedCount;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
            border: Border.all(color: const Color(0xFF0F766E).withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF0F766E),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Uploading Closet Items ($completed/$total)",
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF171717),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0.0 : completed / total,
                        backgroundColor: Colors.grey.shade100,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => showBatchUploadSheet([]),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  "View",
                  style: TextStyle(
                    color: Color(0xFF0F766E),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTripPlannerBanner() {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const TripPackingScreen()),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0F766E),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF0F766E).withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.luggage, color: Colors.white, size: 28),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Plan your next trip",
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  Text(
                    "AI suitcase packing from your closet",
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white, size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions() {
    if (!showInsights) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F6F4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFEAE6)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lightbulb, color: Color(0xFF0F766E), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Wardrobe Insights', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF0F766E))),
                    const SizedBox(width: 8),
                    if (isAnalyzing) const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E))),
                  ],
                ),
                const SizedBox(height: 6),
                // Small stats row
                if (wardrobeStats != null) Row(
                  children: [
                    Text('Total: ${wardrobeStats!["total_items"]}', style: const TextStyle(fontSize: 12, color: Color(0xFF0F766E))),
                    const SizedBox(width: 12),
                    // show top 2 categories
                    if (wardrobeStats!["percent_by_category"] is Map && (wardrobeStats!["percent_by_category"] as Map).isNotEmpty)
                      ...((wardrobeStats!["percent_by_category"] as Map<String, dynamic>).entries.take(2).map((e) => Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Chip(label: Text('${e.key} ${e.value}%', style: const TextStyle(fontSize: 11, color: Color(0xFF0F766E))), backgroundColor: Colors.white),
                      ))).toList(),
                  ],
                ),
                const SizedBox(height: 6),
                if (wardrobeStats != null && wardrobeStats!["dominant_colors"] is List && (wardrobeStats!["dominant_colors"] as List).isNotEmpty) ...[
                  Text('Top colors: ' + (wardrobeStats!["dominant_colors"] as List).take(3).map((c) => '${c["value"]}').join(', '), style: const TextStyle(fontSize: 12, color: Color(0xFF0F766E))),
                  if (wardrobeGaps.isNotEmpty) const SizedBox(height: 6),
                ],
                if (wardrobeGaps.isNotEmpty)
                  Text('Tips: ${wardrobeGaps.first["suggestion"]}', style: const TextStyle(fontSize: 12, color: Color(0xFF0F766E))),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF0F766E), size: 20),
            onPressed: () {
              setState(() => showInsights = false);
            },
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final bool showOfflineEmpty = isOffline && clothes.isEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.grey.shade200, blurRadius: 12)
                ],
              ),
              child: Icon(
                showOfflineEmpty ? Icons.cloud_off_rounded : Icons.checkroom,
                size: 50,
                color: const Color(0xFF0F766E),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              showOfflineEmpty ? "Connection Unavailable" : "Your wardrobe is empty",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF171717),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              showOfflineEmpty
                  ? "We couldn't connect to the server to retrieve your wardrobe. Please check your internet connection."
                  : "Digitize your closet to get started",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            if (showOfflineEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => loadClothes(forceRefresh: true),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text("Retry Connection"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryFilters() {
    final List<Map<String, dynamic>> cats = [
      {"label": "All", "icon": Icons.grid_view_outlined},
      {"label": "Tops", "icon": Icons.checkroom_outlined},
      {"label": "Bottoms", "icon": Icons.accessibility_new_outlined},
      {"label": "Dresses", "icon": Icons.pregnant_woman_outlined},
      {"label": "Shoes", "icon": Icons.nordic_walking_outlined},
      {"label": "Outerwear", "icon": Icons.layers_outlined},
      {"label": "Accessories", "icon": Icons.watch_outlined},
    ];

    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cats.length,
        itemBuilder: (context, index) {
          final cat = cats[index];
          final label = cat["label"] as String;
          final icon = cat["icon"] as IconData;
          final isSelected = selectedCategory == label;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedCategory = label;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0F766E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFE5E7EB),
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: const Color(0xFF0F766E).withOpacity(0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    )
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 16,
                    color: isSelected ? Colors.white : const Color(0xFF0F766E),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF171717),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showClothesDetailSheet(Map<String, String> item) {
    final int itemId = int.tryParse(item["id"] ?? "") ?? 0;
    final String imagePath = item["path"] ?? "";
    final String category = item["category"] ?? "";
    final String subcategory = item["subcategory"] ?? "";
    final String occasion = item["occasion"] ?? "";
    final String season = item["season"] ?? "";
    final String color = item["color"] ?? "";

    final stylingAdvice = "Pair this $color ${subcategory.isNotEmpty ? subcategory : category.toLowerCase()} with neutral pieces to make it the center of attention. Ideal for $season $occasion styling.";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFAF7F2),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    subcategory.isNotEmpty ? subcategory : category,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF171717),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _confirmDeleteItem(itemId),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFF0F0),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.network(
                  imagePath,
                  width: double.infinity,
                  height: 250,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 250,
                    color: const Color(0xFFF3F4F6),
                    child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMetaTag("Category: $category", Icons.checkroom),
                  if (subcategory.isNotEmpty) _buildMetaTag("Style: $subcategory", Icons.style),
                  _buildMetaTag("Color: $color", Icons.palette),
                  _buildMetaTag("Season: $season", Icons.cloud),
                  _buildMetaTag("Occasion: $occasion", Icons.local_activity),
                ],
              ),
              const SizedBox(height: 20),

              const Text(
                "AI STYLIST RECOMMENDATION",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
                child: Text(
                  stylingAdvice,
                  style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.45),
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AIOutfitScreen(
                          preselectedItemIds: [itemId],
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                  label: const Text(
                    "Style Around This Item",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F766E),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMetaTag(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0F766E).withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF0F766E)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF0F766E),
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteItem(int itemId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text("Remove Item", style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text("Are you sure you want to remove this item from your wardrobe?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                Navigator.pop(context);
                
                setState(() => isLoadingClothes = true);
                final success = await ApiService.deleteClothes(itemId);
                if (!mounted) return;
                if (success) {
                  loadClothes(forceRefresh: true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Clothes item deleted successfully"),
                      backgroundColor: Color(0xFF0F766E),
                    ),
                  );
                } else {
                  setState(() => isLoadingClothes = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Failed to delete clothing item")),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildClothesCard(List<Map<String, String>> filteredList, int index) {
    final item = filteredList[index];
    return GestureDetector(
      onTap: () => _showClothesDetailSheet(item),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: item["path"]!,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E)),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.broken_image_outlined, color: Colors.grey),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item["subcategory"]!.isEmpty
                            ? item["category"]!
                            : item["subcategory"]!,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        "${item["color"]} · ${item["season"]}",
                        style: const TextStyle(color: Colors.white70, fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
  }
}

class _BatchUploadTray extends StatefulWidget {
  final String userEmail;
  final VoidCallback onComplete;

  const _BatchUploadTray({
    required this.userEmail,
    required this.onComplete,
  });

  @override
  State<_BatchUploadTray> createState() => _BatchUploadTrayState();
}

class _BatchUploadTrayState extends State<_BatchUploadTray> {
  @override
  void initState() {
    super.initState();
    WardrobeUploadManager().addListener(_onManagerUpdate);
  }

  @override
  void dispose() {
    WardrobeUploadManager().removeListener(_onManagerUpdate);
    super.dispose();
  }

  void _onManagerUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  void _openReview(int index) {
    final manager = WardrobeUploadManager();
    if (index >= manager.queue.length) return;
    final item = manager.queue[index];
    if (item.status != "Done" && item.status != "Invalid") return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ItemReviewSheet(
        item: item,
        userEmail: widget.userEmail,
        onUpdate: () {
          setState(() {});
          widget.onComplete();
        },
        onRemove: () {
          setState(() {
            manager.queue.removeAt(index);
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final manager = WardrobeUploadManager();
    final items = manager.queue;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFFFAF7F2),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 20),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Wardrobe Scanner",
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    Text(
                        "${manager.processedCount} of ${items.length} items processed",
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
                Row(
                  children: [
                    if (manager.isProcessing)
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFF0F766E))),
                    if (manager.processedCount > 0) ...[
                      const SizedBox(width: 16),
                      TextButton(
                        onPressed: () {
                          manager.clearCompleted();
                        },
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                        child: const Text(
                          "Clear Done",
                          style: TextStyle(
                            color: Color(0xFFE11D48),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_done_outlined, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          "No active uploads in queue",
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return GestureDetector(
                        onTap: () {
                          if (item.status == "Failed") {
                            manager.retryItem(item);
                          } else {
                            _openReview(index);
                          }
                        },
                        child: _ProcessingCard(item: item),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text("Close Scanner",
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessingCard extends StatelessWidget {
  final UploadItem item;
  const _ProcessingCard({required this.item});

  @override
  Widget build(BuildContext context) {
    bool isDone = item.status == "Done";
    bool isInvalid = item.status == "Invalid";

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDone
                ? const Color(0xFF0F766E)
                : (isInvalid ? Colors.orange : Colors.grey.shade200),
            width: (isDone || isInvalid) ? 2 : 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(item.file.path), fit: BoxFit.cover),
            if (item.status == "Uploading" || item.status == "Analyzing")
              Container(
                color: Colors.black.withValues(alpha: 0.4),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              value: item.progress,
                              color: Colors.white,
                              strokeWidth: 2)),
                      const SizedBox(height: 8),
                      Text(item.status,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            if (isDone)
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                      color: Color(0xFF0F766E), shape: BoxShape.circle),
                  child: const Icon(Icons.check, color: Colors.white, size: 14),
                ),
              ),
            if (isInvalid)
              Container(
                color: Colors.orange.withValues(alpha: 0.3),
                child: const Center(
                    child: Icon(Icons.help_outline,
                        color: Colors.white, size: 32)),
              ),
            if (item.status == "Failed")
              Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.refresh, color: Colors.white, size: 28),
                      SizedBox(height: 4),
                      Text(
                        "Tap to Retry",
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemReviewSheet extends StatefulWidget {
  final UploadItem item;
  final String userEmail;
  final VoidCallback onUpdate;
  final VoidCallback onRemove;

  const _ItemReviewSheet({
    required this.item,
    required this.userEmail,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  State<_ItemReviewSheet> createState() => _ItemReviewSheetState();
}

class _ItemReviewSheetState extends State<_ItemReviewSheet> {
  late TextEditingController categoryController;
  late TextEditingController subcategoryController;
  late TextEditingController colorController;
  late TextEditingController occasionController;
  late TextEditingController seasonController;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    final tags = widget.item.detectedTags ?? {};
    categoryController = TextEditingController(text: tags["category"]?.toString() ?? "");
    subcategoryController = TextEditingController(text: tags["subcategory"]?.toString() ?? "");
    colorController = TextEditingController(text: tags["color"]?.toString() ?? "");
    occasionController = TextEditingController(text: tags["occasion"]?.toString() ?? "");
    seasonController = TextEditingController(text: tags["season"]?.toString() ?? "");
  }

  @override
  void dispose() {
    categoryController.dispose();
    subcategoryController.dispose();
    colorController.dispose();
    occasionController.dispose();
    seasonController.dispose();
    super.dispose();
  }

  Future<void> _saveToDatabase() async {
    if (widget.item.cloudinaryUrl == null) return;

    setState(() => isSaving = true);

    bool success = false;
    if (widget.item.savedId != null) {
      success = await ApiService.updateClothes(
        id: widget.item.savedId!,
        category: categoryController.text.trim(),
        subcategory: subcategoryController.text.trim(),
        occasion: occasionController.text.trim(),
        season: seasonController.text.trim(),
        color: colorController.text.trim(),
        stylistNote: widget.item.detectedTags?["stylist_note"]?.toString() ?? "",
      );
    } else {
      final res = await ApiService.saveClothes(
        widget.userEmail,
        widget.item.cloudinaryUrl!,
        categoryController.text.trim(),
        subcategoryController.text.trim(),
        occasionController.text.trim(),
        seasonController.text.trim(),
        colorController.text.trim(),
        widget.item.detectedTags?["stylist_note"]?.toString() ?? "",
      );
      if (res != null && res["success"] == true) {
        success = true;
        widget.item.savedId = int.tryParse(res["id"]?.toString() ?? "");
      }
    }

    if (mounted) setState(() => isSaving = false);
    if (!mounted) return;

    if (success) {
      widget.item.status = "Done";
      widget.item.detectedTags = {
        ...?widget.item.detectedTags,
        "category": categoryController.text.trim(),
        "subcategory": subcategoryController.text.trim(),
        "color": colorController.text.trim(),
        "occasion": occasionController.text.trim(),
        "season": seasonController.text.trim(),
      };
      widget.onUpdate();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Clothing item successfully verified and updated!"),
          backgroundColor: Color(0xFF0F766E),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Failed to save clothing item. Please check network/values."),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tags = widget.item.detectedTags ?? {};
    final bool isInvalid = widget.item.status == "Invalid";
    final String confidence = tags["confidence"]?.toString() ?? "high";

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (isInvalid)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "AI marked this as low confidence. Please verify details to save it to your wardrobe.",
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.file(
                        File(widget.item.file.path),
                        width: 120,
                        height: 160,
                        fit: BoxFit.cover,
                      ),
                    ),
                    if (confidence == "low")
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            "Blurry Image",
                            style: TextStyle(color: Colors.white, fontSize: 10),
                          ),
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
                        "Stylist's Note",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F766E),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tags["stylist_note"]?.toString() ?? "Ready to style!",
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF171717),
                          height: 1.5,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              "Details",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _editRow("Category", categoryController),
            _editRow("Style", subcategoryController),
            _editRow("Color", colorController),
            _editRow("Occasion", occasionController),
            _editRow("Season", seasonController),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: widget.onRemove,
                    child: const Text(
                      "Remove Item",
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : (isInvalid ? _saveToDatabase : () => Navigator.pop(context)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF171717),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            isInvalid ? "Save to Wardrobe" : "Keep Details",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _editRow(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class UploadItem {
  final XFile file;
  String? cloudinaryUrl;
  Map<String, dynamic>? detectedTags;
  String status; // "Pending", "Uploading", "Analyzing", "Done", "Invalid", "Failed"
  double progress;
  int? savedId;

  UploadItem({
    required this.file,
    this.cloudinaryUrl,
    this.detectedTags,
    this.status = "Pending",
    this.progress = 0.0,
    this.savedId,
  });
}

class WardrobeUploadManager extends ChangeNotifier {
  static final WardrobeUploadManager _instance = WardrobeUploadManager._internal();
  factory WardrobeUploadManager() => _instance;
  WardrobeUploadManager._internal();

  final List<UploadItem> queue = [];
  bool isProcessing = false;
  String? userEmail;

  int get totalCount => queue.length;
  int get processedCount => queue.where((item) => item.status == "Done" || item.status == "Failed" || item.status == "Invalid").length;
  int get successCount => queue.where((item) => item.status == "Done").length;
  int get failedCount => queue.where((item) => item.status == "Failed").length;

  void initialize(String email) {
    userEmail = email;
  }

  void addItems(List<XFile> files) {
    if (userEmail == null) return;
    final existingPaths = queue.map((item) => item.file.path).toSet();
    final newItems = files
        .where((file) => !existingPaths.contains(file.path))
        .map((file) => UploadItem(file: file))
        .toList();

    queue.addAll(newItems);
    notifyListeners();

    if (!isProcessing) {
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    isProcessing = true;
    notifyListeners();

    while (true) {
      UploadItem? nextItem;
      try {
        nextItem = queue.firstWhere((item) => item.status == "Pending");
      } catch (_) {
        nextItem = null;
      }

      if (nextItem == null) break;

      await _processSingleItem(nextItem);
    }

    isProcessing = false;
    notifyListeners();
  }

  Future<void> _processSingleItem(UploadItem item) async {
    if (item.cloudinaryUrl == null || item.detectedTags == null) {
      item.status = "Uploading";
      item.progress = 0.3;
      notifyListeners();

      final result = await ApiService.processWardrobeImage(item.file.path);
      if (result == null || result["success"] != true) {
        item.status = "Failed";
        item.progress = 0.0;
        notifyListeners();
        return;
      }

      item.cloudinaryUrl = result["image_url"]?.toString();
      item.detectedTags = Map<String, dynamic>.from(result["tags"] ?? {});
    }

    final url = item.cloudinaryUrl!;
    final tags = item.detectedTags!;
    bool isClothing = tags["is_clothing"] == "true" || tags["is_clothing"] == true;

    try {
      if (isClothing && userEmail != null) {
        final bool isFallback = tags["fallback"] == true ||
            tags["confidence"]?.toString().toLowerCase() == "low" ||
            (tags["category"] == null || tags["category"].toString().trim().isEmpty);

        if (!isFallback) {
          final res = await ApiService.saveClothes(
            userEmail!,
            url,
            tags["category"]?.toString() ?? "",
            tags["subcategory"]?.toString() ?? "",
            tags["occasion"]?.toString() ?? "",
            tags["season"]?.toString() ?? "",
            tags["color"]?.toString() ?? "",
            tags["stylist_note"]?.toString() ?? "",
          );
          if (res != null && res["success"] == true) {
            item.status = "Done";
            item.progress = 1.0;
            item.savedId = int.tryParse(res["id"]?.toString() ?? "");
          } else {
            item.status = "Failed";
          }
        } else {
          item.status = "Invalid";
          item.progress = 1.0;
        }
      } else {
        item.status = "Invalid";
        item.progress = 1.0;
      }
    } catch (e) {
      item.status = "Failed";
      item.progress = 0.0;
    }

    notifyListeners();
  }


  Future<void> retryItem(UploadItem item) async {
    item.status = "Pending";
    item.progress = 0.0;
    notifyListeners();
    if (!isProcessing) {
      _processQueue();
    }
  }

  void retryFailedItems() {
    bool hasFailed = false;
    for (var item in queue) {
      if (item.status == "Failed") {
        item.status = "Pending";
        item.progress = 0.0;
        hasFailed = true;
      }
    }
    if (hasFailed) {
      notifyListeners();
      if (!isProcessing) {
        _processQueue();
      }
    }
  }

  void clearCompleted() {
    queue.removeWhere((item) => item.status == "Done" || item.status == "Invalid");
    notifyListeners();
  }

}
