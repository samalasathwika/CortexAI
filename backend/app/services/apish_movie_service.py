import logging
import os
from typing import List, Dict, Any, Optional
import httpx
from app.config import settings

logger = logging.getLogger("cortex.apish_movies")

_CACHE: Dict[str, Any] = {}

FALLBACK_MOVIES = [
    {
        "imdb_id": "tt1375666",
        "title": "Inception",
        "year": "2010",
        "poster": "https://m.media-amazon.com/images/M/MV5BMjAxMzY3NjcxNF5BMl5BanBnXkFtZTcwNTI5OTM0Mw@@._V1_SX300.jpg",
        "genre": "Action, Adventure, Sci-Fi",
        "rating": "8.8",
        "runtime": "148 min",
        "plot": "A thief who steals corporate secrets through the use of dream-sharing technology is given the inverse task of planting an idea into the mind of a C.E.O.",
        "suggested_budget": 350.0,
        "why_recommended": "High-rated mind-bending thriller. Fits comfortably within your monthly entertainment bucket."
    },
    {
        "imdb_id": "tt0816692",
        "title": "Interstellar",
        "year": "2014",
        "poster": "https://m.media-amazon.com/images/M/MV5BYzdjMDAxZGItMjI2My00ODA1LTlkNzItOWFjMDU5ZDJlYWY3XkEyXkFqcGc@._V1_SX300.jpg",
        "genre": "Adventure, Drama, Sci-Fi",
        "rating": "8.7",
        "runtime": "169 min",
        "plot": "When Earth becomes uninhabitable in the future, a farmer and ex-NASA pilot is tasked to pilot a spacecraft to find a new planet for humans.",
        "suggested_budget": 400.0,
        "why_recommended": "Visually spectacular sci-fi classic ideal for an evening cinema or premium streaming night."
    },
    {
        "imdb_id": "tt0468569",
        "title": "The Dark Knight",
        "year": "2008",
        "poster": "https://m.media-amazon.com/images/M/MV5BMTMxNTMwODM0NF5BMl5BanBnXkFtZTcwODAyMTk2Mw@@._V1_SX300.jpg",
        "genre": "Action, Crime, Drama",
        "rating": "9.0",
        "runtime": "152 min",
        "plot": "When the menace known as the Joker wreaks havoc and chaos on the people of Gotham, Batman must fight injustice.",
        "suggested_budget": 300.0,
        "why_recommended": "Top-tier critically acclaimed masterpiece delivering maximum entertainment per rupee."
    },
    {
        "imdb_id": "tt0111161",
        "title": "The Shawshank Redemption",
        "year": "1994",
        "poster": "https://m.media-amazon.com/images/M/MV5BMDAyY2FhYjctNDc5OS00MDNlLThiMGUtY2UxYWVkNGY2ZjljXkEyXkFqcGc@._V1_SX300.jpg",
        "genre": "Drama",
        "rating": "9.3",
        "runtime": "142 min",
        "plot": "Over the course of several years, two convicts form a friendship, seeking solace and eventual redemption.",
        "suggested_budget": 200.0,
        "why_recommended": "Timeless story of patience, discipline and freedom — themes that align with financial resilience."
    },
    {
        "imdb_id": "tt15398776",
        "title": "Oppenheimer",
        "year": "2023",
        "poster": "https://m.media-amazon.com/images/M/MV5BN2JkMDc5MGQtZjg3YS00NmFiLWIyZmQtZTGCYmE2ODA3OWUxXkEyXkFqcGc@._V1_SX300.jpg",
        "genre": "Biography, Drama, History",
        "rating": "8.9",
        "runtime": "180 min",
        "plot": "The story of American scientist J. Robert Oppenheimer and his role in the development of the atomic bomb.",
        "suggested_budget": 450.0,
        "why_recommended": "Award-winning cinematic spectacle that fits a planned leisure evening without overshooting budget."
    }
]

