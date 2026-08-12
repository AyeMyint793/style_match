import json
import os
from typing import List, Optional, Dict
from fastapi import HTTPException
import google.generativeai as genai
from dotenv import load_dotenv

# Load Environment Variables
load_dotenv()
load_dotenv(dotenv_path="../.env")

# Configure Gemini
gemini_api_key = os.getenv("GEMINI_API_KEY")
if gemini_api_key:
    genai.configure(api_key=gemini_api_key)

class AIService:
    @staticmethod
    def call_gemini(prompt: str) -> str:
        if not gemini_api_key:
            raise HTTPException(
                status_code=500,
                detail="GEMINI_API_KEY not configured on server"
            )

        models = ["gemini-2.0-flash", "gemini-2.0-flash-lite", "gemini-1.5-flash"]
        last_err = None
        for model_name in models:
            try:
                model = genai.GenerativeModel(model_name)
                response = model.generate_content(prompt)
                return response.text
            except Exception as e:
                last_err = e
                continue
        raise HTTPException(
            status_code=500,
            detail=f"Gemini API Error: {str(last_err)}"
        )

    @staticmethod
    def clean_json_response(text: str) -> str:
        cleaned = text.strip()
        if cleaned.startswith("```json"):
            cleaned = cleaned[7:]
        elif cleaned.startswith("```"):
            cleaned = cleaned[3:]
        if cleaned.endswith("```"):
            cleaned = cleaned[:-3]
        return cleaned.strip()

    @staticmethod
    def generate_outfit(user_height, user_size, pref_fit, pref_style, occasion, season, weather, shown_item_ids, items_json):
        prompt = f"""
        You are a professional fashion stylist. A client wants outfit recommendations from their personal wardrobe.

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

        Please generate up to 3 different outfit combinations from the wardrobe that fit the occasion, season, weather, and style preferences.
        Try to avoid using items in this list: {shown_item_ids} if possible, to provide variety.

        For each outfit:
        1. Select appropriate items from the wardrobe. An outfit must contain a Top and a Bottom, OR a Single Dress, and optionally Shoes, Outerwear, and Accessories. Do NOT mix categories incorrectly.
        2. Provide a 1-2 sentence fashion rationale/explanation describing why this combination works for the weather/occasion and styling tips.

        Respond with ONLY a valid JSON object in this exact format (no markdown, no backticks, no other text):
        {{
          "success": true,
          "outfits": [
            {{
              "outfit_number": 1,
              "description": "Fashion styling rationale...",
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

        If the wardrobe has too few matching items to make a valid outfit for this occasion/season/weather, return:
        {{
          "success": false,
          "message": "Add more clothing items matching this occasion/season to generate outfits."
        }}
        """
        response_text = AIService.call_gemini(prompt)
        cleaned = AIService.clean_json_response(response_text)
        return json.loads(cleaned)

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
        return json.loads(cleaned)

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
    def trip_packing(destination, days, trip_type, activities, weather, items_json):
        prompt = f"""
        You are an expert travel packing assistant.
        The user is planning a trip with the following details:
        - Destination: {destination}
        - Duration: {days} days
        - Trip Type: {trip_type}
        - Planned Activities: {activities}
        - Weather Forecast: {weather}

        Here is the user's wardrobe (in JSON format):
        {items_json}

        Create a travel packing plan:
        1. Select a subset of items from their wardrobe to pack. For each packed item, give a reason.
        2. Recommend outfits they can combine from these packed items. Return the combinations as string labels using the item subcategory and ID in parentheses, e.g., "Dinner Night: Blue Jeans (10) and White Shirt (6)".
        3. Identify "missing items" not in their wardrobe that they should buy or pack separately (e.g. if traveling to a cold city and they have no outerwear).
        4. Give one general packing tip.

        Respond with ONLY a valid JSON object in this exact format (no markdown, no backticks, no other text):
        {{
          "success": true,
          "packing_list": [
            {{
              "item": {{
                "id": 1,
                "category": "Tops",
                "subcategory": "Shirt",
                "color": "White",
                "image_path": "https://..."
              }},
              "reason": "Perfect for casual sightseeing in mild weather."
            }}
          ],
          "combinations": [
            "Sightseeing: White Shirt (1) and Blue Jeans (2)"
            "Sightseeing: Blue Jeans (2) and T-Shirt (3)"
          ],
          "missing_items": [
            "A heavy coat (it is cold at night)"
          ],
          "packing_tip": "Roll clothes instead of folding to maximize suitcase space."
        }}
        """
        response_text = AIService.call_gemini(prompt)
        cleaned = AIService.clean_json_response(response_text)
        return json.loads(cleaned)
