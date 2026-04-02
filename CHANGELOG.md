# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.1.0] - 2026-04-02

### Added
- Admin reports screen with AI-powered report generation
- Officer drafting capability for response management
- AI chatbot integration for user assistance
- Clear chat history on logout

### Fixed
- Resolved 11 critical bugs including setState crashes
- Fixed verification false positives in media analysis
- Corrected category mapping inconsistencies
- Restored recent activity feed functionality
- Fixed map pin detail display issues
- Resolved chat state persistence problems
- Fixed Edge Function timeout issues
- Added local draft fallback for offline scenarios
- Implemented SQLite logging for better debugging
- Fixed service logging across all modules
- Added background sync capability

### Changed
- Restructured documentation with industry-standard organization
- Resolved all flutter analyze warnings
- Secured credentials: moved from source code to environment variables
- Updated .gitignore for open-source readiness
- Added .env.example template for developers

### Security
- Removed hardcoded Supabase URL and anon key from source
- Removed hardcoded Google Maps API key from Android/iOS configs
- Added comprehensive .gitignore for secrets and build artifacts
- Prepared project for public open-source release

## [1.0.0] - 2026-03-31

### Added
- Initial release of Nagar Sewa civic accountability platform
- User authentication with Supabase Auth (login, register, forgot password)
- Issue reporting with photo/video capture and AI-powered image analysis
- Live map with MapLibre GL showing all reported issues
- Dashboard with overview cards and activity feed
- Issue detail tracking with status updates
- Upvote/downvote system for community engagement
- Notification system for issue status changes
- Offline support with Hive caching and sync queue
- Media verification layer (EXIF, GPS, timestamp analysis)
- AI Edge Functions for image analysis, chatbot, drafting, and reporting
- Multi-language support (English, Hindi, Odia)
- Department categorization for 13 issue types
- Draft saving and management
- User profile management
- Admin verification queue for media review

[Unreleased]: https://github.com/thisIsRajbirMajhi/Nagar-Sewa-2.0/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/thisIsRajbirMajhi/Nagar-Sewa-2.0/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/thisIsRajbirMajhi/Nagar-Sewa-2.0/releases/tag/v1.0.0
