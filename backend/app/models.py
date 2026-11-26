import datetime
from sqlalchemy import (
    Column, Integer, String, Boolean, Numeric, DateTime, Date,
    ForeignKey, Text, UniqueConstraint
)
from sqlalchemy.orm import relationship
from app.database import Base

class User(Base):
    __tablename__ = "users"

    user_id = Column(Integer, primary_key=True, autoincrement=True)
    email = Column(String(255), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    role = Column(String(20), nullable=False, default="employee")  # 'student' or 'employee'
    status = Column(String(20), nullable=False, default="active")  # 'active', 'inactive', 'suspended'
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    profile = relationship("UserProfile", back_populates="user", uselist=False, cascade="all, delete-orphan")
    preferences = relationship("UserPreference", back_populates="user", uselist=False, cascade="all, delete-orphan")
    budgets = relationship("MonthlyBudget", back_populates="user", cascade="all, delete-orphan")
    goals = relationship("FinancialGoal", back_populates="user", cascade="all, delete-orphan")
    interests = relationship("UserInterest", back_populates="user", cascade="all, delete-orphan")
    recommendations = relationship("Recommendation", back_populates="user", cascade="all, delete-orphan")
    plans = relationship("MonthlyPlan", back_populates="user", cascade="all, delete-orphan")


class UserProfile(Base):
    __tablename__ = "user_profiles"

    profile_id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), unique=True, nullable=False)
    full_name = Column(String(150), nullable=False, default="")
    avatar_url = Column(String(500), nullable=True)
    currency = Column(String(3), nullable=False, default="INR")
    risk_tolerance = Column(String(20), nullable=False, default="moderate")  # conservative, moderate, aggressive
    lifestyle_pct = Column(Numeric(5, 2), nullable=False, default=15.00)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    user = relationship("User", back_populates="profile")


class UserPreference(Base):
    __tablename__ = "user_preferences"

    pref_id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), unique=True, nullable=False)
    theme_mode = Column(String(20), nullable=False, default="dark")  # dark, light, oled, midnight
    card_style = Column(String(20), nullable=False, default="glass")  # glass, flat, bordered
    accent_color = Column(String(7), nullable=False, default="#F92E92")
    animations_enabled = Column(Boolean, nullable=False, default=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    user = relationship("User", back_populates="preferences")


class UserSession(Base):
    __tablename__ = "user_sessions"

    session_id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    session_token_hash = Column(String(64), unique=True, nullable=False)
    ip_address = Column(String(45), nullable=True)
    user_agent = Column(String(500), nullable=True)
    expires_at = Column(DateTime, nullable=False)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)


class MonthlyBudget(Base):
    __tablename__ = "monthly_budgets"

    budget_id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    year_month = Column(String(7), nullable=False)  # 'YYYY-MM'
    status = Column(String(20), nullable=False, default="active")
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    __table_args__ = (UniqueConstraint("user_id", "year_month", name="uq_user_year_month"),)

    user = relationship("User", back_populates="budgets")
    income_entries = relationship("IncomeEntry", back_populates="budget", cascade="all, delete-orphan")
    expense_entries = relationship("ExpenseEntry", back_populates="budget", cascade="all, delete-orphan")
    plans = relationship("MonthlyPlan", back_populates="budget")


class IncomeCategory(Base):
    __tablename__ = "income_categories"

    category_id = Column(Integer, primary_key=True, autoincrement=True)
    code = Column(String(50), unique=True, nullable=False)  # salary, allowance, scholarship, other
    name = Column(String(100), nullable=False)
    description = Column(String(255), nullable=True)


class IncomeEntry(Base):
    __tablename__ = "income_entries"

    entry_id = Column(Integer, primary_key=True, autoincrement=True)
    budget_id = Column(Integer, ForeignKey("monthly_budgets.budget_id", ondelete="CASCADE"), nullable=False)
    category_id = Column(Integer, ForeignKey("income_categories.category_id"), nullable=False)
    amount = Column(Numeric(12, 2), nullable=False, default=0.00)
    notes = Column(String(255), nullable=True)

    budget = relationship("MonthlyBudget", back_populates="income_entries")
    category = relationship("IncomeCategory")


