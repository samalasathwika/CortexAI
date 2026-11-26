import datetime
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.database import get_db
from app.models import User, UserProfile, UserPreference, UserSession
from app.schemas import (
    UserRegister, UserLogin, Token, UserProfileUpdate, PasswordChange,
    ForgotPasswordRequest, ForgotPasswordVerify, ForgotPasswordValidateOtp
)
from app.auth import get_password_hash, verify_password, create_access_token, get_current_user
import hashlib

router = APIRouter(prefix="/auth", tags=["Authentication"])

@router.post("/register", response_model=Token)
def register(user_in: UserRegister, db: Session = Depends(get_db)):
    # Check if user already exists
    existing = db.query(User).filter(User.email == user_in.email.lower()).first()
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="An account with this email address already exists."
        )

    # Create new user
    hashed_pw = get_password_hash(user_in.password)
    user = User(
        email=user_in.email.lower(),
        password_hash=hashed_pw,
        role=user_in.role,
        status="active"
    )
    db.add(user)
    db.commit()
    db.refresh(user)

    # Initialize Profile & Preferences
    profile = UserProfile(
        user_id=user.user_id,
        full_name=user_in.name,
        currency="INR",
        risk_tolerance="moderate",
        lifestyle_pct=15.00
    )
    preferences = UserPreference(
        user_id=user.user_id,
        theme_mode="dark",
        card_style="glass",
        accent_color="#F92E92",
        animations_enabled=True
    )
    db.add(profile)
    db.add(preferences)
    db.commit()

    token = create_access_token(data={"sub": str(user.user_id), "role": user.role, "email": user.email})
    return {
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "id": user.user_id,
            "email": user.email,
            "name": user_in.name,
            "role": user.role,
            "risk_tolerance": "moderate",
            "lifestyle_pct": 15.00
        }
    }

@router.post("/login", response_model=Token)
def login(credentials: UserLogin, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.email == credentials.email.lower()).first()
    if not user or not verify_password(credentials.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password."
        )

    if user.status != "active":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Account is inactive or suspended."
        )

    # Check role mismatch if specified
    if credentials.role and credentials.role != user.role:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Those credentials belong to a different role ({user.role}). Switch role or check your details."
        )

    token = create_access_token(data={"sub": str(user.user_id), "role": user.role, "email": user.email})

    profile = db.query(UserProfile).filter(UserProfile.user_id == user.user_id).first()
    name = profile.full_name if profile and profile.full_name else user.email.split("@")[0].capitalize()

    return {
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "id": user.user_id,
            "email": user.email,
            "name": name,
            "role": user.role,
            "risk_tolerance": profile.risk_tolerance if profile else "moderate",
            "lifestyle_pct": float(profile.lifestyle_pct) if profile else 15.00
        }
    }

@router.get("/me")
def get_me(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.user_id).first()
    prefs = db.query(UserPreference).filter(UserPreference.user_id == current_user.user_id).first()

    return {
        "id": current_user.user_id,
        "email": current_user.email,
        "role": current_user.role,
        "name": profile.full_name if profile else "",
        "avatar_url": profile.avatar_url if profile else None,
        "risk_tolerance": profile.risk_tolerance if profile else "moderate",
        "lifestyle_pct": float(profile.lifestyle_pct) if profile else 15.0,
        "currency": profile.currency if profile else "INR",
        "preferences": {
            "theme_mode": prefs.theme_mode if prefs else "dark",
            "card_style": prefs.card_style if prefs else "glass",
            "accent_color": prefs.accent_color if prefs else "#F92E92",
            "animations_enabled": prefs.animations_enabled if prefs else True
        }
    }

