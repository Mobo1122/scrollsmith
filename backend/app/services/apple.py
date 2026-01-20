"""Apple Sign In token verification service."""

import logging
from typing import Optional

import jwt
from jwt import PyJWKClient

from app.core.config import settings

logger = logging.getLogger(__name__)

# Apple's JWKS endpoint for public keys
APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"
APPLE_ISSUER = "https://appleid.apple.com"

# Cache JWKS client for performance
_jwks_client: Optional[PyJWKClient] = None


def _get_jwks_client() -> PyJWKClient:
    """Get or create cached JWKS client."""
    global _jwks_client
    if _jwks_client is None:
        _jwks_client = PyJWKClient(APPLE_JWKS_URL)
    return _jwks_client


class AppleSignInError(Exception):
    """Error during Apple Sign In verification."""
    pass


class AppleSignInService:
    """Service for verifying Apple Sign In identity tokens."""

    def __init__(self, bundle_id: str):
        """Initialize with app's bundle ID (audience for token validation)."""
        self.bundle_id = bundle_id

    def verify_identity_token(self, identity_token: str) -> dict:
        """Verify an Apple identity token and extract user info.

        Args:
            identity_token: The JWT identity token from Apple Sign In

        Returns:
            dict with keys:
                - apple_user_id: Unique, stable identifier for the user
                - email: User's email (may be private relay address)
                - email_verified: Whether Apple has verified the email

        Raises:
            AppleSignInError: If token validation fails
        """
        try:
            # Get the signing key that matches the token's kid header
            jwks_client = _get_jwks_client()
            signing_key = jwks_client.get_signing_key_from_jwt(identity_token)

            # Decode and verify the token
            payload = jwt.decode(
                identity_token,
                signing_key.key,
                algorithms=["RS256"],
                audience=self.bundle_id,
                issuer=APPLE_ISSUER,
            )

            # Extract user information
            apple_user_id = payload.get("sub")
            if not apple_user_id:
                raise AppleSignInError("Missing 'sub' claim in token")

            return {
                "apple_user_id": apple_user_id,
                "email": payload.get("email"),
                "email_verified": payload.get("email_verified", False),
            }

        except jwt.ExpiredSignatureError:
            logger.warning("Apple identity token expired")
            raise AppleSignInError("Apple identity token expired")

        except jwt.InvalidAudienceError:
            logger.warning(f"Invalid audience in Apple token (expected {self.bundle_id})")
            raise AppleSignInError("Invalid token audience")

        except jwt.InvalidIssuerError:
            logger.warning("Invalid issuer in Apple token")
            raise AppleSignInError("Invalid token issuer")

        except jwt.PyJWKClientError as e:
            logger.error(f"Failed to fetch Apple JWKS: {e}")
            raise AppleSignInError("Failed to verify token signing key")

        except jwt.InvalidTokenError as e:
            logger.warning(f"Invalid Apple token: {e}")
            raise AppleSignInError("Invalid Apple identity token")

        except Exception as e:
            logger.error(f"Unexpected error verifying Apple token: {e}")
            raise AppleSignInError("Failed to verify Apple identity token")


# Singleton instance configured with bundle ID from settings
apple_sign_in_service = AppleSignInService(settings.APPLE_BUNDLE_ID)
