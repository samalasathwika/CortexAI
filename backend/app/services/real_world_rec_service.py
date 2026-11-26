import logging
from typing import List, Dict, Any, Optional
from sqlalchemy.orm import Session

from app.models import (
    RealWorldRecommendationItem, User, UserProfile, MonthlyBudget,
    FinancialGoal, UserInterest
)
from app.services.real_time_market_service import real_time_market_service

logger = logging.getLogger("cortex.real_world_rec")

DEFAULT_CATALOG_ITEMS = [
    # 1. Entertainment & Movies
    {
        "category": "entertainment",
        "name": "Netflix",
        "official_url": "https://www.netflix.com/",
        "logo_icon": "🎬",
        "description": "Streaming entertainment service offering movies, original series, documentaries, and global cinema across screens.",
        "pricing_or_rate": "Mobile: ₹149/mo · Basic: ₹199/mo · Standard: ₹499/mo",
        "min_amount": 149.0,
        "tenure": "Monthly subscription",
        "risk_level": "None",
        "terms_note": "Cancel anytime. Billed monthly. Ultra HD requires Premium plan.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 1
    },
    {
        "category": "entertainment",
        "name": "Amazon Prime Video",
        "official_url": "https://www.primevideo.com/",
        "logo_icon": "📺",
        "description": "Popular video streaming platform bundled with free fast Amazon shopping delivery and Prime Music access.",
        "pricing_or_rate": "₹299/mo or ₹1,499/year (All-in-one bundle)",
        "min_amount": 299.0,
        "tenure": "Monthly / Annual",
        "risk_level": "None",
        "terms_note": "Includes shopping discounts and Prime Music. Annual plan provides ~58% savings over monthly.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 2
    },
    {
        "category": "entertainment",
        "name": "Spotify",
        "official_url": "https://www.spotify.com/",
        "logo_icon": "🎵",
        "description": "Global audio streaming platform featuring over 100 million songs, podcasts, and curated mood playlists.",
        "pricing_or_rate": "Free ad-supported · Premium: ₹119/mo · Student: ₹59/mo",
        "min_amount": 59.0,
        "tenure": "Monthly / Annual",
        "risk_level": "None",
        "terms_note": "Student discount requires accredited college verification. Offline downloads supported.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 3
    },
    {
        "category": "entertainment",
        "name": "YouTube",
        "official_url": "https://www.youtube.com/",
        "logo_icon": "▶️",
        "description": "World's largest video platform for entertainment, skill learning, podcasts, and background ad-free streaming.",
        "pricing_or_rate": "Free ad-supported · Premium: ₹149/mo · Student: ₹79/mo",
        "min_amount": 79.0,
        "tenure": "Monthly subscription",
        "risk_level": "None",
        "terms_note": "Premium includes YouTube Music, background play, and zero ads across TV, phone, and PC.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 4
    },
    {
        "category": "entertainment",
        "name": "BookMyShow",
        "official_url": "https://in.bookmyshow.com/",
        "logo_icon": "🎟️",
        "description": "India's premier entertainment ticketing platform for latest cinema releases, multiplexes, live concerts, theater plays, and sports matches.",
        "pricing_or_rate": "Movie tickets from ₹120 · Credit card 1-on-1 offers available",
        "min_amount": 120.0,
        "tenure": "Instant booking",
        "risk_level": "None",
        "terms_note": "Convenience fee applies. Verified cinema seat selection with digital m-ticket entry. Check bank card BOGO offers before checkout.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 5
    },
    {
        "category": "entertainment",
        "name": "PVR INOX Cinemas",
        "official_url": "https://www.pvrcinemas.com/",
        "logo_icon": "🍿",
        "description": "India's largest multiplex chain with IMAX, 4DX, ICE, and luxury cinema screens across 115+ cities nationwide.",
        "pricing_or_rate": "Tickets from ₹150 · PVR INOX Passport weekday movie pass",
        "min_amount": 150.0,
        "tenure": "Instant booking / Monthly pass",
        "risk_level": "None",
        "terms_note": "PVR INOX Passport offers subsidized weekday movie passes. Early morning and weekday showtimes offer maximum ticket savings.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 6
    },
    {
        "category": "entertainment",
        "name": "TicketNew",
        "official_url": "https://ticketnew.com/",
        "logo_icon": "🎬",
        "description": "Popular online movie ticket booking platform offering extensive coverage of regional cinema theaters and single-screen auditoriums.",
        "pricing_or_rate": "Single screen & multiplex tickets from ₹90",
        "min_amount": 90.0,
        "tenure": "Instant booking",
        "risk_level": "None",
        "terms_note": "Direct cinema box-office pricing. Digital QR pass support for paperless counter entry.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 7
    },

    # 2. Travel & Bus Booking
    {
        "category": "travel",
        "name": "redBus",
        "official_url": "https://www.redbus.in/",
        "logo_icon": "🚌",
        "description": "India's #1 online bus ticketing network covering 3,500+ private bus operators and state RTCs (APSRTC, TSRTC, KSRTC, MSRTC, UPSRTC) with live bus tracking.",
        "pricing_or_rate": "Intercity fares from ₹200 · Up to 20% discount on first app booking",
        "min_amount": 200.0,
        "tenure": "Advance / On-demand booking",
        "risk_level": "None",
        "terms_note": "Free cancellation on select Primo buses. Real-time GPS bus location tracking and women-safe verified seating.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 1
    },
    {
        "category": "travel",
        "name": "AbhiBus",
        "official_url": "https://www.abhibus.com/",
        "logo_icon": "🚎",
        "description": "Leading bus ticketing aggregator offering government RTC and top private operator bookings with zero booking fee promotions.",
        "pricing_or_rate": "Bus tickets from ₹150 · AbhiCash wallet cashback rewards",
        "min_amount": 150.0,
        "tenure": "Instant bus booking",
        "risk_level": "None",
        "terms_note": "Instant cancellation refunds to wallet. 24x7 customer transit support and guaranteed boarding assurance.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 2
    },
    {
        "category": "travel",
        "name": "MakeMyTrip",
        "official_url": "https://www.makemytrip.com/",
        "logo_icon": "✈️",
        "description": "Comprehensive travel super-app for intercity bus tickets, trains, budget flights, and hotel bookings across India.",
        "pricing_or_rate": "Intercity bus tickets from ₹250 · MMT Black loyalty rewards",
        "min_amount": 250.0,
        "tenure": "Trip booking",
        "risk_level": "None",
        "terms_note": "Compare bus fares against train and flight schedules to optimize travel budget. Zero cancellation fee add-on available.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 3
    },
    {
        "category": "travel",
        "name": "IRCTC Official",
        "official_url": "https://www.irctc.co.in/",
        "logo_icon": "🚆",
        "description": "Official Indian Railway Catering and Tourism Corporation portal for nationwide rail bookings, Tatkal reservations, and integrated state bus connections.",
        "pricing_or_rate": "Standard regulated government fares · Budget Sleeper & 3AC travel",
        "min_amount": 50.0,
        "tenure": "Up to 120 days advance booking",
        "risk_level": "None",
        "terms_note": "Official Government of India railway ticketing. Most economical transit option for students and long-distance intercity commuters.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 4
    },

    # 3. Shopping
    {
        "category": "shopping",
        "name": "Amazon India",
        "official_url": "https://www.amazon.in/",
        "logo_icon": "📦",
        "description": "Leading digital marketplace for electronics, books, desk productivity gear, groceries, and daily personal essentials.",
        "pricing_or_rate": "Price matching, Prime next-day delivery, EMI options",
        "min_amount": 100.0,
        "tenure": "Instant checkout",
        "risk_level": "Low",
        "terms_note": "Standard 7-day return policy on eligible electronics and lifestyle items. Use wishlist to avoid impulse purchases.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 1
    },
    {
        "category": "shopping",
        "name": "Flipkart",
        "official_url": "https://www.flipkart.com/",
        "logo_icon": "🛒",
        "description": "Major Indian e-commerce destination known for budget gadgets, student laptops, appliances, and fashion sales.",
        "pricing_or_rate": "SuperCoin rewards, seasonal Big Billion Days discounts",
        "min_amount": 100.0,
        "tenure": "Instant checkout",
        "risk_level": "Low",
        "terms_note": "Verified Plus program rewards repeat shoppers with coin discounts and express shipping.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 2
    },
    {
        "category": "shopping",
        "name": "Myntra",
        "official_url": "https://www.myntra.com/",
        "logo_icon": "👗",
        "description": "Curated fashion & personal lifestyle portal offering branded apparel, campus casuals, footwear, and grooming essentials.",
        "pricing_or_rate": "Seasonal discounts, Myntra Insider points, coupon stack",
        "min_amount": 300.0,
        "tenure": "Instant checkout",
        "risk_level": "Low",
        "terms_note": "Easy 14-day doorstep exchange and return. Check size guide before checkout.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 3
    },
    {
        "category": "shopping",
        "name": "Ajio",
        "official_url": "https://www.ajio.com/",
        "logo_icon": "🛍️",
        "description": "Reliance Retail digital fashion storefront offering on-trend western, ethnic, and indie collections at pocket-friendly price points.",
        "pricing_or_rate": "Frequent 50-70% seasonal sales, AJIOMANIA coupon offers",
        "min_amount": 250.0,
        "tenure": "Instant checkout",
        "risk_level": "Low",
        "terms_note": "Reliable return and exchange window. Free shipping on qualifying order sizes.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 4
    },

    # 4. Savings
    {
        "category": "savings",
        "name": "State Bank of India (SBI)",
        "official_url": "https://sbi.co.in/",
        "logo_icon": "🏦",
        "description": "India's largest public sector bank. Regular Savings Bank Account with zero average balance requirement and YONO digital banking.",
        "pricing_or_rate": "2.70% p.a. interest rate on savings balance",
        "min_amount": 0.0,
        "tenure": "Liquid savings account",
        "risk_level": "Low",
        "terms_note": "Zero average monthly balance (AMB) penalty. DICGC insured up to ₹5,00,000 per depositor.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 1
    },
    {
        "category": "savings",
        "name": "HDFC Bank",
        "official_url": "https://www.hdfcbank.com/",
        "logo_icon": "🏛️",
        "description": "Premier private bank offering DigiSave and Regular Savings accounts with NetBanking, auto bill-pay, and digital security.",
        "pricing_or_rate": "3.00% to 3.50% p.a. interest rate",
        "min_amount": 2500.0,
        "tenure": "Liquid savings account",
        "risk_level": "Low",
        "terms_note": "DICGC insured up to ₹5 Lakh. Minimum average balance requirements vary between urban, semi-urban, and rural branches.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 2
    },
    {
        "category": "savings",
        "name": "ICICI Bank",
        "official_url": "https://www.icicibank.com/",
        "logo_icon": "💳",
        "description": "Instasave Savings Account opened in minutes via Aadhaar OTP. Features robust iMobile Pay and smart spending categorization.",
        "pricing_or_rate": "3.00% to 3.50% p.a. interest rate",
        "min_amount": 5000.0,
        "tenure": "Liquid savings account",
        "risk_level": "Low",
        "terms_note": "DICGC insured up to ₹5,00,000. Online video KYC available with zero physical branch visit.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 3
    },
    {
        "category": "savings",
        "name": "India Post Payments Bank (POSA)",
        "official_url": "https://www.indiapost.gov.in/",
        "logo_icon": "📮",
        "description": "Government of India backed Post Office Savings Account (POSA) offering the highest safety guarantee and vast branch outreach.",
        "pricing_or_rate": "4.00% p.a. (Government guaranteed interest rate)",
        "min_amount": 500.0,
        "tenure": "Flexible savings account",
        "risk_level": "Low (Sovereign Guarantee)",
        "terms_note": "100% Sovereign Guarantee by Govt of India. Interest up to ₹10,000 per year is tax-exempt under Section 80TTA.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 4
    },

    # 5. Fixed Deposits (FD)
    {
        "category": "fd",
        "name": "SBI Fixed Deposit",
        "official_url": "https://sbi.co.in/",
        "logo_icon": "🛡️",
        "description": "Guaranteed capital preservation. Includes the popular 400-day 'Amrit Vrishti' scheme and green term deposit options.",
        "pricing_or_rate": "6.80% to 7.10% p.a. (General) · 7.60% (Senior Citizens)",
        "min_amount": 1000.0,
        "tenure": "7 days to 10 years (Special 400-day tenure)",
        "risk_level": "Low",
        "terms_note": "DICGC insured up to ₹5 Lakh. Premature withdrawal allowed with 0.50% penalty. Loan facility up to 90% of deposit.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 1
    },
    {
        "category": "fd",
        "name": "HDFC Bank Fixed Deposit",
        "official_url": "https://www.hdfcbank.com/",
        "logo_icon": "📈",
        "description": "High liquidity term deposit with flexible interest payout (monthly, quarterly, or on maturity). Instant digital booking via NetBanking.",
        "pricing_or_rate": "Up to 7.25% p.a. (General) · Up to 7.75% (Senior Citizens)",
        "min_amount": 5000.0,
        "tenure": "7 days to 10 years",
        "risk_level": "Low",
        "terms_note": "DICGC insured up to ₹5 Lakh. TDS applicable under Income Tax rules unless Form 15G/15H is submitted.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 2
    },
    {
        "category": "fd",
        "name": "ICICI Bank Fixed Deposit",
        "official_url": "https://www.icicibank.com/",
        "logo_icon": "📊",
        "description": "Fixed Deposit with 'FD Xtra' features, offering premature partial withdrawal and overdraft protection without breaking the principal.",
        "pricing_or_rate": "Up to 7.20% p.a. (General) · Up to 7.75% (Senior Citizens)",
        "min_amount": 10000.0,
        "tenure": "7 days to 10 years",
        "risk_level": "Low",
        "terms_note": "DICGC insured up to ₹5 Lakh. Flexible interest reinvestment options for compounded growth.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 3
    },
    {
        "category": "fd",
        "name": "Axis Bank Fixed Deposit",
        "official_url": "https://www.axisbank.com/",
        "logo_icon": "🔒",
        "description": "Competitive fixed returns particularly for 15-month to 2-year tenures. Allows auto-renewal and flexible monthly payout schedules.",
        "pricing_or_rate": "Up to 7.25% p.a. (General) · Up to 7.75% (Senior Citizens)",
        "min_amount": 5000.0,
        "tenure": "7 days to 10 years",
        "risk_level": "Low",
        "terms_note": "DICGC insured up to ₹5 Lakh. Partial withdrawals supported on digital accounts.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 4
    },
    {
        "category": "fd",
        "name": "IDFC FIRST Bank Fixed Deposit",
        "official_url": "https://www.idfcfirstbank.com/",
        "logo_icon": "✨",
        "description": "Market-leading fixed deposit rates on popular tenures (500 days). Provides monthly interest credit for supplementary cashflow.",
        "pricing_or_rate": "Up to 7.75% p.a. (General) · Up to 8.25% (Senior Citizens)",
        "min_amount": 10000.0,
        "tenure": "7 days to 10 years (Peak 500-day scheme)",
        "risk_level": "Low",
        "terms_note": "DICGC insured up to ₹5,00,000 per depositor. Safe RBI-regulated scheduled commercial bank.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 5
    },

    # 6. Stock Market
    {
        "category": "stocks",
        "name": "National Stock Exchange (NSE)",
        "official_url": "https://www.nseindia.com/",
        "logo_icon": "🇮🇳",
        "description": "India's premier electronic stock exchange and home to the benchmark NIFTY 50 index. Essential for tracking official market data and investor education.",
        "pricing_or_rate": "Benchmark: NIFTY 50 Index · Free market education via NSE Academy",
        "min_amount": None,
        "tenure": "Continuous market trading",
        "risk_level": "Educational / Benchmark",
        "terms_note": "Regulated by SEBI. Equity investments carry market risk. Does not provide direct trading accounts — trade via certified brokers.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 1
    },
    {
        "category": "stocks",
        "name": "Bombay Stock Exchange (BSE)",
        "official_url": "https://www.bseindia.com/",
        "logo_icon": "🏢",
        "description": "Asia's oldest stock exchange and home to the S&P BSE SENSEX index. Provides authoritative market disclosures and mutual fund platforms (BSE StAR).",
        "pricing_or_rate": "Benchmark: SENSEX Index · Investor protection and regulatory disclosures",
        "min_amount": None,
        "tenure": "Continuous market trading",
        "risk_level": "Educational / Benchmark",
        "terms_note": "Regulated by SEBI. Past market performance is not an indicator of guaranteed future returns.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "conservative,moderate,aggressive",
        "priority_order": 2
    },
    {
        "category": "stocks",
        "name": "Zerodha",
        "official_url": "https://zerodha.com/",
        "logo_icon": "🪁",
        "description": "India's pioneer discount broker. Zero brokerage on equity delivery investments and direct mutual funds via Coin with no distributor commission.",
        "pricing_or_rate": "₹0 for equity delivery & direct MF · ₹20 flat for F&O & Intraday",
        "min_amount": 100.0,
        "tenure": "Long-term SIP / Delivery",
        "risk_level": "Moderate to High",
        "terms_note": "SEBI registered broker (INZ000031633). Securities market investments are subject to market risks. Read all scheme documents carefully.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "moderate,aggressive",
        "priority_order": 3
    },
    {
        "category": "stocks",
        "name": "Groww",
        "official_url": "https://groww.in/",
        "logo_icon": "🌱",
        "description": "Intuitive investment app ideal for students and beginners. Invest in direct mutual fund SIPs from ₹100, Indian stocks, IPOs, and Gold bonds.",
        "pricing_or_rate": "₹0 account maintenance charges · ₹20 or 0.05% per executed equity order",
        "min_amount": 100.0,
        "tenure": "SIP or One-time",
        "risk_level": "Moderate to High",
        "terms_note": "SEBI registered broker. Member of NSE & BSE. No guaranteed return claims. Capital is subject to market volatility.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "moderate,aggressive",
        "priority_order": 4
    },
    {
        "category": "stocks",
        "name": "Angel One",
        "official_url": "https://www.angelone.in/",
        "logo_icon": "👼",
        "description": "Full-service digital broker with SmartAPI rule-based investing, automated ARQ market research, and free equity delivery for beginners.",
        "pricing_or_rate": "₹0 delivery brokerage · ₹20 flat for Intraday & F&O",
        "min_amount": 100.0,
        "tenure": "Flexible",
        "risk_level": "Moderate to High",
        "terms_note": "SEBI registered broker. Standard market risk and regulatory disclosures apply.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "moderate,aggressive",
        "priority_order": 5
    },

    # 7. Cryptocurrency
    {
        "category": "crypto",
        "name": "CoinDCX",
        "official_url": "https://coindcx.com/",
        "logo_icon": "⚡",
        "description": "FIU-registered Indian virtual digital asset exchange offering INR bank deposit/withdrawal gateways and strict 2FA authentication.",
        "pricing_or_rate": "Competitive spot trading fees · 1% statutory TDS deducted on sell orders",
        "min_amount": 100.0,
        "tenure": "Spot digital asset custody",
        "risk_level": "Very High",
        "terms_note": "WARNING: Crypto assets are unregulated and highly volatile. You can lose all invested money. 30% flat tax on gains + 1% TDS applies in India.",
        "suitable_personas": "employee",
        "suitable_risk_levels": "aggressive",
        "priority_order": 1
    },
    {
        "category": "crypto",
        "name": "CoinSwitch",
        "official_url": "https://coinswitch.co/",
        "logo_icon": "🔄",
        "description": "User-friendly Indian crypto trading app with beginner learning guides, recurring buy plan (RBP) option, and localized INR payments.",
        "pricing_or_rate": "Market execution rates · 1% statutory TDS compliance",
        "min_amount": 100.0,
        "tenure": "Spot exchange",
        "risk_level": "Very High",
        "terms_note": "WARNING: Virtual digital assets are highly volatile and carry high risk of loss. Never invest funds earmarked for essential living expenses.",
        "suitable_personas": "employee",
        "suitable_risk_levels": "aggressive",
        "priority_order": 2
    },
    {
        "category": "crypto",
        "name": "Bitcoin.org",
        "official_url": "https://bitcoin.org/",
        "logo_icon": "₿",
        "description": "Official open-source educational resource for the Bitcoin protocol. Learn peer-to-peer electronic cash mechanics and non-custodial wallet security.",
        "pricing_or_rate": "Free open-source educational portal",
        "min_amount": None,
        "tenure": "Open protocol",
        "risk_level": "High / Educational",
        "terms_note": "Educational information only. Bitcoin is not legal tender in India and experiences extreme market price swings.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "moderate,aggressive",
        "priority_order": 3
    },
    {
        "category": "crypto",
        "name": "Ethereum.org",
        "official_url": "https://ethereum.org/",
        "logo_icon": "Ξ",
        "description": "Official community foundation portal for Ethereum. Comprehensive guides on smart contracts, decentralized finance (DeFi), and open protocols.",
        "pricing_or_rate": "Free open-source educational portal",
        "min_amount": None,
        "tenure": "Open protocol",
        "risk_level": "High / Educational",
        "terms_note": "Educational documentation only. Smart contract code execution risks and gas fee volatility apply.",
        "suitable_personas": "student,employee",
        "suitable_risk_levels": "moderate,aggressive",
        "priority_order": 4
    }
]

