from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import (
    User, UserProfile, MonthlyBudget, Strategy, Recommendation,
    RecommendationAllocation, RecommendationFactor, RecommendationInsight,
    AllocationBucket, FinancialGoal, UserInterest, RealWorldRecommendationItem
)
from app.schemas import RecommendationGenerateRequest, RecommendationResponse
from app.auth import get_current_user, get_optional_current_user
from app.services.recommendation_engine import recommendation_engine
from app.services.real_world_rec_service import real_world_rec_service
from app.routers.budget_router import get_current_year_month

router = APIRouter(prefix="/recommendations", tags=["Cortex AI Recommendations"])

@router.post("/generate", response_model=RecommendationResponse)
def generate_recommendations(
    req: RecommendationGenerateRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    ym = get_current_year_month()
    budget = db.query(MonthlyBudget).filter(
        MonthlyBudget.user_id == current_user.user_id,
        MonthlyBudget.year_month == ym
    ).first()

    # Calculate disposable income
    gross_income = 0.0
    total_expenses = 0.0
    if budget:
        for i in budget.income_entries:
            gross_income += float(i.amount)
        for e in budget.expense_entries:
            total_expenses += float(e.planned_amount)

    disposable_income = max(0.0, gross_income - total_expenses)

    # User profile & preferences
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.user_id).first()
    risk = req.risk or (profile.risk_tolerance if profile else "moderate")
    lifestyle_pct = req.lifestyle_pct if req.lifestyle_pct is not None else (float(profile.lifestyle_pct) if profile else 15.0)

    # Active goals
    goals_query = db.query(FinancialGoal).filter(
        FinancialGoal.user_id == current_user.user_id,
        FinancialGoal.status == "in_progress"
    ).all()
    goals_data = [
        {"type_code": g.goal_type.code if g.goal_type else "other", "priority": g.priority}
        for g in goals_query
    ]

    # Interests
    interests_query = db.query(UserInterest).filter(UserInterest.user_id == current_user.user_id).all()
    interests_data = [ui.interest.name for ui in interests_query if ui.interest]

    # Generate recommendation via Cortex Engine
    rec_result = recommendation_engine.generate_recommendation(
        disposable_income=disposable_income,
        persona=current_user.role,
        risk_tolerance=risk,
        lifestyle_pct=lifestyle_pct,
        active_goals=goals_data,
        interests=interests_data,
        strategy_override=req.strategy
    )

    # Persist in database
    strategy_obj = db.query(Strategy).filter(Strategy.code == rec_result["strategy_code"]).first()
    if strategy_obj:
        rec_record = Recommendation(
            user_id=current_user.user_id,
            budget_id=budget.budget_id if budget else None,
            strategy_id=strategy_obj.strategy_id,
            disposable_income=rec_result["disposable_income"],
            engine_version="cortex-v2.1"
        )
        db.add(rec_record)
        db.commit()
        db.refresh(rec_record)

        # Save allocations
        for alloc in rec_result["allocations"]:
            bucket = db.query(AllocationBucket).filter(AllocationBucket.code == alloc["bucket_code"]).first()
            if bucket:
                db.add(RecommendationAllocation(
                    recommendation_id=rec_record.recommendation_id,
                    bucket_id=bucket.bucket_id,
                    weight_pct=alloc["weight_pct"],
                    allocated_amount=alloc["amount"]
                ))

        # Save factors
        for f in rec_result["factors"]:
            db.add(RecommendationFactor(
                recommendation_id=rec_record.recommendation_id,
                factor_name=f["factor_name"],
                impact_weight=f["impact_weight"],
                description=f.get("description", "")
            ))

        # Save insights
        for ins in rec_result["insights"]:
            db.add(RecommendationInsight(
                recommendation_id=rec_record.recommendation_id,
                icon=ins.get("icon", "✦"),
                title=ins.get("title", ""),
                body=ins.get("body", "")
            ))

        db.commit()

    return rec_result


@router.get("/real-world")
def get_real_world_recommendations(
    category: Optional[str] = Query(None, description="Category filter (entertainment, shopping, savings, fd, stocks, crypto, all)"),
    current_user: Optional[User] = Depends(get_optional_current_user),
    db: Session = Depends(get_db)
):
    """
    Returns personalized real-world recommendations with verified, clickable official links
    across Entertainment, Shopping, Savings, Fixed Deposits, Stocks, and Cryptocurrency.
    """
    return real_world_rec_service.get_personalized_recommendations(
        db=db,
        current_user=current_user,
        category_filter=category
    )


@router.get("/catalog")
def get_recommendation_catalog(
    db: Session = Depends(get_db)
):
    """
    Returns the verified catalog of official platforms and products.
    """
    items = db.query(RealWorldRecommendationItem).filter(RealWorldRecommendationItem.is_verified == True).order_by(RealWorldRecommendationItem.priority_order).all()
    return {
        "total": len(items),
        "items": [
            {
                "id": it.item_id,
                "category": it.category,
                "name": it.name,
                "official_url": it.official_url,
                "logo_icon": it.logo_icon,
                "description": it.description,
                "pricing_or_rate": it.pricing_or_rate,
                "min_amount": float(it.min_amount) if it.min_amount is not None else None,
                "tenure": it.tenure,
                "risk_level": it.risk_level,
                "terms_note": it.terms_note
            }
            for it in items
        ]
    }

