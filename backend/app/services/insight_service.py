import collections
from typing import List, Dict, Any


class InsightService:
    @staticmethod
    def compute_stats(items: List[Any]) -> Dict[str, Any]:
        """
        Compute wardrobe statistics from a list of ClothingItem ORM objects.
        Returns a serializable dict with totals, distributions and simple summaries.
        """
        total = len(items)

        category_counts = collections.Counter()
        color_counts = collections.Counter()
        season_counts = collections.Counter()
        occasion_counts = collections.Counter()

        for x in items:
            cat = (x.category or "Unknown").strip()
            category_counts[cat] += 1

            col = (x.color or "Unknown").strip()
            color_counts[col] += 1

            season = (x.season or "Unknown").strip()
            season_counts[season] += 1

            occ = (x.occasion or "Unknown").strip()
            occasion_counts[occ] += 1

        def top_n(counter, n=3):
            return [{"value": k, "count": v, "percent": round((v / total) * 100) if total else 0}
                    for k, v in counter.most_common(n)]

        stats = {
            "total_items": total,
            "category_counts": dict(category_counts),
            "percent_by_category": {k: round((v / total) * 100) for k, v in category_counts.items()} if total else {},
            "dominant_colors": top_n(color_counts, 3),
            "season_distribution": dict(season_counts),
            "occasion_distribution": dict(occasion_counts),
            "top_count": category_counts.get("Tops", 0),
            "bottom_count": category_counts.get("Bottoms", 0),
        }

        return stats

    @staticmethod
    def generate_insights_from_stats(stats: Dict[str, Any]) -> List[Dict[str, str]]:
        """
        Deterministic rule-based insights derived from stats.
        Each insight is a dict: {"suggestion": "..."}
        """
        insights = []
        total = stats.get("total_items", 0)

        # Small wardrobe
        if total == 0:
            insights.append({"suggestion": "Your wardrobe is empty — digitize a few items to get personalized insights."})
            return insights

        if total < 3:
            insights.append({"suggestion": "You have a small wardrobe — add a few basic Tops and Bottoms to unlock outfit combinations."})

        # Top/Bottom balance
        top = stats.get("top_count", 0)
        bottom = stats.get("bottom_count", 0)
        if top and bottom:
            if top > bottom * 1.6:
                insights.append({"suggestion": "You have many Tops compared to Bottoms — adding versatile bottoms will increase outfit variety."})
            elif bottom > top * 1.6:
                insights.append({"suggestion": "You have more Bottoms than Tops — consider adding a few Tops to balance outfit options."})
        else:
            # If one of them is missing
            if top and not bottom:
                insights.append({"suggestion": "Your wardrobe has Tops but no Bottoms — add basic bottoms to create outfits."})
            if bottom and not top:
                insights.append({"suggestion": "Your wardrobe has Bottoms but no Tops — add a few Tops to complete outfits."})

        # Dominant color
        dominant = stats.get("dominant_colors", [])
        if dominant:
            top_color = dominant[0]
            if top_color.get("percent", 0) >= 40:
                insights.append({"suggestion": f"{top_color['value']} is a dominant color in your wardrobe, which makes mixing easy but may limit variety — try adding contrasting pieces."})
            elif top_color.get("percent", 0) >= 25:
                insights.append({"suggestion": f"{top_color['value']} appears frequently in your wardrobe — good for consistency; adding accent colors can create fresh looks."})

        # Occasion skew
        occasion_dist = stats.get("occasion_distribution", {})
        occ_total = sum(occasion_dist.values()) if occasion_dist else 0
        if occ_total:
            # Find if Casual is overwhelmingly high
            casual_count = occasion_dist.get("Casual", 0)
            if casual_count and casual_count / occ_total >= 0.7:
                insights.append({"suggestion": "Your wardrobe leans casual — adding a couple of formal or work-appropriate pieces could increase versatility."})

        # Category dominance
        percent_by_cat = stats.get("percent_by_category", {})
        for cat, pct in percent_by_cat.items():
            if pct >= 60 and total >= 3:
                insights.append({"suggestion": f"Your wardrobe is heavy on {cat} ({pct}% of items). Consider diversifying categories to expand outfit combinations."})

        # Fallback insight if none created
        if not insights:
            insights.append({"suggestion": "Your wardrobe looks balanced — keep curating pieces you love. Try adding a versatile neutral to increase pairings."})

        return insights
