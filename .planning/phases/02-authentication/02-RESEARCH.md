# Phase 2: Authentication - Research

**Researched:** 2026-01-20
**Domain:** FastAPI Backend + iOS SwiftUI Authentication
**Confidence:** HIGH

## Summary

This research covers the complete authentication stack for a FastAPI backend with iOS SwiftUI frontend. The domain has matured significantly, with clear best practices emerging around JWT token management, password hashing, email verification, and Apple Sign In.

The primary finding is that the FastAPI ecosystem has shifted away from previously recommended libraries: **PyJWT** has replaced python-jose (which was unmaintained until recently), and **pwdlib with Argon2** has replaced passlib with bcrypt. These changes are reflected in official FastAPI documentation as of 2025.

For email services, **Resend** offers the best developer experience for transactional emails, while iOS Keychain remains the only acceptable storage mechanism for JWT tokens on mobile.

**Primary recommendation:** Use PyJWT + pwdlib + Resend for backend auth, KeychainAccess for iOS token storage, implement refresh token rotation with short-lived access tokens (15 min) and long-lived refresh tokens (7 days).

## Standard Stack

The established libraries/tools for this domain:

### Core Backend (FastAPI)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| PyJWT | 2.x | JWT encode/decode | Actively maintained, FastAPI docs now recommend over python-jose |
| pwdlib[argon2] | 0.2.x | Password hashing | Modern replacement for passlib, works with Python 3.13+ |
| cryptography | 41.x+ | RSA operations for Apple Sign In | Required for PyJWT RS256 algorithms |

### Supporting Backend

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| resend | 2.19.x | Transactional email | Email verification, password reset |
| python-multipart | 0.0.x | Form data parsing | Required for OAuth2PasswordRequestForm |
| slowapi | 0.1.x | Rate limiting | Protect /login and /refresh endpoints |

### iOS (SwiftUI)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| KeychainAccess | 4.2.x | Secure token storage | Simple Keychain wrapper, widely adopted |
| AuthenticationServices | Native | Apple Sign In | Apple's official framework |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| PyJWT | python-jose | python-jose released v3.5.0 in May 2025 after long hiatus; now viable if you need JWE encryption |
| pwdlib | passlib | passlib won't work on Python 3.13+; only use for legacy hash migration |
| Resend | SendGrid | SendGrid removes free tier May 2025; more features but more complex |
| Resend | AWS SES | $0.10/1000 emails but 2-4 hour setup, no dashboard |
| KeychainAccess | Native Security framework | More control but verbose boilerplate |

**Installation (Backend):**
```bash
pip install PyJWT "pwdlib[argon2]" cryptography resend python-multipart slowapi
```

**Installation (iOS - Swift Package Manager):**
```swift
// Package.swift or Xcode > File > Add Packages
.package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.0")
```

## Architecture Patterns

### Recommended Backend Structure
```
src/
├── auth/
│   ├── __init__.py
│   ├── router.py           # /login, /register, /refresh, /logout endpoints
│   ├── service.py          # Business logic (authenticate, create_tokens)
│   ├── dependencies.py     # get_current_user, require_auth
│   ├── schemas.py          # Token, TokenData, UserCreate pydantic models
│   ├── security.py         # Password hashing, JWT operations
│   └── apple.py            # Apple Sign In verification
├── users/
│   ├── __init__.py
│   ├── models.py           # User SQLAlchemy model
│   └── repository.py       # Database operations
└── email/
    ├── __init__.py
    ├── service.py          # Send verification, password reset
    └── templates.py        # Email HTML templates
```

### iOS Structure
```
App/
├── Services/
│   ├── AuthService.swift       # Login, logout, token refresh
│   ├── KeychainService.swift   # Token storage wrapper
│   └── AppleSignInService.swift
├── Models/
│   ├── AuthTokens.swift        # Access/refresh token model
│   └── User.swift
└── ViewModels/
    └── AuthViewModel.swift     # Observable auth state
```

### Pattern 1: Dual Token Authentication

