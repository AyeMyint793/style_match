import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AIService {
  static Future<Map<String, dynamic>> detectClothing(String imagePath) async {
    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        debugPrint('AIService.detectClothing: GEMINI_API_KEY not set');
        return {"fallback": true, "confidence": "low"};
      }

      final model = GenerativeModel(
        model: 'gemini-3.5-flash',
        apiKey: apiKey,
      );

      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();

      String mimeType = "image/jpeg";
      if (imagePath.toLowerCase().endsWith('.png')) {
        mimeType = "image/png";
      }

      final prompt = TextPart("""Analyze this image for a professional digital fashion wardrobe.

Respond with ONLY this exact JSON format, no extra text:
{
  "is_clothing": true/false,
  "confidence": "high/low",
  "category": "...",
  "subcategory": "...",
  "occasion": "...",
  "season": "...",
  "color": "...",
  "stylist_note": "..."
}

Rules:
1. is_clothing: Set to true ONLY if the main subject is a clothing item, footwear, or fashion accessory. Set to false for rooms, pets, faces, or non-fashion objects.
2. confidence: Set to "low" if the image is dark, blurry, or the item is mostly obscured.
3. category: Choose ONE (Tops, Bottoms, Dress, Shoes, Outerwear, Accessories).
4. subcategory: Be specific (e.g. "Chelsea Boots", "Oversized Hoodie", "Slim Fit Jeans").
5. occasion: Casual, Work, Formal, Date Night, Party, Gym, Travel.
6. season: Summer, Winter, All Season.
7. color: Dominant primary color.
8. stylist_note: Write 1 professional sentence on why this item is versatile or stylish.

IMPORTANT: Return JSON only. No markdown, no backticks.""");

      final imagePart = DataPart(mimeType, imageBytes);

      String rawText = '';
      Map<String, dynamic>? jsonResult;

      // Limited retry attempts
      int attempts = 0;
      const int maxAttempts = 3;
      while (attempts < maxAttempts) {
        attempts += 1;
        try {
          final response = await model.generateContent([
            Content.multi([imagePart, prompt])
          ]);
          rawText = response.text ?? '';
          if (rawText.trim().isEmpty) {
            debugPrint('AIService.detectClothing: empty response on attempt $attempts');
            if (attempts < maxAttempts) {
              await Future.delayed(Duration(seconds: attempts * 2));
            }
            continue;
          }
 
          // Try to extract a JSON object from the raw text safely
          String candidate = rawText;
          // Remove common fence markers
          candidate = candidate.replaceAll('```json', '').replaceAll('```', '').trim();
 
          // Find the first { and last } to try to isolate JSON
          int first = candidate.indexOf('{');
          int last = candidate.lastIndexOf('}');
          if (first != -1 && last != -1 && last > first) {
            String sub = candidate.substring(first, last + 1);
            try {
              jsonResult = jsonDecode(sub);
              break; // parsed successfully
            } catch (pe) {
              debugPrint('AIService.detectClothing: JSON parse failed on attempt $attempts, trying to clean - error: $pe');
              if (attempts < maxAttempts) {
                await Future.delayed(Duration(seconds: attempts * 2));
              }
            }
          } else {
            debugPrint('AIService.detectClothing: no JSON braces found on attempt $attempts');
            if (attempts < maxAttempts) {
              await Future.delayed(Duration(seconds: attempts * 2));
            }
          }
        } catch (e) {
          debugPrint('AIService.detectClothing: model.generateContent failed on attempt $attempts: $e');
          if (attempts < maxAttempts) {
            final errStr = e.toString().toLowerCase();
            if (errStr.contains('quota') || errStr.contains('limit') || errStr.contains('429') || errStr.contains('exceeded')) {
              // Wait longer for free-tier rate limit to reset (typically 15s)
              debugPrint('AIService.detectClothing: Quota/Rate limit exceeded. Waiting 15s before retrying...');
              await Future.delayed(const Duration(seconds: 15));
            } else {
              await Future.delayed(Duration(seconds: attempts * 2));
            }
          }
        }
      }

      if (jsonResult == null) {
        debugPrint('AIService.detectClothing: all attempts failed, returning fallback marker');
        return {"fallback": true, "confidence": "low"};
      }

      // Robust boolean parsing
      bool isClothing = jsonResult["is_clothing"] == true ||
                        jsonResult["is_clothing"]?.toString().toLowerCase() == "true";

      // Normalize fields to strings where appropriate
      String confidence = jsonResult["confidence"]?.toString() ?? "low";
      String category = jsonResult["category"]?.toString() ?? "";
      String subcategory = jsonResult["subcategory"]?.toString() ?? "";
      String occasion = jsonResult["occasion"]?.toString() ?? "";
      String season = jsonResult["season"]?.toString() ?? "";
      String color = jsonResult["color"]?.toString() ?? "";
      String stylistNote = jsonResult["stylist_note"]?.toString() ?? "";

      // Return parsed result; do not inject optimistic defaults here — let the UI decide about saving
      final result = {
        "is_clothing": isClothing.toString(),
        "confidence": confidence,
        "category": category,
        "subcategory": subcategory,
        "occasion": occasion,
        "season": season,
        "color": color,
        "stylist_note": stylistNote,
      };

      return result;
    } catch (e) {
      debugPrint('AIService.detectClothing: unexpected error: $e');
      return {"fallback": true, "confidence": "low"};
    }
  }
}
