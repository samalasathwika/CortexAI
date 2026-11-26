import logging
import os
from typing import List, Dict, Any, Optional
import httpx
from app.config import settings

logger = logging.getLogger("cortex.omdb")

_OMDB_CACHE: Dict[str, Any] = {}

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
        "why_recommended": "High-rated mind-bending thriller. Fits within your weekend entertainment budget."
    },
    {
        "imdb_id": "tt0816692",
        "title": "Interstellar",
        "year": "2014",
        "poster": "https://m.media-amazon.com/images/M/MV5BYzdjMDAxZGItMjI2My00ODA1LTlkNzItOWFjMDU5ZDJlYWY3XkEyXkFqcGc@._V1_SX300.jpg",
        "genre": "Adventure, Drama, Sci-Fi",
        "rating": "8.7",
        "runtime": "169 min",
        "plot": "When Earth becomes uninhabitable in the future, a farmer and ex-NASA pilot is tasked to pilot a spacecraft along with a team of researchers to find a new planet for humans.",
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
        "plot": "When the menace known as the Joker wreaks havoc and chaos on the people of Gotham, Batman must accept one of the greatest psychological and physical tests of his ability to fight injustice.",
        "suggested_budget": 300.0,
        "why_recommended": "Top-tier critically acclaimed masterpiece that delivers maximum entertainment per rupee."
    },
    {
        "imdb_id": "tt0111161",
        "title": "The Shawshank Redemption",
        "year": "1994",
        "poster": "https://m.media-amazon.com/images/M/MV5BMDAyY2FhYjctNDc5OS00MDNlLThiMGUtY2UxYWVkNGY2ZjljXkEyXkFqcGc@._V1_SX300.jpg",
        "genre": "Drama",
        "rating": "9.3",
        "runtime": "142 min",
        "plot": "Over the course of several years, two convicts form a friendship, seeking solace and eventual redemption through basic compassion.",
        "suggested_budget": 200.0,
        "why_recommended": "Timeless story of patience, discipline and freedom — themes that resonate with financial resilience."
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
        "why_recommended": "Gripping, award-winning cinematic experience that fits a planned leisure evening."
    }
]

class OMDbService:
    def __init__(self):
        self.api_key = settings.OMDB_API_KEY
        self.base_url = settings.OMDB_BASE_URL
        self.enable_live_http = os.getenv("OMDB_LIVE_CALLS", "false").lower() in ("true", "1", "yes")

    def fetch_movie_by_title(self, title: str) -> Optional[Dict[str, Any]]:
        cache_key = f"title_{title.lower()}"
        if cache_key in _OMDB_CACHE:
            return _OMDB_CACHE[cache_key]

        # Check local catalog first
        for m in FALLBACK_MOVIES:
            if m["title"].lower() == title.lower():
                data = {
                    "Title": m["title"], "Year": m["year"], "imdbID": m["imdb_id"],
                    "Genre": m["genre"], "imdbRating": m["rating"], "Runtime": m["runtime"],
                    "Plot": m["plot"], "Poster": m["poster"], "Response": "True"
                }
                _OMDB_CACHE[cache_key] = data
                return data

        if not self.enable_live_http or not self.api_key or self.api_key == "YOUR_OMDB_API_KEY":
            return None

        try:
            with httpx.Client(timeout=2.0) as client:
                resp = client.get(self.base_url, params={"apikey": self.api_key, "t": title, "plot": "short"})
                if resp.status_code == 200:
                    data = resp.json()
                    if data.get("Response") == "True":
                        _OMDB_CACHE[cache_key] = data
                        return data
        except Exception as e:
            logger.warning(f"Error calling OMDb API for title '{title}': {e}")
        return None

    def search_movies(self, query: str) -> List[Dict[str, Any]]:
        cache_key = f"search_{query.lower()}"
        if cache_key in _OMDB_CACHE:
            return _OMDB_CACHE[cache_key]

        q = query.lower()
        local_matches = [
            {"Title": m["title"], "Year": m["year"], "imdbID": m["imdb_id"], "Type": "movie", "Poster": m["poster"]}
            for m in FALLBACK_MOVIES if q in m["title"].lower()
        ]

        if local_matches or not self.enable_live_http or not self.api_key or self.api_key == "YOUR_OMDB_API_KEY":
            return local_matches

        try:
            with httpx.Client(timeout=2.0) as client:
                resp = client.get(self.base_url, params={"apikey": self.api_key, "s": query, "type": "movie"})
                if resp.status_code == 200:
                    data = resp.json()
                    if data.get("Response") == "True":
                        results = data.get("Search", [])
                        _OMDB_CACHE[cache_key] = results
                        return results
        except Exception as e:
            logger.warning(f"Error searching OMDb API: {e}")

        return local_matches

    def get_curated_movie_recommendations(self, entertainment_budget: float = 1000.0) -> List[Dict[str, Any]]:
        curated_titles = ["Inception", "Interstellar", "The Dark Knight", "Oppenheimer", "The Shawshank Redemption"]
        recommendations = []

        for title in curated_titles:
            omdb_data = self.fetch_movie_by_title(title)
            if omdb_data:
                est_cost = min(500.0, max(200.0, entertainment_budget * 0.25))
                recommendations.append({
                    "imdb_id": omdb_data.get("imdbID", ""),
                    "title": omdb_data.get("Title", title),
                    "year": omdb_data.get("Year", ""),
                    "poster": omdb_data.get("Poster", "") if omdb_data.get("Poster") != "N/A" else "https://images.unsplash.com/photo-1489599849927-2ee91cede3ba?w=300",
                    "genre": omdb_data.get("Genre", "Cinema"),
                    "rating": omdb_data.get("imdbRating", "8.0"),
                    "runtime": omdb_data.get("Runtime", "120 min"),
                    "plot": omdb_data.get("Plot", "Acclaimed cinematic title."),
                    "suggested_budget": round(est_cost, 2),
                    "why_recommended": f"Matches your Movie interest. Consumes only {round((est_cost / max(1, entertainment_budget)) * 100)}% of your monthly entertainment bucket."
                })

        if not recommendations:
            for m in FALLBACK_MOVIES:
                item = m.copy()
                item["suggested_budget"] = min(item["suggested_budget"], max(150.0, entertainment_budget * 0.3))
                recommendations.append(item)

        return recommendations

omdb_service = OMDbService()
