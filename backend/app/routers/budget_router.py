import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import (
    User, MonthlyBudget, IncomeCategory, IncomeEntry,
    ExpenseCategory, ExpenseEntry, ExpenseCategoryGroup
)
from app.schemas import BudgetSaveRequest, BudgetSummaryResponse
from app.auth import get_current_user

router = APIRouter(prefix="/budget", tags=["Budgets & Cashflow"])

def get_current_year_month() -> str:
    now = datetime.datetime.utcnow()
    return f"{now.year}-{now.month:02d}"

@router.get("/current", response_model=BudgetSummaryResponse)
def get_current_budget(
    year_month: str = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    ym = year_month or get_current_year_month()

    budget = db.query(MonthlyBudget).filter(
        MonthlyBudget.user_id == current_user.user_id,
        MonthlyBudget.year_month == ym
    ).first()

    income_dict = {}
    expense_dict = {}
    custom_expenses = []
    gross_income = 0.0
    total_expenses = 0.0

    if budget:
        # Load user's actual saved data from DB
        for inc in budget.income_entries:
            code = inc.category.code if inc.category else "other"
            amt = float(inc.amount)
            income_dict[code] = amt
            gross_income += amt

        for exp in budget.expense_entries:
            amt = float(exp.planned_amount)
            total_expenses += amt
            if exp.category:
                expense_dict[exp.category.code] = {
                    "amount": amt,
                    "is_flexible": exp.is_flexible,
                    "due_day": exp.due_day
                }
            else:
                custom_expenses.append({
                    "id": f"custom_{exp.entry_id}",
                    "label": exp.custom_label or "Custom Expense",
                    "amount": amt,
                    "is_flexible": exp.is_flexible,
                    "due_day": exp.due_day
                })

    remaining = max(0.0, gross_income - total_expenses)
    deficit = max(0.0, total_expenses - gross_income)

    return {
        "year_month": ym,
        "gross_income": round(gross_income, 2),
        "total_expenses": round(total_expenses, 2),
        "remaining_money": round(remaining, 2),
        "deficit": round(deficit, 2),
        "income": income_dict,
        "expenses": expense_dict,
        "custom_expenses": custom_expenses
    }

@router.post("/save", response_model=BudgetSummaryResponse)
def save_budget(
    data: BudgetSaveRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    ym = data.year_month or get_current_year_month()

    budget = db.query(MonthlyBudget).filter(
        MonthlyBudget.user_id == current_user.user_id,
        MonthlyBudget.year_month == ym
    ).first()

    if not budget:
        budget = MonthlyBudget(user_id=current_user.user_id, year_month=ym, status="active")
        db.add(budget)
        db.commit()
        db.refresh(budget)
    else:
        # Clean existing entries to replace with new snapshot
        db.query(IncomeEntry).filter(IncomeEntry.budget_id == budget.budget_id).delete()
        db.query(ExpenseEntry).filter(ExpenseEntry.budget_id == budget.budget_id).delete()
        db.commit()

    # Save income entries
    for inc in data.income:
        cat = db.query(IncomeCategory).filter(IncomeCategory.code == inc.code).first()
        if cat:
            db.add(IncomeEntry(
                budget_id=budget.budget_id,
                category_id=cat.category_id,
                amount=inc.amount
            ))

    # Save expense entries
    for exp in data.expenses:
        if exp.code.startswith("custom_") or exp.custom_label:
            db.add(ExpenseEntry(
                budget_id=budget.budget_id,
                category_id=None,
                custom_label=exp.custom_label or exp.code,
                planned_amount=exp.amount,
                actual_amount=exp.amount,
                is_flexible=exp.is_flexible,
                due_day=exp.due_day
            ))
        else:
            cat = db.query(ExpenseCategory).filter(ExpenseCategory.code == exp.code).first()
            if cat:
                db.add(ExpenseEntry(
                    budget_id=budget.budget_id,
                    category_id=cat.category_id,
                    custom_label=None,
                    planned_amount=exp.amount,
                    actual_amount=exp.amount,
                    is_flexible=exp.is_flexible,
                    due_day=exp.due_day
                ))

    db.commit()
    return get_current_budget(year_month=ym, current_user=current_user, db=db)
