import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import (
    User, UserProfile, FinancialGoal, GoalType,
    InterestOption, UserInterest
)
from app.schemas import GoalsAndPreferencesRequest
from app.auth import get_current_user

router = APIRouter(prefix="/goals", tags=["Goals & Preferences"])

@router.get("")
def get_user_goals_and_preferences(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.user_id).first()
    risk = profile.risk_tolerance if profile else "moderate"
    lifestyle_pct = float(profile.lifestyle_pct) if profile else 15.0

    # User goals
    goals_query = db.query(FinancialGoal).filter(
        FinancialGoal.user_id == current_user.user_id,
        FinancialGoal.status == "in_progress"
    ).all()

    goals_list = []
    goal_details = {}
    for g in goals_query:
        if g.goal_type:
            code = g.goal_type.code
            goals_list.append(code)
            goal_details[code] = {
                "target": float(g.target_amount),
                "deadline": str(g.deadline_date) if g.deadline_date else "",
                "priority": g.priority
            }

    if not goals_list:
        goals_list = ["emergency"]
        goal_details["emergency"] = {"target": 100000.0, "deadline": "", "priority": 3}

    # User interests
    interests_query = db.query(UserInterest).filter(UserInterest.user_id == current_user.user_id).all()
    interests_list = [ui.interest.name for ui in interests_query if ui.interest]
    if not interests_list:
        interests_list = ["Shopping", "Movies", "Entertainment"]

    return {
        "risk": risk,
        "lifestyle_pct": lifestyle_pct,
        "goals": goals_list,
        "goal_details": goal_details,
        "interests": interests_list,
        "preferred_finance": ["Savings", "Fixed Deposit", "Stocks"]
    }

@router.post("")
def save_user_goals_and_preferences(
    data: GoalsAndPreferencesRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Update profile
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.user_id).first()
    if profile:
        profile.risk_tolerance = data.risk
        profile.lifestyle_pct = data.lifestyle_pct
        db.commit()

    # Update goals
    # Clear existing in_progress goals
    db.query(FinancialGoal).filter(
        FinancialGoal.user_id == current_user.user_id,
        FinancialGoal.status == "in_progress"
    ).delete()

    for g in data.goals:
        gt = db.query(GoalType).filter(GoalType.code == g.type_code).first()
        if gt:
            deadline = None
            if g.deadline:
                try:
                    deadline = datetime.date.fromisoformat(g.deadline)
                except Exception:
                    deadline = None

            db.add(FinancialGoal(
                user_id=current_user.user_id,
                type_id=gt.type_id,
                target_amount=g.target,
                current_amount=0.0,
                deadline_date=deadline,
                priority=g.priority,
                status="in_progress"
            ))

    # Update interests
    db.query(UserInterest).filter(UserInterest.user_id == current_user.user_id).delete()
    for name in data.interests:
        opt = db.query(InterestOption).filter(InterestOption.name == name).first()
        if opt:
            db.add(UserInterest(user_id=current_user.user_id, interest_id=opt.interest_id))

    db.commit()
    return get_user_goals_and_preferences(current_user=current_user, db=db)