**What:** Use short-lived access tokens (15 min) with long-lived refresh tokens (7 days). Access tokens authorize API requests; refresh tokens obtain new access tokens.

**When to use:** All mobile apps requiring persistent sessions.

**Example (Backend):**
```python
# Source: https://fastapi.tiangolo.com/tutorial/security/oauth2-jwt/
from datetime import datetime, timedelta, timezone
import jwt
from pwdlib import PasswordHash

SECRET_KEY = "your-secret-key-from-env"  # openssl rand -hex 32
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 15
REFRESH_TOKEN_EXPIRE_DAYS = 7

password_hash = PasswordHash.recommended()

def create_access_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire, "type": "access"})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)

def create_refresh_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.now(timezone.utc) + timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    to_encode.update({"exp": expire, "type": "refresh"})
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
```

### Pattern 2: Refresh Token Rotation

**What:** Issue new refresh token each time one is used; invalidate the old one. Prevents replay attacks if refresh token is stolen.

**When to use:** Production mobile apps with security requirements.

**Example:**
```python
# Store refresh tokens in database with one-token-per-user policy
async def refresh_tokens(refresh_token: str, db: Session):
    try:
        payload = jwt.decode(refresh_token, SECRET_KEY, algorithms=[ALGORITHM])
        if payload.get("type") != "refresh":
            raise HTTPException(status_code=401, detail="Invalid token type")

        user_id = payload.get("sub")

        # Verify token exists in database (not revoked)
        stored_token = db.query(RefreshToken).filter(
            RefreshToken.user_id == user_id,
            RefreshToken.token == refresh_token
        ).first()

        if not stored_token:
            raise HTTPException(status_code=401, detail="Token revoked")

        # Delete old token (rotation)
        db.delete(stored_token)

        # Create new tokens
        new_access = create_access_token({"sub": user_id})
        new_refresh = create_refresh_token({"sub": user_id})

        # Store new refresh token
        db.add(RefreshToken(user_id=user_id, token=new_refresh))
        db.commit()

        return {"access_token": new_access, "refresh_token": new_refresh}
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Refresh token expired")
```

### Pattern 3: iOS Keychain Token Storage

**What:** Store JWT tokens in iOS Keychain, never in UserDefaults or local storage.

**When to use:** Always for any authentication tokens.

**Example (iOS):**
```swift
// Source: https://github.com/kishikawakatsumi/KeychainAccess
import KeychainAccess

class KeychainService {
    private let keychain = Keychain(service: "com.yourapp.auth")
        .accessibility(.whenUnlockedThisDeviceOnly)

    private let accessTokenKey = "access_token"
    private let refreshTokenKey = "refresh_token"

    func saveTokens(access: String, refresh: String) throws {
        try keychain.set(access, key: accessTokenKey)
        try keychain.set(refresh, key: refreshTokenKey)
    }

    func getAccessToken() -> String? {
        try? keychain.get(accessTokenKey)
    }

    func getRefreshToken() -> String? {
        try? keychain.get(refreshTokenKey)
    }

    func clearTokens() throws {
        try keychain.remove(accessTokenKey)
        try keychain.remove(refreshTokenKey)
    }
}
```

### Pattern 4: Apple Sign In Verification

**What:** Validate Apple identity token on backend using Apple's JWKS public keys.

**When to use:** Any app offering Sign In with Apple.

**Example:**
```python
# Source: https://gist.github.com/davidhariri/b053787aabc9a8a9cc0893244e1549fe
import jwt
from jwt import PyJWKClient

APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"
APPLE_ISSUER = "https://appleid.apple.com"
APPLE_AUDIENCE = "com.yourapp.bundleid"  # Your app's bundle ID

jwks_client = PyJWKClient(APPLE_JWKS_URL)

async def verify_apple_token(identity_token: str) -> dict:
    try:
        # Get signing key matching token's kid header
        signing_key = jwks_client.get_signing_key_from_jwt(identity_token)

        # Decode and verify
        payload = jwt.decode(
            identity_token,
            signing_key.key,
            algorithms=["RS256"],
            audience=APPLE_AUDIENCE,
            issuer=APPLE_ISSUER
        )

        return {
            "apple_user_id": payload["sub"],  # Unique, stable identifier
            "email": payload.get("email"),    # May be None for returning users
            "email_verified": payload.get("email_verified", False)
        }
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Apple token expired")
    except jwt.InvalidAudienceError:
        raise HTTPException(status_code=401, detail="Invalid audience")
    except Exception as e:
        raise HTTPException(status_code=401, detail="Invalid Apple token")
```

