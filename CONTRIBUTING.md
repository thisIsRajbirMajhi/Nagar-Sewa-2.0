# Contributing to Nagar Sewa

Thank you for your interest in contributing! This project is a civic accountability platform for Odisha, India, and every contribution helps improve governance.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Commit Messages](#commit-messages)
- [Pull Requests](#pull-requests)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Features](#suggesting-features)

## Code of Conduct

This project follows our [Code of Conduct](CODE_OF_CONDUCT.md). Please read it before participating.

## Getting Started

1. **Fork** the repository on GitHub
2. **Clone** your fork locally
3. **Set up** the development environment:

```bash
flutter pub get
cp .env.example .env
# Edit .env with your credentials
```

4. **Verify** the setup works:

```bash
flutter analyze
flutter test
```

## How to Contribute

### Types of Contributions

- **Bug fixes** — Fix issues reported in the [issue tracker](https://github.com/thisIsRajbirMajhi/Nagar-Sewa-2.0/issues)
- **New features** — Add functionality that aligns with the project's civic accountability mission
- **Documentation** — Improve guides, API docs, or inline comments
- **Translations** — Help support more languages (currently English, Hindi, Odia)
- **Performance improvements** — Optimize rendering, caching, or network usage
- **Security hardening** — Improve authentication, data handling, or dependency management

### Before You Start

1. Check existing [issues](https://github.com/thisIsRajbirMajhi/Nagar-Sewa-2.0/issues) and [pull requests](https://github.com/thisIsRajbirMajhi/Nagar-Sewa-2.0/pulls) to avoid duplicate work
2. For significant changes, open an issue first to discuss the approach
3. Ensure your changes are compatible with Android, iOS, and Web platforms

## Development Workflow

### Branch Naming

```
feature/description     — New features
fix/description         — Bug fixes
docs/description        — Documentation changes
refactor/description    — Code refactoring
chore/description       — Maintenance tasks
```

### Before Submitting

```bash
# Analyze code for issues
flutter analyze

# Format code
dart format .

# Run tests
flutter test

# Check for hardcoded secrets
# Ensure no credentials are in source files
```

## Coding Standards

Follow our [Coding Standards](docs/development/coding-standards.md) guide. Key rules:

- **Architecture**: Feature-first organization with clean architecture
- **State Management**: Riverpod for all state management
- **Naming**: camelCase for variables/functions, PascalCase for classes, snake_case for files
- **Widgets**: Keep widgets under 150 lines; extract complex widgets
- **Error Handling**: Use typed exceptions; never swallow errors silently
- **Imports**: Order as flutter → dart → packages → local imports

## Commit Messages

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
type(scope): description

[optional body]
```

**Types:**
- `feat` — New feature
- `fix` — Bug fix
- `docs` — Documentation changes
- `style` — Formatting, no code change
- `refactor` — Code restructuring, no behavior change
- `test` — Adding or updating tests
- `chore` — Maintenance, config changes

**Examples:**
```
feat(ai): add image tamper detection
fix(auth): resolve session refresh crash
docs(readme): update setup instructions
refactor(services): extract verification logic
```

## Pull Requests

1. **Title**: Use conventional commit format (e.g., `feat: add dark mode`)
2. **Description**: Fill out the PR template
3. **Checklist**:
   - [ ] Code follows coding standards
   - [ ] `flutter analyze` passes with no warnings
   - [ ] Tests added/updated for new functionality
   - [ ] Documentation updated if needed
   - [ ] No secrets or credentials in code
4. **Review**: At least one maintainer approval required
5. **Merge**: Squash and merge after approval

### PR Size

- Keep PRs focused and small (ideally under 400 lines of changes)
- Split large changes into multiple PRs when possible

## Reporting Bugs

Use the [bug report template](https://github.com/thisIsRajbirMajhi/Nagar-Sewa-2.0/issues/new) when filing an issue. Include:

- Flutter and Dart versions
- Device/OS information
- Steps to reproduce
- Expected vs actual behavior
- Screenshots or logs if applicable

## Suggesting Features

Use the [feature request template](https://github.com/thisIsRajbirMajhi/Nagar-Sewa-2.0/issues/new) to suggest improvements. Describe:

- The problem you're solving
- Your proposed solution
- How it benefits users
- Any alternatives you've considered

## Questions?

- Check the [documentation](docs/README.md) first
- Search existing [issues](https://github.com/thisIsRajbirMajhi/Nagar-Sewa-2.0/issues)
- Open a new issue with the `question` label
