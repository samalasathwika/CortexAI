from typing import List, Optional
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User, MonthlyBudget, UserInterest
from app.auth import get_optional_current_user
from app.services.apish_movie_service import apish_movie_service
from app.services.shopping_service import shopping_service
from app.routers.budget_router import get_current_year_month

router = APIRouter(prefix="/lifestyle", tags=["Lifestyle: api.sh IMDb & Shopping Integration"])

@router.get("/movies")
def get_movie_recommendations(
    budget: Optional[float] = Query(None, description="Optional override for entertainment budget"),
    current_user: Optional[User] = Depends(get_optional_current_user),
    db: Session = Depends(get_db)
):
    ent_budget = budget or 1200.0

    if current_user and budget is None:
        ym = get_current_year_month()
        b = db.query(MonthlyBudget).filter(
            MonthlyBudget.user_id == current_user.user_id,
            MonthlyBudget.year_month == ym
        ).first()
        if b:
            for e in b.expense_entries:
                if e.category and e.category.code == "entertainment":
                    ent_budget = max(200.0, float(e.planned_amount))

    movies = apish_movie_service.get_curated_movie_recommendations(entertainment_budget=ent_budget)
    return {
        "provider": "api.sh (IMDb Live)",
        "entertainment_budget": ent_budget,
        "recommendations": movies
    }

@router.get("/movies/search")
def search_movies(
    q: str = Query(..., min_length=2, description="Search term for IMDb movie lookup via api.sh")
):
    results = apish_movie_service.search_movies(query=q)
    return {"provider": "api.sh (IMDb Live)", "query": q, "results": results}

@router.get("/shopping")
def get_shopping_recommendations(
    budget: Optional[float] = Query(None, description="Optional override for shopping budget"),
    current_user: Optional[User] = Depends(get_optional_current_user),
    db: Session = Depends(get_db)
):
    shop_budget = budget or 1500.0
    user_interests = ["Shopping", "Lifestyle", "Tech"]

    if current_user:
        interests_query = db.query(UserInterest).filter(UserInterest.user_id == current_user.user_id).all()
        if interests_query:
            user_interests = [ui.interest.name for ui in interests_query if ui.interest]

    products = shopping_service.get_recommendations(
        shopping_budget=shop_budget,
        user_interests=user_interests
    )
    return {
        "shopping_budget": shop_budget,
        "matched_interests": user_interests,
        "products": products
    }
