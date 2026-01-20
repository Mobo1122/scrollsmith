"""Email service using Resend for transactional emails."""

import logging
from typing import Optional

from app.core.config import settings

logger = logging.getLogger(__name__)

# Lazy import to avoid errors when RESEND_API_KEY is not set
_resend = None


def _get_resend():
    """Lazy load Resend client."""
    global _resend
    if _resend is None:
        import resend
        resend.api_key = settings.RESEND_API_KEY
        _resend = resend
    return _resend


class EmailService:
    """Service for sending transactional emails via Resend."""

    def __init__(self):
        self.from_email = f"Scrollsmith <noreply@{self._get_domain()}>"
        self.enabled = bool(settings.RESEND_API_KEY)

    def _get_domain(self) -> str:
        """Extract domain from APP_URL or use default."""
        # In production, this should be your verified domain
        # For development/testing, Resend allows onboarding@resend.dev
        if settings.ENVIRONMENT == "production":
            # Extract domain from APP_URL
            from urllib.parse import urlparse
            parsed = urlparse(settings.APP_URL)
            return parsed.netloc or "scrollsmith.app"
        return "resend.dev"

    def send_verification_email(self, to_email: str, verification_token: str) -> bool:
        """Send email verification link.

        Returns True if email was sent successfully.
        """
        if not self.enabled:
            logger.warning("Email service disabled (no RESEND_API_KEY)")
            return False

        verification_url = f"{settings.APP_URL}/verify-email?token={verification_token}"

        try:
            resend = _get_resend()
            params = {
                "from": self.from_email,
                "to": [to_email],
                "subject": "Verify your Scrollsmith email",
                "html": self._verification_email_template(verification_url),
            }
            response = resend.Emails.send(params)
            logger.info(f"Verification email sent to {to_email}: {response}")
            return True
        except Exception as e:
            logger.error(f"Failed to send verification email to {to_email}: {e}")
            return False

    def send_password_reset_email(self, to_email: str, reset_token: str) -> bool:
        """Send password reset link.

        Returns True if email was sent successfully.
        """
        if not self.enabled:
            logger.warning("Email service disabled (no RESEND_API_KEY)")
            return False

        reset_url = f"{settings.APP_URL}/reset-password?token={reset_token}"

        try:
            resend = _get_resend()
            params = {
                "from": self.from_email,
                "to": [to_email],
                "subject": "Reset your Scrollsmith password",
                "html": self._password_reset_email_template(reset_url),
            }
            response = resend.Emails.send(params)
            logger.info(f"Password reset email sent to {to_email}: {response}")
            return True
        except Exception as e:
            logger.error(f"Failed to send password reset email to {to_email}: {e}")
            return False

    def _verification_email_template(self, verification_url: str) -> str:
        """HTML template for verification email."""
        return f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 600px; margin: 0 auto; padding: 40px 20px;">
            <h1 style="color: #1a1a1a; font-size: 24px; margin-bottom: 24px;">Welcome to Scrollsmith!</h1>

            <p style="color: #4a4a4a; font-size: 16px; line-height: 1.6;">
                Thanks for signing up. Please verify your email address by clicking the button below.
            </p>

            <a href="{verification_url}"
               style="display: inline-block; background-color: #007AFF; color: white; padding: 14px 28px; text-decoration: none; border-radius: 8px; font-weight: 600; margin: 24px 0;">
                Verify Email
            </a>

            <p style="color: #888; font-size: 14px; margin-top: 32px;">
                This link expires in 24 hours. If you didn't create a Scrollsmith account, you can ignore this email.
            </p>

            <hr style="border: none; border-top: 1px solid #eee; margin: 32px 0;">

            <p style="color: #888; font-size: 12px;">
                If the button doesn't work, copy and paste this link into your browser:<br>
                <a href="{verification_url}" style="color: #007AFF;">{verification_url}</a>
            </p>
        </body>
        </html>
        """

    def _password_reset_email_template(self, reset_url: str) -> str:
        """HTML template for password reset email."""
        return f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 600px; margin: 0 auto; padding: 40px 20px;">
            <h1 style="color: #1a1a1a; font-size: 24px; margin-bottom: 24px;">Reset your password</h1>

            <p style="color: #4a4a4a; font-size: 16px; line-height: 1.6;">
                We received a request to reset your Scrollsmith password. Click the button below to create a new password.
            </p>

            <a href="{reset_url}"
               style="display: inline-block; background-color: #007AFF; color: white; padding: 14px 28px; text-decoration: none; border-radius: 8px; font-weight: 600; margin: 24px 0;">
                Reset Password
            </a>

            <p style="color: #888; font-size: 14px; margin-top: 32px;">
                This link expires in 1 hour. If you didn't request a password reset, you can ignore this email—your password will remain unchanged.
            </p>

            <hr style="border: none; border-top: 1px solid #eee; margin: 32px 0;">

            <p style="color: #888; font-size: 12px;">
                If the button doesn't work, copy and paste this link into your browser:<br>
                <a href="{reset_url}" style="color: #007AFF;">{reset_url}</a>
            </p>
        </body>
        </html>
        """


# Singleton instance
email_service = EmailService()
