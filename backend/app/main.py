import logging
import os
from pathlib import Path
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

from app.config import settings
from app.database import engine, SessionLocal
from app.init_db import init_db

# Import routers
from app.routers.auth_router import router as auth_router
from app.routers.budget_router import router as budget_router
from app.routers.goals_router import router as goals_router
from app.routers.recommendation_router import router as rec_router
from app.routers.plans_router import router as plans_router
from app.routers.lifestyle_router import router as lifestyle_router

logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s")
logger = logging.getLogger("cortex.main")

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="Cortex AI - Personal Money-Balancing & Financial Decision-Support System API"
)

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Startup Event: Initialize database & reference tables
@app.on_event("startup")
def on_startup():
    logger.info("Initializing database and verifying tables...")
    db = SessionLocal()
    try:
        init_db(db)
        logger.info("Database ready!")
    except Exception as e:
        logger.error(f"Error initializing database: {e}")
    finally:
        db.close()

# Include API Routers
app.include_router(auth_router, prefix=settings.API_V1_STR)
app.include_router(budget_router, prefix=settings.API_V1_STR)
app.include_router(goals_router, prefix=settings.API_V1_STR)
app.include_router(rec_router, prefix=settings.API_V1_STR)
app.include_router(plans_router, prefix=settings.API_V1_STR)
app.include_router(lifestyle_router, prefix=settings.API_V1_STR)

@app.get(f"{settings.API_V1_STR}/health", tags=["Health"])
def health_check():
    return {
        "status": "healthy",
        "service": settings.PROJECT_NAME,
        "version": settings.VERSION,
        "database": engine.url.drivername
    }

# Serve Frontend static assets
frontend_dir = Path(__file__).resolve().parent.parent.parent / "frontend"
if frontend_dir.exists():
    app.mount("/static", StaticFiles(directory=str(frontend_dir)), name="static")

    no_cache_headers = {
        "Cache-Control": "no-cache, no-store, must-revalidate",
        "Pragma": "no-cache",
        "Expires": "0"
    }

    @app.get("/")
    def serve_frontend_root():
        index_file = frontend_dir / "index.html"
        return FileResponse(str(index_file), headers=no_cache_headers)

    @app.get("/{filename:path}")
    def serve_frontend_files(filename: str):
        target = frontend_dir / filename
        if target.exists() and target.is_file():
            return FileResponse(str(target), headers=no_cache_headers)
        return FileResponse(str(frontend_dir / "index.html"), headers=no_cache_headers)
