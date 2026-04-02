---
name: Documentation Improvement
description: Suggest improvements to documentation
title: '[DOCS] '
labels: ['documentation']
assignees: []
body:
  - type: markdown
    attributes:
      value: |
        Help us improve our documentation!

  - type: dropdown
    id: doc-type
    attributes:
      label: Documentation Type
      options:
        - README
        - Setup Guide
        - Architecture Docs
        - API Reference
        - Contributing Guide
        - Other
    validations:
      required: true

  - type: textarea
    id: description
    attributes:
      label: What needs improvement?
      description: Describe what's missing, unclear, or outdated.
    validations:
      required: true

  - type: textarea
    id: suggestion
    attributes:
      label: Suggested Changes
      description: What should the documentation say instead?
