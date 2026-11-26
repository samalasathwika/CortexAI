from typing import List, Optional, Dict, Any
from pydantic import BaseModel, Field

# ----------------- AUTH SCHEMAS -----------------
class UserRegister(BaseModel):
    name: str = Field(..., min_length=1)
    email: str = Field(..., min_length=3)
    password: str = Field(..., min_length=6)
    role: str = Field("employee", pattern="^(student|employee)$")

class UserLogin(BaseModel):
    email: str
    password: str
    role: Optional[str] = None

class Token(BaseModel):
    access_token: str
    token_type: str
    user: Dict[str, Any]

class UserProfileUpdate(BaseModel):
    full_name: Optional[str] = None
    avatar_url: Optional[str] = None
    role: Optional[str] = None
    risk_tolerance: Optional[str] = None
    lifestyle_pct: Optional[float] = None
    theme_mode: Optional[str] = None
    card_style: Optional[str] = None
    accent_color: Optional[str] = None

class PasswordChange(BaseModel):
    current_password: str
    new_password: str

class ForgotPasswordRequest(BaseModel):
    email: str

class ForgotPasswordValidateOtp(BaseModel):
    email: str
    otp: str

class ForgotPasswordVerify(BaseModel):
    email: str
    otp: str
    new_password: str

# ----------------- BUDGET & EXPENSE SCHEMAS -----------------
class IncomeItem(BaseModel):
    code: str
    amount: float

class ExpenseItem(BaseModel):
    code: str
    amount: float
    is_flexible: bool = False
    due_day: Optional[int] = None
    custom_label: Optional[str] = None

class BudgetSaveRequest(BaseModel):
    year_month: Optional[str] = None  # e.g. "2026-11"
    income: List[IncomeItem] = []
    expenses: List[ExpenseItem] = []

class BudgetSummaryResponse(BaseModel):
    year_month: str
    gross_income: float
    total_expenses: float
    remaining_money: float
    deficit: float
    income: Dict[str, float]
    expenses: Dict[str, Dict[str, Any]]
    custom_expenses: List[Dict[str, Any]]

# ----------------- GOALS & PREFERENCES SCHEMAS -----------------
class GoalDetail(BaseModel):
    type_code: str
    target: float = 0.0
    deadline: Optional[str] = None
    priority: int = 3

class GoalsAndPreferencesRequest(BaseModel):
    risk: str = "moderate"
    lifestyle_pct: float = 15.0
    goals: List[GoalDetail] = []
    interests: List[str] = []
    preferred_finance: List[str] = []

# ----------------- RECOMMENDATION SCHEMAS -----------------
class RecommendationGenerateRequest(BaseModel):
    strategy: Optional[str] = None  # conservative, balanced, accelerated
    lifestyle_pct: Optional[float] = None
    risk: Optional[str] = None

class AllocationItem(BaseModel):
    bucket_code: str
    name: str
    color: str
    weight_pct: float
    amount: float
    priority: str = "Medium"

class RecommendationResponse(BaseModel):
    strategy_code: str
    strategy_name: str
    disposable_income: float
    allocations: List[AllocationItem]
    rationales: List[str]
    factors: List[Dict[str, Any]]
    insights: List[Dict[str, Any]]

# ----------------- PLAN SCHEMAS -----------------
class PlanLockRequest(BaseModel):
    strategy_code: str
    allocations: Dict[str, float]  # bucket_code -> allocated_amount
    frozen_remaining: float

class NextMonthApplyRequest(BaseModel):
    action_code: str  # continue, modify, review
    custom_weights: Optional[Dict[str, float]] = None

# ----------------- OMDB & SHOPPING SCHEMAS -----------------
class MovieRecommendationItem(BaseModel):
    imdb_id: str
    title: str
    year: str
    poster: str
    genre: str
    rating: str
    runtime: str
    plot: str
    suggested_budget: float
    why_recommended: str

class ShoppingProductItem(BaseModel):
    id: str
    title: str
    category: str
    price: float
    rating: float
    image_url: str
    description: str
    affiliate_tag: str = "cortex_deals"
    is_budget_friendly: bool = True