class ApishMovieService:
    """
    Movie decision-support service powered by api.sh IMDb endpoints.
    Uses 'ash_live_...' key to fetch official IMDb charts and search results.
    """
    def __init__(self):
        self.api_key = getattr(settings, "APISH_API_KEY", os.getenv("APISH_API_KEY", "ash_live_GXGKCEFkWVSi8nEtddVQHZqKjYpSJN2Z"))
        self.base_url = getattr(settings, "APISH_BASE_URL", "https://api.api.sh").rstrip("/")

    def _headers(self) -> Dict[str, str]:
        return {
            "x-api-key": self.api_key,
            "Accept": "application/json",
            "User-Agent": "CortexAI/1.0"
        }

    def get_curated_movie_recommendations(self, entertainment_budget: float = 1000.0) -> List[Dict[str, Any]]:
        cache_key = "chart_top_movies"
        raw_entries = _CACHE.get(cache_key)

        if not raw_entries and self.api_key:
            try:
                url = f"{self.base_url}/imdb/v1/chart"
                with httpx.Client(timeout=6.0) as client:
                    resp = client.get(url, headers=self._headers())
                    if resp.status_code == 200:
                        data = resp.json()
                        entries = data.get("entries", [])
                        if entries:
                            raw_entries = entries
                            _CACHE[cache_key] = entries
                            logger.info(f"Loaded {len(entries)} movies from api.sh IMDb chart.")
                    else:
                        logger.warning(f"api.sh chart returned status {resp.status_code}: {resp.text[:100]}")
            except Exception as e:
                logger.warning(f"Error fetching api.sh IMDb chart: {e}")

        recommendations = []
        if raw_entries:
            for entry in raw_entries[:8]:
                title = entry.get("name") or entry.get("title") or "Movie"
                year = entry.get("year", "")
                rating = entry.get("rating_value") or entry.get("rating", "8.5")
                genres = entry.get("genre", [])
                genre_str = ", ".join(genres) if isinstance(genres, list) else str(genres)
                plot = entry.get("plot") or entry.get("description") or "Acclaimed top-ranked IMDb cinematic title."
                poster = entry.get("image") or "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=300"
                runtime = f"{entry.get('runtime_minutes', 130)} min" if entry.get("runtime_minutes") else "120 min"
                imdb_id = entry.get("id") or ""

                est_cost = min(500.0, max(180.0, entertainment_budget * 0.22))
                pct = round((est_cost / max(1.0, entertainment_budget)) * 100)

                recommendations.append({
                    "imdb_id": imdb_id,
                    "title": title,
                    "year": str(year),
                    "poster": poster,
                    "genre": genre_str or "Cinema",
                    "rating": str(rating),
                    "runtime": runtime,
                    "plot": plot,
                    "suggested_budget": round(est_cost, 2),
                    "why_recommended": f"IMDb Top Rank #{entry.get('rank', 1)}. Uses only {pct}% of your ₹{int(entertainment_budget):,} entertainment budget."
                })

        # Fallback if offline or empty
        if not recommendations:
            for m in FALLBACK_MOVIES:
                item = m.copy()
                item["suggested_budget"] = min(item["suggested_budget"], max(150.0, entertainment_budget * 0.25))
                recommendations.append(item)

        return recommendations

    def search_movies(self, query: str) -> List[Dict[str, Any]]:
        cache_key = f"search_{query.lower()}"
        if cache_key in _CACHE:
            return _CACHE[cache_key]

        results = []
        if self.api_key:
            try:
                url = f"{self.base_url}/imdb/v1/search"
                with httpx.Client(timeout=6.0) as client:
                    resp = client.get(url, params={"q": query}, headers=self._headers())
                    if resp.status_code == 200:
                        data = resp.json()
                        raw_results = data.get("results", [])
                        for item in raw_results[:12]:
                            title = item.get("name") or item.get("title") or query
                            year = item.get("year", "")
                            rating = item.get("rating") or "N/A"
                            poster = item.get("image") or "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=300"
                            imdb_id = item.get("id") or ""
                            
                            results.append({
                                "Title": title,
                                "Year": str(year) if year else "",
                                "imdbID": imdb_id,
                                "Poster": poster,
                                "rating": str(rating),
                                "Type": item.get("title_type", "movie")
                            })
                        if results:
                            _CACHE[cache_key] = results
                            return results
            except Exception as e:
                logger.warning(f"Error searching api.sh IMDb API: {e}")

        # Local fallback search
        q = query.lower()
        local_matches = [
            {
                "Title": m["title"],
                "Year": m["year"],
                "imdbID": m["imdb_id"],
                "Poster": m["poster"],
                "rating": m["rating"],
                "Type": "movie"
            }
            for m in FALLBACK_MOVIES if q in m["title"].lower()
        ]
        return local_matches

apish_movie_service = ApishMovieService()
