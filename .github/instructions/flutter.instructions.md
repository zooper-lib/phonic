---
applyTo: '**/*.dart'
---

# General
- ALWAYS write clean, readable, maintainable, explicit code.
- ALWAYS write code that is easy to refactor and reason about.
- NEVER assume context or generate code that I did not explicitly request.

# Documentation
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

# Clean Architecture for Flutter apps
- ALWAYS separate responsibilities:
  - domain/: entities, value objects, business rules
  - application/: services, use-cases, orchestrators
  - infrastructure/: concrete implementations, IO, APIs
  - presentation/: Flutter widgets, controllers, adapters
- NEVER mix domain logic inside UI or infrastructure.
- NEVER inject `WidgetRef` or `Ref` into domain/application classes — ONLY resolve dependencies at provider boundaries.

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

# Flutter Widgets
- ALWAYS explain the purpose of a widget in Dart-doc.
- ALWAYS extract callbacks into named functions when possible.
- NEVER override themes or text styles unless explicitly requested.

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
- ALWAYS write code that compiles with ZERO warnings, errors, or analyzer hints.
- ALWAYS remove unused imports, unused variables, unused private fields, and unreachable code.
- ALWAYS prefer explicit typing to avoid inference warnings.
- ALWAYS mark classes, methods, or variables as `@visibleForTesting` or private when they are not part of the public API.
- NEVER ignore analyzer warnings with `// ignore:` unless explicitly asked.
- ALWAYS keep lint and style problems in VSCode Problems panel at ZERO, unless unavoidable and explicitly justified in comments.
