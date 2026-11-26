import logging
from typing import List, Dict, Any

logger = logging.getLogger("cortex.shopping")

PRODUCTS_CATALOG: List[Dict[str, Any]] = [
    {
        "id": "prod_1",
        "title": "Ergonomic Memory Foam Lumbar Cushion",
        "category": "Lifestyle",
        "price": 899.0,
        "rating": 4.6,
        "image_url": "https://images.unsplash.com/photo-1584100936595-c0654b55a2e2?w=300",
        "description": "Premium orthopedic back support cushion for long work or study desk hours.",
        "affiliate_tag": "cortex_lumbar",
    },
    {
        "id": "prod_2",
        "title": "Minimalist Matte Stainless Steel Water Flask (1L)",
        "category": "Personal Care",
        "price": 649.0,
        "rating": 4.8,
        "image_url": "https://images.unsplash.com/photo-1602143407151-7111542de6e8?w=300",
        "description": "Double-walled vacuum insulated bottle keeps drinks cold for 24h or hot for 12h.",
        "affiliate_tag": "cortex_flask",
    },
    {
        "id": "prod_3",
        "title": "Anker 20W Fast USB-C Power Adapter",
        "category": "Tech",
        "price": 1199.0,
        "rating": 4.7,
        "image_url": "https://images.unsplash.com/photo-1583863788434-e58a36330cf0?w=300",
        "description": "Ultra-compact high-speed charger with intelligent temperature control for phones and tablets.",
        "affiliate_tag": "cortex_charger",
    },
    {
        "id": "prod_4",
        "title": "The Psychology of Money by Morgan Housel",
        "category": "Lifestyle",
        "price": 320.0,
        "rating": 4.9,
        "image_url": "https://images.unsplash.com/photo-1544716278-ca5e3f4abd8c?w=300",
        "description": "Timeless lessons on wealth, greed, and happiness — the definitive modern financial mindset guide.",
        "affiliate_tag": "cortex_book_money",
    },
    {
        "id": "prod_5",
        "title": "Multi-Device Wireless Bluetooth Mouse",
        "category": "Tech",
        "price": 999.0,
        "rating": 4.5,
        "image_url": "https://images.unsplash.com/photo-1527864550417-7fd91fc51a46?w=300",
        "description": "Silent-click multi-pairing mouse that toggles between laptop, tablet, and PC seamlessly.",
        "affiliate_tag": "cortex_mouse",
    },
    {
        "id": "prod_6",
        "title": "Atomic Habits by James Clear",
        "category": "Lifestyle",
        "price": 450.0,
        "rating": 4.9,
        "image_url": "https://images.unsplash.com/photo-1512820790803-83ca734da794?w=300",
        "description": "An easy & proven way to build good habits and break bad ones, maximizing monthly discipline.",
        "affiliate_tag": "cortex_book_habits",
    },
    {
        "id": "prod_7",
        "title": "Noise-Cancelling Over-Ear Wireless Headphones",
        "category": "Tech",
        "price": 2499.0,
        "rating": 4.4,
        "image_url": "https://images.unsplash.com/photo-1505740420928-5e560c06d30e?w=300",
        "description": "Deep bass, 40-hour playtime and active ambient isolation for deep focus study sessions.",
        "affiliate_tag": "cortex_headphones",
    },
    {
        "id": "prod_8",
        "title": "Organic Green Tea & Herbal Infusions Assortment",
        "category": "Dining",
        "price": 499.0,
        "rating": 4.6,
        "image_url": "https://images.unsplash.com/photo-1576092768241-dec231879fc3?w=300",
        "description": "Hand-plucked loose leaf green teas for daily calm, immunity boost, and stress relief.",
        "affiliate_tag": "cortex_tea",
    }
]

class ShoppingService:
    def get_recommendations(
        self,
        shopping_budget: float = 1500.0,
        user_interests: List[str] = None
    ) -> List[Dict[str, Any]]:
        interests_lower = [i.lower() for i in (user_interests or ["Shopping", "Lifestyle", "Tech"])]

        results = []
        for p in PRODUCTS_CATALOG:
            # Check if category matches or generic shopping
            cat_match = (
                p["category"].lower() in interests_lower or
                "shopping" in interests_lower or
                "lifestyle" in interests_lower
            )

            is_affordable = p["price"] <= max(500.0, shopping_budget * 1.1)

            results.append({
                **p,
                "is_budget_friendly": p["price"] <= shopping_budget,
                "budget_percentage": round((p["price"] / max(1.0, shopping_budget)) * 100, 1),
                "matched_interest": p["category"] if cat_match else "General Lifestyle"
            })

        # Sort so that items that best fit the budget and user interests come first
        results.sort(key=lambda x: (x["is_budget_friendly"], -x["rating"]), reverse=True)
        return results

shopping_service = ShoppingService()