### Anti-Patterns to Avoid

- **Storing tokens in UserDefaults (iOS):** Not encrypted, trivially readable. Always use Keychain.
- **Long-lived access tokens (>30 min):** Increases damage window if token stolen.
- **Not rotating refresh tokens:** Stolen refresh tokens remain valid indefinitely.
- **Storing plaintext passwords:** Always hash with pwdlib/Argon2.
- **Using `random` for tokens:** Use `secrets` module for cryptographic randomness.
- **Hardcoding SECRET_KEY:** Always load from environment variables.

## Don't Hand-Roll

Problems that look simple but have existing solutions:

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Password hashing | Custom hash function | pwdlib with Argon2 | Timing attacks, salt management, algorithm tuning |
| JWT creation/validation | Manual base64 + HMAC | PyJWT | Header parsing, claim validation, algorithm support |
| Secure random tokens | `random.choice()` | `secrets.token_urlsafe()` | Cryptographic randomness required |
| Email delivery | SMTP library directly | Resend SDK | Deliverability, SPF/DKIM, bounce handling |
| Apple token verification | Manual JWKS parsing | PyJWKClient | Key rotation, kid matching, algorithm verification |
| iOS token storage | UserDefaults/files | Keychain + KeychainAccess | Hardware encryption, Secure Enclave |
| Rate limiting | Custom middleware | slowapi | Token bucket algorithms, distributed state |

**Key insight:** Authentication is a high-stakes domain where subtle implementation errors (timing attacks, weak randomness, improper validation) create exploitable vulnerabilities. The libraries handle edge cases you won't anticipate.

## Common Pitfalls

### Pitfall 1: Apple Sign In Returns Email/Name Only Once

**What goes wrong:** App fails to capture user's email on first Apple Sign In, then can never retrieve it again.

**Why it happens:** Apple only shares email and name during initial authorization for privacy. Subsequent logins only return the stable `sub` identifier.

**How to avoid:**
1. Cache credentials immediately on first auth before any server call
2. Retry server submission if it fails before clearing cached data
3. Store email in your database on first successful registration

**Warning signs:** Users report they can't complete registration; logs show missing email on sign-in attempts.

### Pitfall 2: Expired Token During Email Verification

**What goes wrong:** User clicks verification link hours/days later, token has expired.

**Why it happens:** Verification tokens set with same expiry as access tokens (15 min).

**How to avoid:** Use longer expiry for email verification tokens (24-48 hours). Store token hash in database with explicit expiry timestamp.

**Warning signs:** Support tickets about "expired" verification links.

### Pitfall 3: Keychain Items Persist After App Uninstall

**What goes wrong:** User reinstalls app, gets logged in as previous user or hits conflicts.

**Why it happens:** iOS Keychain items are NOT deleted when app is uninstalled.

**How to avoid:** Check for first-launch flag in UserDefaults (which IS deleted on uninstall). If first launch but Keychain has tokens, clear Keychain.

**Warning signs:** Test devices have stale auth state after reinstall.

```swift
// Clear keychain on first launch
let hasLaunchedKey = "hasLaunchedBefore"
if !UserDefaults.standard.bool(forKey: hasLaunchedKey) {
    try? keychainService.clearTokens()
    UserDefaults.standard.set(true, forKey: hasLaunchedKey)
}
```

### Pitfall 4: Universal Links Break in Email Clients

**What goes wrong:** Verification/reset links open in browser instead of app.