class ExpenseCategoryGroup(Base):
    __tablename__ = "expense_category_groups"

    group_id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(100), unique=True, nullable=False)
    display_order = Column(Integer, nullable=False, default=0)

    categories = relationship("ExpenseCategory", back_populates="group")


class ExpenseCategory(Base):
    __tablename__ = "expense_categories"

    category_id = Column(Integer, primary_key=True, autoincrement=True)
    group_id = Column(Integer, ForeignKey("expense_category_groups.group_id"), nullable=False)
    code = Column(String(50), unique=True, nullable=False)
    name = Column(String(100), nullable=False)
    nature = Column(String(20), nullable=False, default="essential")  # essential or discretionary
    is_active = Column(Boolean, nullable=False, default=True)

    group = relationship("ExpenseCategoryGroup", back_populates="categories")


class ExpenseEntry(Base):
    __tablename__ = "expense_entries"

    entry_id = Column(Integer, primary_key=True, autoincrement=True)
    budget_id = Column(Integer, ForeignKey("monthly_budgets.budget_id", ondelete="CASCADE"), nullable=False)
    category_id = Column(Integer, ForeignKey("expense_categories.category_id"), nullable=True)
    custom_label = Column(String(100), nullable=True)
    planned_amount = Column(Numeric(12, 2), nullable=False, default=0.00)
    actual_amount = Column(Numeric(12, 2), nullable=False, default=0.00)
    is_flexible = Column(Boolean, nullable=False, default=False)
    due_day = Column(Integer, nullable=True)

    budget = relationship("MonthlyBudget", back_populates="expense_entries")
    category = relationship("ExpenseCategory")


class GoalType(Base):
    __tablename__ = "goal_types"

    type_id = Column(Integer, primary_key=True, autoincrement=True)
    code = Column(String(50), unique=True, nullable=False)
    name = Column(String(100), nullable=False)
    icon = Column(String(10), nullable=True)


class FinancialGoal(Base):
    __tablename__ = "financial_goals"

    goal_id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    type_id = Column(Integer, ForeignKey("goal_types.type_id"), nullable=False)
    target_amount = Column(Numeric(12, 2), nullable=False, default=0.00)
    current_amount = Column(Numeric(12, 2), nullable=False, default=0.00)
    deadline_date = Column(Date, nullable=True)
    priority = Column(Integer, nullable=False, default=3)  # 1 to 5
    status = Column(String(20), nullable=False, default="in_progress")

    user = relationship("User", back_populates="goals")
    goal_type = relationship("GoalType")


class InterestOption(Base):
    __tablename__ = "interest_options"

    interest_id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String(50), unique=True, nullable=False)


class UserInterest(Base):
    __tablename__ = "user_interests"

    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), primary_key=True)
    interest_id = Column(Integer, ForeignKey("interest_options.interest_id"), primary_key=True)

    user = relationship("User", back_populates="interests")
    interest = relationship("InterestOption")


class Strategy(Base):
    __tablename__ = "strategies"

    strategy_id = Column(Integer, primary_key=True, autoincrement=True)
    code = Column(String(50), unique=True, nullable=False)  # conservative, balanced, accelerated
    name = Column(String(100), nullable=False)
    description = Column(Text, nullable=True)
    risk_level = Column(String(20), nullable=False, default="moderate")

    weights = relationship("StrategyBucketWeight", back_populates="strategy")
    rationales = relationship("StrategyRationale", back_populates="strategy")


class AllocationBucket(Base):
    __tablename__ = "allocation_buckets"

    bucket_id = Column(Integer, primary_key=True, autoincrement=True)
    code = Column(String(50), unique=True, nullable=False)  # savings, fd, rd, stocks, crypto, chits, entertainment, shopping, others
    name = Column(String(100), nullable=False)
    color = Column(String(7), nullable=False)
    description = Column(String(255), nullable=True)
    bucket_group = Column(String(50), nullable=False)  # saving, investment, lifestyle, other


