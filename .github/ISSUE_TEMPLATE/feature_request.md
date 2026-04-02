---
name: Feature Request
description: Suggest an idea for Nagar Sewa
title: '[FEATURE] '
labels: ['enhancement']
assignees: []
body:
  - type: markdown
    attributes:
      value: |
        Thanks for suggesting a feature! Please fill out the sections below.

  - type: dropdown
    id: area
    attributes:
      label: Feature Area
      description: Which area of the app does this relate to?
      options:
        - User Interface
        - Issue Reporting
        - AI / Verification
        - Maps
        - Authentication
        - Offline / Sync
        - Admin Dashboard
        - Performance
        - Other
    validations:
      required: true

  - type: textarea
    id: problem
    attributes:
      label: Problem Statement
      description: Is your feature request related to a problem? Please describe it.
      placeholder: I'm always frustrated when...
    validations:
      required: true

  - type: textarea
    id: solution
    attributes:
      label: Proposed Solution
      description: Describe the solution you'd like.
    validations:
      required: true

  - type: textarea
    id: alternatives
    attributes:
      label: Alternatives Considered
      description: Describe any alternative solutions or features you've considered.

  - type: textarea
    id: benefits
    attributes:
      label: User Benefits
      description: How would this feature benefit users of Nagar Sewa?
    validations:
      required: true

  - type: dropdown
    id: priority
    attributes:
      label: Priority
      description: How important is this feature?
      options:
        - Low — Nice to have
        - Medium — Would improve experience
        - High — Blocks important use cases
    validations:
      required: true

  - type: textarea
    id: additional
    attributes:
      label: Additional Context
      description: Any other context, mockups, or screenshots
