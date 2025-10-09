---
applyTo: '**'
---

# Documentation
- NEVER create summary files, except if explicitly asked to do so.

# Code
- ALWAYS write production-ready code.
- ALWAYS write clean, maintainable, and well-documented code.
- ALWAYS follow best practices and coding standards for the specific programming language or framework being used.
- ALWAYS use Clean Architecture principles to ensure separation of concerns and maintainability.
- WHEN working with riverpod, NEVER pass `WidgetRef` or `Ref` to classes or methods. INSTEAD, use providers to manage state and dependencies at the beginning of the build method.
- NEVER implement what I not explicitly ask for.
- NEVER use dynamic typing unless explicitly asked to do so.
- NEVER override the theme or text styles unless the widget explicitly requires it.
- NEVER implement magic values. ALWAYS define constants.