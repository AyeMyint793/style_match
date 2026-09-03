import json
import io
import os
import re
import time
from typing import List, Optional, Dict
from fastapi import HTTPException
import google.generativeai as genai
from dotenv import load_dotenv
import numpy as np
from PIL import Image, ImageOps

# Load Environment Variables
load_dotenv()
load_dotenv(dotenv_path="../.env")

# Configure Gemini
gemini_api_key = os.getenv("GEMINI_API_KEY")
if gemini_api_key:
    genai.configure(api_key=gemini_api_key)

class AIService:
    VISION_MODELS = [
        "gemini-3.1-flash-lite",
        "gemini-2.5-flash-lite",
        "gemini-flash-lite-latest",
        "gemini-3.7-flash",
        "gemini-flash-latest",
    ]

    @staticmethod
    def _prepare_vision_image_bytes(image_bytes: bytes, max_side: int = 1024) -> bytes:
        """Resize large uploads before Gemini detection; crop coordinates remain normalized."""
        try:
            img = ImageOps.exif_transpose(Image.open(io.BytesIO(image_bytes))).convert("RGB")
            if max(img.size) <= max_side:
                return image_bytes
            img.thumbnail((max_side, max_side), Image.Resampling.LANCZOS)
            output = io.BytesIO()
            img.save(output, format="JPEG", quality=85, optimize=True)
            return output.getvalue()
        except Exception:
            return image_bytes

    @staticmethod
    def _background_palette(img: Image.Image) -> np.ndarray:
        """Build a background color palette from corners and outer border regions."""
        arr = np.array(img.convert("RGB")).astype(float)
        h, w, _ = arr.shape
        # Sample four corners (which are almost always background surface in flat-lays)
        cw = max(4, int(w * 0.08))
        ch = max(4, int(h * 0.08))
        corner_samples = np.vstack([
            arr[:ch, :cw].reshape(-1, 3),
            arr[:ch, w - cw:].reshape(-1, 3),
            arr[h - ch:, :cw].reshape(-1, 3),
            arr[h - ch:, w - cw:].reshape(-1, 3),
        ])
        
        # Also sample top and side borders (top 5%, left 5%, right 5%)
        top_h = max(2, int(h * 0.05))
        side_w = max(2, int(w * 0.05))
        border_samples = np.vstack([
            arr[:top_h, :].reshape(-1, 3),
            arr[:, :side_w].reshape(-1, 3),
            arr[:, w - side_w:].reshape(-1, 3),
        ])
        
        samples = np.vstack([corner_samples, border_samples])
        if len(samples) == 0:
            return np.empty((0, 3))

        # Quantize to discover repeated background colors (e.g. bedsheet base and floral prints)
        quantized = (samples // 24).astype(int)
        values, counts = np.unique(quantized, axis=0, return_counts=True)
        top_indices = np.argsort(counts)[-8:]
        palette = (values[top_indices].astype(float) * 24.0) + 12.0
        median = np.median(corner_samples, axis=0, keepdims=True) if len(corner_samples) > 0 else np.median(samples, axis=0, keepdims=True)
        return np.vstack([palette, median])

    @staticmethod
    def _box_to_pixels(box_2d: list, width: int, height: int):
        if not isinstance(box_2d, list) or len(box_2d) != 4:
            return None
        try:
            y1, x1, y2, x2 = [float(v) for v in box_2d]
        except (TypeError, ValueError):
            return None

        ymin, ymax = min(y1, y2), max(y1, y2)
        xmin, xmax = min(x1, x2), max(x1, x2)
        max_val = max(ymin, xmin, ymax, xmax)
        if max_val <= 1.0:
            ymin, xmin, ymax, xmax = ymin * height, xmin * width, ymax * height, xmax * width
        elif max_val <= 1000.0:
            ymin, xmin, ymax, xmax = ymin / 1000.0 * height, xmin / 1000.0 * width, ymax / 1000.0 * height, xmax / 1000.0 * width

        left = max(0, min(width - 1, int(round(xmin))))
        top = max(0, min(height - 1, int(round(ymin))))
        right = max(0, min(width, int(round(xmax))))
        bottom = max(0, min(height, int(round(ymax))))
        if right <= left or bottom <= top:
            return None
        return left, top, right, bottom

    @staticmethod
    def _normalize_box_1000(box_px, width: int, height: int) -> list:
        left, top, right, bottom = box_px
        return [
            int(round(top / height * 1000)),
            int(round(left / width * 1000)),
            int(round(bottom / height * 1000)),
            int(round(right / width * 1000)),
        ]

    @staticmethod
    def _background_like_ratio(crop: Image.Image, palette: np.ndarray) -> float:
        if palette.size == 0:
            return 0.0
        arr = np.array(crop.convert("RGB")).astype(float)
        if arr.size == 0:
            return 1.0
        flat = arr.reshape(-1, 3)
        if len(flat) > 12000:
            flat = flat[np.linspace(0, len(flat) - 1, 12000).astype(int)]
        distances = np.sqrt(np.sum((flat[:, None, :] - palette[None, :, :]) ** 2, axis=2))
        return float(np.mean(np.min(distances, axis=1) < 44.0))

    @staticmethod
    def _canonical_category(category: str, subcategory: str) -> str:
        cat = (category or "").strip()
        subcat = (subcategory or "").lower()
        if any(k in subcat for k in ["jean", "pant", "trouser", "short", "skirt", "legging", "jogger", "sweatpant"]):
            return "Bottoms"
        if any(k in subcat for k in ["shoe", "boot", "sneaker", "heel", "sandal", "loafer", "flat", "slide"]):
            return "Shoes"
        if any(k in subcat for k in ["dress", "gown", "jumpsuit", "romper"]):
            return "Dress"
        if any(k in subcat for k in ["jacket", "coat", "blazer", "cardigan", "parka", "vest", "overshirt"]):
            return "Outerwear"
        if any(k in subcat for k in ["belt", "hat", "cap", "bag", "scarf", "sunglasses", "tie", "watch", "necklace"]):
            return "Accessories"
        if any(k in subcat for k in ["top", "tee", "t-shirt", "shirt", "blouse", "camisole", "tank", "sweater", "hoodie", "crop"]):
            return "Tops"
        return cat if cat in ["Tops", "Bottoms", "Dress", "Shoes", "Outerwear", "Accessories"] else "Tops"

    @staticmethod
    def _validate_detected_item(item: dict, idx: int, img: Image.Image, bg_palette: np.ndarray):
        subcategory = str(item.get("subcategory", "")).strip()
        category = AIService._canonical_category(str(item.get("category", "")), subcategory)
        subcat_l = subcategory.lower()
        box_px = AIService._box_to_pixels(item.get("box_2d", [0, 0, 1000, 1000]), img.width, img.height)
        if box_px is None:
            print(f"[AIService] Filtered out item {idx}: invalid bounding box")
            return None

        left, top, right, bottom = box_px
        box_w = right - left
        box_h = bottom - top
        area_pct = (box_w * box_h) / float(img.width * img.height)
        aspect = box_w / float(max(box_h, 1))

        non_clothing_keywords = [
            "bed", "sheet", "bedsheet", "pillow", "blanket", "comforter", "duvet",
            "mattress", "carpet", "floor", "wall", "curtain", "furniture",
            "table", "quilt", "cushion", "headboard", "towel", "cover",
            "linen", "bolster", "pillowcase", "rug", "nightstand", "fabric background"
        ]
        clothing_keywords = [
            "jean", "pant", "trouser", "short", "skirt", "legging", "shirt", "tee",
            "top", "camisole", "tank", "blouse", "sweater", "hoodie", "dress",
            "jacket", "coat", "blazer", "shoe", "boot", "sneaker", "sandal", "bag",
            "belt", "scarf", "hat", "cap", "crop"
        ]
        if any(kw in subcat_l for kw in non_clothing_keywords) and not any(kw in subcat_l for kw in clothing_keywords):
            print(f"[AIService] Filtered out non-clothing background object: {subcategory}")
            return None

        is_confirmed_garment = any(kw in subcat_l for kw in clothing_keywords)

        if box_w < img.width * 0.035 or box_h < img.height * 0.035 or area_pct < 0.005:
            print(f"[AIService] Filtered out tiny item {idx}: box={item.get('box_2d')}")
            return None
        if area_pct > 0.92:
            print(f"[AIService] Filtered out whole-frame background/item mix: box={item.get('box_2d')}")
            return None
        if category == "Bottoms" and (box_h < img.height * 0.14 or box_w < img.width * 0.14 or aspect > 2.5 or aspect < 0.10):
            print(f"[AIService] Filtered out implausible bottoms shape: {subcategory} box={item.get('box_2d')}")
            return None
        if category == "Tops" and (box_h < img.height * 0.05 or box_w < img.width * 0.05):
            print(f"[AIService] Filtered out implausible tops shape: {subcategory} box={item.get('box_2d')}")
            return None

        crop = img.crop(box_px)
        bg_ratio = AIService._background_like_ratio(crop, bg_palette)
        # Background ratio filter: only reject if the crop is overwhelmingly background
        # and not a confirmed anatomical garment.
        if bg_ratio > 0.92 and not is_confirmed_garment:
            print(f"[AIService] Filtered out background-like crop ({bg_ratio:.2f}): {subcategory}")
            return None
        if bg_ratio > 0.85 and str(item.get("confidence", "")).lower() == "low" and not is_confirmed_garment:
            print(f"[AIService] Filtered out low-confidence background-heavy crop ({bg_ratio:.2f}): {subcategory}")
            return None

        item["category"] = category
        item["box_2d"] = AIService._normalize_box_1000(box_px, img.width, img.height)
        return item

    @staticmethod
    def _box_iou(a: list, b: list) -> float:
        ay1, ax1, ay2, ax2 = a
        by1, bx1, by2, bx2 = b
        inter_y1, inter_x1 = max(ay1, by1), max(ax1, bx1)
        inter_y2, inter_x2 = min(ay2, by2), min(ax2, bx2)
        if inter_y2 <= inter_y1 or inter_x2 <= inter_x1:
            return 0.0
        inter = (inter_y2 - inter_y1) * (inter_x2 - inter_x1)
        area_a = (ay2 - ay1) * (ax2 - ax1)
        area_b = (by2 - by1) * (bx2 - bx1)
        return inter / float(max(area_a + area_b - inter, 1))

    @staticmethod
    def _dedupe_overlapping_items(items: list) -> list:
        confidence_rank = {"high": 3, "medium": 2, "low": 1}
        ordered = sorted(
            items,
            key=lambda it: (
                confidence_rank.get(str(it.get("confidence", "")).lower(), 1),
                -((it["box_2d"][2] - it["box_2d"][0]) * (it["box_2d"][3] - it["box_2d"][1])),
            ),
            reverse=True,
        )
        kept = []
        for item in ordered:
            if all(AIService._box_iou(item["box_2d"], existing["box_2d"]) < 0.42 for existing in kept):
                kept.append(item)
            else:
                print(f"[AIService] Filtered out overlapping duplicate crop: {item.get('subcategory')}")
        return kept

    @staticmethod
    def call_gemini(prompt: str) -> str:
        if not gemini_api_key:
            raise HTTPException(
                status_code=500,
                detail="GEMINI_API_KEY not configured on server"
            )

        last_err = None
        for model_name in AIService.VISION_MODELS:
            try:
                model = genai.GenerativeModel(model_name)
                response = model.generate_content(prompt, request_options={"timeout": 30})
                return response.text
            except Exception as e:
                last_err = e
                if "429" in str(e) or "quota" in str(e).lower():
                    time.sleep(2.0)
                continue
        raise HTTPException(
            status_code=500,
            detail=f"Gemini API Error: {str(last_err)}"
        )

    @staticmethod
    def _verify_and_enrich_outfit_items(outfit_items: list, db_items_json: str) -> list:
        """Validate returned items against real database records and ensure exact Cloudinary image paths."""
        try:
            db_items = json.loads(db_items_json) if isinstance(db_items_json, str) else db_items_json
            db_map = {int(x["id"]): x for x in db_items if "id" in x and x["id"] is not None}
        except Exception:
            return outfit_items

        verified_items = []
        for it in outfit_items:
            if not isinstance(it, dict):
                continue
            raw_id = it.get("id")
            try:
                item_id = int(raw_id) if raw_id is not None else None
            except (ValueError, TypeError):
                item_id = None

            if item_id is not None and item_id in db_map:
                real_db_item = db_map[item_id]
                verified_items.append({
                    "id": real_db_item["id"],
                    "category": real_db_item.get("category", it.get("category", "Tops")),
                    "subcategory": real_db_item.get("subcategory", it.get("subcategory", "Garment")),
                    "color": real_db_item.get("color", it.get("color", "Mixed")),
                    "image_path": real_db_item.get("image_path", it.get("image_path", ""))
                })
            else:
                # If model hallucinates an ID, try matching by subcategory/category from wardrobe
                cat = it.get("category")
                subcat = str(it.get("subcategory", "")).lower()
                matched = None
                for db_id, db_item in db_map.items():
                    if db_item.get("category") == cat and (subcat in str(db_item.get("subcategory", "")).lower()):
                        matched = db_item
                        break
                if matched and matched["id"] not in [v["id"] for v in verified_items]:
                    verified_items.append({
                        "id": matched["id"],
                        "category": matched.get("category", "Tops"),
                        "subcategory": matched.get("subcategory", "Garment"),
                        "color": matched.get("color", "Mixed"),
                        "image_path": matched.get("image_path", "")
                    })
                elif it.get("image_path"):
                    verified_items.append(it)

        return verified_items

    @staticmethod
    def clean_json_response(text: str) -> str:
        cleaned = text.strip()
        if "```" in cleaned:
            match = re.search(r"```(?:json)?\s*([\s\S]*?)\s*```", cleaned)
            if match:
                cleaned = match.group(1).strip()
        if not (cleaned.startswith("{") or cleaned.startswith("[")):
            start_brace = cleaned.find("{")
            start_bracket = cleaned.find("[")
            if start_brace != -1 and (start_bracket == -1 or start_brace < start_bracket):
                end_brace = cleaned.rfind("}")
                if end_brace != -1:
                    cleaned = cleaned[start_brace:end_brace+1]
            elif start_bracket != -1:
                end_bracket = cleaned.rfind("]")
                if end_bracket != -1:
                    cleaned = cleaned[start_bracket:end_bracket+1]
        return cleaned.strip()

    @staticmethod
    def generate_outfit(user_height, user_size, pref_fit, pref_style, occasion, season, weather, previous_outfits, items_json, style_item_ids=[]):
        style_items_prompt = ""
        if style_item_ids:
            style_items_prompt = f"\n        CRITICAL Styling Override: The user has manually selected these specific items (by ID) to style around: {style_item_ids}.\n        You MUST build every recommended outfit around these selected items. If they selected a single item, recommend the matching pieces (tops, bottoms, shoes) from their wardrobe to complete a full look. If they selected multiple items (e.g., a top and a bottom), pair them together and choose the matching shoes/outerwear/accessories."

        prompt = f"""
        You are a creative, professional personal fashion stylist specializing in modern, high-end, Pinterest-style aesthetics.
        Your goal is to propose stylish, wearable, yet highly creative outfit combinations using ONLY the user's wardrobe.
        {style_items_prompt}

        Style Philosophy:
        1. Color & Pattern matching: Think beyond safe black/white. Use tonal color matching, complementary color theory, sandwich rules (matching shoes/accessories to top color), and tasteful pattern mixing.
        2. Creative Styling: Show different ways to style the same clothing item (e.g., layering a turtleneck under a button-up shirt, or dressing down a formal blazer with casual bottoms).
        3. Bold yet Wearable combinations: Feel free to suggest unusual or unexpected combinations if they work (e.g., contrasting casual and tailored items). If a combination is unusual, explain briefly in the rationale why it works (e.g. "pairing the casual graphic tee with a structured blazer creates a balanced high-low aesthetic").
        4. Diversity: Actively avoid making identical recommendations or repeating safe, basic combinations. Highlight different vibes (minimalist, street-style, smart casual, preppy, etc.) to help the user discover new styles.

        Smart Stylist Rules:
        - Requirement 1 (Anti-Repetition): Avoid repeating the exact combinations of items that have already been recommended in this session: {previous_outfits}. A combination is considered repeated if it contains the exact same core items. You must prioritize unused combinations while there are still reasonable options available.
        - Requirement 2 (Intelligent Fallbacks): If the user's wardrobe lacks suitable pieces to make a fully complete outfit for this weather/occasion (e.g., they have no pants/skirts, or they lack heavy outerwear for freezing cold weather), do NOT return success: false. Instead, provide the best possible partial outfit recommendation from their available wardrobe (e.g., style the top and pants even if a winter coat is missing). In this fallback case, set "is_fallback": true and provide a clear, helpful "missing_pieces_explanation" explaining exactly what pieces are missing and how they should complete it (e.g., 'This is a partial winter look. We styled your wool sweater and pants, but you are missing a warm winter coat/outerwear to complete this freezing outfit'). If it is a complete, successful outfit, set "is_fallback": false and "missing_pieces_explanation": null.
        - Requirement 3 (Styling Variety): Allow different styling ideas using the same clothing combination. If you are styling an outfit combination containing items that were previously used, avoid repetition by proposing a different styling concept, different layering, accessories, footwear, or tucking details. Every outfit returned MUST include a distinct "style_concept" (e.g., 'Smart Office Tucked', 'Casual Layered Streetwear', 'Tonal Casual') and a brief "styling_tip" (e.g., 'Roll up the sleeves of the shirt and wear it open over a white tee. Half-tuck the front').

        User Profile:
        - Height: {user_height or "Unknown"} cm
        - Size: {user_size or "M"}
        - Fit preference: {pref_fit}
        - Style preference: {pref_style}

        Context:
        - Occasion: {occasion}
        - Season: {season}
        - Weather: {weather}

        Here is the user's personal wardrobe (in JSON format):
        {items_json}

        Please generate up to 3 distinct outfit combinations that fit the occasion, season, weather, and style preferences.

        For each outfit:
        1. Select appropriate items from the wardrobe. An outfit must contain a Top and a Bottom, OR a Single Dress, and optionally Shoes, Outerwear, and Accessories. Do NOT mix categories.
        2. Provide a 1-2 sentence fashion rationale explaining why the colors, fit, and items work together, how it fits the weather/activities/occasion, and styling tips (e.g., tucking, layering, or accessories). If the look is unconventional, explain the fashion reasoning.

        Respond with ONLY a valid JSON object in this exact format (no markdown, no backticks, no other text):
        {{
          "success": true,
          "outfits": [
            {{
              "outfit_number": 1,
              "style_concept": "Relaxed Casual",
              "styling_tip": "Roll up the sleeves and leave the shirt untucked.",
              "description": "Fashion styling rationale...",
              "is_fallback": false,
              "missing_pieces_explanation": null,
              "items": [
                {{
                  "id": 12,
                  "category": "Tops",
                  "subcategory": "Shirt",
                  "color": "Blue",
                  "image_path": "https://..."
                }}
              ]
            }}
          ]
        }}

        If the wardrobe has zero items (or less than 2 items total and no dress), return:
        {{
          "success": false,
          "message": "Add at least 2 items (e.g. Tops and Bottoms) to your wardrobe to generate outfits!"
        }}
        """
        response_text = AIService.call_gemini(prompt)
        cleaned = AIService.clean_json_response(response_text)
        data = json.loads(cleaned)
        
        # Anti-hallucination post processing
        if isinstance(data, dict) and data.get("outfits") and isinstance(data["outfits"], list):
            valid_outfits = []
            for outfit in data["outfits"]:
                if isinstance(outfit, dict) and "items" in outfit:
                    enriched = AIService._verify_and_enrich_outfit_items(outfit["items"], items_json)
                    if len(enriched) > 0:
                        outfit["items"] = enriched
                        valid_outfits.append(outfit)
            data["outfits"] = valid_outfits
            if len(valid_outfits) == 0:
                data["success"] = False
                data["message"] = "Could not find a valid combination in your wardrobe for this occasion."

        return data

    @staticmethod
    def complete_outfit(selected_item, items_json):
        prompt = f"""
        You are a professional fashion stylist. A client wants to complete a stylish outfit starting with a specific item from their wardrobe.

        Starting Item:
        {json.dumps(selected_item)}

        Here is the user's complete wardrobe (in JSON format):
        {items_json}

        Recommend matching items from the user's wardrobe to complete the outfit (e.g. if the starting item is a top, find matching bottoms, shoes, etc.).
        Provide a 1-2 sentence explanation of the completed look.

        Respond with ONLY a valid JSON object in this exact format (no markdown, no backticks, no other text):
        {{
          "success": true,
          "outfit": {{
            "description": "Fashion rationale...",
            "items": [
              {{
                "id": 12,
                "category": "Tops",
                "subcategory": "Shirt",
                "color": "Blue",
                "image_path": "https://..."
              }}
            ]
          }}
        }}
        """
        response_text = AIService.call_gemini(prompt)
        cleaned = AIService.clean_json_response(response_text)
        data = json.loads(cleaned)

        if isinstance(data, dict) and data.get("outfit") and isinstance(data["outfit"], dict):
            outfit = data["outfit"]
            if "items" in outfit and isinstance(outfit["items"], list):
                outfit["items"] = AIService._verify_and_enrich_outfit_items(outfit["items"], items_json)

        return data

    @staticmethod
    def analyze_wardrobe(items_json):
        prompt = f"""
        You are a fashion closet organizer and analyst.
        Here is the user's current wardrobe:
        {items_json}

        Identify styling gaps in this wardrobe (e.g. missing basic colors, missing outerwear, mismatch in top-to-bottom ratio, or missing categories).
        Provide 2 brief, actionable suggestions for what the user should add to their wardrobe next to maximize combinations.

        Respond with ONLY a valid JSON object in this exact format (no markdown, no backticks, no other text):
        {{
          "success": true,
          "gaps": [
            {{
              "suggestion": "Detailed suggestion..."
            }}
          ]
        }}
        """
        response_text = AIService.call_gemini(prompt)
        cleaned = AIService.clean_json_response(response_text)
        return json.loads(cleaned)

    @staticmethod
    def trip_packing(destination, days, trip_type, activities, weather, items_json, start_date=None, end_date=None):
        date_prompt = ""
        if start_date and end_date:
            date_prompt = f"- Trip Dates: From {start_date} to {end_date}\n"

        prompt = f"""
        You are a creative, professional personal fashion stylist and expert travel packing assistant specializing in modern, high-end, Pinterest-style aesthetics.
        Your goal is to create a personalized day-by-day outfit plan for a user's trip using ONLY their wardrobe items.

        The user is planning a trip with the following details:
        - Destination: {destination}
        - Duration: {days} days
        {date_prompt}- Trip Type: {trip_type}
        - Planned Activities: {activities}
        - Weather Forecast: {weather}

        Here is the user's wardrobe (in JSON format):
        {items_json}

        Capsule Styling & Smart Reuse Rules:
        1. Create a day-by-day itinerary of outfits. Each day should have a specific look tailored to the activities and weather of that day.
        2. SMART REUSE: You MUST intelligently reuse items across different days. Do not recommend the exact same complete outfit twice, but do reuse individual items (like the same pair of jeans, jacket, or sneakers) across multiple days to keep the packing list compact. The client should feel like they have a smart, cohesive capsule wardrobe.
        3. Match colors and layering details creatively. Provide styling tips for each day (e.g. French tucking, rolling sleeves, layering).
        4. Day-by-day activity matching: For each day, describe what the look is for (e.g. travel day, sightseeing, dinner, beach, active, etc.) matching the user's activities.

        Respond with ONLY a valid JSON object in this exact format (no markdown, no backticks, no other text):
        {{
          "success": true,
          "destination": "{destination}",
          "days_count": {days},
          "itinerary": [
            {{
              "day_number": 1,
              "date": "YYYY-MM-DD or Day 1 details",
              "activity": "Activity for this day (e.g. Travel & Casual Dinner)",
              "weather": "Weather condition for this day (e.g. Mild and breezy)",
              "style_concept": "Style theme/vibe (e.g. Casual Chic, Edgy Streetwear)",
              "styling_tip": "Specific stylist instructions on tucking, rolling, layering, or accessories.",
              "outfit": {{
                "description": "Fashion rationale for this combination.",
                "items": [
                  {{
                    "id": 1,
                    "category": "Tops",
                    "subcategory": "Shirt",
                    "color": "White",
                    "image_path": "https://..."
                  }}
                ]
              }}
            }}
          ],
          "missing_items": [
            "Heavy winter coat (since forecast is cold but no coats in wardrobe)"
          ],
          "packing_tip": "Roll light knits and use packing cubes to categorize items."
        }}
        """
        response_text = AIService.call_gemini(prompt)
        cleaned = AIService.clean_json_response(response_text)
        data = json.loads(cleaned)

        if isinstance(data, dict) and data.get("itinerary") and isinstance(data["itinerary"], list):
            for day in data["itinerary"]:
                if isinstance(day, dict) and "outfit" in day and isinstance(day["outfit"], dict):
                    if "items" in day["outfit"] and isinstance(day["outfit"]["items"], list):
                        day["outfit"]["items"] = AIService._verify_and_enrich_outfit_items(
                            day["outfit"]["items"], items_json
                        )

        return data

    @staticmethod
    def regenerate_day_outfit(destination, day_number, date, activity, weather, trip_type, previous_outfit_item_ids, other_days_outfits, items_json):
        prompt = f"""
        You are a creative, professional personal fashion stylist specializing in modern, high-end, Pinterest-style aesthetics.
        The user wants to replace/regenerate the outfit for Day {day_number} of their trip to {destination}.

        Day Details:
        - Date: {date}
        - Activity: {activity}
        - Weather: {weather}
        - Trip Type: {trip_type}

        Previously generated outfit item IDs for this day (DO NOT repeat this exact combination): {previous_outfit_item_ids}
        
        Currently Packed Items (used on other days of the trip):
        These items are already in the user's suitcase. To minimize packing, you should STRONGLY prioritize styling this day's look using items from this list if appropriate:
        {other_days_outfits}

        Here is the user's complete wardrobe (in JSON format):
        {items_json}

        Styling Rules:
        1. Select appropriate items from the wardrobe to complete a full outfit for this day (Tops + Bottoms OR a Single Dress, plus optional Outerwear/Shoes/Accessories).
        2. Smart Capsule Reuse: Prioritize items that are already packed (i.e. present in the currently packed items list) to avoid making the user pack new items. Only choose new wardrobe items if they are necessary for the specific weather/activities or if the packed items are completely unsuitable.
        3. Do not recommend the exact same combination of items as {previous_outfit_item_ids}.
        4. Give a creative style concept, styling tip, and explanation.

        Respond with ONLY a valid JSON object in this exact format (no markdown, no backticks, no other text):
        {{
          "success": true,
          "style_concept": "Style theme/vibe (e.g. Edgy Casual)",
          "styling_tip": "Specific styling details (e.g. French tuck, roll sleeves)",
          "description": "Stylist rationale for the new outfit combination.",
          "outfit": {{
            "items": [
              {{
                "id": 1,
                "category": "Tops",
                "subcategory": "Shirt",
                "color": "White",
                "image_path": "https://..."
              }}
            ]
          }}
        }}
        """
        response_text = AIService.call_gemini(prompt)
        cleaned = AIService.clean_json_response(response_text)
        data = json.loads(cleaned)

        if isinstance(data, dict) and data.get("outfit") and isinstance(data["outfit"], dict):
            outfit = data["outfit"]
            if "items" in outfit and isinstance(outfit["items"], list):
                outfit["items"] = AIService._verify_and_enrich_outfit_items(outfit["items"], items_json)

        return data

    @staticmethod
    def detect_clothing(image_bytes: bytes) -> dict:
        prompt = """Analyze this image for a professional digital fashion wardrobe.
        Respond with ONLY this exact JSON format, no extra text:
        {
          "is_clothing": true,
          "confidence": "high",
          "category": "Tops",
          "subcategory": "Oversized Hoodie",
          "occasion": "Casual",
          "season": "Winter",
          "color": "Grey",
          "stylist_note": "A cozy, minimalist statement piece."
        }

        Rules:
        1. is_clothing: Return true if the main subject is a clothing item, footwear, or fashion accessory. Return false for rooms, pets, faces, or non-fashion objects.
        2. confidence: Set to "low" if the image is dark, blurry, or the item is mostly obscured. Otherwise "high".
        3. category: Choose exactly one from (Tops, Bottoms, Dress, Shoes, Outerwear, Accessories).
        4. subcategory: Be descriptive but brief (e.g. "Chelsea Boots", "Oversized Hoodie", "Slim Fit Jeans").
        5. occasion: Casual, Work, Formal, Date Night, Party, Gym, Travel.
        6. season: Summer, Winter, All Season.
        7. color: Dominant primary color of the item (e.g. Blue, Black, White, Red).
        8. stylist_note: Write 1 professional sentence on why this item is versatile or stylish.
        """
        if not gemini_api_key:
            raise HTTPException(
                status_code=500,
                detail="GEMINI_API_KEY not configured on server"
            )

        last_err = None
        for model_name in AIService.VISION_MODELS:
            try:
                model = genai.GenerativeModel(model_name)
                # Call generate_content with image dict and prompt
                vision_bytes = AIService._prepare_vision_image_bytes(image_bytes)
                response = model.generate_content([
                    {"mime_type": "image/jpeg", "data": vision_bytes},
                    prompt
                ], request_options={"timeout": 30})
                cleaned = AIService.clean_json_response(response.text)
                return json.loads(cleaned)
            except Exception as e:
                last_err = e
                continue
        raise HTTPException(
            status_code=500,
            detail=f"Gemini API Error: {str(last_err)}"
        )

    @staticmethod
    def detect_multiple_clothes(image_bytes: bytes, mime_type: str = "image/jpeg") -> dict:
        prompt = """You are a world-class AI fashion vision expert. Your objective is to extract, segment, and identify individual authentic clothing items from real-world smartphone photos (clothes on beds, floors, carpets, hangers, flat-lays).

STEP-BY-STEP VISUAL REASONING:
1. IDENTIFY AND EXCLUDE THE BACKGROUND SURFACE:
   - Identify the background surface (e.g. bedsheet, blanket, duvet, mattress, carpet, floor, table).
   - Note its color and pattern (e.g. turquoise/blue sheet with yellow floral print, beige linen, wooden floor).
   - STRICT RULE: Any region that is part of the background surface is BACKGROUND, NEVER A CLOTHING ITEM.
   - Do NOT classify floral patterns, printed flowers, leaves, stripes, or fabric folds of the bedsheet as a "Floral Top", "Floral Blouse", "Printed Shirt", "Dress", or "Skirt"!
   - A real garment is an authentic, separate physical item laid on top of the sheet with clearly defined boundaries, seams, collars, straps, necklines, or waistband.
   - The floral sheet visible around or between the garments is background. DO NOT output the background surface as a clothing item.

2. IDENTIFY EACH DISTINCT WEARABLE GARMENT:
   - Wearable garments have anatomical clothing structure: waistband, fly/zipper, pockets, cuffs, collars, necklines, sleeves, pant legs, hems, shoe soles.
   - Only output a region if it is a complete physical item someone can pick up and wear.
   - If a region is only visible through a gap between clothing items or around the edges of the bed, it is background and must be excluded.
   - For Bottoms (Jeans/Pants/Trousers/Shorts/Skirts):
     * Look for actual denim/trousers. Note its true color (e.g. washed black, dark grey, charcoal, blue).
     * Bounding box [ymin, xmin, ymax, xmax]: ymin MUST start at the top waistband seam. ymax must end at the bottom leg hems. DO NOT include shirts or tops above the waistband. Category: "Bottoms".
   - For Tops (T-shirts/Shirts/Crop Tops/Camisoles/Sweaters):
     * Look for the top/shirt. Note its true color (e.g. grey, white, black).
     * Bounding box [ymin, xmin, ymax, xmax]: strictly covers the top and straps/sleeves, ending at its bottom hem. DO NOT include the pants below it. Category: "Tops".
     * Crop tops, camisoles, bralettes, and strappy tops may be small and placed above jeans. ALWAYS inspect the area directly above the waistband and the top 35% of the photo for a grey/black/white top with straps, neckline, cups, or hem.
     * If you see jeans plus a small top above them, output BOTH items. Do not return only the jeans.
   - For Outerwear (Jackets/Blazers/Coats): Category: "Outerwear".
   - For Shoes: Category: "Shoes".
   - For Accessories: Category: "Accessories".

3. ACCURATE CATEGORIZATION & BOUNDARIES:
   - If multiple garments are present (e.g., a grey crop top and black wide-leg jeans), output EACH garment as its own separate item.
   - Do NOT label black/dark jeans as a "Graphic Tee" or "Tops".
   - Do NOT label a blue/turquoise floral bedsheet as "Floral Blouse", "Straight Leg Jeans", or "Bottoms".
   - Bounding boxes must strictly enclose the physical garment without bleeding into the surrounding bedsheet.

OUTPUT SCHEMA (JSON ONLY):
{
  "success": true,
  "items_count": <int>,
  "items": [
    {
      "box_2d": [ymin, xmin, ymax, xmax],
      "category": "Tops" | "Bottoms" | "Dress" | "Shoes" | "Outerwear" | "Accessories",
      "subcategory": "<precise specific descriptive name, e.g. Washed Black Wide-Leg Jeans, Heather Grey Camisole Crop Top>",
      "color": "<true dominant color of the garment, e.g. Black, Grey, Blue, White>",
      "pattern": "Solid" | "Graphic" | "Striped" | "Plaid" | "Floral" | "Polka Dot" | "Ribbed" | "Distressed" | "Printed" | "Knit",
      "confidence": "high" | "medium" | "low",
      "occasion": "Casual" | "Work" | "Formal" | "Date Night" | "Party" | "Gym" | "Travel",
      "season": "Summer" | "Winter" | "All Season",
      "stylist_note": "<1 concise sentence on styling this piece>"
    }
  ]
}

If no wearable clothing items are present in the photo:
{
  "success": false,
  "items_count": 0,
  "items": [],
  "message": "No clothing items detected in this image."
}
"""
        if not gemini_api_key:
            raise HTTPException(
                status_code=500,
                detail="GEMINI_API_KEY not configured on server"
            )

        source_img = ImageOps.exif_transpose(Image.open(io.BytesIO(image_bytes))).convert("RGB")
        bg_palette = AIService._background_palette(source_img)
        last_err = None
        for model_name in AIService.VISION_MODELS:
            try:
                print(f"[AIService] Calling Gemini Vision model: {model_name}...")
                model = genai.GenerativeModel(
                    model_name,
                    generation_config={"response_mime_type": "application/json"}
                )
                vision_bytes = AIService._prepare_vision_image_bytes(image_bytes)
                response = model.generate_content([
                    {"mime_type": "image/jpeg", "data": vision_bytes},
                    prompt
                ], request_options={"timeout": 30})
                cleaned = AIService.clean_json_response(response.text)
                parsed = json.loads(cleaned)
                
                print(f"[AIService] Raw Gemini Response from {model_name}:")
                print(cleaned[:300] + ("..." if len(cleaned) > 300 else ""))

                if isinstance(parsed, dict) and parsed.get("items") and isinstance(parsed["items"], list):
                    raw_items = parsed["items"]
                    valid_items = []
                    for idx, it in enumerate(raw_items):
                        if not isinstance(it, dict):
                            continue
                        validated = AIService._validate_detected_item(it, idx, source_img, bg_palette)
                        if validated is None:
                            continue
                        if "pattern" not in it or not it["pattern"]:
                            it["pattern"] = "Solid"
                        if "confidence" not in it or not it["confidence"]:
                            it["confidence"] = "high"
                        valid_items.append(validated)
                    
                    if len(valid_items) > 1:
                        valid_items = AIService._dedupe_overlapping_items(valid_items)

                    parsed["success"] = len(valid_items) > 0
                    parsed["items"] = valid_items
                    parsed["items_count"] = len(valid_items)
                    
                    print(f"[AIService] Successfully detected {len(valid_items)} distinct clothing item(s).")
                    for i, it in enumerate(valid_items):
                        print(f"  Item {i+1}: {it.get('category')} - {it.get('subcategory')} ({it.get('color')}, {it.get('pattern')}) Box: {it.get('box_2d')}")

                return parsed
            except Exception as e:
                print(f"[AIService] Model {model_name} encountered error: {e}")
                last_err = e
                if "429" in str(e) or "quota" in str(e).lower():
                    time.sleep(2.0)
                continue
        raise HTTPException(
            status_code=500,
            detail=f"Gemini API Error: {str(last_err)}"
        )
