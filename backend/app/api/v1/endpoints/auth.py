"""Authentication endpoints."""

import hashlib
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy import select, delete
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_user, get_db
from app.core.config import settings
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    get_password_hash,
    is_refresh_token,
    verify_password,
)
from app.models import Playbook, RefreshToken, User
from app.schemas.auth import (
    AppleSignIn,
    ForgotPassword,
    ResetPassword,
    Token,
    TokenRefresh,
    UserCreate,
    VerifyEmail,
)
from app.schemas.user import UserResponse
from app.services.email import email_service
from app.services.apple import apple_sign_in_service, AppleSignInError

router = APIRouter(prefix="/auth", tags=["auth"])


def _hash_token(token: str) -> str:
    """Hash a token for storage (refresh tokens, verification tokens)."""
    return hashlib.sha256(token.encode()).hexdigest()


async def _store_refresh_token(db: AsyncSession, user_id, refresh_token: str) -> None:
    """Store a refresh token hash in database."""
    expires_at = datetime.now(timezone.utc) + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS)
    token_record = RefreshToken(
        user_id=user_id,
        token_hash=_hash_token(refresh_token),
        expires_at=expires_at,
    )
    db.add(token_record)


async def _revoke_refresh_token(db: AsyncSession, refresh_token: str) -> bool:
    """Revoke a refresh token. Returns True if token was found and revoked."""
    token_hash = _hash_token(refresh_token)
    result = await db.execute(
        delete(RefreshToken).where(RefreshToken.token_hash == token_hash)
    )
    return result.rowcount > 0


@router.post("/register", response_model=Token)
async def register(
    user_data: UserCreate,
    db: AsyncSession = Depends(get_db),
) -> Token:
    """Register a new user with email and password."""
    # Check if email already exists
    result = await db.execute(select(User).where(User.email == user_data.email))
    if result.scalar_one_or_none() is not None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered",
        )

    # Create user with hashed password
    user = User(
        email=user_data.email,
        password_hash=get_password_hash(user_data.password),
        email_verified=False,
    )

    # Generate email verification token
    verification_token = secrets.token_urlsafe(32)
    user.verification_token = _hash_token(verification_token)
    user.verification_token_expires = datetime.now(timezone.utc) + timedelta(hours=24)

    db.add(user)
    await db.flush()  # Get user.id

    # Create default Favorites Playbook
    favorites = Playbook(
        user_id=user.id,
        name="Favorites",
        icon="star.fill",  # SF Symbol name
        is_system=True,
    )
    db.add(favorites)

    # Create tokens
    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token(user.id)

    # Store refresh token
    await _store_refresh_token(db, user.id, refresh_token)

    # Send verification email
    email_service.send_verification_email(user.email, verification_token)

    return Token(access_token=access_token, refresh_token=refresh_token)


@router.post("/login", response_model=Token)
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db),
) -> Token:
    """Login with email and password. Returns access and refresh tokens."""
    # Find user by email (form_data.username is actually email)
    result = await db.execute(select(User).where(User.email == form_data.username))
    user = result.scalar_one_or_none()

    if user is None or user.password_hash is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    if not verify_password(form_data.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    # Create tokens
    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token(user.id)

    # Store refresh token (supports multiple devices)
    await _store_refresh_token(db, user.id, refresh_token)

    return Token(access_token=access_token, refresh_token=refresh_token)


@router.post("/refresh", response_model=Token)
async def refresh_tokens(
    token_data: TokenRefresh,
    db: AsyncSession = Depends(get_db),
) -> Token:
    """Refresh access token using refresh token. Implements token rotation."""
    # Verify it's a refresh token
    if not is_refresh_token(token_data.refresh_token):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid refresh token",
        )

    # Decode to get user_id
    payload = decode_token(token_data.refresh_token)
    if payload is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token expired",
        )

    user_id = payload.get("sub")
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token payload",
        )

    # Verify token exists in database (not already revoked)
    token_hash = _hash_token(token_data.refresh_token)
    result = await db.execute(
        select(RefreshToken).where(RefreshToken.token_hash == token_hash)
    )
    stored_token = result.scalar_one_or_none()

    if stored_token is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Refresh token revoked or not found",
        )

    # Token rotation: delete old token
    await db.delete(stored_token)

    # Verify user still exists
    result = await db.execute(select(User).where(User.id == stored_token.user_id))
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found",
        )

    # Create new token pair
    new_access_token = create_access_token(user.id)
    new_refresh_token = create_refresh_token(user.id)

    # Store new refresh token
    await _store_refresh_token(db, user.id, new_refresh_token)

    return Token(access_token=new_access_token, refresh_token=new_refresh_token)


