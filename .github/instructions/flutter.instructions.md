---
applyTo: '**/*.dart'
---

# Clean Architecture for Flutter apps
- ALWAYS separate responsibilities:
  - domain/: entities, value objects, business rules
  - application/: services, use-cases, orchestrators
  - infrastructure/: concrete implementations, IO, APIs
  - presentation/: Flutter widgets, controllers, adapters
- NEVER mix domain logic inside UI or infrastructure.
- NEVER inject `WidgetRef` or `Ref` into domain/application classes — ONLY resolve dependencies at provider boundaries.

# Flutter Widgets
- ALWAYS explain the purpose of a widget in Dart-doc.
- ALWAYS extract callbacks into named functions when possible.
- NEVER override themes or text styles unless explicitly requested.