class RealWorldRecommendationService:
    """
    Intelligent Real-World Recommendation Service.
    Generates personalized recommendations with verified official links based on the user's
    monthly income, expenses, remaining balance, risk tolerance, goals, and persona.
    """

    def get_personalized_recommendations(
        self,
        db: Session,
        current_user: Optional[User] = None,
        category_filter: Optional[str] = None
    ) -> Dict[str, Any]:
        # 1. Gather User Financial State
        income = 0.0
        expenses = 0.0
        remaining = 0.0
        persona = "employee"
        risk_tolerance = "moderate"
        lifestyle_pct = 15.0
        active_goals = []

        if current_user:
            persona = current_user.role or "employee"
            profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.user_id).first()
            if profile:
                risk_tolerance = profile.risk_tolerance or "moderate"
                lifestyle_pct = float(profile.lifestyle_pct) if profile.lifestyle_pct else 15.0

            # Latest budget
            b = db.query(MonthlyBudget).filter(MonthlyBudget.user_id == current_user.user_id).order_by(MonthlyBudget.budget_id.desc()).first()
            if b:
                for i in b.income_entries:
                    income += float(i.amount)
                for e in b.expense_entries:
                    expenses += float(e.planned_amount)
            remaining = max(0.0, income - expenses)

            # Active goals
            goals_q = db.query(FinancialGoal).filter(
                FinancialGoal.user_id == current_user.user_id,
                FinancialGoal.status == "in_progress"
            ).all()
            active_goals = [(g.goal_type.name if g.goal_type else "Financial Goal") for g in goals_q]

        # Derived allocations
        entertainment_budget = round(remaining * (lifestyle_pct / 100.0) * 0.5, 2) if remaining > 0 else 0.0
        shopping_budget = round(remaining * (lifestyle_pct / 100.0) * 0.5, 2) if remaining > 0 else 0.0
        savings_budget = round(remaining * 0.35, 2) if remaining > 0 else 0.0
        investment_budget = round(max(0.0, remaining - entertainment_budget - shopping_budget - savings_budget), 2)

        # 2. Query items from Database (fallback to DEFAULT_CATALOG_ITEMS if empty)
        db_items = db.query(RealWorldRecommendationItem).filter(RealWorldRecommendationItem.is_verified == True).all()
        raw_catalog = []
        if db_items:
            for item in db_items:
                raw_catalog.append({
                    "id": item.item_id,
                    "category": item.category,
                    "name": item.name,
                    "official_url": item.official_url,
                    "logo_icon": item.logo_icon,
                    "description": item.description,
                    "pricing_or_rate": item.pricing_or_rate,
                    "min_amount": float(item.min_amount) if item.min_amount is not None else None,
                    "tenure": item.tenure,
                    "risk_level": item.risk_level,
                    "terms_note": item.terms_note,
                    "suitable_personas": item.suitable_personas,
                    "suitable_risk_levels": item.suitable_risk_levels,
                    "priority_order": item.priority_order
                })
        else:
            raw_catalog = DEFAULT_CATALOG_ITEMS

        # 3. Fetch Live Crypto Prices
        live_crypto = real_time_market_service.get_live_crypto_prices()

        # 4. Filter by Category
        norm_filter = (category_filter or "all").lower().strip()
        if norm_filter != "all":
            # Map aliases
            alias_map = {
                "fixed deposits": "fd", "fixed deposit": "fd",
                "stock market": "stocks", "stock": "stocks",
                "cryptocurrency": "crypto",
                "movies": "entertainment", "movie": "entertainment", "tickets": "entertainment", "ticket": "entertainment",
                "travel": "travel", "buses": "travel", "bus": "travel", "transport": "travel", "train": "travel"
            }
            cat_target = alias_map.get(norm_filter, norm_filter)
            filtered_items = [it for it in raw_catalog if it["category"] == cat_target]
        else:
            filtered_items = raw_catalog

        # 5. Build Personalized Rationale & Enriched Data for Each Item
        enriched_recommendations = []
        for it in filtered_items:
            cat = it["category"]
            name = it["name"]
            personalized_reason = ""
            risk_badge = it["risk_level"]
            pricing_highlight = it["pricing_or_rate"]

            # Real-time data injection
            if "bitcoin" in name.lower():
                btc_data = live_crypto.get("bitcoin", {})
                if btc_data:
                    pricing_highlight = f"Live: ₹{btc_data.get('inr', 7034000):,} (${btc_data.get('usd', 74900):,}) · 24h: {btc_data.get('inr_24h_change', 0):+.2f}%"
            elif "ethereum" in name.lower():
                eth_data = live_crypto.get("ethereum", {})
                if eth_data:
                    pricing_highlight = f"Live: ₹{eth_data.get('inr', 201000):,} (${eth_data.get('usd', 2140):,}) · 24h: {eth_data.get('inr_24h_change', 0):+.2f}%"

            # Personalized Logic
            if cat == "savings":
                if remaining <= 0:
                    personalized_reason = f"Your essential expenses currently equal your earnings. We recommend opening a zero-balance account (like SBI Regular or India Post) with ₹0 penalty while reclaiming cashflow."
                elif risk_tolerance == "conservative":
                    personalized_reason = f"Based on your ₹{int(remaining):,} remaining balance and conservative risk preference, parking ₹{int(savings_budget):,} in an insured liquid account builds your emergency fund safely."
                elif persona == "student":
                    personalized_reason = f"Ideal for student cashflow. Zero-minimum-balance accounts keep your allowance safe without recurring maintenance fee deductions."
                else:
                    personalized_reason = f"Recommended to deposit ₹{int(savings_budget):,} this month as liquid emergency buffer before committing to long-term lock-ins."

            elif cat == "fd":
                if remaining < 1000:
                    personalized_reason = f"Fixed deposits require a minimum of ₹1,000. Reclaim surplus cashflow to lock in guaranteed returns at up to 7.25% p.a."
                elif risk_tolerance == "conservative" or persona == "student":
                    personalized_reason = f"Capital preservation match: Locks in guaranteed 7.10%–7.25% p.a. returns with zero market volatility, protecting your savings goal."
                else:
                    personalized_reason = f"With ₹{int(remaining):,} surplus, allocating a portion into a 1–2 year FD provides reliable risk-free foundation for your portfolio."

            elif cat == "stocks":
                if risk_tolerance == "conservative" or persona == "student":
                    personalized_reason = f"Educational suggestion: Given your {risk_tolerance} risk preference / student status, avoid active speculative trading. Focus on low-cost Index Funds via Zerodha or Groww."
                elif remaining > 5000 and risk_tolerance in ("moderate", "aggressive"):
                    personalized_reason = f"Your {risk_tolerance} profile supports systematic monthly SIP investing (e.g. ₹{int(investment_budget):,}/mo) for long-term equity wealth compounding."
                else:
                    personalized_reason = f"Explore market indices (NIFTY 50 / SENSEX) and start disciplined micro-investments once your 3-month emergency fund is established."

            elif cat == "crypto":
                if risk_tolerance == "conservative" or persona == "student":
                    personalized_reason = f"⚠️ HIGH RISK WARNING: Not recommended for {risk_tolerance} profiles or student budgets. Crypto is unregulated and volatile. Keep exposure to ≤ 2% or explore only for educational learning."
                else:
                    max_crypto_alloc = round(remaining * 0.05, 2)
                    personalized_reason = f"⚠️ HIGH RISK WARNING: Extreme volatility. Maximum recommended allocation is strictly capped at ₹{int(max_crypto_alloc):,} (≤ 5% of surplus). Never invest essential funds."

            elif cat == "entertainment":
                if "bookmyshow" in name.lower() or "pvr" in name.lower() or "ticketnew" in name.lower():
                    if remaining <= 0:
                        personalized_reason = "Movie ticket spending should be paused or limited to discounted weekday screenings until emergency savings are restored."
                    elif persona == "student":
                        personalized_reason = f"Check for 1+1 credit/debit card offers and weekday morning ticket pricing to enjoy theater experiences within your ₹{int(entertainment_budget):,} leisure budget."
                    else:
                        personalized_reason = f"Book verified cinema tickets and enjoy weekend leisure. Fits within your ₹{int(entertainment_budget):,} entertainment budget."
                elif remaining <= 0:
                    personalized_reason = f"With zero remaining balance, we recommend using free ad-supported tiers (Spotify Free / YouTube Free) to keep entertainment spend at ₹0."
                elif persona == "student":
                    personalized_reason = f"Special student pricing available (Spotify at ₹59/mo, YouTube at ₹79/mo). Uses only a tiny fraction of your ₹{int(entertainment_budget):,} leisure allowance."
                else:
                    personalized_reason = f"Fits comfortably within your ₹{int(entertainment_budget):,} entertainment bucket. Protects discretionary leisure without overshooting your plan."

            elif cat == "travel":
                if remaining <= 0:
                    personalized_reason = "Essential transit only. Use state RTC bus booking on redBus or IRCTC sleeper class to minimize travel expense."
                elif persona == "student":
                    personalized_reason = f"Ideal for student travel & visits home. Book in advance on redBus or AbhiBus with student concession discounts from your ₹{int(entertainment_budget):,} discretionary allowance."
                else:
                    personalized_reason = f"Compare intercity bus and train fares in advance. Advance booking on redBus or MakeMyTrip typically saves 15%–30% on planned journeys."

            elif cat == "shopping":
                if remaining <= 0:
                    personalized_reason = f"Pause discretionary lifestyle shopping until monthly essential obligations are fully covered."
                else:
                    personalized_reason = f"Your shopping budget is ₹{int(shopping_budget):,}. Use wishlist discipline on official apps to wait 48 hours before discretionary purchases."

            cat_label_map = {
                "fd": "Fixed Deposit",
                "stocks": "Stock Market",
                "crypto": "Cryptocurrency",
                "entertainment": "Entertainment & Movies",
                "travel": "Travel & Buses",
                "shopping": "Shopping",
                "savings": "Savings"
            }

            enriched_recommendations.append({
                "id": it.get("id"),
                "category": cat,
                "category_label": cat_label_map.get(cat, cat.title()),
                "name": name,
                "official_url": it["official_url"],
                "logo_icon": it["logo_icon"],
                "description": it["description"],
                "pricing_highlight": pricing_highlight,
                "min_amount": it.get("min_amount"),
                "tenure": it.get("tenure"),
                "risk_level": risk_badge,
                "terms_note": it.get("terms_note"),
                "personalized_reason": personalized_reason,
                "is_verified": True,
                "url_verified_status": "Verified Official Platform"
            })

        # Sort order:
        cat_priority = {
            "savings": 1 if risk_tolerance == "conservative" else 2,
            "fd": 2 if risk_tolerance == "conservative" else 3,
            "stocks": 3 if risk_tolerance != "conservative" else 4,
            "entertainment": 4,
            "travel": 5,
            "shopping": 6,
            "crypto": 7
        }
        enriched_recommendations.sort(key=lambda x: (cat_priority.get(x["category"], 10), x.get("id") or 0))

        return {
            "user_financial_summary": {
                "gross_income": income,
                "total_expenses": expenses,
                "disposable_income": remaining,
                "persona": persona,
                "risk_tolerance": risk_tolerance,
                "entertainment_budget": entertainment_budget,
                "shopping_budget": shopping_budget,
                "savings_budget": savings_budget,
                "investment_budget": investment_budget,
                "active_goals": active_goals
            },
            "active_filter": norm_filter,
            "total_count": len(enriched_recommendations),
            "categories": [
                {"code": "all", "label": "All Categories", "count": len(raw_catalog)},
                {"code": "entertainment", "label": "🎬 Entertainment & Movies", "count": sum(1 for i in raw_catalog if i["category"] == "entertainment")},
                {"code": "travel", "label": "🚌 Travel & Buses", "count": sum(1 for i in raw_catalog if i["category"] == "travel")},
                {"code": "shopping", "label": "🛍️ Shopping", "count": sum(1 for i in raw_catalog if i["category"] == "shopping")},
                {"code": "savings", "label": "🏦 Savings", "count": sum(1 for i in raw_catalog if i["category"] == "savings")},
                {"code": "fd", "label": "📈 Fixed Deposits", "count": sum(1 for i in raw_catalog if i["category"] == "fd")},
                {"code": "stocks", "label": "📊 Stock Market", "count": sum(1 for i in raw_catalog if i["category"] == "stocks")},
                {"code": "crypto", "label": "⚡ Cryptocurrency", "count": sum(1 for i in raw_catalog if i["category"] == "crypto")},
            ],
            "live_market_status": live_crypto.get("status", "live"),
            "recommendations": enriched_recommendations,
            "disclaimer": "Cortex AI provides educational decision-support suggestions and links to official platforms. It does not provide personalized investment advice or guarantee financial returns. Bank deposits are DICGC insured up to ₹5 Lakh. Equities and Cryptocurrencies are subject to market risks."
        }

real_world_rec_service = RealWorldRecommendationService()
