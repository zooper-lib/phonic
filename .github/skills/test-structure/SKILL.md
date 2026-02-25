---
name: Flutter and Dart Test Structure
description: Enforces consistent test structure and naming conventions for Flutter apps and Dart/Flutter packages in a feature-sliced, DDD-oriented workspace.
---

# Instructions

When generating or modifying tests in this repository, first determine the project type:

- Flutter application
- Pure Dart package
- Flutter widget package
- Infrastructure / adapter package

Apply the corresponding rules below.

---

# 1. Flutter Application

Applications support all test types.

Directory structure:

test/
  unit/
  widget/
  integration/

integration_test/

## 1.1 Unit Tests

Purpose: Validate a single class in isolation.

Rules:
- Mirror the lib/ structure (excluding src/ if present).
- One test file per production class.
- File name: `<file_name>_test.dart`
- Use mocks or fakes.
- No real backend or database.

Example:

lib/features/user/controllers/user_controller.dart  
test/unit/features/user/controllers/user_controller_test.dart  

---

## 1.2 Widget Tests

Purpose: Validate UI composition and interaction.

Rules:
- Mirror presentation layer.
- Use `pumpWidget`.
- Mock domain and infrastructure.
- No real backend logic.

Example:

lib/features/user/presentation/user_profile_page.dart  
test/widget/features/user/presentation/user_profile_page_test.dart  

---

## 1.3 Integration Tests (Application-Level)

Purpose: Validate workflows and capabilities across layers.

Rules:
- Located in test/integration/
- Scenario-driven naming.
- Do NOT mirror lib structure.
- May involve multiple features.
- Prefer in-memory repositories.

Examples:

test/integration/cataloging_flow_test.dart  
test/integration/waveform_generation_flow_test.dart  

---

## 1.4 End-to-End Tests

Purpose: Validate real user journeys.

Located in:

integration_test/

Rules:
- Boot full app.
- Test navigation and real flows.
- Avoid mocks unless strictly required.
- Name by user journey.

Examples:

integration_test/app_startup_test.dart  
integration_test/complete_import_flow_test.dart  

---

# 2. Pure Dart Package

Used for domain logic, utilities, event systems, generators, etc.

Directory structure:

test/
  unit/
  integration/

No integration_test/ folder.

## 2.1 Unit Tests

Rules:
- Mirror lib/ structure (excluding src/).
- One test file per class.
- Fast and deterministic.
- Prefer no mocks unless required.

Example:

lib/src/aggregate/audio_file.dart  
test/unit/aggregate/audio_file_test.dart  

---

## 2.2 Integration Tests (Package-Level)

Purpose: Validate collaboration between components.

Rules:
- Located in test/integration/
- Scenario-driven naming.
- Do NOT mirror lib structure.
- Test real behavior (e.g. round-trips, persistence contracts).

Examples:

test/integration/aggregate_event_roundtrip_test.dart  
test/integration/repository_transaction_test.dart  

---

# 3. Flutter Widget Package

Used for design systems or reusable UI components.

Directory structure:

test/
  unit/
  widget/

No integration_test/.

## Widget Tests

Rules:
- Mirror lib structure.
- Use `pumpWidget`.
- Focus on rendering and interaction.
- Do not test app-level navigation.

---

# 4. Infrastructure / Adapter Package

Used for database adapters, HTTP clients, persistence layers.

Directory structure:

test/
  unit/
  integration/

## Unit

- Test mapping, serialization, configuration.
- No external systems.

## Integration

- May use in-memory database.
- May use local test server.
- Validate transaction behavior and contract adherence.

Example:

test/integration/sqlite_repository_roundtrip_test.dart  

---

# 5. Path Mirroring Rules

When mirroring lib/ structure:
- Skip the src/ directory if present
- lib/src/domain/model.dart → test/unit/domain/model_test.dart
- lib/features/user/user.dart → test/unit/features/user/user_test.dart

# 6. Naming Rules

Unit:
- `<class_name>_test.dart`

Widget:
- `<widget_name>_test.dart`

Integration (apps):
- `<capability>_flow_test.dart`

Integration (packages):
- `<behavior>_contract_test.dart`
- `<behavior>_roundtrip_test.dart`

E2E:
- `<user_journey>_test.dart`

---

# 7. Forbidden Patterns

- Do not mix test types in the same folder.
- Do not mirror lib structure for integration tests.
- Do not place E2E tests inside test/.
- Do not use real backend in unit tests.
- Do not test implementation details in integration tests.

---

# 8. Decision Rule

Before generating a test, determine:

1. Is this a Flutter application?
2. Is this a reusable package?
3. Is this a widget library?
4. Is this an infrastructure adapter?

Then apply the correct structure rules above.