**Why it happens:** Email clients (Gmail, Outlook) wrap links in tracking URLs, breaking Universal Links.

**How to avoid:**
1. Configure AASA file correctly
2. Use direct HTTPS links without redirects
3. Test with actual email clients, not Safari address bar
4. Consider fallback web page that redirects to app

**Warning signs:** Users report links "don't open the app."

### Pitfall 5: passlib Deprecation Warning

**What goes wrong:** Deprecation warnings in logs, will break on Python 3.13+.

**Why it happens:** passlib uses deprecated `crypt` module removed in Python 3.13.

**How to avoid:** Migrate to pwdlib. It can read passlib-generated hashes for backwards compatibility.

**Warning signs:** "DeprecationWarning: 'crypt' is deprecated" in logs.

## Code Examples

Verified patterns from official sources:

### Complete Login Endpoint

```python
# Source: https://fastapi.tiangolo.com/tutorial/security/oauth2-jwt/
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel

router = APIRouter(prefix="/auth", tags=["auth"])

class Token(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"

@router.post("/login", response_model=Token)
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: Session = Depends(get_db)
):
    user = await authenticate_user(db, form_data.username, form_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )

    access_token = create_access_token(data={"sub": str(user.id)})
    refresh_token = create_refresh_token(data={"sub": str(user.id)})

    # Store refresh token in database for rotation
    await store_refresh_token(db, user.id, refresh_token)

    return Token(access_token=access_token, refresh_token=refresh_token)
```

### Password Hashing with pwdlib

```python
# Source: https://fastapi.tiangolo.com/tutorial/security/oauth2-jwt/
from pwdlib import PasswordHash

password_hash = PasswordHash.recommended()

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return password_hash.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    return password_hash.hash(password)
```

### Secure Token Generation for Email Verification

```python
# Source: https://docs.python.org/3/library/secrets.html
import secrets
from datetime import datetime, timedelta

def create_verification_token() -> tuple[str, datetime]:
    """Returns (token, expiry) for email verification."""
    token = secrets.token_urlsafe(32)  # 256 bits of entropy
    expiry = datetime.utcnow() + timedelta(hours=24)
    return token, expiry

def create_password_reset_token() -> tuple[str, datetime]:
    """Returns (token, expiry) for password reset."""
    token = secrets.token_urlsafe(32)
    expiry = datetime.utcnow() + timedelta(hours=1)  # Shorter for security
    return token, expiry
```

### Email Sending with Resend

```python
# Source: https://resend.com/docs/send-with-python
import os
import resend

resend.api_key = os.environ["RESEND_API_KEY"]

def send_verification_email(to_email: str, verification_url: str):
    params = {
        "from": "YourApp <noreply@yourdomain.com>",
        "to": [to_email],
        "subject": "Verify your email address",
        "html": f"""
            <h1>Welcome to YourApp!</h1>
            <p>Please verify your email by clicking the link below:</p>
            <a href="{verification_url}">Verify Email</a>
            <p>This link expires in 24 hours.</p>
        """,
    }
    return resend.Emails.send(params)

def send_password_reset_email(to_email: str, reset_url: str):
    params = {
        "from": "YourApp <noreply@yourdomain.com>",
        "to": [to_email],
        "subject": "Reset your password",
        "html": f"""
            <h1>Password Reset Request</h1>
            <p>Click the link below to reset your password:</p>
            <a href="{reset_url}">Reset Password</a>
            <p>This link expires in 1 hour.</p>
            <p>If you didn't request this, you can ignore this email.</p>
        """,
    }
    return resend.Emails.send(params)
```

### iOS Auth Service

