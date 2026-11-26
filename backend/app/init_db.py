import logging
from sqlalchemy.orm import Session
from app.database import Base, engine, SessionLocal
from app.models import (
    IncomeCategory, ExpenseCategoryGroup, ExpenseCategory,
    AllocationBucket, Strategy, StrategyBucketWeight, StrategyRationale,
    GoalType, InterestOption, NextMonthAction, NextMonthActionTweak,
    RealWorldRecommendationItem
)

logger = logging.getLogger("cortex.init_db")

def init_db(db: Session):
    Base.metadata.create_all(bind=engine)

    # 1. Income Categories
    income_cats = [
        {"code": "salary", "name": "Monthly Salary", "description": "Primary employment earnings"},
        {"code": "allowance", "name": "Monthly Allowance", "description": "Family allowance or stipend"},
        {"code": "scholarship", "name": "Scholarship", "description": "Academic or merit financial aid"},
        {"code": "other", "name": "Other Income", "description": "Freelance, side projects or gifts"},
    ]
    for ic in income_cats:
        if not db.query(IncomeCategory).filter_by(code=ic["code"]).first():
            db.add(IncomeCategory(**ic))
    db.commit()

    # 2. Expense Groups
    groups = [
        {"name": "Regular Bills", "display_order": 1},
        {"name": "Debt & Obligations", "display_order": 2},
        {"name": "Subscriptions & Insurance", "display_order": 3},
        {"name": "Student Essentials", "display_order": 4},
        {"name": "Custom", "display_order": 5},
    ]
    group_map = {}
    for g in groups:
        grp = db.query(ExpenseCategoryGroup).filter_by(name=g["name"]).first()
        if not grp:
            grp = ExpenseCategoryGroup(**g)
            db.add(grp)
            db.commit()
            db.refresh(grp)
        group_map[g["name"]] = grp.group_id

    # 3. Expense Categories
    exp_cats = [
        {"code": "rent", "name": "Rent", "group": "Regular Bills", "nature": "essential"},
        {"code": "electricity", "name": "Electricity", "group": "Regular Bills", "nature": "essential"},
        {"code": "water", "name": "Water", "group": "Regular Bills", "nature": "essential"},
        {"code": "food", "name": "Food", "group": "Regular Bills", "nature": "essential"},
        {"code": "transport", "name": "Transportation", "group": "Regular Bills", "nature": "essential"},
        {"code": "insurance", "name": "Insurance / EMI", "group": "Regular Bills", "nature": "essential"},
        {"code": "other_bills", "name": "Other Regular Bills", "group": "Regular Bills", "nature": "essential"},

        {"code": "credit_card", "name": "Credit Card Bills", "group": "Debt & Obligations", "nature": "essential"},
        {"code": "student_loan", "name": "Student Loans", "group": "Debt & Obligations", "nature": "essential"},
        {"code": "gas", "name": "Gas", "group": "Debt & Obligations", "nature": "essential"},
        {"code": "groceries", "name": "Groceries", "group": "Debt & Obligations", "nature": "essential"},
        {"code": "recharges", "name": "Recharges (Mobile, Wi-Fi, TV)", "group": "Debt & Obligations", "nature": "essential"},

        {"code": "auto_insurance", "name": "Auto Insurance", "group": "Subscriptions & Insurance", "nature": "essential"},
        {"code": "health_insurance", "name": "Health Insurance", "group": "Subscriptions & Insurance", "nature": "essential"},
        {"code": "home_insurance", "name": "Home Insurance", "group": "Subscriptions & Insurance", "nature": "essential"},

        {"code": "education", "name": "Education", "group": "Student Essentials", "nature": "essential"},
        {"code": "student_food", "name": "Food", "group": "Student Essentials", "nature": "essential"},
        {"code": "student_travel", "name": "Travel", "group": "Student Essentials", "nature": "essential"},
        {"code": "entertainment", "name": "Entertainment", "group": "Student Essentials", "nature": "discretionary"},
        {"code": "personal", "name": "Personal Needs", "group": "Student Essentials", "nature": "essential"},
        {"code": "student_other", "name": "Other Expenses", "group": "Student Essentials", "nature": "essential"},
    ]
    for ec in exp_cats:
        if not db.query(ExpenseCategory).filter_by(code=ec["code"]).first():
            db.add(ExpenseCategory(
                code=ec["code"],
                name=ec["name"],
                group_id=group_map[ec["group"]],
                nature=ec["nature"]
            ))
    db.commit()

    # 4. Allocation Buckets
    buckets = [
        {"code": "savings", "name": "Savings", "color": "#3B82F6", "description": "Liquid emergency buffer", "bucket_group": "saving"},
        {"code": "fd", "name": "Fixed Deposit", "color": "#22D3EE", "description": "Locked-in, low-risk growth", "bucket_group": "investment"},
        {"code": "rd", "name": "Recurring Deposit", "color": "#5EEAD4", "description": "Disciplined monthly investing", "bucket_group": "investment"},
        {"code": "stocks", "name": "Stocks", "color": "#F92E92", "description": "Market-linked, higher risk", "bucket_group": "investment"},
        {"code": "crypto", "name": "Crypto", "color": "#A855F7", "description": "High-risk, high-volatility", "bucket_group": "investment"},
        {"code": "chits", "name": "Chits", "color": "#818CF8", "description": "Community pooled savings", "bucket_group": "saving"},
        {"code": "entertainment", "name": "Entertainment", "color": "#FBBF24", "description": "Movies, dining, leisure", "bucket_group": "lifestyle"},
        {"code": "shopping", "name": "Shopping", "color": "#C084FC", "description": "Lifestyle & personal purchases", "bucket_group": "lifestyle"},
        {"code": "others", "name": "Others", "color": "#94A3B8", "description": "Miscellaneous / uncategorized", "bucket_group": "other"},
    ]
    bucket_map = {}
    for b in buckets:
        buck = db.query(AllocationBucket).filter_by(code=b["code"]).first()
        if not buck:
            buck = AllocationBucket(**b)
            db.add(buck)
            db.commit()
            db.refresh(buck)
        bucket_map[b["code"]] = buck.bucket_id

    # 5. Strategies
    strats = [
        {"code": "conservative", "name": "Conservative", "description": "Capital preservation with steady, low-risk returns.", "risk_level": "conservative"},
        {"code": "balanced", "name": "Balanced", "description": "Blend of stability and moderate market-linked growth.", "risk_level": "moderate"},
        {"code": "accelerated", "name": "Accelerated", "description": "Maximises growth with higher equity and crypto exposure.", "risk_level": "aggressive"},
    ]
    strat_map = {}
    for s in strats:
        st = db.query(Strategy).filter_by(code=s["code"]).first()
        if not st:
            st = Strategy(**s)
            db.add(st)
            db.commit()
            db.refresh(st)
        strat_map[s["code"]] = st.strategy_id

    # 6. Strategy Weights
    weights_data = {
        "conservative": {"savings": 30, "fd": 20, "rd": 10, "stocks": 5, "crypto": 0, "chits": 5, "entertainment": 10, "shopping": 10, "others": 10},
        "balanced":     {"savings": 20, "fd": 15, "rd": 10, "stocks": 15, "crypto": 5, "chits": 5, "entertainment": 12, "shopping": 13, "others": 5},
        "accelerated":  {"savings": 35, "fd": 10, "rd": 5,  "stocks": 20, "crypto": 10, "chits": 0, "entertainment": 5,  "shopping": 5,  "others": 10},
    }
    for strat_code, weights in weights_data.items():
        s_id = strat_map[strat_code]
        for b_code, w in weights.items():
            b_id = bucket_map[b_code]
            if not db.query(StrategyBucketWeight).filter_by(strategy_id=s_id, bucket_id=b_id).first():
                db.add(StrategyBucketWeight(strategy_id=s_id, bucket_id=b_id, weight_pct=w))
    db.commit()

    # 7. Strategy Rationales
    rationales_data = {
        "conservative": [
            "Strong allocation to liquid savings for immediate emergencies.",
            "Fixed & recurring deposits provide guaranteed, steady growth.",
            "Minimal exposure to volatile market instruments."
        ],
        "balanced": [
            "Balances cash buffer with disciplined recurring investments.",
            "Controlled stock exposure captures market upsides safely.",
            "Dedicated lifestyle budget protects discretionary spending."
        ],
        "accelerated": [
            "Prioritises long-term equity compounding and higher returns.",
            "Controlled exposure to high-growth emerging digital assets.",
            "Streamlined discretionary spend directed toward wealth creation."
        ]
    }
    for strat_code, bullets in rationales_data.items():
        s_id = strat_map[strat_code]
        for idx, text in enumerate(bullets, start=1):
            if not db.query(StrategyRationale).filter_by(strategy_id=s_id, display_order=idx).first():
                db.add(StrategyRationale(strategy_id=s_id, display_order=idx, bullet_text=text))
    db.commit()

    # 8. Goal Types
    goals = [
        {"code": "emergency", "name": "Emergency Fund", "icon": "🛡️"},
        {"code": "debt_clearance", "name": "Clear High-Interest Debt", "icon": "⚡"},
        {"code": "vacation", "name": "Vacation / Travel", "icon": "✈️"},
        {"code": "big_purchase", "name": "Big Purchase", "icon": "🛍️"},
        {"code": "investing", "name": "Invest for Future", "icon": "📈"},
        {"code": "none", "name": "No specific goal right now", "icon": "⚪"},
    ]
    for g in goals:
        if not db.query(GoalType).filter_by(code=g["code"]).first():
            db.add(GoalType(**g))
    db.commit()

    # 9. Interest Options
    interests = ['Shopping', 'Movies', 'Entertainment', 'Travel', 'Lifestyle', 'Personal Care', 'Tech', 'Dining']
    for i_name in interests:
        if not db.query(InterestOption).filter_by(name=i_name).first():
            db.add(InterestOption(name=i_name))
    db.commit()

    # 10. Next Month Actions
    next_actions = [
        {
            "code": "continue",
            "title": "Continue",
            "badge": "Recommended",
            "description": "Your previous allocation performed positively. You may consider maintaining a similar allocation next month.",
            "tweaks": {}
        },
        {
            "code": "modify",
            "title": "Modify",
            "badge": "Rebalance",
            "description": "One allocation was roughly flat. A small shift toward your top goal could help next month.",
            "tweaks": {"savings": 5, "fd": 5, "stocks": -5, "entertainment": -5}
        },
        {
            "code": "review",
            "title": "Review / Reduce",
            "badge": "Caution",
            "description": "This allocation experienced a decline. Consider reviewing it before making a similar decision.",
            "tweaks": {"savings": 10, "fd": 5, "stocks": -15, "crypto": -5, "others": 5}
        }
    ]
    for na in next_actions:
        action = db.query(NextMonthAction).filter_by(code=na["code"]).first()
        if not action:
            action = NextMonthAction(code=na["code"], title=na["title"], badge=na["badge"], description=na["description"])
            db.add(action)
            db.commit()
            db.refresh(action)
            for b_code, delta in na["tweaks"].items():
                if b_code in bucket_map:
                    db.add(NextMonthActionTweak(action_id=action.action_id, bucket_id=bucket_map[b_code], delta_weight_pct=delta))
            db.commit()

    # 8. Real-World Recommendations Catalog (Verified Official Links stored in MySQL/Relational DB)
    from app.services.real_world_rec_service import DEFAULT_CATALOG_ITEMS

    for item in DEFAULT_CATALOG_ITEMS:
        existing_item = db.query(RealWorldRecommendationItem).filter_by(
            name=item["name"],
            category=item["category"]
        ).first()
        if not existing_item:
            db.add(RealWorldRecommendationItem(**item))
        else:
            for k, v in item.items():
                setattr(existing_item, k, v)
    db.commit()
    logger.info(f"Synchronized {len(DEFAULT_CATALOG_ITEMS)} verified real-world recommendations into MySQL database.")

    logger.info("Database schema and master reference tables verified successfully.")

if __name__ == "__main__":
    db = SessionLocal()
    try:
        init_db(db)
        print("Initialization completed!")
    finally:
        db.close()