class StrategyBucketWeight(Base):
    __tablename__ = "strategy_bucket_weights"

    weight_id = Column(Integer, primary_key=True, autoincrement=True)
    strategy_id = Column(Integer, ForeignKey("strategies.strategy_id"), nullable=False)
    bucket_id = Column(Integer, ForeignKey("allocation_buckets.bucket_id"), nullable=False)
    weight_pct = Column(Numeric(5, 2), nullable=False)

    strategy = relationship("Strategy", back_populates="weights")
    bucket = relationship("AllocationBucket")


class StrategyRationale(Base):
    __tablename__ = "strategy_rationales"

    rationale_id = Column(Integer, primary_key=True, autoincrement=True)
    strategy_id = Column(Integer, ForeignKey("strategies.strategy_id"), nullable=False)
    display_order = Column(Integer, nullable=False, default=1)
    bullet_text = Column(String(255), nullable=False)

    strategy = relationship("Strategy", back_populates="rationales")


class Recommendation(Base):
    __tablename__ = "recommendations"

    recommendation_id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    budget_id = Column(Integer, ForeignKey("monthly_budgets.budget_id", ondelete="SET NULL"), nullable=True)
    strategy_id = Column(Integer, ForeignKey("strategies.strategy_id"), nullable=False)
    disposable_income = Column(Numeric(12, 2), nullable=False)
    engine_version = Column(String(50), nullable=False, default="cortex-v2.1")
    created_at = Column(DateTime, default=datetime.datetime.utcnow)

    user = relationship("User", back_populates="recommendations")
    strategy = relationship("Strategy")
    allocations = relationship("RecommendationAllocation", back_populates="recommendation", cascade="all, delete-orphan")
    factors = relationship("RecommendationFactor", back_populates="recommendation", cascade="all, delete-orphan")
    insights = relationship("RecommendationInsight", back_populates="recommendation", cascade="all, delete-orphan")


class RecommendationAllocation(Base):
    __tablename__ = "recommendation_allocations"

    rec_alloc_id = Column(Integer, primary_key=True, autoincrement=True)
    recommendation_id = Column(Integer, ForeignKey("recommendations.recommendation_id", ondelete="CASCADE"), nullable=False)
    bucket_id = Column(Integer, ForeignKey("allocation_buckets.bucket_id"), nullable=False)
    weight_pct = Column(Numeric(5, 2), nullable=False)
    allocated_amount = Column(Numeric(12, 2), nullable=False)

    recommendation = relationship("Recommendation", back_populates="allocations")
    bucket = relationship("AllocationBucket")


class RecommendationFactor(Base):
    __tablename__ = "recommendation_factors"

    factor_id = Column(Integer, primary_key=True, autoincrement=True)
    recommendation_id = Column(Integer, ForeignKey("recommendations.recommendation_id", ondelete="CASCADE"), nullable=False)
    factor_name = Column(String(100), nullable=False)
    impact_weight = Column(Numeric(5, 2), nullable=False)
    description = Column(String(255), nullable=True)

    recommendation = relationship("Recommendation", back_populates="factors")


class RecommendationInsight(Base):
    __tablename__ = "recommendation_insights"

    insight_id = Column(Integer, primary_key=True, autoincrement=True)
    recommendation_id = Column(Integer, ForeignKey("recommendations.recommendation_id", ondelete="CASCADE"), nullable=False)
    icon = Column(String(10), nullable=True)
    title = Column(String(150), nullable=False)
    body = Column(Text, nullable=False)

    recommendation = relationship("Recommendation", back_populates="insights")


