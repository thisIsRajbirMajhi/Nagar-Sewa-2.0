# Authentication

## Overview

Email/password authentication via Supabase Auth with email verification, password reset, and deep linking for mobile callbacks.

## Flow

```
Splash Screen
    │
    ▼
Check auth state
    │
    ├── Authenticated → Dashboard
    └── Unauthenticated → Login
```

## Screens

### SplashScreen
- Initializes Supabase client
- Checks connectivity
- Requests location permissions
- Redirects based on auth state

### LoginScreen
- Email/password form with validation
- Links to forgot password and registration
- Deep link handling for OAuth callbacks

### RegisterScreen
- Full name, email, phone, password fields
- Password strength indicator
- Email verification sent on success

### ForgotPasswordScreen
- Email input for password reset
- Redirects to PasswordResetSentScreen

### PasswordResetSentScreen
- Confirmation that reset email was sent
- Link back to login

## Deep Linking

```
Scheme: io.supabase.nagarsewa
Host: login-callback
Full URL: io.supabase.nagarsewa://login-callback/
```

Used for:
- OAuth callbacks
- Password reset links
- Email confirmation links

## Auth Guards

GoRouter redirect logic:
- Unauthenticated + protected route → `/login`
- Authenticated + auth route → `/dashboard`
- SplashScreen handles its own navigation

## Session Management

- JWT tokens managed by Supabase client
- Tokens auto-refreshed
- Session cleared on logout
- Chat history cleared on logout via `handleLogout(ref)`

## Security

- Email verification required before accessing protected routes
- Password strength validation on client
- Supabase RLS enforces data access at database level
