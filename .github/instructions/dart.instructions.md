---
applyTo: '**/*.dart'
---

# General
- ALWAYS write clean, readable, maintainable, explicit code.
- ALWAYS write code that is easy to refactor and reason about.
- NEVER assume context or generate code that I did not explicitly request.

# Documentation
- ALWAYS place a `///` library-level documentation block (before imports) ONLY on:
  - lib/<package>.dart (the main public entrypoint)
  - a small number of intentionally exposed public sub-libraries
- NEVER add library file-docs on internal files inside `src/`
- ALWAYS keep package-surface documentation concise, stable, and user-facing
- ALWAYS write Dart-doc (`///`) for:
  - every class
  - every constructor
  - every public and private method
  - every important field/property
- ALWAYS add inline comments INSIDE methods explaining **why** something is done (preferred) or **what** it does if unclear.
- NEVER generate README / docs / summary files unless explicitly asked.

# Code Style
- ALWAYS use long, descriptive variable and method names. NEVER use abbreviations.
- ALWAYS use explicit return types — NEVER rely on type inference for public API surfaces.
- ALWAYS avoid hidden behavior or magic — explain reasons in comments.
- NEVER use `dynamic` unless explicitly requested.
- NEVER swallow exceptions — failures must be explicit and documented.

# Package Modularity
- ALWAYS organize code by feature or concept, NOT by layers (domain/app/infrastructure/etc.).
- ALWAYS keep related classes in the same folder to avoid unnecessary cross-navigation.
- ALWAYS aim for package-internal cohesion: a feature should be usable independently of others.
- NEVER introduce folders like `domain`, `application`, `infrastructure`, `presentation` inside a package unless explicitly asked.
- ALWAYS design APIs as small, composable, orthogonal units that can be imported independently.
- ALWAYS hide internal details using file-private symbols or exports from a single public interface file.
- ALWAYS expose only few careful public entrypoints through `package_name.dart`.
- NEVER expose cluttered API surfaces; keep users' imports short and predictable.

# Asynchronous / IO
- ALWAYS suffix async methods with `Async`.
- NEVER do IO inside constructors.
- ALWAYS document async side-effects.

# Constants
- NEVER implement magic values.
- ALWAYS elevate numbers, strings, durations, etc. to named constants.

# Assumptions
- IF details are missing, ALWAYS state assumptions **above the code** before writing it.
- NEVER introduce global state unless explicitly required.

# API Design
- ALWAYS think in terms of public API surface: every public symbol must be intentionally exposed and supported long-term.
- ALWAYS hide implementation details behind internal files.
- ALWAYS consider whether adding a type forces future backwards-compatibility.
- ALWAYS design for testability (stateless helpers, pure functions, injectable dependencies).

# Folder Hygiene
- NEVER create folders "just in case."
- ALWAYS delete dead code aggressively.
- ALWAYS keep `src/` readable even after 2 years of growth.

# Code Hygiene
- NEVER implement barrel export files.
- ALWAYS write code that compiles with ZERO warnings, errors, or analyzer hints.
- ALWAYS remove unused imports, unused variables, unused private fields, and unreachable code.
- ALWAYS prefer explicit typing to avoid inference warnings.
- ALWAYS mark classes, methods, or variables as `@visibleForTesting` or private when they are not part of the public API.
- NEVER ignore analyzer warnings with `// ignore:` unless explicitly asked.
- ALWAYS keep lint and style problems in VSCode Problems panel at ZERO, unless unavoidable and explicitly justified in comments.