class MonthlyPlan(Base):
    __tablename__ = "monthly_plans"

    plan_id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.user_id", ondelete="CASCADE"), nullable=False)
    budget_id = Column(Integer, ForeignKey("monthly_budgets.budget_id", ondelete="SET NULL"), nullable=True)
    recommendation_id = Column(Integer, ForeignKey("recommendations.recommendation_id", ondelete="SET NULL"), nullable=True)
    status = Column(String(20), nullable=False, default="draft")  # draft, locked, executed
    frozen_remaining_money = Column(Numeric(12, 2), nullable=False, default=0.00)
    locked_at = Column(DateTime, nullable=True)
    created_at = Column(DateTime, default=datetime.datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.datetime.utcnow, onupdate=datetime.datetime.utcnow)

    user = relationship("User", back_populates="plans")
    budget = relationship("MonthlyBudget", back_populates="plans")
    allocations = relationship("PlanAllocation", back_populates="plan", cascade="all, delete-orphan")


class PlanAllocation(Base):
    __tablename__ = "plan_allocations"

    plan_allocation_id = Column(Integer, primary_key=True, autoincrement=True)
    plan_id = Column(Integer, ForeignKey("monthly_plans.plan_id", ondelete="CASCADE"), nullable=False)
    bucket_id = Column(Integer, ForeignKey("allocation_buckets.bucket_id"), nullable=False)
    allocated_amount = Column(Numeric(12, 2), nullable=False, default=0.00)
    weight_pct = Column(Numeric(5, 2), nullable=False, default=0.00)
    priority = Column(String(20), nullable=False, default="Medium")

    plan = relationship("MonthlyPlan", back_populates="allocations")
    bucket = relationship("AllocationBucket")
    valuations = relationship("AllocationValuation", back_populates="plan_allocation", cascade="all, delete-orphan")


class AllocationValuation(Base):
    __tablename__ = "allocation_valuations"

    valuation_id = Column(Integer, primary_key=True, autoincrement=True)
    plan_allocation_id = Column(Integer, ForeignKey("plan_allocations.plan_allocation_id", ondelete="CASCADE"), nullable=False)
    activity_name = Column(String(100), nullable=False)
    allocated_amount = Column(Numeric(12, 2), nullable=False)
    previous_value = Column(Numeric(12, 2), nullable=False)
    current_value = Column(Numeric(12, 2), nullable=True)
    valuation_date = Column(Date, default=datetime.date.today)

    plan_allocation = relationship("PlanAllocation", back_populates="valuations")


class NextMonthAction(Base):
    __tablename__ = "next_month_actions"

    action_id = Column(Integer, primary_key=True, autoincrement=True)
    code = Column(String(50), unique=True, nullable=False)  # continue, modify, review
    title = Column(String(100), nullable=False)
    badge = Column(String(50), nullable=False)
    description = Column(Text, nullable=False)

    tweaks = relationship("NextMonthActionTweak", back_populates="action")


class NextMonthActionTweak(Base):
    __tablename__ = "next_month_action_tweaks"

    tweak_id = Column(Integer, primary_key=True, autoincrement=True)
    action_id = Column(Integer, ForeignKey("next_month_actions.action_id"), nullable=False)
    bucket_id = Column(Integer, ForeignKey("allocation_buckets.bucket_id"), nullable=False)
    delta_weight_pct = Column(Numeric(5, 2), nullable=False)

    action = relationship("NextMonthAction", back_populates="tweaks")
    bucket = relationship("AllocationBucket")


class RealWorldRecommendationItem(Base):
    __tablename__ = "real_world_recommendations"

    item_id = Column(Integer, primary_key=True, autoincrement=True)
    category = Column(String(50), nullable=False, index=True)  # entertainment, shopping, savings, fd, stocks, crypto
    name = Column(String(100), nullable=False)
    official_url = Column(String(500), nullable=False)
    logo_icon = Column(String(100), nullable=False)
    description = Column(Text, nullable=False)
    pricing_or_rate = Column(String(200), nullable=True)
    min_amount = Column(Numeric(12, 2), nullable=True)
    tenure = Column(String(100), nullable=True)
    risk_level = Column(String(50), nullable=False, default="Low")  # Low, Moderate, High, Very High, Educational
    terms_note = Column(Text, nullable=True)
    suitable_personas = Column(String(100), default="student,employee")
    suitable_risk_levels = Column(String(100), default="conservative,moderate,aggressive")
    priority_order = Column(Integer, default=1)
    is_verified = Column(Boolean, default=True)

