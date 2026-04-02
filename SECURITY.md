# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.1.x   | :white_check_mark: |
| < 1.1   | :x:                |

## Reporting a Vulnerability

We take the security of Nagar Sewa seriously. If you believe you have found a security vulnerability, please report it to us as described below.

**Please do NOT report security vulnerabilities through public GitHub issues.**

Instead, please report them via:

1. **Email**: [your-email@example.com](mailto:your-email@example.com)
2. **GitHub Security Advisory**: Use the [private reporting feature](https://github.com/thisIsRajbirMajhi/Nagar-Sewa-2.0/security/advisories/new)

Please include the following information in your report:

- Type of vulnerability (e.g., XSS, SQL injection, auth bypass, data exposure)
- Affected component (Flutter app, Supabase functions, Edge Functions, etc.)
- Steps to reproduce or proof of concept
- Potential impact
- Suggested fix (if you have one)

## What to Expect

- **Acknowledgment**: We will acknowledge receipt of your report within **48 hours**
- **Assessment**: We will assess the vulnerability and provide an initial response within **7 days**
- **Resolution**: We aim to resolve critical vulnerabilities within **30 days**
- **Credit**: We will credit you in the release notes (unless you prefer to remain anonymous)

## Security Best Practices

When contributing to this project, please follow these guidelines:

### Credentials

- **Never** commit secrets, API keys, or credentials to the repository
- Use `.env` files for local development (already in `.gitignore`)
- Use Supabase Edge Function secrets for server-side keys
- Rotate any accidentally exposed credentials immediately

### Authentication & Authorization

- Always rely on Supabase Row Level Security (RLS) for data access control
- Never bypass auth checks in client-side code
- Validate all user input on both client and server

### Data Handling

- Never log sensitive user data (tokens, passwords, PII)
- Use HTTPS for all network communication
- Validate and sanitize all user inputs

### Dependencies

- Keep dependencies up to date
- Review `pubspec.yaml` changes carefully
- Dependabot is configured for automated security updates

## Security Architecture

The application implements multiple security layers:

- **Authentication**: Supabase Auth with JWT tokens
- **Authorization**: Row Level Security (RLS) policies on all tables
- **Rate Limiting**: Per-user rate limits on AI Edge Functions
- **Media Verification**: EXIF validation, GPS comparison, timestamp analysis
- **Data Encryption**: Supabase handles encryption at rest and in transit

## Disclosure Policy

- We follow responsible disclosure
- We will coordinate with you before any public disclosure
- We prefer a 90-day disclosure timeline
- We will publish a security advisory once the issue is resolved
