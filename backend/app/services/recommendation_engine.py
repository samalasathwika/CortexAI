import logging
from typing import Dict, Any, List, Optional

logger = logging.getLogger("cortex.ai_engine")

BUCKET_ORDER = ['savings', 'fd', 'rd', 'stocks', 'crypto', 'chits', 'entertainment', 'shopping', 'others']

BUCKET_META = {
    'savings': {'name': 'Savings', 'color': '#3B82F6', 'desc': 'Liquid emergency buffer', 'group': 'saving'},
    'fd':      {'name': 'Fixed Deposit', 'color': '#22D3EE', 'desc': 'Locked-in, low-risk growth', 'group': 'investment'},
    'rd':      {'name': 'Recurring Deposit', 'color': '#5EEAD4', 'desc': 'Disciplined monthly investing', 'group': 'investment'},
    'stocks':  {'name': 'Stocks', 'color': '#F92E92', 'desc': 'Market-linked, higher risk', 'group': 'investment'},
    'crypto':  {'name': 'Crypto', 'color': '#A855F7', 'desc': 'High-risk, high-volatility', 'group': 'investment'},
    'chits':   {'name': 'Chits', 'color': '#818CF8', 'desc': 'Community pooled savings', 'group': 'saving'},
    'entertainment': {'name': 'Entertainment', 'color': '#FBBF24', 'desc': 'Movies, dining, leisure', 'group': 'lifestyle'},
    'shopping': {'name': 'Shopping', 'color': '#C084FC', 'desc': 'Lifestyle & personal purchases', 'group': 'lifestyle'},
    'others':  {'name': 'Others', 'color': '#94A3B8', 'desc': 'Miscellaneous / uncategorized', 'group': 'other'}
}

BASE_STRATEGIES = {
    'conservative': {
        'name': 'Conservative',
        'desc': 'Capital preservation with steady, low-risk returns.',
        'weights': {'savings': 30, 'fd': 20, 'rd': 10, 'stocks': 5,  'crypto': 0,  'chits': 5, 'entertainment': 10, 'shopping': 10, 'others': 10},
        'rationales': [
            'Strong allocation to liquid savings for immediate emergencies.',
            'Fixed & recurring deposits provide guaranteed, steady growth.',
            'Minimal exposure to volatile market instruments.'
        ]
    },
    'balanced': {
        'name': 'Balanced',
        'desc': 'Blend of stability and moderate market-linked growth.',
        'weights': {'savings': 20, 'fd': 15, 'rd': 10, 'stocks': 15, 'crypto': 5,  'chits': 5, 'entertainment': 12, 'shopping': 13, 'others': 5},
        'rationales': [
            'Balances cash buffer with disciplined recurring investments.',
            'Controlled stock exposure captures market upsides safely.',
            'Dedicated lifestyle budget protects discretionary spending.'
        ]
    },
    'accelerated': {
        'name': 'Accelerated',
        'desc': 'Maximises growth with higher equity and crypto exposure.',
        'weights': {'savings': 35, 'fd': 10, 'rd': 5,  'stocks': 20, 'crypto': 10, 'chits': 0, 'entertainment': 5,  'shopping': 5,  'others': 10},
        'rationales': [
            'Prioritises long-term equity compounding and higher returns.',
            'Controlled exposure to high-growth emerging digital assets.',
            'Streamlined discretionary spend directed toward wealth creation.'
        ]
    }
}

