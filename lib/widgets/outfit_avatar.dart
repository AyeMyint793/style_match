import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class OutfitAvatar extends StatelessWidget {
  final List<dynamic> items;

  const OutfitAvatar({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEBEAE5)),
      ),
      child: _buildDynamicLayout(context),
    );
  }

  Widget _buildDynamicLayout(BuildContext context) {
    if (items.length == 1) {
      return _buildSingleItemLayout(items[0]);
    } else if (items.length == 2) {
      return _buildTwoItemLayout(items[0], items[1]);
    } else if (items.length == 3) {
      return _buildThreeItemLayout(items[0], items[1], items[2]);
    } else if (items.length == 4) {
      return _buildFourItemLayout(items[0], items[1], items[2], items[3]);
    } else {
      return _buildFivePlusItemLayout(items);
    }
  }

  Widget _buildSingleItemLayout(dynamic item) {
    return SizedBox(
      height: 220,
      child: _buildGarmentCard(item),
    );
  }

  Widget _buildTwoItemLayout(dynamic item1, dynamic item2) {
    return Row(
      children: [
        Expanded(child: SizedBox(height: 180, child: _buildGarmentCard(item1))),
        const SizedBox(width: 10),
        Expanded(child: SizedBox(height: 180, child: _buildGarmentCard(item2))),
      ],
    );
  }

  Widget _buildThreeItemLayout(dynamic item1, dynamic item2, dynamic item3) {
    return SizedBox(
      height: 290,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: SizedBox(
              height: double.infinity,
              child: _buildGarmentCard(item1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 5,
            child: Column(
              children: [
                Expanded(child: _buildGarmentCard(item2)),
                const SizedBox(height: 10),
                Expanded(child: _buildGarmentCard(item3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFourItemLayout(dynamic item1, dynamic item2, dynamic item3, dynamic item4) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: SizedBox(height: 155, child: _buildGarmentCard(item1))),
            const SizedBox(width: 10),
            Expanded(child: SizedBox(height: 155, child: _buildGarmentCard(item2))),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: SizedBox(height: 155, child: _buildGarmentCard(item3))),
            const SizedBox(width: 10),
            Expanded(child: SizedBox(height: 155, child: _buildGarmentCard(item4))),
          ],
        ),
      ],
    );
  }

  Widget _buildFivePlusItemLayout(List<dynamic> itemList) {
    List<List<dynamic>> rows = [];
    if (itemList.length == 5) {
      rows.add(itemList.sublist(0, 2));
      rows.add(itemList.sublist(2, 5));
    } else {
      for (int i = 0; i < itemList.length; i += 3) {
        rows.add(itemList.sublist(i, (i + 3 > itemList.length) ? itemList.length : i + 3));
      }
    }

    return Column(
      children: rows.asMap().entries.map((entry) {
        final rowIndex = entry.key;
        final rowItems = entry.value;
        final isTwoItems = rowItems.length == 2;
        final rowHeight = isTwoItems ? 150.0 : 130.0;

        return Padding(
          padding: EdgeInsets.only(bottom: rowIndex == rows.length - 1 ? 0 : 10),
          child: Row(
            children: rowItems.map((item) {
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: rowHeight,
                  child: _buildGarmentCard(item),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGarmentCard(dynamic item) {
    final String imgUrl = item["image_path"]?.toString() ?? "";
    final String subcat = item["subcategory"]?.toString() ?? "";
    final String category = item["category"]?.toString() ?? "Clothing";
    final String displayName = subcat.isNotEmpty ? subcat : category;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: CachedNetworkImage(
                imageUrl: imgUrl,
                fit: BoxFit.contain,
                placeholder: (context, url) => const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFCCCCCC)),
                  ),
                ),
                errorWidget: (context, url, error) => const Center(
                  child: Icon(Icons.broken_image_outlined, color: Color(0xFFBBBBBB), size: 24),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
            child: Text(
              displayName,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Color(0xFF555555),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
