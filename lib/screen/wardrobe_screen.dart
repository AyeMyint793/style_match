import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../services/ai_service.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'trip_packing_screen.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  List<Map<String, String>> clothes = [];
  final ImagePicker picker = ImagePicker();
  String? userEmail;
  bool isLoadingClothes = false;
  List<dynamic> wardrobeGaps = [];
  Map<String, dynamic>? wardrobeStats;
  bool isAnalyzing = false;
  String? insightsError;

  @override
  void initState() {
    super.initState();
    _initUser();
  }

  Future<void> _initUser() async {
    userEmail = await AuthService.getUserEmail();
    if (mounted) setState(() {});
    loadClothesFromBackend();
  }

  Future<void> loadClothesFromBackend() async {
    if (userEmail == null) return;
    setState(() => isLoadingClothes = true);
    try {
      final clothesData = await ApiService.getClothes(userEmail!);
      setState(() {
        clothes = List<Map<String, String>>.from(
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
      });
    } catch (e) {
      debugPrint("Load error: $e");
    }

    setState(() => isAnalyzing = true);
    final analysis = await ApiService.analyzeWardrobe(userEmail!);
    if (analysis != null && mounted) {
      setState(() {
        wardrobeStats = analysis["stats"];
        wardrobeGaps = analysis["gaps"] ?? analysis["insights"] ?? [];
      });
    } else if (mounted) {
      setState(() {
        wardrobeStats = null;
        wardrobeGaps = [];
      });
    }
    setState(() => isAnalyzing = false);

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
      debugPrint("Cloudinary upload error: $e");
      return null;
    }
  }

  void showBatchUploadSheet(List<XFile> selectedFiles) {
    if (selectedFiles.isEmpty || userEmail == null) return;

    List<_UploadItem> uploadItems =
        selectedFiles.map((file) => _UploadItem(file: file)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      builder: (context) {
        return _BatchUploadTray(
          items: uploadItems,
          userEmail: userEmail!,
          onComplete: () {
            loadClothesFromBackend();
          },
          uploadHandler: uploadToCloudinary,
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
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined,
                    color: Color(0xFF0F766E)),
                title: const Text("Gallery (Select Multiple)"),
                subtitle: const Text("Digitize your closet in bulk"),
                onTap: () async {
                  Navigator.pop(context);
                  final List<XFile> images =
                      await picker.pickMultiImage(imageQuality: 80);
                  if (images.isNotEmpty) {
                    showBatchUploadSheet(images);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined,
                    color: Color(0xFF0F766E)),
                title: const Text("Camera"),
                subtitle: const Text("Take a photo of an item"),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image =
                      await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
                  if (image != null) {
                    showBatchUploadSheet([image]);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: isLoadingClothes
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0F766E)))
          : Column(
              children: [
                _buildTripPlannerBanner(),
                if (wardrobeGaps.isNotEmpty) _buildSuggestions(),
                Expanded(
                  child: clothes.isEmpty
                      ? _buildEmptyState()
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.85,
                          ),
                          itemCount: clothes.length,
                          itemBuilder: (context, index) =>
                              _buildClothesCard(index),
                        ),
                ),
              ],
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE082)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tips_and_updates, color: Colors.amber.shade900, size: 18),
              const SizedBox(width: 8),
              Text(
                "Wardrobe Insights",
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade900),
              ),
              const Spacer(),
              if (isAnalyzing) const SizedBox(width: 16),
              if (isAnalyzing) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            ],
          ),
          const SizedBox(height: 8),

          // Stats section
          if (wardrobeStats != null) ...[
            Text("Total items: ${wardrobeStats!["total_items"]}", style: TextStyle(fontSize: 12, color: Colors.amber.shade900)),
            const SizedBox(height: 8),
            if ((wardrobeStats!["category_counts"] as Map).isNotEmpty) Wrap(
              spacing: 8,
              runSpacing: 6,
              children: (wardrobeStats!["percent_by_category"] as Map<String, dynamic>).entries.map((e) {
                return Chip(
                  backgroundColor: Colors.white,
                  label: Text('${e.key} (${e.value}%)', style: TextStyle(color: Colors.amber.shade900, fontSize: 12)),
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            if ((wardrobeStats!["dominant_colors"] as List).isNotEmpty) Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Dominant colors:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Row(
                  children: (wardrobeStats!["dominant_colors"] as List).map((c) {
                    // color value may be a string like 'Black' — show a colored dot when possible
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Row(
                        children: [
                          Container(width: 18, height: 18, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4))),
                          const SizedBox(width: 6),
                          Text('${c["value"]} (${c["percent"]}%)', style: TextStyle(fontSize: 12, color: Colors.amber.shade900)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ],

          // Insights / suggestions
          if (wardrobeGaps.isNotEmpty)
            ...wardrobeGaps.take(3).map((gap) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text("• ${gap['suggestion']}", style: TextStyle(fontSize: 12, color: Colors.amber.shade900)),
                ))
          else if (!isAnalyzing)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('No specific suggestions at the moment.', style: TextStyle(fontSize: 12, color: Colors.amber.shade900)),
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
          Icon(Icons.checkroom, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text("Your wardrobe is empty",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const Text("Digitize your closet to get started",
              style: TextStyle(color: Colors.grey, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildClothesCard(int index) {
    final item = clothes[index];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              item["path"]!,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              },
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
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
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
    );
  }
}

class _BatchUploadTray extends StatefulWidget {
  final List<_UploadItem> items;
  final String userEmail;
  final VoidCallback onComplete;
  final Future<String?> Function(String) uploadHandler;

  const _BatchUploadTray({
    required this.items,
    required this.userEmail,
    required this.onComplete,
    required this.uploadHandler,
  });

  @override
  State<_BatchUploadTray> createState() => _BatchUploadTrayState();
}

class _BatchUploadTrayState extends State<_BatchUploadTray> {
  int processedCount = 0;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _startParallelProcessing();
  }

  Future<void> _startParallelProcessing() async {
    List<Future<void>> uploadFutures = [];
    for (var item in widget.items) {
      uploadFutures.add(_processSingleItem(item));
    }
    await Future.wait(uploadFutures);
  }

  Future<void> _processSingleItem(_UploadItem item) async {
    if (!mounted) return;
    setState(() {
      item.status = "Uploading";
      item.progress = 0.2;
    });

    final url = await widget.uploadHandler(item.file.path);
    if (url == null) {
      if (mounted) setState(() => item.status = "Failed");
      return;
    }

    if (!mounted) return;
    setState(() {
      item.cloudinaryUrl = url;
      item.status = "Analyzing";
      item.progress = 0.6;
    });

    try {
      final tags = await AIService.detectClothing(item.file.path);
      if (mounted) {
        setState(() {
          item.detectedTags = tags;
          bool isClothing = tags["is_clothing"] == "true";
          item.status = isClothing ? "Done" : "Invalid";
          item.progress = 1.0;
          processedCount++;
        });
      }
    } catch (e) {
      if (mounted) setState(() => item.status = "Failed");
    }
  }

  void _openReview(int index) {
    final item = widget.items[index];
    if (item.status != "Done" && item.status != "Invalid") return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ItemReviewSheet(
        item: item,
        onUpdate: () => setState(() {}),
        onRemove: () {
          setState(() {
            widget.items.removeAt(index);
            processedCount--;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _saveAllToDatabase() async {
    setState(() => isSaving = true);
    int successCount = 0;

    for (var item in widget.items) {
      if (item.status == "Done" && item.detectedTags != null) {
        debugPrint('saveAllToDatabase item: status=${item.status}, detectedTags=${item.detectedTags}');
        final success = await ApiService.saveClothes(
          widget.userEmail,
          item.cloudinaryUrl!,
          item.detectedTags!["category"] ?? "Tops",
          item.detectedTags!["subcategory"] ?? "",
          item.detectedTags!["occasion"] ?? "Casual",
          item.detectedTags!["season"] ?? "All Season",
          item.detectedTags!["color"] ?? "",
          item.detectedTags!["stylist_note"] ?? "",
        );
        debugPrint('saveAllToDatabase result: success=$success');
        if (success) successCount++;
      }
    }

    if (mounted) {
      Navigator.pop(context);
      widget.onComplete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text("Successfully added $successCount items to your wardrobe!"),
          backgroundColor: const Color(0xFF0F766E),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        "$processedCount of ${widget.items.length} items ready for review",
                        style:
                            const TextStyle(fontSize: 13, color: Colors.grey)),
                  ],
                ),
                if (processedCount < widget.items.length)
                  const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFF0F766E))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                return GestureDetector(
                  onTap: () => _openReview(index),
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
                onPressed: (processedCount > 0 && !isSaving)
                    ? _saveAllToDatabase
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F766E),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  disabledBackgroundColor: Colors.grey.shade200,
                ),
                child: isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text("Add $processedCount Items to Wardrobe",
                        style: const TextStyle(
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
  final _UploadItem item;
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
              const Center(
                  child: Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 32)),
          ],
        ),
      ),
    );
  }
}

class _ItemReviewSheet extends StatelessWidget {
  final _UploadItem item;
  final VoidCallback onUpdate;
  final VoidCallback onRemove;

  const _ItemReviewSheet({
    required this.item,
    required this.onUpdate,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final tags = item.detectedTags!;
    final bool isInvalid = item.status == "Invalid";
    final String confidence = tags["confidence"] ?? "high";

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
                        borderRadius: BorderRadius.circular(10)))),
            const SizedBox(height: 24),
            if (isInvalid)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200)),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded,
                        color: Colors.orange),
                    const SizedBox(width: 12),
                    const Expanded(
                        child: Text(
                            "AI isn't sure this is clothing. Please verify details or remove.",
                            style:
                                TextStyle(fontSize: 12, color: Colors.orange))),
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
                      child: Image.file(File(item.file.path),
                          width: 120, height: 160, fit: BoxFit.cover),
                    ),
                    if (confidence == "low")
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20)),
                          child: const Text("Blurry Image",
                              style:
                                  TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Stylist's Note",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F766E),
                              fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(
                        tags["stylist_note"] ?? "",
                        style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF171717),
                            height: 1.5,
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text("Details",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _editRow("Category", tags["category"]!, (val) {
              tags["category"] = val;
              item.status = "Done";
              onUpdate();
            }),
            _editRow("Style", tags["subcategory"]!, (val) {
              tags["subcategory"] = val;
              onUpdate();
            }),
            _editRow("Color", tags["color"]!, (val) {
              tags["color"] = val;
              onUpdate();
            }),
            _editRow("Occasion", tags["occasion"]!, (val) {
              tags["occasion"] = val;
              onUpdate();
            }),
            _editRow("Season", tags["season"]!, (val) {
              tags["season"] = val;
              onUpdate();
            }),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: onRemove,
                    child: const Text("Remove Item",
                        style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF171717),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text("Keep Details",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _editRow(String label, String value, Function(String) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          TextField(
            controller: TextEditingController(text: value),
            onChanged: onChanged,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF5F5F5),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _UploadItem {
  final XFile file;
  String? cloudinaryUrl;
  Map<String, String>? detectedTags;
  String status; // "Pending", "Uploading", "Analyzing", "Done", "Invalid", "Failed"
  double progress;

  _UploadItem({
    required this.file,
    this.cloudinaryUrl,
    this.detectedTags,
    this.status = "Pending",
    this.progress = 0.0,
  });
}
