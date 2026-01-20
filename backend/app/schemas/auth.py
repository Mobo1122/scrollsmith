"""Authentication request/response schemas."""

from pydantic import BaseModel, EmailStr, Field


class UserCreate(BaseModel):
    """Schema for user registration."""

    email: EmailStr
    password: str = Field(..., min_length=8, description="Password must be at least 8 characters")


class UserLogin(BaseModel):
    """Schema for user login (used with OAuth2PasswordRequestForm alternative)."""

    email: EmailStr
    password: str


class Token(BaseModel):
    """Schema for token response after login/register."""

    access_token: str
    refresh_token: str
    token_type: str = "bearer"


class TokenRefresh(BaseModel):
    """Schema for refresh token request."""

    refresh_token: str


class AppleSignIn(BaseModel):
    """Schema for Apple Sign In request."""

    identity_token: str
    email: EmailStr | None = None
    full_name: str | None = None


class VerifyEmail(BaseModel):
    """Schema for email verification."""

    token: str


class ForgotPassword(BaseModel):
    """Schema for password reset request."""

    email: EmailStr


class ResetPassword(BaseModel):
    """Schema for password reset."""

    token: str
    new_password: str = Field(..., min_length=8)
