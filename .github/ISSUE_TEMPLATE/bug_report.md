---
name: Bug Report
description: Report a bug to help us improve Nagar Sewa
title: '[BUG] '
labels: ['bug']
assignees: []
body:
  - type: markdown
    attributes:
      value: |
        Thanks for taking the time to fill out this bug report!

  - type: dropdown
    id: platform
    attributes:
      label: Platform
      description: Which platform are you experiencing this on?
      options:
        - Android
        - iOS
        - Web
    validations:
      required: true

  - type: input
    id: version
    attributes:
      label: App Version
      description: What version of the app are you using?
      placeholder: e.g., 1.1.0
    validations:
      required: true

  - type: input
    id: os
    attributes:
      label: OS Version
      description: What OS version are you using?
      placeholder: e.g., Android 14, iOS 17.2, Chrome 120
    validations:
      required: true

  - type: textarea
    id: description
    attributes:
      label: Bug Description
      description: A clear and concise description of what the bug is.
      placeholder: When I tap the report button, the app crashes...
    validations:
      required: true

  - type: textarea
    id: reproduction
    attributes:
      label: Steps to Reproduce
      description: Steps to reproduce the behavior
      placeholder: |
        1. Go to '...'
        2. Tap on '...'
        3. Scroll to '...'
        4. See error
    validations:
      required: true

  - type: textarea
    id: expected
    attributes:
      label: Expected Behavior
      description: What did you expect to happen?
    validations:
      required: true

  - type: textarea
    id: actual
    attributes:
      label: Actual Behavior
      description: What actually happened?
    validations:
      required: true

  - type: textarea
    id: logs
    attributes:
      label: Logs / Stack Trace
      description: If applicable, paste any logs or stack traces
      render: shell

  - type: textarea
    id: screenshots
    attributes:
      label: Screenshots
      description: Add screenshots to help explain the problem

  - type: textarea
    id: additional
    attributes:
      label: Additional Context
      description: Any other context about the problem