class CortexRecommendationEngine:
    """
    Intelligent Cortex AI Financial Recommendation Engine.
    Synthesizes persona, disposable income, risk tolerance, goals, and lifestyle preferences.
    """

    def generate_recommendation(
        self,
        disposable_income: float,
        persona: str = 'employee',
        risk_tolerance: str = 'moderate',
        lifestyle_pct: float = 15.0,
        active_goals: Optional[List[Dict[str, Any]]] = None,
        interests: Optional[List[str]] = None,
        strategy_override: Optional[str] = None
    ) -> Dict[str, Any]:
        # 1. Determine strategy code
        strategy_code = strategy_override or self._infer_strategy(risk_tolerance, persona, disposable_income)
        if strategy_code not in BASE_STRATEGIES:
            strategy_code = 'balanced'

        base = BASE_STRATEGIES[strategy_code]
        weights = dict(base['weights'])

        # 2. Adjust for Lifestyle % slider
        weights = self._apply_lifestyle_adjustment(weights, lifestyle_pct, interests or [])

        # 3. Adjust for active goals (e.g. urgent emergency fund or debt payoff)
        weights, goal_factors = self._apply_goal_adjustments(weights, active_goals or [])

        # 4. Student vs Employee constraints
        if persona == 'student':
            # Cap crypto and stocks if disposable income is modest
            if weights['crypto'] > 5:
                diff = weights['crypto'] - 5
                weights['crypto'] = 5
                weights['savings'] += diff

        # 5. Normalize weights so they sum strictly to 100%
        weights = self._normalize_weights(weights)

        # 6. Calculate rupee amounts
        allocations = []
        for bucket_code in BUCKET_ORDER:
            pct = weights.get(bucket_code, 0.0)
            amt = round(max(0.0, disposable_income) * (pct / 100.0), 2)
            meta = BUCKET_META[bucket_code]

            # Priority assignment
            if bucket_code in ['savings', 'fd'] and pct >= 15:
                priority = 'High'
            elif bucket_code in ['entertainment', 'shopping'] and pct <= 10:
                priority = 'Low'
            else:
                priority = 'Medium'

            allocations.append({
                'bucket_code': bucket_code,
                'name': meta['name'],
                'color': meta['color'],
                'weight_pct': round(pct, 1),
                'amount': amt,
                'priority': priority
            })

        # 7. Generate factors
        factors = [
            {'factor_name': 'Risk Profile', 'impact_weight': 35.0, 'description': f'Calibrated to {risk_tolerance.capitalize()} risk preference.'},
            {'factor_name': 'Lifestyle Cap', 'impact_weight': 25.0, 'description': f'Discretionary spending allocated at {lifestyle_pct}%, protecting core savings.'},
            {'factor_name': 'Persona Optimization', 'impact_weight': 20.0, 'description': f'Asset allocation tuned for {persona.capitalize()} cashflow dynamics.'},
        ]
        factors.extend(goal_factors)

        # 8. Dynamic AI insights
        insights = self._build_insights(disposable_income, lifestyle_pct, persona, allocations)

        return {
            'strategy_code': strategy_code,
            'strategy_name': base['name'],
            'disposable_income': round(disposable_income, 2),
            'allocations': allocations,
            'rationales': list(base['rationales']),
            'factors': factors,
            'insights': insights
        }

    def _infer_strategy(self, risk: str, persona: str, disposable_income: float) -> str:
        if risk == 'conservative' or disposable_income < 3000:
            return 'conservative'
        elif risk == 'aggressive' and disposable_income > 15000:
            return 'accelerated'
        return 'balanced'

    def _apply_lifestyle_adjustment(self, weights: Dict[str, float], lifestyle_pct: float, interests: List[str]) -> Dict[str, float]:
        current_lifestyle = weights['entertainment'] + weights['shopping']
        diff = lifestyle_pct - current_lifestyle

        # Split diff between entertainment and shopping based on interests
        has_movies = any(i.lower() in ['movies', 'entertainment'] for i in interests)
        has_shopping = any(i.lower() in ['shopping', 'fashion', 'tech'] for i in interests)

        if has_movies and not has_shopping:
            ent_share = 0.65
        elif has_shopping and not has_movies:
            ent_share = 0.35
        else:
            ent_share = 0.5

        weights['entertainment'] = max(2.0, weights['entertainment'] + (diff * ent_share))
        weights['shopping'] = max(2.0, weights['shopping'] + (diff * (1.0 - ent_share)))

        # Balance the remaining from investment/savings buckets
        adjust_target = 'savings' if diff > 0 else 'stocks'
        weights[adjust_target] = max(5.0, weights[adjust_target] - diff)
        return weights

    def _apply_goal_adjustments(self, weights: Dict[str, float], goals: List[Dict[str, Any]]) -> (Dict[str, float], List[Dict[str, Any]]):
        factors = []
        for g in goals:
            t = g.get('type_code')
            priority = g.get('priority', 3)
            if t in ['emergency', 'debt_clearance'] and priority >= 4:
                # Urgent security need: shift 5% from crypto/others to savings
                shift = 5.0
                if weights['crypto'] >= shift:
                    weights['crypto'] -= shift
                    weights['savings'] += shift
                else:
                    weights['others'] = max(2.0, weights['others'] - shift)
                    weights['savings'] += shift

                factors.append({
                    'factor_name': 'Emergency Buffer Boost',
                    'impact_weight': 20.0,
                    'description': 'Elevated liquid savings allocation due to active urgent financial goal.'
                })
                break
        return weights, factors

    def _normalize_weights(self, weights: Dict[str, float]) -> Dict[str, float]:
        total = sum(weights.values())
        if total <= 0:
            return {b: round(100.0 / len(BUCKET_ORDER), 1) for b in BUCKET_ORDER}
        norm = {b: round((v / total) * 100.0, 1) for b, v in weights.items()}
        # Fix rounding error on savings
        delta = 100.0 - sum(norm.values())
        norm['savings'] = round(norm['savings'] + delta, 1)
        return norm

    def _build_insights(self, disposable: float, lifestyle_pct: float, persona: str, allocations: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        insights = []
        savings_amt = next((a['amount'] for a in allocations if a['bucket_code'] == 'savings'), 0.0)
        lifestyle_amt = next((a['amount'] for a in allocations if a['bucket_code'] == 'entertainment'), 0.0) + \
                        next((a['amount'] for a in allocations if a['bucket_code'] == 'shopping'), 0.0)

        if disposable > 0:
            insights.append({
                'icon': '🛡️',
                'title': 'Emergency Buffer On Track',
                'body': f'Allocating ₹{int(savings_amt):,} this month steadily compounds your liquid reserves against unanticipated costs.'
            })
            insights.append({
                'icon': '✦',
                'title': 'Lifestyle Budget Guardrail',
                'body': f'Capping lifestyle spend at {lifestyle_pct}% (₹{int(lifestyle_amt):,}) preserves capital while sustaining guilt-free leisure.'
            })
        else:
            insights.append({
                'icon': '⚠️',
                'title': 'Zero Disposable Balance',
                'body': 'Your essential expenses equal or exceed monthly income. Review flexible bills to reclaim positive cashflow.'
            })

        return insights

recommendation_engine = CortexRecommendationEngine()