@router.put("/profile")
def update_profile(
    profile_data: UserProfileUpdate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    profile = db.query(UserProfile).filter(UserProfile.user_id == current_user.user_id).first()
    prefs = db.query(UserPreference).filter(UserPreference.user_id == current_user.user_id).first()

    if profile_data.full_name is not None and profile:
        profile.full_name = profile_data.full_name
    if profile_data.role is not None and profile_data.role in ("student", "employee"):
        current_user.role = profile_data.role
    if profile_data.avatar_url is not None and profile:
        profile.avatar_url = profile_data.avatar_url
    if profile_data.risk_tolerance is not None and profile:
        profile.risk_tolerance = profile_data.risk_tolerance
    if profile_data.lifestyle_pct is not None and profile:
        profile.lifestyle_pct = profile_data.lifestyle_pct

    if prefs:
        if profile_data.theme_mode is not None:
            prefs.theme_mode = profile_data.theme_mode
        if profile_data.card_style is not None:
            prefs.card_style = profile_data.card_style
        if profile_data.accent_color is not None:
            prefs.accent_color = profile_data.accent_color

    db.commit()
    return {"status": "success", "message": "Profile updated successfully."}

@router.post("/change-password")
def change_password(
    data: PasswordChange,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    if not verify_password(data.current_password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect."
        )
    if len(data.new_password) < 6:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be at least 6 characters long."
        )
    current_user.password_hash = get_password_hash(data.new_password)
    db.commit()
    return {"status": "success", "message": "Password updated successfully."}

# In-memory OTP storage for password reset
import random
import os
import logging
auth_logger = logging.getLogger("cortex.auth")
otp_store = {}

def send_real_email_otp(to_email: str, otp: str) -> bool:
    smtp_host = os.getenv("SMTP_HOST")
    smtp_port = int(os.getenv("SMTP_PORT", 587))
    smtp_user = os.getenv("SMTP_USER")
    smtp_pass = os.getenv("SMTP_PASSWORD")
    sender = os.getenv("SMTP_FROM", smtp_user or "noreply@cortex-ai.com")

    if smtp_host and smtp_user and smtp_pass:
        try:
            import smtplib
            from email.mime.text import MIMEText
            msg = MIMEText(f"Hello,\n\nYour Cortex AI password reset verification code is:\n\n{otp}\n\nThis OTP is valid for 10 minutes.\nIf you did not request this, please ignore this email.\n\nBest regards,\nCortex AI Team")
            msg["Subject"] = "Cortex AI - Password Reset OTP Code"
            msg["From"] = sender
            msg["To"] = to_email

            with smtplib.SMTP(smtp_host, smtp_port, timeout=5) as server:
                server.starttls()
                server.login(smtp_user, smtp_pass)
                server.sendmail(sender, [to_email], msg.as_string())
            auth_logger.info(f"OTP email sent to {to_email}")
            return True
        except Exception as e:
            auth_logger.warning(f"SMTP error: {e}")
    return False

@router.post("/forgot-password/send-otp")
def send_forgot_password_otp(data: ForgotPasswordRequest, db: Session = Depends(get_db)):
    email = data.email.lower().strip()
    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="No account found with this Gmail / email address. Please check your spelling or register."
        )

    otp = f"{random.randint(100000, 999999)}"
    expires_at = datetime.datetime.utcnow() + datetime.timedelta(minutes=10)
    otp_store[email] = {
        "otp": otp,
        "expires_at": expires_at
    }

    sent = send_real_email_otp(email, otp)
    auth_logger.info(f"[FORGOT_PASSWORD] OTP for {email} is {otp}. SMTP sent: {sent}")

    return {
        "status": "success",
        "message": f"Verification OTP code sent to {email}.",
        "sent_via_email": sent,
        "otp_preview": otp
    }

@router.post("/forgot-password/validate-otp")
def validate_forgot_password_otp(data: ForgotPasswordValidateOtp):
    email = data.email.lower().strip()
    if email not in otp_store:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No active verification code found for this email, or it has expired. Please request a new OTP."
        )

    record = otp_store[email]
    if datetime.datetime.utcnow() > record["expires_at"]:
        del otp_store[email]
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The verification code has expired. Please request a new OTP."
        )

    if str(record["otp"]).strip() != str(data.otp).strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid 6-digit OTP code. Please check and enter the correct code."
        )

    record["validated"] = True
    return {
        "status": "success",
        "message": "OTP validated successfully! You may now set your new password."
    }

@router.post("/forgot-password/verify-reset")
def verify_otp_and_reset_password(data: ForgotPasswordVerify, db: Session = Depends(get_db)):
    email = data.email.lower().strip()
    if email not in otp_store:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No active verification code found for this email, or it has expired. Please request a new code."
        )

    record = otp_store[email]
    if datetime.datetime.utcnow() > record["expires_at"]:
        del otp_store[email]
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The verification code has expired. Please request a new OTP."
        )

    if str(record["otp"]).strip() != str(data.otp).strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid 6-digit OTP code. Please check your email and try again."
        )

    if len(data.new_password) < 6:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="New password must be at least 6 characters long."
        )

    user = db.query(User).filter(User.email == email).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Account not found."
        )

    user.password_hash = get_password_hash(data.new_password)
    db.commit()
    del otp_store[email]

    auth_logger.info(f"[FORGOT_PASSWORD] Password reset successful for {email}")
    return {
        "status": "success",
        "message": "Password reset successfully! Please sign in with your new password."
    }
