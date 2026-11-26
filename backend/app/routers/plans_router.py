import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import (
    User, MonthlyBudget, MonthlyPlan, PlanAllocation,
    AllocationBucket, AllocationValuation, NextMonthAction,
    NextMonthActionTweak
)
from app.schemas import PlanLockRequest, NextMonthApplyRequest
from app.auth import get_current_user
from app.routers.budget_router import get_current_year_month

router = APIRouter(prefix="/plans", tags=["Allocation Plans & History"])

@router.get("/current")
def get_current_plan(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    ym = get_current_year_month()
    budget = db.query(MonthlyBudget).filter(
        MonthlyBudget.user_id == current_user.user_id,
        MonthlyBudget.year_month == ym
    ).first()

    plan = db.query(MonthlyPlan).filter(
        MonthlyPlan.user_id == current_user.user_id,
        MonthlyPlan.budget_id == (budget.budget_id if budget else None)
    ).order_by(MonthlyPlan.plan_id.desc()).first()

    if not plan:
        return {"locked": False, "plan_id": None, "allocations": {}}

    alloc_map = {}
    for a in plan.allocations:
        if a.bucket:
            alloc_map[a.bucket.code] = {
                "amount": float(a.allocated_amount),
                "weight_pct": float(a.weight_pct),
                "priority": a.priority
            }

    return {
        "locked": plan.status == "locked",
        "plan_id": plan.plan_id,
        "frozen_remaining_money": float(plan.frozen_remaining_money),
        "locked_at": str(plan.locked_at) if plan.locked_at else None,
        "allocations": alloc_map
    }

@router.post("/lock")
def lock_plan(
    data: PlanLockRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    ym = get_current_year_month()
    budget = db.query(MonthlyBudget).filter(
        MonthlyBudget.user_id == current_user.user_id,
        MonthlyBudget.year_month == ym
    ).first()

    plan = MonthlyPlan(
        user_id=current_user.user_id,
        budget_id=budget.budget_id if budget else None,
        status="locked",
        frozen_remaining_money=data.frozen_remaining,
        locked_at=datetime.datetime.utcnow()
    )
    db.add(plan)
    db.commit()
    db.refresh(plan)

    total_allocated = sum(data.allocations.values())
    strat_label = (data.strategy_code or "Applied").capitalize()
    if "strategy" not in strat_label.lower():
        strat_label = f"{strat_label} Strategy"

    for b_code, amt in data.allocations.items():
        if amt is None or amt <= 0:
            continue
        code_lookup = 'others' if b_code == 'other' else b_code
        bucket = db.query(AllocationBucket).filter(
            (AllocationBucket.code == code_lookup) | (AllocationBucket.code == b_code)
        ).first()
        if bucket:
            weight = round((amt / max(1.0, total_allocated)) * 100, 1)
            alloc = PlanAllocation(
                plan_id=plan.plan_id,
                bucket_id=bucket.bucket_id,
                allocated_amount=amt,
                weight_pct=weight,
                priority="High" if weight >= 15 else "Medium"
            )
            db.add(alloc)
            db.commit()
            db.refresh(alloc)

            growth_factor = 1.05 if b_code in ['stocks', 'crypto'] else (1.02 if b_code in ['fd', 'rd'] else 1.0)
            prev_val = round(amt * 0.95, 2)
            curr_val = round(amt * growth_factor, 2) if b_code not in ['entertainment', 'shopping'] else None

            db.add(AllocationValuation(
                plan_allocation_id=alloc.plan_allocation_id,
                activity_name=f"{bucket.name} ({strat_label})",
                allocated_amount=amt,
                previous_value=prev_val,
                current_value=curr_val,
                valuation_date=datetime.date.today()
            ))

    db.commit()
    return {"status": "success", "message": "Plan successfully locked and stored in MySQL.", "plan_id": plan.plan_id}

@router.post("/apply-strategy")
def apply_strategy_plan(
    data: PlanLockRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    return lock_plan(data, current_user, db)

@router.get("/history")
def get_financial_history(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    valuations = db.query(AllocationValuation).join(PlanAllocation).join(MonthlyPlan).filter(
        MonthlyPlan.user_id == current_user.user_id
    ).order_by(AllocationValuation.valuation_id.desc()).limit(50).all()

    # If user has no valuations yet, seed a baseline history from previous month
    if not valuations:
        today = datetime.date.today()
        # ~1 month ago
        prev_date = (today.replace(day=1) - datetime.timedelta(days=15))
        baseline_plan = MonthlyPlan(
            user_id=current_user.user_id,
            budget_id=None,
            status="locked",
            frozen_remaining_money=25000.0,
            locked_at=datetime.datetime.utcnow() - datetime.timedelta(days=30)
        )
        db.add(baseline_plan)
        db.commit()
        db.refresh(baseline_plan)

        baseline_items = [
            ("savings", "Savings (Baseline)", 8000.0, 7600.0, 8000.0),
            ("fd", "Fixed Deposit (Baseline)", 5000.0, 4900.0, 5100.0),
            ("stocks", "Stocks (Baseline)", 6000.0, 5700.0, 6300.0),
            ("entertainment", "Entertainment (Baseline)", 3000.0, 3000.0, None),
            ("shopping", "Shopping (Baseline)", 3000.0, 3000.0, None),
        ]
        for b_code, act_name, amt, p_val, c_val in baseline_items:
            bucket = db.query(AllocationBucket).filter(AllocationBucket.code == b_code).first()
            if bucket:
                alloc = PlanAllocation(
                    plan_id=baseline_plan.plan_id,
                    bucket_id=bucket.bucket_id,
                    allocated_amount=amt,
                    weight_pct=round((amt / 25000.0) * 100, 1),
                    priority="High"
                )
                db.add(alloc)
                db.commit()
                db.refresh(alloc)
                db.add(AllocationValuation(
                    plan_allocation_id=alloc.plan_allocation_id,
                    activity_name=act_name,
                    allocated_amount=amt,
                    previous_value=p_val,
                    current_value=c_val,
                    valuation_date=prev_date
                ))
        db.commit()

        # Re-fetch after baseline creation
        valuations = db.query(AllocationValuation).join(PlanAllocation).join(MonthlyPlan).filter(
            MonthlyPlan.user_id == current_user.user_id
        ).order_by(AllocationValuation.valuation_id.desc()).limit(50).all()

    results = []
    for v in valuations:
        is_expense = v.current_value is None
        diff = (float(v.current_value) - float(v.previous_value)) if not is_expense else 0.0
        results.append({
            "activity": v.activity_name,
            "amount": float(v.allocated_amount),
            "prev": float(v.previous_value),
            "curr": float(v.current_value) if v.current_value is not None else None,
            "date": v.valuation_date.strftime("%b %d, %Y") if v.valuation_date else "",
            "status": "expense" if is_expense else ("good" if diff >= 0 else "bad")
        })
    return results

@router.get("/analysis")
def get_monthly_analysis(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    month_names = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    
    # Fetch all actual budgets for this user ordered chronologically
    budgets = db.query(MonthlyBudget).filter(
        MonthlyBudget.user_id == current_user.user_id
    ).order_by(MonthlyBudget.year_month.asc()).all()

    trend_labels = []
    trend_data = []

    if budgets:
        for b in budgets:
            b_inc = sum(float(i.amount) for i in b.income_entries)
            b_exp = sum(float(e.planned_amount) for e in b.expense_entries)
            b_rem = max(0.0, b_inc - b_exp)
            
            try:
                y, m = b.year_month.split("-")
                m_label = month_names[int(m) - 1]
            except Exception:
                m_label = b.year_month
            
            trend_labels.append(m_label)
            trend_data.append(round(b_rem, 2))
    else:
        # User has no saved budget yet: use current calendar month
        now = datetime.datetime.utcnow()
        curr_label = month_names[now.month - 1]
        trend_labels = [curr_label]
        trend_data = [0.0]

    # Current month summary
    ym = get_current_year_month()
    curr_b = next((b for b in budgets if b.year_month == ym), None)
    income = sum(float(i.amount) for i in curr_b.income_entries) if curr_b else 0.0
    expenses = sum(float(e.planned_amount) for e in curr_b.expense_entries) if curr_b else 0.0
    remaining = max(0.0, income - expenses)

    return {
        "income": round(income, 2),
        "expenses": round(expenses, 2),
        "remaining": round(remaining, 2),
        "trend_labels": trend_labels,
        "trend_data": trend_data,
    }

@router.get("/next-month")
def get_next_month_options(db: Session = Depends(get_db)):
    actions = db.query(NextMonthAction).all()
    res = []
    for a in actions:
        tweak_dict = {}
        for tw in a.tweaks:
            if tw.bucket:
                tweak_dict[tw.bucket.code] = float(tw.delta_weight_pct)
        res.append({
            "id": a.code,
            "title": a.title,
            "badge": a.badge,
            "text": a.description,
            "tweak": tweak_dict
        })
    return res
