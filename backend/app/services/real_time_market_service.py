import logging
import time
from typing import Dict, Any, Optional
import httpx

logger = logging.getLogger("cortex.real_time_market")

_CRYPTO_CACHE: Dict[str, Any] = {}
_LAST_FETCH_TIME: float = 0.0
_CACHE_TTL_SECONDS: float = 300.0  # 5 minutes

# Reliable baseline quotes if network is offline
FALLBACK_CRYPTO_DATA = {
    "bitcoin": {
        "name": "Bitcoin (BTC)",
        "inr": 7034000,
        "usd": 74900,
        "inr_24h_change": -1.25,
        "last_updated": "Benchmark data"
    },
    "ethereum": {
        "name": "Ethereum (ETH)",
        "inr": 201000,
        "usd": 2140,
        "inr_24h_change": -3.80,
        "last_updated": "Benchmark data"
    }
}

class RealTimeMarketService:
    """
    Fetches real-time cryptocurrency and market data.
    Uses CoinGecko public API with in-memory TTL caching to prevent rate-limiting.
    """
    def __init__(self):
        self.coingecko_url = "https://api.coingecko.com/api/v3/simple/price"

    def get_live_crypto_prices(self) -> Dict[str, Any]:
        global _CRYPTO_CACHE, _LAST_FETCH_TIME

        now = time.time()
        if _CRYPTO_CACHE and (now - _LAST_FETCH_TIME < _CACHE_TTL_SECONDS):
            return _CRYPTO_CACHE

        params = {
            "ids": "bitcoin,ethereum",
            "vs_currencies": "inr,usd",
            "include_24hr_change": "true"
        }
        headers = {
            "Accept": "application/json",
            "User-Agent": "CortexAI/1.0"
        }

        try:
            with httpx.Client(timeout=4.0) as client:
                resp = client.get(self.coingecko_url, params=params, headers=headers)
                if resp.status_code == 200:
                    data = resp.json()
                    parsed = {
                        "bitcoin": {
                            "name": "Bitcoin (BTC)",
                            "inr": round(data.get("bitcoin", {}).get("inr", 7034000), 2),
                            "usd": round(data.get("bitcoin", {}).get("usd", 74900), 2),
                            "inr_24h_change": round(data.get("bitcoin", {}).get("inr_24h_change", 0.0), 2),
                            "last_updated": "Live from CoinGecko"
                        },
                        "ethereum": {
                            "name": "Ethereum (ETH)",
                            "inr": round(data.get("ethereum", {}).get("inr", 201000), 2),
                            "usd": round(data.get("ethereum", {}).get("usd", 2140), 2),
                            "inr_24h_change": round(data.get("ethereum", {}).get("inr_24h_change", 0.0), 2),
                            "last_updated": "Live from CoinGecko"
                        },
                        "status": "live"
                    }
                    _CRYPTO_CACHE = parsed
                    _LAST_FETCH_TIME = now
                    logger.info("Successfully fetched live crypto prices from CoinGecko.")
                    return parsed
                else:
                    logger.warning(f"CoinGecko API returned status {resp.status_code}")
        except Exception as e:
            logger.warning(f"Could not connect to CoinGecko API ({e}). Using reliable baseline data.")

        # Return fallback with indicator
        fallback = FALLBACK_CRYPTO_DATA.copy()
        fallback["status"] = "cached_benchmark"
        return fallback

real_time_market_service = RealTimeMarketService()