@router.post("/logout")
async def logout(
    token_data: TokenRefresh,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Logout by revoking the refresh token."""
    revoked = await _revoke_refresh_token(db, token_data.refresh_token)

    if not revoked:
        # Token not found, but we don't want to leak info
        pass

    return {"message": "Successfully logged out"}


@router.get("/me", response_model=UserResponse)
async def get_me(
    current_user: User = Depends(get_current_user),
) -> User:
    """Get current authenticated user's profile."""
    return current_user


@router.post("/verify-email")
async def verify_email(
    data: VerifyEmail,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Verify email address with token from verification email."""
    token_hash = _hash_token(data.token)

    result = await db.execute(
        select(User).where(
            User.verification_token == token_hash,
            User.verification_token_expires > datetime.now(timezone.utc),
        )
    )
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired verification token",
        )

    user.email_verified = True
    user.verification_token = None
    user.verification_token_expires = None

    return {"message": "Email verified successfully"}


@router.post("/resend-verification")
async def resend_verification(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Resend email verification link."""
    if current_user.email_verified:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already verified",
        )

    # Generate new verification token
    verification_token = secrets.token_urlsafe(32)
    current_user.verification_token = _hash_token(verification_token)
    current_user.verification_token_expires = datetime.now(timezone.utc) + timedelta(hours=24)

    # Send verification email
    email_service.send_verification_email(current_user.email, verification_token)

    return {"message": "Verification email sent"}


@router.post("/forgot-password")
async def forgot_password(
    data: ForgotPassword,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Request password reset email."""
    result = await db.execute(select(User).where(User.email == data.email))
    user = result.scalar_one_or_none()

    # Always return success to prevent email enumeration
    if user is not None and user.password_hash is not None:
        # Generate reset token
        reset_token = secrets.token_urlsafe(32)
        user.password_reset_token = _hash_token(reset_token)
        user.password_reset_expires = datetime.now(timezone.utc) + timedelta(hours=1)

        # Send password reset email
        email_service.send_password_reset_email(user.email, reset_token)

    return {"message": "If that email exists, a password reset link has been sent"}


@router.post("/reset-password")
async def reset_password(
    data: ResetPassword,
    db: AsyncSession = Depends(get_db),
) -> dict:
    """Reset password using token from email."""
    token_hash = _hash_token(data.token)

    result = await db.execute(
        select(User).where(
            User.password_reset_token == token_hash,
            User.password_reset_expires > datetime.now(timezone.utc),
        )
    )
    user = result.scalar_one_or_none()

    if user is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired reset token",
        )

    # Update password
    user.password_hash = get_password_hash(data.new_password)
    user.password_reset_token = None
    user.password_reset_expires = None

    # Revoke all refresh tokens for security
    await db.execute(delete(RefreshToken).where(RefreshToken.user_id == user.id))

    return {"message": "Password reset successfully"}


@router.post("/apple", response_model=Token)
async def apple_sign_in(
    data: AppleSignIn,
    db: AsyncSession = Depends(get_db),
) -> Token:
    """Sign in with Apple. Creates account if new user.

    Note: Apple only provides email and name on FIRST authorization.
    The iOS client must cache and send these on subsequent sign-ins.
    """
    try:
        # Verify the identity token with Apple
        apple_data = apple_sign_in_service.verify_identity_token(data.identity_token)
    except AppleSignInError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
        )

    apple_user_id = apple_data["apple_user_id"]

    # Check if user exists by apple_id
    result = await db.execute(select(User).where(User.apple_id == apple_user_id))
    user = result.scalar_one_or_none()

    if user is None:
        # New user - create account
        # Email comes from token on first auth, or from client cache
        email = apple_data.get("email") or data.email
        if not email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Email required for new Apple Sign In users",
            )

        # Check if email already registered (different auth method)
        result = await db.execute(select(User).where(User.email == email))
        existing_user = result.scalar_one_or_none()

        if existing_user is not None:
            # Link Apple ID to existing account
            existing_user.apple_id = apple_user_id
            user = existing_user
        else:
            # Create new user
            user = User(
                email=email,
                apple_id=apple_user_id,
                email_verified=apple_data.get("email_verified", False),
            )
            db.add(user)
            await db.flush()

            # Create default Favorites Playbook for new user
            favorites = Playbook(
                user_id=user.id,
                name="Favorites",
                icon="star.fill",  # SF Symbol name
                is_system=True,
            )
            db.add(favorites)

    # Create tokens
    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token(user.id)

    # Store refresh token
    await _store_refresh_token(db, user.id, refresh_token)

    return Token(access_token=access_token, refresh_token=refresh_token)