```swift
import Foundation

actor AuthService {
    private let keychainService = KeychainService()
    private let baseURL = URL(string: "https://api.yourapp.com")!

    func login(email: String, password: String) async throws -> User {
        var request = URLRequest(url: baseURL.appendingPathComponent("/auth/login"))
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "username=\(email)&password=\(password)"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.invalidCredentials
        }

        let tokens = try JSONDecoder().decode(AuthTokens.self, from: data)
        try keychainService.saveTokens(access: tokens.accessToken, refresh: tokens.refreshToken)

        return try await fetchCurrentUser()
    }

    func refreshTokens() async throws {
        guard let refreshToken = keychainService.getRefreshToken() else {
            throw AuthError.noRefreshToken
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("/auth/refresh"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["refresh_token": refreshToken])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            try keychainService.clearTokens()
            throw AuthError.refreshFailed
        }

        let tokens = try JSONDecoder().decode(AuthTokens.self, from: data)
        try keychainService.saveTokens(access: tokens.accessToken, refresh: tokens.refreshToken)
    }
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| passlib + bcrypt | pwdlib + Argon2 | 2024-2025 | passlib breaks on Python 3.13; Argon2 is PHC winner |
| python-jose | PyJWT | 2024-2025 | python-jose was unmaintained 2021-2025; FastAPI docs updated |
| Firebase Dynamic Links | Universal Links (native) | August 2025 | Firebase Dynamic Links deprecated |
| SendGrid free tier | Resend free tier | May 2025 | SendGrid removing free tier |
| Single long-lived token | Access + Refresh tokens | Established | Industry standard for mobile apps |

**Deprecated/outdated:**
- **passlib:** Use pwdlib instead. Can still read legacy passlib hashes.
- **python-jose (pre-3.5.0):** Unmaintained 2021-2025. Version 3.5.0 (May 2025) revived it.
- **Firebase Dynamic Links:** Shutting down August 2025. Use native Universal Links.
- **UserDefaults for tokens:** Never acceptable. Use Keychain.

## Open Questions

Things that couldn't be fully resolved:

1. **python-jose vs PyJWT post-May 2025**
   - What we know: python-jose released 3.5.0 in May 2025 after years of inactivity
   - What's unclear: Whether maintenance will continue; FastAPI still recommends PyJWT
   - Recommendation: Use PyJWT for new projects; python-jose viable if you need JWE

2. **pwdlib maturity**
   - What we know: Created by FastAPI Users maintainer, used in FastAPI official docs
   - What's unclear: Long-term maintenance commitment, community adoption breadth
   - Recommendation: Use pwdlib; it's the official recommendation and handles migration from passlib

3. **Optimal token expiration times**
   - What we know: Access 15-30 min, Refresh 7-30 days are common
   - What's unclear: No universal "correct" answer; depends on security vs UX tradeoff
   - Recommendation: Start with access=15min, refresh=7days; adjust based on user feedback

## Sources

### Primary (HIGH confidence)
- [FastAPI Official Documentation - OAuth2 JWT](https://fastapi.tiangolo.com/tutorial/security/oauth2-jwt/) - Password hashing, JWT creation, authentication flow
- [Python secrets module](https://docs.python.org/3/library/secrets.html) - Secure token generation
- [KeychainAccess GitHub](https://github.com/kishikawakatsumi/KeychainAccess) - iOS Keychain wrapper API

### Secondary (MEDIUM confidence)
- [pwdlib PyPI](https://pypi.org/project/pwdlib/) - Modern password hashing
- [Resend Python SDK](https://resend.com/docs/send-with-python) - Email API
- [Apple Sign In verification gist](https://gist.github.com/davidhariri/b053787aabc9a8a9cc0893244e1549fe) - Token verification pattern
- [DEV.to Apple Sign In guide](https://dev.to/amzar/guide-to-validating-sign-in-with-apple-tokens-in-python-13fm) - Implementation details

### Tertiary (LOW confidence - from WebSearch)
- Token expiration time recommendations (varies by source)
- Email service comparison pricing (may change)

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - Official FastAPI docs, PyPI releases verified
- Architecture patterns: HIGH - Established patterns with code from official sources
- Pitfalls: MEDIUM - Community reports and developer forums
- Apple Sign In: MEDIUM - Gists and tutorials, not official Apple docs (requires JavaScript)

**Research date:** 2026-01-20
**Valid until:** 2026-02-20 (30 days - stable domain, but check for library updates)
